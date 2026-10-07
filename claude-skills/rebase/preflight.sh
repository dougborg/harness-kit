#!/usr/bin/env bash
# Rebase pre-flight: validate state before starting a rebase.
#
# Usage: preflight.sh [--allow-shared] [target-branch]   (either order)
# Output: prints the target branch to stdout, and STASH_REF=<stash commit>
#   to stderr when it stashed
# Exit 1: on a primary branch, or on a branch with other authors' commits
#   (pass --allow-shared only after the user confirms rebasing it anyway)
#
# Checks: not on main/master, fetches remote, detects collaboration,
# stashes uncommitted changes if needed.

set -euo pipefail

# is-branch-shared.sh ships beside this script in every copy of the skill.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

allow_shared=false
target=""
for arg in "$@"; do
  case "$arg" in
  --allow-shared) allow_shared=true ;;
  -*)
    echo "Unknown option: $arg" >&2
    exit 2
    ;;
  *) target=$arg ;;
  esac
done
target="${target:-origin/main}"

# Confirm not on main
current=$(git branch --show-current)
if [ "$current" = "main" ] || [ "$current" = "master" ]; then
  echo "Refusing to rebase primary branch '$current'. Create a feature branch first." >&2
  exit 1
fi

# Fetch the remote
remote="${target%%/*}"
git fetch "$remote"

# Check for collaboration (other authors); is-branch-shared.sh names them.
# Run through bash so a lost exec bit fails loudly instead of reading as shared.
if [ "$allow_shared" = false ] && ! bash "$SCRIPT_DIR/is-branch-shared.sh" "$target"; then
  echo "Branch is shared: ask the user before rebasing it. If they confirm, rerun with --allow-shared." >&2
  exit 1
fi

# Stash uncommitted changes, untracked files included. Report the stash only
# if this run created it, so a caller never pops someone else's stash.
if [ -n "$(git status --porcelain)" ]; then
  before=$(git rev-parse -q --verify refs/stash || true)
  git stash push -u -m "rebase-skill: auto-stash before rebase onto $target"
  after=$(git rev-parse -q --verify refs/stash || true)
  if [ -n "$after" ] && [ "$after" != "$before" ]; then
    echo "STASH_REF=$after" >&2
  fi
fi

# Output target for the caller
echo "$target"
