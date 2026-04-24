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

echo "✓ $file schema OK"
