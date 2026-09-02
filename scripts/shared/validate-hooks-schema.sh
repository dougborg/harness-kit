#!/usr/bin/env bash
# Validate plugin hooks.json has the correct top-level "hooks" wrapper.
# Usage: validate-hooks-schema.sh [path]   (default: hooks/hooks.json)
# Exit 0: valid or no hooks.json. Exit non-zero: malformed.

set -euo pipefail

file="${1:-hooks/hooks.json}"

if [ ! -f "$file" ]; then
  # Plugins without hooks are valid — nothing to check.
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to validate $file" >&2
  exit 1
fi

if ! jq -e '.hooks | type == "object"' "$file" >/dev/null 2>&1; then
  echo "ERROR: $file must have a top-level 'hooks' object." >&2
  echo "       Plugin hooks.json wraps event types in a 'hooks' record." >&2
  echo "       See agents/references/hooks-reference.md" >&2
  exit 1
fi

bad_events=$(jq -r '.hooks | to_entries[] | select(.value | type != "array") | .key' "$file")
if [ -n "$bad_events" ]; then
  echo "ERROR: $file event types must be arrays. Bad keys: $bad_events" >&2
  echo "       See agents/references/hooks-reference.md" >&2
  exit 1
fi

# Each handler entry inside an event array must have a "hooks" array of commands.
# Catches: forgot the inner "hooks" key, used a string instead of array, etc.
bad_handlers=$(jq -r '
  .hooks | to_entries[] as $e
  | $e.value | to_entries[]
  | select(.value | (has("hooks") | not) or (.hooks | type != "array"))
  | "\($e.key)[\(.key)]"
' "$file")
if [ -n "$bad_handlers" ]; then
  echo "ERROR: $file handler entries must contain a 'hooks' array." >&2
  echo "       Bad entries: $bad_handlers" >&2
  echo "       See agents/references/hooks-reference.md" >&2
  exit 1
fi

# Each command entry must have type=="command" and a non-empty command string.
bad_commands=$(jq -r '
  .hooks | to_entries[] as $e
  | $e.value | to_entries[] as $h
  | $h.value.hooks | to_entries[]
  | select(.value.type != "command" or (.value.command | type != "string") or (.value.command | length == 0))
  | "\($e.key)[\($h.key)].hooks[\(.key)]"
' "$file")
if [ -n "$bad_commands" ]; then
  echo "ERROR: $file command entries must have type=\"command\" and a non-empty command string." >&2
  echo "       Bad entries: $bad_commands" >&2
  echo "       See agents/references/hooks-reference.md" >&2
  exit 1
fi

# If hooks.json sits at the auto-discovery path, plugin.json must NOT also
# declare a "hooks" field — Claude Code loads both and refuses with
# "Duplicate hooks file detected". See agents/references/hooks-reference.md.
#
# `-ef` compares inodes, so any spelling of the same file (./hooks/hooks.json,
# hooks/hooks.json, an absolute path) is detected. The check is silently
# skipped when cwd isn't the plugin root, since auto-discovery wouldn't fire
# there anyway.
manifest=".claude-plugin/plugin.json"
if [ -f "hooks/hooks.json" ] && [ "$file" -ef "hooks/hooks.json" ] && [ -f "$manifest" ]; then
  if jq -e 'has("hooks")' "$manifest" >/dev/null 2>&1; then
    echo "ERROR: $manifest declares a 'hooks' field, but $file is at the auto-discovery path." >&2
    echo "       Both register the same hooks, causing 'Duplicate hooks file detected' at load time." >&2
    echo "       Remove the 'hooks' field from $manifest." >&2
    echo "       See agents/references/hooks-reference.md" >&2
    exit 1
  fi
fi

echo "✓ $file schema OK"
