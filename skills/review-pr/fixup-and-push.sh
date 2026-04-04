#!/usr/bin/env bash
# Stage files, create fixup commit, autosquash rebase, and push.
#
# Usage: fixup-and-push.sh <base-branch> <original-commit-subject> <files...>
# Example: fixup-and-push.sh main "feat(auth): add login" src/auth.ts src/auth.test.ts
#
# Creates a fixup commit targeting the original commit subject,
# then rebases with --autosquash and force-pushes with lease.

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <base-branch> <original-commit-subject> <files...>" >&2
  exit 1
fi

base="$1"
shift
subject="$1"
shift
files=("$@")

# Stage specific files (never git add -A)
git add "${files[@]}"

# Create fixup commit
git commit -m "$(
  cat <<EOF
fixup! ${subject}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Autosquash rebase
git fetch origin "$base"
git rebase --autosquash "origin/${base}"

# Force push with lease
git push --force-with-lease
