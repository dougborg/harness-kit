#!/usr/bin/env bash
# Discover the project's verification/CI command.
#
# A project that states its gate in .harness/config.toml wins:
#
#   [facts]
#   verification_command = "moon ci"
#
# Otherwise searches for common project configuration files and returns the
# appropriate test/check command. Exits 1 if no verification command found,
# if the config sets the key to something other than a non-empty one-line
# string, or if the config names the key anywhere it isn't read (an inline
# table, a dotted key, another table), naming the file and line.
#
# In a vendored project (one with .harness/lock.json), the command is
# prefixed with the harness skill's check-snapshot.sh, so the gate also fails
# when a vendored file is edited. It exits 1 if the lock is there and the
# check script is not. Without a lock, the output is unchanged.
#
# Usage: discover-verification-cmd.sh [directory]
# Output: Prints the verification command to stdout

set -euo pipefail

dir="${1:-.}"
cd "$dir"

# Vendored projects run the snapshot edit check first. The .claude/ copy wins
# because the GitHub Action restores .claude/ from a PR's base branch.
prefix=""
if [ -f .harness/lock.json ]; then
  for check in .claude/skills/harness/check-snapshot.sh .agents/skills/harness/check-snapshot.sh; do
    if [ -x "$check" ]; then
      prefix="$check && "
      break
    fi
  done
  if [ -z "$prefix" ]; then
    echo ".harness/lock.json is present but the harness skill's check-snapshot.sh is not; re-vendor the snapshot" >&2
    exit 1
  fi
fi
emit() { echo "$prefix$1"; }

# Read [facts].verification_command from the config. Exit 0 and print it when
# set, 3 when the file or key is absent, 2 when the value is malformed.
# shortcut: one-line TOML strings in a [facts] table only (no dotted keys,
# multi-line strings, or \u escapes) | revisit when a project needs them
config_cmd() {
  [ -f .harness/config.toml ] || return 3
  awk '
    function bad(msg) { print FILENAME ":" NR ": " msg > "/dev/stderr"; status = 2; exit }
    /^[[:space:]]*\[/ {
      in_facts = ($0 ~ /^[[:space:]]*\[[[:space:]]*facts[[:space:]]*\][[:space:]]*(#.*)?$/)
      next
    }
    in_facts && /^[[:space:]]*"?verification_command"?[[:space:]]*=/ {
      v = $0
      sub(/^[^=]*=[[:space:]]*/, "", v)
      q = substr(v, 1, 1)
      if (q != "\"" && q != "'\''") bad("verification_command must be a quoted string")
      out = ""; closed = 0
      for (i = 2; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c == q) { closed = 1; break }
        if (q == "\"" && c == "\\") {
          i++; e = substr(v, i, 1)
          if (e == "\"" || e == "\\") c = e
          else if (e == "t") c = "\t"
          else bad("unsupported escape \\" e " in verification_command")
        }
        out = out c
      }
      rest = substr(v, i + 1)
      if (!closed) bad("verification_command string is not closed on its line")
      if (rest !~ /^[[:space:]]*(#.*)?$/) bad("unexpected text after verification_command")
      if (out == "") bad("verification_command is empty")
      print out; status = 0; exit
    }
    END { exit (status == "" ? 3 : status) }
  ' .harness/config.toml
}

set +e
from_config=$(config_cmd)
config_status=$?
set -e
if [ "$config_status" -eq 0 ]; then
  emit "$from_config"
  exit 0
elif [ "$config_status" -ne 3 ]; then
  exit 1
fi
# The key written anywhere else (an inline table, a dotted key, another
# table) would silently be ignored, so fail and say where it is.
unread=$(grep -nE '^[^#]*verification_command' .harness/config.toml 2>/dev/null || true)
if [ -n "$unread" ]; then
  while IFS=: read -r line _; do
    echo ".harness/config.toml:$line: verification_command is not read here; write it as" \
      "verification_command = \"...\" on its own line under [facts]" >&2
  done <<<"$unread"
  exit 1
fi

if [ -f justfile ] && grep -qE '^(check|ci):' justfile; then
  recipe=$(grep -oE '^(ci|check):' justfile | head -1 | tr -d ':')
  emit "just $recipe"
elif [ -f Makefile ] && grep -qE '^(ci|check|test):' Makefile; then
  target=$(grep -oE '^(ci|check|test):' Makefile | head -1 | tr -d ':')
  emit "make $target"
elif [ -f pyproject.toml ] && grep -q '\[tool\.poe\.tasks' pyproject.toml; then
  # Python project with poe — check before package.json so monorepos that
  # carry a TS workspace at the root still resolve to the documented Python
  # gate. Prefer a `check` recipe when one exists (full validation: format
  # + lint + types + tests), fall back to `test`.
  #
  # Scope the recipe lookup to the [tool.poe.tasks] section so an unrelated
  # TOML key named `check` (e.g. a dependency or other table key) doesn't
  # false-positive. Handles both inline (`check = ...`) and sub-table
  # (`[tool.poe.tasks.check]`) task forms, with or without TOML quoted keys
  # (`"check" = ...` / `[tool.poe.tasks."check"]`), which are valid TOML
  # and would otherwise silently fall through to task=test (issue #20).
  poe_inline_tasks=$(awk '
    /^\[tool\.poe\.tasks\]/ { in_section = 1; next }
    /^\[/                   { in_section = 0 }
    in_section              { print }
  ' pyproject.toml)
  if grep -qE '^"?check"?[[:space:]]*=' <<<"$poe_inline_tasks" \
    || grep -qE '^\[tool\.poe\.tasks\."?check"?\]' pyproject.toml; then
    task="check"
  else
    task="test"
  fi
  # `poe` is rarely on PATH outside `uv run` / `poetry run` in modern repos,
  # so pick a launcher that's actually available rather than emitting a
  # command that can't run. Verifier agent allowlist must cover all three
  # forms (see agents/verifier.md).
  if command -v uv >/dev/null 2>&1; then
    emit "uv run poe $task"
  elif command -v poetry >/dev/null 2>&1; then
    emit "poetry run poe $task"
  elif command -v poe >/dev/null 2>&1; then
    emit "poe $task"
  else
    echo "Found [tool.poe.tasks] in pyproject.toml, but none of uv, poetry, or poe is installed" >&2
    exit 1
  fi
elif [ -f package.json ] && command -v jq >/dev/null; then
  if jq -e '.scripts.check' package.json >/dev/null 2>&1; then
    emit "npm run check"
  elif jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    emit "npm test"
  else
    echo "No verification command found in package.json" >&2
    exit 1
  fi
elif [ -f Cargo.toml ]; then
  emit "cargo test"
elif [ -f flake.nix ]; then
  emit "nix flake check"
elif [ -f pyproject.toml ]; then
  emit "pytest"
else
  echo "No verification command found" >&2
  exit 1
fi
