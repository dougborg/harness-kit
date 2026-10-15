#!/usr/bin/env bash
# Helpers run indirectly through check(), which ShellCheck cannot see.
# shellcheck disable=SC2317
# resolve and asked run only through expect, which ShellCheck cannot see.
# shellcheck disable=SC2329
# Tests for the upstream lookup both callers share: resolve-upstream.sh run
# directly (as the harness-issue skill runs it) and harness-update.sh run in a
# scratch vendored project with a stub gh that records which upstream it asked
# for. Each source is checked in order: $HARNESS_UPSTREAM,
# .claude/harness-upstream, the legacy .harness-lock.json (only without
# .harness/lock.json), then the default.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
resolver="$repo_root/scripts/shared/resolve-upstream.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
pass() { echo "PASS: $1"; }
flunk() {
  echo "FAIL: $1"
  fail=1
}
# expect <name> <want-rc> <want-output> <command...>: output is stdout+stderr.
expect() {
  local name=$1 want_rc=$2 want=$3 out rc
  shift 3
  set +e
  out=$("$@" 2>&1)
  rc=$?
  set -e
  if [ "$rc" = "$want_rc" ] && grep -qF -- "$want" <<<"$out"; then
    pass "$name"
  else
    flunk "$name (rc=$rc, want $want_rc and '$want'): $out"
  fi
}

legacy_lock='{"sources": {"harness-kit": {"version": "1.0.0", "repo": "legacy/harness"}}, "files": {}}'

# project <dir> [file|legacy|vendored]...: a scratch project with those sources.
project() {
  local dir=$1
  shift
  mkdir -p "$dir/.claude"
  for source in "$@"; do
    case $source in
      file) echo "file/harness" >"$dir/.claude/harness-upstream" ;;
      legacy) echo "$legacy_lock" >"$dir/.harness-lock.json" ;;
      vendored) mkdir -p "$dir/.harness" && echo '{}' >"$dir/.harness/lock.json" ;;
    esac
  done
}

# --- resolve-upstream.sh, as the harness-issue skill runs it ------------------
# resolve <dir> [env]: run the resolver in <dir>, with $HARNESS_UPSTREAM=<env>.
resolve() { (cd "$1" && HARNESS_UPSTREAM=${2:-} "$resolver"); }

project "$scratch/r-all" file legacy
expect resolver-env-first 0 env/harness resolve "$scratch/r-all" env/harness
expect resolver-file-before-legacy 0 file/harness resolve "$scratch/r-all"
project "$scratch/r-legacy" legacy
expect resolver-legacy-unmigrated 0 legacy/harness resolve "$scratch/r-legacy"
project "$scratch/r-stale" legacy vendored
expect resolver-legacy-ignored-when-vendored 0 dougborg/harness-kit resolve "$scratch/r-stale"
project "$scratch/r-none"
expect resolver-default 0 dougborg/harness-kit resolve "$scratch/r-none"
expect resolver-bad-env 1 'not a valid owner/repo' resolve "$scratch/r-none" 'not a repo'
project "$scratch/r-empty"
: >"$scratch/r-empty/.claude/harness-upstream"
expect resolver-empty-file 1 'is empty' resolve "$scratch/r-empty"
project "$scratch/r-bad"
echo "https://github.com/x/y" >"$scratch/r-bad/.claude/harness-upstream"
expect resolver-bad-file 1 'not contain a valid owner/repo' resolve "$scratch/r-bad"

# --- harness-update.sh, run from the vendored harness skill -------------------
# The Claude projection ships the resolver beside harness-update.sh.
projection="$repo_root/claude-skills/harness"
if cmp -s "$resolver" "$projection/resolve-upstream.sh"; then
  pass projection-ships-resolver
else
  flunk "projection-ships-resolver: $projection/resolve-upstream.sh is missing or stale"
fi

mkdir -p "$scratch/bin"
cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh: record the call and fail, so harness-update.sh stops right after
# resolving the upstream.
echo "$*" >>"$STUB_LOG"
exit 1
STUB
chmod +x "$scratch/bin/gh"

# update_project <dir> [sources...]: a committed vendored project.
update_project() {
  project "$@" vendored
  mkdir -p "$1/.claude/skills/harness"
  cp "$projection/harness-update.sh" "$projection/resolve-upstream.sh" "$1/.claude/skills/harness/"
  git -C "$1" init -q
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm vendored
}
# asked <dir> [env]: the upstream harness-update.sh asked gh for, or its error.
asked() {
  local log
  log="$scratch/gh-$(basename "$1").log"
  : >"$log"
  (cd "$1" && PATH="$scratch/bin:$PATH" STUB_LOG=$log HARNESS_UPSTREAM=${2:-} \
    .claude/skills/harness/harness-update.sh) >"$log.out" 2>&1 || true
  if [ -s "$log" ]; then cat "$log"; else cat "$log.out"; fi
}

update_project "$scratch/u-all" file
expect update-env-first 0 'api repos/env/harness/releases/latest' asked "$scratch/u-all" env/harness
expect update-file-next 0 'api repos/file/harness/releases/latest' asked "$scratch/u-all"
update_project "$scratch/u-stale" legacy
expect update-legacy-ignored 0 'api repos/dougborg/harness-kit/releases/latest' asked "$scratch/u-stale"
update_project "$scratch/u-none"
expect update-default 0 'api repos/dougborg/harness-kit/releases/latest' asked "$scratch/u-none"
expect update-bad-env 0 'not a valid owner/repo' asked "$scratch/u-none" 'not a repo'

exit $fail
