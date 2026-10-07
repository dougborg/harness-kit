#!/usr/bin/env bash
# Regression tests for scripts/shared/retro-nudge.sh: quiet on a small
# session, a valid systemMessage on a large one, and once per session.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/shared/retro-nudge.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/repo" "$scratch/tmp"
cd "$scratch/repo"
git init -q

fail=0
# nudge <name> <stdin> <want: quiet|message>
nudge() {
  local out got
  set +e
  out=$(printf '%s' "$2" | TMPDIR="$scratch/tmp" "$script" 2>&1)
  got=$?
  set -e
  if [ "$got" -ne 0 ]; then
    echo "FAIL: $1: exit $got"
    fail=1
  elif [ "$3" = quiet ] && [ -z "$out" ]; then
    echo "PASS: $1 (quiet)"
  elif [ "$3" = message ] && jq -e '.systemMessage | test("touched 5 files")' <<<"$out" >/dev/null 2>&1; then
    echo "PASS: $1 (message)"
  else
    echo "FAIL: $1: want $3, got '$out'"
    fail=1
  fi
}

nudge small-session '{"session_id":"s1"}' quiet
for i in 1 2 3 4 5; do echo "$i" >"f$i"; done
git add .
nudge large-session '{"session_id":"s1"}' message
nudge same-session-again '{"session_id":"s1"}' quiet
nudge new-session '{"session_id":"s2"}' message
nudge no-session-id '' message

exit "$fail"
