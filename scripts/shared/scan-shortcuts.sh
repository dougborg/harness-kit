#!/usr/bin/env bash
# List the code's `shortcut:` markers (see the minimal-change skill):
#   <comment> shortcut: <ceiling> | revisit when <trigger>
# Usage: scan-shortcuts.sh [dir]   (default: the current directory)
# Prints file:line:text per marker; exits 0 even when there are none.
set -euo pipefail

grep -rnE \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist \
  --exclude-dir=build --exclude-dir=vendor --exclude-dir=target \
  --exclude-dir=.venv --exclude='*.md' \
  '(#|//|--|/\*|<!--) ?shortcut:' "${1:-.}" || true
