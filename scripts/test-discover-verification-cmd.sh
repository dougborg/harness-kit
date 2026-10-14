#!/usr/bin/env bash
# Regression tests for scripts/shared/discover-verification-cmd.sh: the
# [facts] verification_command in .harness/config.toml wins over discovery,
# and discovery is unchanged when the key or the file is absent.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/shared/discover-verification-cmd.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

fail=0
# new_repo <name>: a scratch project whose discovered gate is `just check`
new_repo() {
  mkdir -p "$scratch/$1/.harness"
  printf 'check:\n    echo ok\n' >"$scratch/$1/justfile"
  echo "$scratch/$1"
}
# expect <name> <dir> <want stdout> [want exit]
expect() {
  local out got
  set +e
  out=$("$script" "$2" 2>/dev/null)
  got=$?
  set -e
  if [ "$got" -ne "${4:-0}" ]; then
    echo "FAIL: $1: exit $got, want ${4:-0} (stdout '$out')"
    fail=1
  elif [ "$out" != "$3" ]; then
    echo "FAIL: $1: got '$out', want '$3'"
    fail=1
  else
    echo "PASS: $1"
  fi
}

dir=$(new_repo key-wins)
cat >"$dir/.harness/config.toml" <<'TOML'
# Project facts read by harness-kit's generic skills.
skills = ["open-pr", "review-pr"]

[facts]
verification_command = "moon ci"  # the one gate
TOML
expect config-key-wins "$dir" "moon ci"

dir=$(new_repo literal-string)
cat >"$dir/.harness/config.toml" <<'TOML'
[facts]
verification_command = 'pnpm check --filter "app"'
TOML
expect literal-string "$dir" 'pnpm check --filter "app"'

dir=$(new_repo escaped-basic-string)
cat >"$dir/.harness/config.toml" <<'TOML'
[facts]
verification_command = "make ci ARGS=\"-j 4\" # not a comment"
TOML
expect escaped-basic-string "$dir" 'make ci ARGS="-j 4" # not a comment'

dir=$(new_repo key-in-other-table)
cat >"$dir/.harness/config.toml" <<'TOML'
[forks.skills]
verification_command = "not a fact"

[facts]
TOML
expect key-outside-facts-ignored "$dir" "just check"

dir=$(new_repo absent-key)
cat >"$dir/.harness/config.toml" <<'TOML'
skills = ["open-pr"]

[facts]
TOML
expect absent-key-falls-back "$dir" "just check"

dir=$(new_repo absent-file)
expect absent-file-falls-back "$dir" "just check"

dir=$(new_repo empty-value)
cat >"$dir/.harness/config.toml" <<'TOML'
[facts]
verification_command = ""
TOML
expect empty-value-fails "$dir" "" 1

dir=$(new_repo unquoted-value)
cat >"$dir/.harness/config.toml" <<'TOML'
[facts]
verification_command = moon ci
TOML
expect unquoted-value-fails "$dir" "" 1

exit "$fail"
