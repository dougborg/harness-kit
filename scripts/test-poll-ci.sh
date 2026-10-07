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
"pr view") [ "${STUB_PR_VIEW:-ok}" = ok ] || exit 1
  echo "abc123 main feature ${STUB_CROSS_REPO:-false} ${STUB_MERGEABLE:-MERGEABLE}" ;;
"api repos/{owner}/{repo}/rules/branches/main") echo '[]' ;;
"pr checks")
  if [ -n "${STUB_CHECKS:-}" ]; then printf '%s\n' "$STUB_CHECKS"
  else echo '[{"name":"CodeQL","bucket":"pass"}]'; fi ;;
"run list") [ "${STUB_RUNS:-fail}" = ok ] || exit 1; echo 0 ;;
*) exit 1 ;;
esac
STUB
chmod +x "$scratch/bin/gh"
# A stub git, so the live cases never touch a real remote: STUB_REMOTE_TIP is
# the branch tip origin reports; STUB_REMOTE=fail makes ls-remote fail.
cat >"$scratch/bin/git" <<'STUB'
#!/usr/bin/env bash
[ "$1" = ls-remote ] || exit 1
[ "${STUB_REMOTE:-ok}" = ok ] || exit 128
[ -z "${STUB_REMOTE_TIP:-}" ] || printf '%s\trefs/heads/feature\n' "$STUB_REMOTE_TIP"
STUB
chmod +x "$scratch/bin/git"
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
live head-current 0 STUB_RUNS=ok STUB_REMOTE_TIP=abc123
# #131: GitHub hasn't caught up with a push, so the checks shown are the old
# commit's; wait rather than pass on them, or fail on them.
live head-stale 2 STUB_RUNS=ok STUB_REMOTE_TIP=def456
live head-stale-old-failure 2 STUB_RUNS=ok STUB_REMOTE_TIP=def456 \
  'STUB_CHECKS=[{"name":"ShellCheck","bucket":"fail"}]'
live tip-unknown 0 STUB_RUNS=ok
live remote-unreadable 0 STUB_RUNS=ok STUB_REMOTE=fail
live fork-pr-skips-check 0 STUB_RUNS=ok STUB_CROSS_REPO=true STUB_REMOTE_TIP=def456
# #147: a PR conflicting with its base gets no CI runs; say so, don't time out.
# CI that already finished keeps its verdict; only unfinished CI stops early.
live conflict 4 STUB_RUNS=ok STUB_MERGEABLE=CONFLICTING STUB_REMOTE_TIP=def456
live conflict-after-green 0 STUB_RUNS=ok STUB_MERGEABLE=CONFLICTING
live conflict-after-failure 1 STUB_RUNS=ok STUB_MERGEABLE=CONFLICTING \
  'STUB_CHECKS=[{"name":"ShellCheck","bucket":"fail"}]'
live mergeable-unknown 0 STUB_RUNS=ok STUB_MERGEABLE=UNKNOWN
live mergeable-null 0 STUB_RUNS=ok STUB_MERGEABLE=null
conflict_line=$(env PATH="$scratch/bin:$PATH" POLL_CI_INTERVAL=0 STUB_RUNS=ok \
  STUB_MERGEABLE=CONFLICTING STUB_REMOTE_TIP=def456 "$script" 1 0 2>&1 | tail -n 1 || true)
if [[ "$conflict_line" == *"conflicts with main"* && "$conflict_line" == *"Rebase onto main"* ]]; then
  echo "PASS: conflict names the base and the fix"
else
  echo "FAIL: conflict message: $conflict_line"
  fail=1
fi
stale_line=$(env PATH="$scratch/bin:$PATH" POLL_CI_INTERVAL=0 STUB_RUNS=ok \
  STUB_REMOTE_TIP=def456 "$script" 1 0 2>&1 | tail -n 1 || true)
if [[ "$stale_line" == *"PR head abc123 is behind the branch tip def456"* &&
  "$stale_line" == *"closing and reopening the PR resyncs it"* ]]; then
  echo "PASS: head-stale names both commits"
else
  echo "FAIL: head-stale message: $stale_line"
  fail=1
fi

exit "$fail"
