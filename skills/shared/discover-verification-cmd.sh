#!/usr/bin/env bash
# Discover the project's verification/CI command.
#
# Searches for common project configuration files and returns the
# appropriate test/check command. Exits 1 if no verification command found.
#
# Usage: discover-verification-cmd.sh [directory]
# Output: Prints the verification command to stdout

set -euo pipefail

dir="${1:-.}"
cd "$dir"

if [ -f justfile ] && grep -qE '^(check|ci):' justfile; then
  recipe=$(grep -oE '^(ci|check):' justfile | head -1 | tr -d ':')
  echo "just $recipe"
elif [ -f Makefile ] && grep -qE '^(ci|check|test):' Makefile; then
  target=$(grep -oE '^(ci|check|test):' Makefile | head -1 | tr -d ':')
  echo "make $target"
elif [ -f pyproject.toml ] && grep -q '\[tool\.poe\.tasks' pyproject.toml; then
  # Python project with poe — check before package.json so monorepos that
  # carry a TS workspace at the root still resolve to the documented Python
  # gate. Prefer a `check` recipe when one exists (full validation: format
  # + lint + types + tests), fall back to `test`.
  #
  # Scope the recipe lookup to the [tool.poe.tasks] section so an unrelated
  # TOML key named `check` (e.g. a dependency or other table key) doesn't
  # false-positive. Handles both inline (`check = ...`) and sub-table
  # (`[tool.poe.tasks.check]`) task forms.
  poe_inline_tasks=$(awk '
    /^\[tool\.poe\.tasks\]/ { in_section = 1; next }
    /^\[/                   { in_section = 0 }
    in_section              { print }
  ' pyproject.toml)
  if grep -qE '^check[[:space:]]*=' <<<"$poe_inline_tasks" \
    || grep -qE '^\[tool\.poe\.tasks\.check\]' pyproject.toml; then
    task="check"
  else
    task="test"
  fi
  # `poe` is rarely on PATH outside `uv run` / `poetry run` in modern repos,
  # so pick a launcher that's actually available rather than emitting a
  # command that can't run. Verifier agent allowlist must cover all three
  # forms (see agents/verifier.md).
  if command -v uv >/dev/null 2>&1; then
    echo "uv run poe $task"
  elif command -v poetry >/dev/null 2>&1; then
    echo "poetry run poe $task"
  elif command -v poe >/dev/null 2>&1; then
    echo "poe $task"
  else
    echo "Found [tool.poe.tasks] in pyproject.toml, but none of uv, poetry, or poe is installed" >&2
    exit 1
  fi
elif [ -f package.json ] && command -v jq >/dev/null; then
  if jq -e '.scripts.check' package.json >/dev/null 2>&1; then
    echo "npm run check"
  elif jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    echo "npm test"
  else
    echo "No verification command found in package.json" >&2
    exit 1
  fi
elif [ -f Cargo.toml ]; then
  echo "cargo test"
elif [ -f flake.nix ]; then
  echo "nix flake check"
elif [ -f pyproject.toml ]; then
  echo "pytest"
else
  echo "No verification command found" >&2
  exit 1
fi
