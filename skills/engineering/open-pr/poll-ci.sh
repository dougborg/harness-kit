#!/usr/bin/env bash
# Poll CI status for a PR with timeout.
#
# Usage: poll-ci.sh <pr-number> [timeout-seconds]
# Exit 0: all checks passed
# Exit 1: a check failed (prints failed check details)
# Exit 2: timeout reached (checks still running — NON-terminal)
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
#   - every status check the base branch's rules require has reported.
#
# Deliberately does not use `gh pr checks --watch`: --watch produces no
# heartbeat and its output, truncated by an external timeout, is
# indistinguishable from a finished run.
#
# Testing: POLL_CI_FIXTURE_DIR=<dir> reads checks.json, runs.json, and
# required.json from that directory instead of calling GitHub (see
# scripts/test-poll-ci.sh); POLL_CI_INTERVAL overrides the 30s interval.

set -euo pipefail

pr_number="${1:?Usage: poll-ci.sh <pr-number> [timeout-seconds]}"
timeout="${2:-300}" # default 5 minutes
interval="${POLL_CI_INTERVAL:-30}"
fixtures="${POLL_CI_FIXTURE_DIR:-}"
elapsed=0

head_sha=""
base=""
required="[]"
if [ -n "$fixtures" ]; then
  required=$(cat "$fixtures/required.json")
else
  read -r head_sha base < <(gh pr view "$pr_number" \
    --json headRefOid,baseRefName --jq '"\(.headRefOid) \(.baseRefName)"')
  # Required checks from the branch's effective rules (rulesets). A repo
  # without rules, or a token that can't read them, yields an empty list.
  required=$(gh api "repos/{owner}/{repo}/rules/branches/${base}" \
    --jq '[.[] | select(.type == "required_status_checks")
           | .parameters.required_status_checks[].context]' 2>/dev/null ||
    echo "[]")
fi

checks_json() {
  if [ -n "$fixtures" ]; then
    cat "$fixtures/checks.json"
  else
    # "no checks reported" exits non-zero; treat it as an empty list.
    gh pr checks "$pr_number" --json name,bucket 2>/dev/null || echo "[]"
  fi
}

active_runs() {
  if [ -n "$fixtures" ]; then
    jq '[.[] | select(.status != "completed")] | length' "$fixtures/runs.json"
  else
    gh run list --commit "$head_sha" --json status \
      --jq '[.[] | select(.status != "completed")] | length'
  fi
}

while true; do
  checks=$(checks_json)
  failed=$(jq -r '.[] | select(.bucket == "fail" or .bucket == "cancel") | .name' <<<"$checks")
  if [ -n "$failed" ]; then
    printf 'failed: %s\n' "$failed" >&2
    echo "CI RESULT: FAILED for PR #${pr_number} after ${elapsed}s (see failed checks above)"
    exit 1
  fi

  pending=$(jq '[.[] | select(.bucket == "pending")] | length' <<<"$checks")
  reported=$(jq 'length' <<<"$checks")
  runs=$(active_runs)
  missing=$(jq -rn --argjson req "$required" --argjson checks "$checks" \
    '[$req[] | select(. as $r | [$checks[].name] | index($r) | not)] | join(", ")')

  if [ "$reported" -gt 0 ] && [ "$pending" -eq 0 ] && [ "$runs" -eq 0 ] && [ -z "$missing" ]; then
    echo "CI RESULT: PASSED for PR #${pr_number} after ${elapsed}s — all checks green"
    exit 0
  fi

  if [ "$elapsed" -ge "$timeout" ]; then
    echo "CI RESULT: TIMEOUT for PR #${pr_number} after ${elapsed}s — checks still running or not started, NOT complete; re-poll to get final state" >&2
    exit 2
  fi

  echo "CI POLL: ${elapsed}s elapsed for PR #${pr_number} — ${pending} pending, ${runs} run(s) queued or running, required not yet reported: ${missing:-none} — not final, waiting..."
  sleep "$interval"
  elapsed=$((elapsed + interval))
done
