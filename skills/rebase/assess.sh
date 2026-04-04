#!/usr/bin/env bash
# Assess what will be rebased: commit count, changed files, merge base.
#
# Usage: assess.sh <target-branch>
# Output: commit list, diff stats, merge base to stdout

set -euo pipefail

target="${1:?Usage: assess.sh <target-branch>}"

echo "=== Commits to replay ==="
git log --oneline "$target..HEAD"

echo ""
echo "=== Files that may conflict ==="
git diff --stat "$target...HEAD"

echo ""
echo "=== Merge base ==="
git merge-base HEAD "$target"
