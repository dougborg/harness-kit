#!/usr/bin/env bash
# Check if the current branch has commits from other authors.
# Used to determine if rebasing is safe (solo branch) or risky (shared).
#
# Usage: is-branch-shared.sh [base]   (base defaults to origin/main)
# Exit 0: safe — branch is unpublished or solo-authored
# Exit 1: shared — other authors found, rebasing would disrupt collaborators
#
# Looks at every commit on the branch since base, local or already pushed: a
# teammate's commit on the remote branch counts even when nothing of theirs
# is unpushed. Uses git config user.email for comparison (not $USER, which is
# a short username).

set -euo pipefail

base="${1:-origin/main}"

# Check if branch has a remote tracking ref
if ! git rev-parse --verify "@{u}" >/dev/null 2>&1; then
  # No upstream — branch is unpublished, safe to rebase
  exit 0
fi

current_email=$(git config user.email 2>/dev/null || true)
if [ -z "$current_email" ]; then
  echo "Warning: git user.email not configured, cannot check authorship" >&2
  exit 0
fi

others=$(git log --format='%ae' HEAD "@{u}" --not "$base" | sort -u | grep -Fvx "$current_email" || true)

if [ -n "$others" ]; then
  echo "Branch has commits from other authors. Rebasing will disrupt collaborators." >&2
  echo "Other authors:" >&2
  printf '%s\n' "$others" >&2
  exit 1
fi

exit 0
