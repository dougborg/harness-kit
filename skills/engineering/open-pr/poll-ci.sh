#!/usr/bin/env bash
# Poll CI status for a PR with timeout.
#
# Usage: poll-ci.sh <pr-number> [timeout-seconds]
# Exit 0: all checks passed
# Exit 1: a check failed or was cancelled (prints failed check details)
# Exit 2: timeout reached (checks still running or not started — NON-terminal)
# Exit 3: error — the PR couldn't be read from GitHub
# Exit 4: CI hasn't finished and the PR conflicts with its base, so GitHub
#         won't run its pull_request workflows; rebase onto the base and push
#
# Output contract: every terminal outcome prints a final line starting with
# "CI RESULT:". While waiting, the script prints a "CI POLL:" heartbeat each
# interval. If captured output ends with a heartbeat (no "CI RESULT:" line),
# the poll was killed mid-wait — e.g. by the Bash tool's default 120s timeout —
# and CI state is UNKNOWN, not complete. Re-poll in that case.
#
# CI counts as passed only when all of these hold:
#   - at least one check has reported, and none is pending or failed;
#   - no workflow run for the PR's head commit is still queued or running
#     (a queued run has no check entries yet, so `gh pr checks` alone misses
#     it);
#   - every status check the base branch's rules require has reported;
#   - the PR's recorded head matches the branch's tip on the remote. GitHub
#     can lag behind a push (seen during an incident), and until it catches up
#     the checks shown belong to the previous commit (#131).
# A transient API failure while polling counts as "not known yet", never as a
# pass or a failure.
#
# Deliberately does not use `gh pr checks --watch`: --watch produces no
# heartbeat and its output, truncated by an external timeout, is
# indistinguishable from a finished run.
#
# Testing: scripts/test-poll-ci.sh puts a stub gh and git first on PATH;
# POLL_CI_INTERVAL overrides the 30s interval.

set -euo pipefail

pr_number="${1:?Usage: poll-ci.sh <pr-number> [timeout-seconds]}"
timeout="${2:-300}" # default 5 minutes
interval="${POLL_CI_INTERVAL:-30}"
elapsed=0

pr_head() {
  gh pr view "$pr_number" --json headRefOid,baseRefName,headRefName,isCrossRepository,mergeable \
    --jq '"\(.headRefOid) \(.baseRefName) \(.headRefName) \(.isCrossRepository) \(.mergeable)"'
}

# The branch's tip on origin, or nothing when it can't be read (no origin,
# a network failure, a deleted branch). Callers skip the check for a fork's
# PR, whose branch lives in another repository.
remote_tip() {
  { git ls-remote origin "refs/heads/$1" 2>/dev/null || true; } | cut -f1
}

head_sha=""
head_ref=""
cross_repo="false"
mergeable="UNKNOWN"
if ! pr_info=$(pr_head); then
  echo "CI RESULT: ERROR for PR #${pr_number} — couldn't read the PR from GitHub (check the number and gh auth)"
  exit 3
fi
read -r head_sha base head_ref cross_repo mergeable <<<"$pr_info"
# Required checks from the branch's effective rules (rulesets). A branch
# with no rules returns an empty list; a failed call means the gate is
# unknown, so say so rather than silently dropping it.
if ! required=$(gh api "repos/{owner}/{repo}/rules/branches/${base}" \
  --jq '[.[] | select(.type == "required_status_checks")
         | .parameters.required_status_checks[].context]'); then
  echo "CI POLL: couldn't read ${base}'s branch rules; required checks are not enforced by this poll" >&2
  required="[]"
fi

checks_json() {
  # "no checks reported" exits non-zero; treat it as an empty list.
  gh pr checks "$pr_number" --json name,bucket 2>/dev/null || echo "[]"
}

# Prints the number of workflows whose latest run for the head commit hasn't
# finished. A newer run of the same workflow (a re-run, or a close and reopen)
# supersedes an older one, so an orphaned older run doesn't hold the poll. On
# an API failure, prints "?" so the poll keeps waiting.
latest_unfinished='group_by(.name) | map(max_by(.createdAt))
  | map(select(.status != "completed")) | length'
active_runs() {
  gh run list --commit "$head_sha" --limit 100 --json name,status,createdAt \
    --jq "$latest_unfinished" 2>/dev/null || echo "?"
}

while true; do
  if pr_info=$(pr_head 2>/dev/null); then
    read -r head_sha base head_ref cross_repo mergeable <<<"$pr_info" # follow a push made during the poll
  else
    mergeable=UNKNOWN # never act on a conflict read before a failed refresh
  fi
  stale=""
  if [ "$cross_repo" != true ]; then
    tip=$(remote_tip "$head_ref")
    if [ -n "$tip" ] && [ -n "$head_sha" ] && [ "$tip" != "$head_sha" ]; then
      stale="PR head ${head_sha:0:7} is behind the branch tip ${tip:0:7}"
    fi
  fi

  checks=$(checks_json)
  failed=$(jq -r '.[] | select(.bucket == "fail" or .bucket == "cancel") | .name' <<<"$checks")
  # While the head is stale, the checks belong to the previous commit: wait.
  if [ -z "$stale" ] && [ -n "$failed" ]; then
    printf 'failed: %s\n' "$failed" >&2
    echo "CI RESULT: FAILED for PR #${pr_number} after ${elapsed}s (see failed checks above)"
    exit 1
  fi

  pending=$(jq '[.[] | select(.bucket == "pending")] | length' <<<"$checks")
  reported=$(jq 'length' <<<"$checks")
  runs=$(active_runs)
  missing=$(jq -rn --argjson req "$required" --argjson checks "$checks" \
    '[$req[] | select(. as $r | [$checks[].name] | index($r) | not)] | join(", ")')

  if [ -z "$stale" ] && [ "$reported" -gt 0 ] && [ "$pending" -eq 0 ] && [ "$runs" = 0 ] && [ -z "$missing" ]; then
    echo "CI RESULT: PASSED for PR #${pr_number} after ${elapsed}s — all checks green"
    exit 0
  fi

  # Not passed or failed yet, and the PR conflicts with its base: GitHub runs
  # no pull_request workflows for it, so waiting would only time out. A null
  # or UNKNOWN mergeable (GitHub still computing it) keeps waiting.
  if [ "$mergeable" = CONFLICTING ]; then
    echo "CI RESULT: CONFLICT for PR #${pr_number} after ${elapsed}s — the PR conflicts with ${base}, so GitHub won't run its CI. Rebase onto ${base}, resolve, and push; closing and reopening won't help."
    exit 4
  fi

  if [ "$elapsed" -ge "$timeout" ]; then
    echo "CI RESULT: TIMEOUT for PR #${pr_number} after ${elapsed}s — NOT complete: ${pending} pending, ${runs} run(s) queued or running, required checks not yet reported: ${missing:-none}. A required check that never reports may be skipped by path filters.${stale:+ ${stale}: GitHub has not processed the push yet; closing and reopening the PR resyncs it.} Re-poll to get the final state."
    exit 2
  fi

  echo "CI POLL: ${elapsed}s elapsed for PR #${pr_number} — ${pending} pending, ${runs} run(s) queued or running, required not yet reported: ${missing:-none}${stale:+ — ${stale}} — not final, waiting..."
  sleep "$interval"
  elapsed=$((elapsed + interval))
done
