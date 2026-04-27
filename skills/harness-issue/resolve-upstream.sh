#!/usr/bin/env bash
# Resolve the upstream harness repository (owner/repo) for the current project.
#
# Resolution order:
#   1. $HARNESS_UPSTREAM environment variable (escape hatch for CI/scripting)
#   2. .claude/harness-upstream file (one line: owner/repo)
#   3. .harness-lock.json — first source object's `repo` field
#      (i.e. .sources.<name>.repo, where <name> is the first key whose value
#       has a `repo` field)
#   4. Default: dougborg/harness-kit
#
# Usage: resolve-upstream.sh
# Output: prints owner/repo to stdout, exit 0
# Exit 1: malformed config (e.g. config file present but unreadable)

set -euo pipefail

DEFAULT_UPSTREAM="dougborg/harness-kit"

valid_repo() {
  # owner/repo, both segments non-empty and free of whitespace/slashes-within
  [[ "$1" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
}

if [ -n "${HARNESS_UPSTREAM:-}" ]; then
  if ! valid_repo "$HARNESS_UPSTREAM"; then
    echo "ERROR: \$HARNESS_UPSTREAM is not a valid owner/repo: $HARNESS_UPSTREAM" >&2
    exit 1
  fi
  echo "$HARNESS_UPSTREAM"
  exit 0
fi

config=".claude/harness-upstream"
if [ -f "$config" ]; then
  upstream=$(tr -d '[:space:]' < "$config")
  if [ -z "$upstream" ]; then
    echo "ERROR: $config is empty" >&2
    exit 1
  fi
  if ! valid_repo "$upstream"; then
    echo "ERROR: $config does not contain a valid owner/repo: $upstream" >&2
    exit 1
  fi
  echo "$upstream"
  exit 0
fi

lock=".harness-lock.json"
if [ -f "$lock" ] && command -v jq >/dev/null 2>&1; then
  upstream=$(jq -r '
    .sources // {}
    | to_entries
    | map(select(.value.repo))
    | .[0].value.repo // empty
  ' "$lock")
  if [ -n "$upstream" ]; then
    if ! valid_repo "$upstream"; then
      echo "ERROR: $lock has an invalid sources[].repo value: $upstream" >&2
      exit 1
    fi
    echo "$upstream"
    exit 0
  fi
fi

echo "$DEFAULT_UPSTREAM"
