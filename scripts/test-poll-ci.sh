#!/usr/bin/env bash
# Regression tests for skills/engineering/open-pr/poll-ci.sh, using canned
# check, run, and required-check lists (POLL_CI_FIXTURE_DIR) instead of
# calling GitHub.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/skills/engineering/open-pr/poll-ci.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

required='["Validate plugin","ShellCheck"]'
green='[{"name":"Validate plugin","bucket":"pass"},{"name":"ShellCheck","bucket":"pass"},{"name":"CodeQL","bucket":"pass"}]'
done_runs='[{"status":"completed"}]'

# case <name> <checks> <runs> <required> <want-exit>
fail=0
case_() {
  local name=$1 dir="$scratch/$1" got
  mkdir -p "$dir"
  printf '%s' "$2" >"$dir/checks.json"
  printf '%s' "$3" >"$dir/runs.json"
  printf '%s' "$4" >"$dir/required.json"
  set +e
  POLL_CI_FIXTURE_DIR="$dir" POLL_CI_INTERVAL=0 "$script" 1 0 >/dev/null 2>&1
  got=$?
  set -e
  if [ "$got" = "$5" ]; then
    echo "PASS: $name (exit $got)"
  else
    echo "FAIL: $name: want exit $5, got $got"
    fail=1
  fi
}

case_ all-green "$green" "$done_runs" "$required" 0
case_ check-failed '[{"name":"ShellCheck","bucket":"fail"}]' "$done_runs" "$required" 1
case_ check-cancelled '[{"name":"ShellCheck","bucket":"cancel"}]' "$done_runs" "$required" 1
case_ check-pending '[{"name":"ShellCheck","bucket":"pending"}]' "$done_runs" "$required" 2
# The #126 case: CodeQL done, the CI workflow run still queued with no checks.
case_ run-queued '[{"name":"CodeQL","bucket":"pass"}]' '[{"status":"queued"},{"status":"completed"}]' '[]' 2
case_ required-missing '[{"name":"CodeQL","bucket":"pass"}]' "$done_runs" "$required" 2
case_ nothing-reported '[]' '[]' '[]' 2
case_ skipped-counts '[{"name":"Validate plugin","bucket":"pass"},{"name":"ShellCheck","bucket":"skipping"}]' "$done_runs" "$required" 0

exit "$fail"
