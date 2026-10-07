#!/usr/bin/env bash
# Rebase pre-flight: validate state before starting a rebase.
#
# Usage: preflight.sh [--allow-shared] [target-branch]
# Output: prints the target branch to stdout, and STASH_REF=<ref> to stderr
#   when it stashed
# Exit 1: on a primary branch, or on a branch with other authors' commits
#   (pass --allow-shared only after the user confirms rebasing it anyway)
#
# Checks: not on main/master, fetches remote, detects collaboration,
# stashes uncommitted changes if needed.

set -euo pipefail

# is-branch-shared.sh ships beside this script in every copy of the skill.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

allow_shared=false
if [ "${1:-}" = "--allow-shared" ]; then
  allow_shared=true
  shift
fi

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

# Check for collaboration (other authors); is-branch-shared.sh names them.
if [ "$allow_shared" = false ] && ! "$SCRIPT_DIR/is-branch-shared.sh"; then
  echo "Branch is shared: ask the user before rebasing it. If they confirm, rerun with --allow-shared." >&2
  exit 1
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
