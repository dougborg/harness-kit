#!/usr/bin/env bash
# Non-interactive squash/drop/reword operations via GIT_SEQUENCE_EDITOR.
#
# Usage:
#   squash.sh squash <target>           # Squash all commits into one
#   squash.sh drop <target> <sha>       # Drop a specific commit
#   squash.sh reword <target> <sha>     # Mark a commit for rewording
#
# NOTE: On macOS, sed -i requires empty string argument.

set -euo pipefail

# Detect sed flavor and set appropriate -i flag
get_sed_inplace_cmd() {
  if sed --version >/dev/null 2>&1; then
    printf '%s' "sed -i"
  else
    printf '%s' "sed -i ''"
  fi
}

sed_inplace="$(get_sed_inplace_cmd)"

action="${1:?Usage: squash.sh <squash|drop|reword> <target> [sha]}"
target="${2:?Missing target branch}"
sha="${3:-}"

case "$action" in
  squash)
    GIT_SEQUENCE_EDITOR="${sed_inplace} '2,\$s/^pick/squash/'" git rebase -i "$target"
    ;;
  drop)
    [ -z "$sha" ] && {
      echo "drop requires a SHA" >&2
      exit 1
    }
    GIT_SEQUENCE_EDITOR="${sed_inplace} '/^pick ${sha}/d'" git rebase -i "$target"
    ;;
  reword)
    [ -z "$sha" ] && {
      echo "reword requires a SHA" >&2
      exit 1
    }
    GIT_SEQUENCE_EDITOR="${sed_inplace} 's/^pick ${sha}/reword ${sha}/'" git rebase -i "$target"
    ;;
  *)
    echo "Unknown action: $action (use squash, drop, or reword)" >&2
    exit 1
    ;;
esac
