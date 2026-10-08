#!/usr/bin/env bash
# Negative tests for scripts/validate-codex.sh's layout guards, each run on a
# scratch git copy of the tracked tree with one thing broken.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
# copy <name>: a fresh git repo at $scratch/<name> holding the working tree's
# tracked and new files (a file deleted but not yet committed is skipped).
copy() {
  local dir="$scratch/$1"
  mkdir -p "$dir"
  (
    cd "$repo_root"
    git ls-files -z -co --exclude-standard | while IFS= read -r -d '' f; do
      if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
    done | xargs -0 tar cf -
  ) | tar xf - -C "$dir"
  git -C "$dir" init -q
  git -C "$dir" add -A
  work=$dir
}
# expect <name> <want: pass|fail> [message]: run the validator in $work.
expect() {
  local out rc
  set +e
  out=$("$work/scripts/validate-codex.sh" 2>&1)
  rc=$?
  set -e
  if { [ "$2" = pass ] && [ "$rc" = 0 ]; } ||
    { [ "$2" = fail ] && [ "$rc" != 0 ] && [[ "$out" == *"$3"* ]]; }; then
    echo "PASS: $1"
  else
    echo "FAIL: $1: want $2${3:+ with \"$3\"}, got exit $rc: $(tail -n 1 <<<"$out")"
    fail=1
  fi
}

copy clean
expect clean-tree pass

copy untracked-junk
touch "$work/scripts/shared/.DS_Store"
expect untracked-junk-ignored pass

copy stray-shared
cp "$work/scripts/test-hooks-schema.sh" "$work/scripts/shared/"
git -C "$work" add scripts/shared
expect stray-shared-file fail "scripts/shared/ holds files no skill or hook uses"

copy shared-subdir
mkdir -p "$work/scripts/shared/fixtures"
echo '{}' >"$work/scripts/shared/fixtures/x.json"
git -C "$work" add scripts/shared
expect shared-subdirectory fail "scripts/shared/ holds files no skill or hook uses"

copy missing-sibling
cat >>"$work/skills/engineering/rebase/assess.sh" <<'SH'
"$SCRIPT_DIR/no-such-helper.sh"
SH
expect missing-sibling-call fail "calls no-such-helper.sh"

exit "$fail"
