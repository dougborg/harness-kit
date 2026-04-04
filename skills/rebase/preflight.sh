#!/usr/bin/env bash
# Rebase pre-flight: validate state before starting a rebase.
#
# Usage: preflight.sh [target-branch]
# Output: prints target branch and stash ref (if stashed) to stdout
# Exit 1: if on primary branch or branch is shared
#
# Checks: not on main/master, fetches remote, detects collaboration,
# stashes uncommitted changes if needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="${SCRIPT_DIR}/../shared"

# Confirm not on main
current=$(git branch --show-current)
if [ "$current" = "main" ] || [ "$current" = "master" ]; then
  echo "Refusing to rebase primary branch '$current'. Create a feature branch first." >&2
  exit 1
fi

# Determine target
target="${1:-origin/main}"

# Fetch the remote
remote="${target%%/*}"
git fetch "$remote"

# Check for collaboration (other authors)
if [ -x "$SHARED_DIR/is-branch-shared.sh" ]; then
  "$SHARED_DIR/is-branch-shared.sh"
fi

# Stash uncommitted changes if needed
stash_ref=""
if [ -n "$(git status --porcelain)" ]; then
  git stash push -m "rebase-skill: auto-stash before rebase onto $target"
  stash_ref=$(git stash list --format="%gd" -1)
  echo "STASH_REF=$stash_ref" >&2
fi

# Output target for the caller
echo "$target"
