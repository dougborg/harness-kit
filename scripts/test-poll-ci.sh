#!/usr/bin/env bash
# Regression tests for skills/engineering/open-pr/poll-ci.sh: the decision
# logic through canned check, run, and required-check lists
# (POLL_CI_FIXTURE_DIR), and the live path through a stub `gh`.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/skills/engineering/open-pr/poll-ci.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

fail=0
# check <name> <want-exit> <output> <got-exit>: the exit code matches and the
# last line follows the "CI RESULT:" contract.
check() {
  local last
  last=$(tail -n 1 <<<"$3")
  if [ "$4" = "$2" ] && [[ "$last" == "CI RESULT:"* ]]; then
    echo "PASS: $1 (exit $4)"
  else
    echo "FAIL: $1: want exit $2 ending in 'CI RESULT:', got exit $4 ending '$last'"
    fail=1
  fi
}

# run_case <name> <checks> <runs> <required> <want-exit>
run_case() {
  local dir="$scratch/$1" out got
  mkdir -p "$dir"
  printf '%s' "$2" >"$dir/checks.json"
  printf '%s' "$3" >"$dir/runs.json"
  printf '%s' "$4" >"$dir/required.json"
  set +e
  out=$(POLL_CI_FIXTURE_DIR="$dir" POLL_CI_INTERVAL=0 "$script" 1 0 2>&1)
  got=$?
  set -e
  check "$1" "$5" "$out" "$got"
}

both='["Validate plugin","ShellCheck"]'
green='[{"name":"Validate plugin","bucket":"pass"},{"name":"ShellCheck","bucket":"pass"},{"name":"CodeQL","bucket":"pass"}]'
done_runs='[{"name":"CI","status":"completed","createdAt":"2026-10-07T15:00:00Z"}]'

run_case all-green "$green" "$done_runs" "$both" 0
run_case check-failed '[{"name":"ShellCheck","bucket":"fail"}]' "$done_runs" '[]' 1
run_case check-cancelled '[{"name":"ShellCheck","bucket":"cancel"}]' "$done_runs" '[]' 1
run_case failed-while-queued '[{"name":"ShellCheck","bucket":"fail"}]' '[{"name":"CI","status":"queued","createdAt":"2026-10-07T15:00:00Z"}]' '[]' 1
run_case check-pending '[{"name":"ShellCheck","bucket":"pending"},{"name":"CodeQL","bucket":"pass"}]' "$done_runs" '[]' 2
# The #126 case: CodeQL done, the CI workflow run still queued with no checks.
run_case run-queued '[{"name":"CodeQL","bucket":"pass"}]' '[{"name":"CI","status":"queued","createdAt":"2026-10-07T15:00:00Z"},{"name":"CodeQL","status":"completed","createdAt":"2026-10-07T15:00:00Z"}]' '[]' 2
run_case required-missing '[{"name":"CodeQL","bucket":"pass"}]' "$done_runs" "$both" 2
run_case required-partial '[{"name":"ShellCheck","bucket":"pass"}]' "$done_runs" "$both" 2
# An orphaned older run superseded by a finished newer run of the same workflow.
run_case superseded-run "$green" '[{"name":"CI","status":"queued","createdAt":"2026-10-07T15:07:28Z"},{"name":"CI","status":"completed","createdAt":"2026-10-07T15:45:14Z"}]' "$both" 0
run_case nothing-reported '[]' '[]' '[]' 2
run_case skipped-counts '[{"name":"Validate plugin","bucket":"pass"},{"name":"ShellCheck","bucket":"skipping"}]' "$done_runs" "$both" 0

# Live path, with a stub gh: an unreadable PR is an explicit error, and an
# unreadable run list keeps the poll waiting instead of passing or crashing.
mkdir -p "$scratch/bin"
cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
"pr view") [ "${STUB_PR_VIEW:-ok}" = ok ] || exit 1; echo "abc123 main" ;;
"api repos/{owner}/{repo}/rules/branches/main") echo '[]' ;;
"pr checks") echo '[{"name":"CodeQL","bucket":"pass"}]' ;;
"run list") exit 1 ;;
*) exit 1 ;;
esac
STUB
chmod +x "$scratch/bin/gh"
live() { # live <name> <want-exit> [env...]
  local name=$1 want=$2 out got
  shift 2
  set +e
  out=$(env PATH="$scratch/bin:$PATH" POLL_CI_INTERVAL=0 "$@" "$script" 1 0 2>&1)
  got=$?
  set -e
  check "$name" "$want" "$out" "$got"
}
live pr-unreadable 3 STUB_PR_VIEW=fail
live runs-unreadable 2

exit "$fail"
