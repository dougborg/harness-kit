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
# Deliberately does not use `gh pr checks --watch`: --watch produces no
# heartbeat and its output, truncated by an external timeout, is
# indistinguishable from a finished run.

set -euo pipefail

pr_number="${1:?Usage: poll-ci.sh <pr-number> [timeout-seconds]}"
timeout="${2:-300}" # default 5 minutes
interval=30
elapsed=0

while true; do
  status=$(gh pr checks "$pr_number" 2>&1 || true)

  if echo "$status" | grep -q "fail"; then
    echo "$status" | grep "fail" >&2
    echo "CI RESULT: FAILED for PR #${pr_number} after ${elapsed}s (see failed checks above)"
    exit 1
  fi

  if ! echo "$status" | grep -qE "pending|queued|in_progress"; then
    echo "CI RESULT: PASSED for PR #${pr_number} after ${elapsed}s — all checks green"
    exit 0
  fi

  if [ "$elapsed" -ge "$timeout" ]; then
    echo "CI RESULT: TIMEOUT for PR #${pr_number} after ${elapsed}s — checks still running, NOT complete; re-poll to get final state" >&2
    exit 2
  fi

  running=$(echo "$status" | grep -cE "pending|queued|in_progress" || true)
  echo "CI POLL: ${elapsed}s elapsed, ${running} check(s) still running for PR #${pr_number} — not final, waiting..."
  sleep "$interval"
  elapsed=$((elapsed + interval))
done
