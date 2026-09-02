#!/usr/bin/env bash
# Auto-fix markdown lint issues reported by Claude Edit/Write or Codex
# apply_patch hook input. An explicit path remains supported for manual use.
# Exits 0 always (hook safety).

set -uo pipefail

lint_file() {
  file_path=$1
  [ -f "$file_path" ] || return 0

  case "$file_path" in
  *.md)
    if command -v markdownlint-cli2 >/dev/null 2>&1; then
      markdownlint-cli2 --fix "$file_path" 2>/dev/null || true
    elif command -v markdownlint >/dev/null 2>&1; then
      markdownlint --fix "$file_path" 2>/dev/null || true
    fi
    ;;
  esac
}

if [ -n "${1:-}" ] && [ "${1:-}" != "{file_path}" ]; then
  lint_file "$1"
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0
[ -t 0 ] && exit 0

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file_path" ] && lint_file "$file_path"
printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null |
  sed -nE 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' |
  while IFS= read -r changed; do lint_file "$changed"; done

exit 0
