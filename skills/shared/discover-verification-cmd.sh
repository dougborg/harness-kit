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
  if grep -q '\[tool\.poe' pyproject.toml; then
    echo "poe test"
  else
    echo "pytest"
  fi
else
  echo "No verification command found" >&2
  exit 1
fi
