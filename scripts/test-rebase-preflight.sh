#!/usr/bin/env bash
# Regression tests for skills/engineering/rebase/preflight.sh and
# is-branch-shared.sh, against throwaway repos with a local bare "origin":
# no network, no real remote, and no global git config.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
preflight="$repo_root/skills/engineering/rebase/preflight.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
# expect <name> <want-exit> <want-in-output>: runs preflight in $work with
# $args, checks the exit code and that the output contains the text.
expect() {
  local out got
  set +e
  out=$(cd "$work" && "$preflight" "${args[@]+"${args[@]}"}" 2>&1)
  got=$?
  set -e
  if [ "$got" = "$2" ] && [[ "$out" == *"$3"* ]]; then
    echo "PASS: $1 (exit $got)"
  else
    echo "FAIL: $1: want exit $2 with '$3', got exit $got: $out"
    fail=1
  fi
}

# fresh <name>: a bare origin with main, and a clone in $work as me@example.com.
fresh() {
  local dir="$scratch/$1"
  git init -q --bare -b main "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/work" 2>/dev/null
  work="$dir/work"
  git -C "$work" config user.email me@example.com
  git -C "$work" config user.name me
  git -C "$work" commit -q --allow-empty -m base
  git -C "$work" push -q origin main
}
commit_as() { # commit_as <email> <msg>
  git -C "$work" -c user.email="$1" -c user.name="$1" commit -q --allow-empty -m "$2"
}

fresh on-main
args=()
expect on-main 1 "Refusing to rebase primary branch"

fresh unpublished
git -C "$work" switch -q -c feature
commit_as me@example.com mine
args=()
expect unpublished 0 "origin/main"

fresh solo
git -C "$work" switch -q -c feature
commit_as me@example.com mine
git -C "$work" push -q -u origin feature
args=()
expect solo-published 0 "origin/main"

# A teammate's commit is already on the remote branch and pulled locally,
# with nothing of theirs unpushed: the case that matters.
fresh shared
git -C "$work" switch -q -c feature
commit_as me@example.com mine
commit_as them@example.com theirs
git -C "$work" push -q -u origin feature
args=()
expect shared-stops 1 "them@example.com"
expect shared-asks 1 "ask the user before rebasing"
args=(--allow-shared)
expect allow-shared 0 "origin/main"
args=(origin/main)
expect shared-target-first-stops 1 "them@example.com"
args=(origin/main --allow-shared)
expect allow-shared-after-target 0 "origin/main"
args=(--allow-sharde)
expect unknown-option 2 "Unknown option: --allow-sharde"

# Untracked files only, with someone else's older stash on top: preflight
# must stash the new file and report its own stash, not the older one.
fresh dirty
git -C "$work" switch -q -c feature
commit_as me@example.com mine
echo tracked >"$work/tracked.txt"
git -C "$work" add tracked.txt
commit_as me@example.com add-tracked
echo older >>"$work/tracked.txt"
git -C "$work" stash push -q -m "someone else's stash"
older=$(git -C "$work" rev-parse refs/stash)
echo change >"$work/new-file.txt"
args=()
expect dirty-stashes 0 "STASH_REF="
reported=$( (cd "$work" && "$preflight" 2>&1 >/dev/null) | sed -n 's/^STASH_REF=//p' || true)
if [ -z "$(git -C "$work" status --porcelain)" ] && [ -n "$(git -C "$work" stash list)" ]; then
  echo "PASS: dirty-untracked-stashed"
else
  echo "FAIL: dirty-untracked-stashed: $(git -C "$work" status --porcelain)"
  fail=1
fi
newest=$(git -C "$work" rev-parse refs/stash)
if [ "$newest" != "$older" ] && git -C "$work" show --stat "$newest^3" 2>/dev/null | grep -q new-file.txt; then
  echo "PASS: stash-ref-is-ours"
else
  echo "FAIL: stash-ref-is-ours"
  fail=1
fi
if [ -z "$reported" ]; then
  echo "PASS: clean-tree-reports-no-stash"
else
  echo "FAIL: clean-tree-reports-no-stash: $reported"
  fail=1
fi

exit "$fail"
