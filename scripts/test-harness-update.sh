#!/usr/bin/env bash
# Helpers run indirectly through check(), which ShellCheck cannot see.
# shellcheck disable=SC2317
# Tests for the vendored update workflow: static checks that
# skills/meta/harness/harness-update.yml runs harness-update.sh, which runs
# vendor-snapshot.sh and the diff guard; then harness-update.sh itself against
# a scratch upstream repo (served over file://), a scratch project with a bare
# origin, and a stub gh that records PR calls. No Action is run.
# The assertions grep for literal backticks, so single quotes are meant, and
# some helpers are only called through check.
# shellcheck disable=SC2016,SC2329
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dir="$repo_root/skills/meta/harness"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
pass() { echo "PASS: $1"; }
flunk() {
  echo "FAIL: $1"
  fail=1
}
check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else flunk "$name"; fi
}

# --- Static: the workflow and what it runs ------------------------------------
wf="$dir/harness-update.yml"
check workflow-runs-update-script grep -qE '^ +run: \.claude/skills/harness/harness-update\.sh$' "$wf"
check workflow-on-schedule grep -qE '^  schedule:' "$wf"
check workflow-on-dispatch grep -qE '^  workflow_dispatch:' "$wf"
check workflow-uses-github-token grep -qF 'GH_TOKEN: ${{ github.token }}' "$wf"
check workflow-no-other-secrets sh -c '! grep -q "secrets\." "$1"' _ "$wf"
check workflow-permissions python3 -c 'import sys; sys.exit("\npermissions:\n  contents: write\n  pull-requests: write\n\n" not in open(sys.argv[1]).read())' "$wf"
check workflow-actions-pinned sh -c '! grep -E "uses: " "$1" | grep -vqE "uses: [^@ ]+@[0-9a-f]{40}( |$)"' _ "$wf"
check script-runs-vendor-snapshot grep -qF '"$plugin/skills/meta/harness/vendor-snapshot.sh" "$plugin" .' "$dir/harness-update.sh"
check script-has-diff-guard grep -qF "the update changed paths the snapshot doesn't own" "$dir/harness-update.sh"

# --- A scratch upstream: release A (this tree) and B ---------------------------
srv="$scratch/srv"
up="$srv/dougborg/harness-kit"
mkdir -p "$up"
(
  cd "$repo_root"
  git ls-files -z -co --exclude-standard | while IFS= read -r -d '' f; do
    if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
  done | xargs -0 tar cf -
) | tar xf - -C "$up"
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$up/.claude-plugin/plugin.json")
ugit() { git -C "$up" -c user.name=t -c user.email=t@t "$@"; }
ugit init -q
ugit add -A
ugit commit -qm A
ugit tag "v$version"
# release <version> [<edit command>]: commit a release of the upstream.
release() {
  local v=$1
  shift
  for m in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
    python3 - "$up/$m" "$v" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["version"] = sys.argv[2]
open(sys.argv[1], "w").write(json.dumps(d, indent=2) + "\n")
PY
  done
  if [ $# -gt 0 ]; then (cd "$up" && "$@"); fi
  ugit add -A
  ugit commit -qm "$v"
  ugit tag "v$v"
}

# --- A vendored project at A, with a fork, pushed to a bare origin -------------
proj="$scratch/project"
mkdir -p "$proj/.harness" "$proj/.claude/skills/tdd"
printf 'skills = ["commit"]\nagents = []\n\n[forks.skills]\ntdd = "%s"\n' "$version" >"$proj/.harness/config.toml"
echo 'my tdd' >"$proj/.claude/skills/tdd/SKILL.md"
echo '# project' >"$proj/AGENTS.md"
"$up/skills/meta/harness/vendor-snapshot.sh" "$up" "$proj" >/dev/null
pgit() { git -C "$proj" -c user.name=t -c user.email=t@t "$@"; }
pgit init -q -b main
pgit add -A
pgit commit -qm vendor
git init -q --bare "$scratch/origin.git"
pgit remote add origin "$scratch/origin.git"
pgit push -q origin main
origin_branch() { git --git-dir "$scratch/origin.git" rev-parse -q --verify refs/heads/harness-kit/update || true; }

release 9.9.9 sh -c 'echo "B change" >>skills/engineering/tdd/SKILL.md; echo "B change" >>claude-skills/tdd/SKILL.md'

# --- A stub gh ------------------------------------------------------------------
mkdir -p "$scratch/bin"
cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh: the latest release is $STUB_TAG; open PRs are in $STUB_DIR/prs.
echo "$*" >>"$STUB_DIR/log"
body() {
  while [ $# -gt 0 ]; do
    if [ "$1" = --body-file ]; then cp "$2" "$STUB_DIR/body.md"; fi
    shift
  done
}
case "$1 $2" in
  "api repos/dougborg/harness-kit/releases/latest")
    printf '{"tag_name": "%s", "html_url": "https://github.com/dougborg/harness-kit/releases/tag/%s", "body": "### Features\\n\\n* the B change"}\n' "$STUB_TAG" "$STUB_TAG" ;;
  "pr list") cat "$STUB_DIR/prs" 2>/dev/null || echo '[]' ;;
  "pr create") body "$@"; echo '[{"number": 7}]' >"$STUB_DIR/prs"; echo "https://github.com/o/r/pull/7" ;;
  "pr edit") body "$@" ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$scratch/bin/gh"
export STUB_DIR="$scratch/stub"
mkdir -p "$STUB_DIR"
: >"$STUB_DIR/log"

# update <tag>: run the vendored harness-update.sh in the project; sets out, rc.
update() {
  set +e
  out=$(cd "$proj" && PATH="$scratch/bin:$PATH" STUB_TAG=$1 GITHUB_SERVER_URL="file://$srv" \
    HARNESS_UPSTREAM='' .claude/skills/harness/harness-update.sh 2>&1)
  rc=$?
  set -e
}
has() { grep -qF -- "$1" <<<"$out"; }
body_has() { grep -qF -- "$1" "$STUB_DIR/body.md"; }
pr_calls() { grep -c '^pr \(create\|edit\)' "$STUB_DIR/log" || true; }

# --- No newer release: nothing happens --------------------------------------------
update "v$version"
check up-to-date-exits-0 test "$rc" = 0
check up-to-date-says-so has "up to date"
check up-to-date-pushes-nothing test -z "$(origin_branch)"
check up-to-date-opens-no-pr test "$(pr_calls)" = 0
check up-to-date-writes-nothing test -z "$(git -C "$proj" status --porcelain)"

# --- A newer release: one PR -------------------------------------------------------
update v9.9.9
check newer-exits-0 test "$rc" = 0
[ "$rc" = 0 ] || echo "$out"
check newer-pushes-branch test -n "$(origin_branch)"
check newer-branch-lock-is-b test "$(git --git-dir "$scratch/origin.git" show harness-kit/update:.harness/lock.json |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')" = 9.9.9
check newer-leaves-config git --git-dir "$scratch/origin.git" diff --quiet main harness-kit/update -- .harness/config.toml AGENTS.md
check newer-opens-pr grep -qF 'pr create --head harness-kit/update --base main' "$STUB_DIR/log"
check body-links-release-notes body_has "[release notes](https://github.com/dougborg/harness-kit/releases/tag/v9.9.9)"
check body-has-release-notes body_has "* the B change"
check body-has-report body_has "vendored harness-kit 9.9.9 (from $version)"
check body-reports-fork-with-fetched-tag body_has "skill \`tdd\` (forked from $version): 2 files changed upstream"
first=$(origin_branch)

# --- Again, with the PR open: it is updated, not duplicated -----------------------
pgit switch -q main
update v9.9.9
check rerun-exits-0 test "$rc" = 0
[ "$rc" = 0 ] || echo "$out"
check rerun-edits-open-pr grep -qF 'pr edit 7 ' "$STUB_DIR/log"
check rerun-creates-no-second-pr test "$(grep -c '^pr create' "$STUB_DIR/log")" = 1
check rerun-same-content-not-pushed test "$(origin_branch)" = "$first"

# --- The diff guard: a release that touches a project file is refused --------------
pgit switch -q main
calls=$(pr_calls)
release 9.9.10 sh -c 'echo "echo tampered >>AGENTS.md" >>skills/meta/harness/vendor-snapshot.sh'
update v9.9.10
check guard-fails test "$rc" = 1
check guard-names-path has "  AGENTS.md"
check guard-pushes-nothing test "$(origin_branch)" = "$first"
check guard-touches-no-pr test "$(pr_calls)" = "$calls"

# --- A release that changes the workflow itself can't be pushed by GITHUB_TOKEN ---
pgit reset -q --hard
pgit clean -qfd
release 9.9.11 sh -c 'git checkout -q v9.9.9 -- skills/meta/harness/vendor-snapshot.sh
  for f in skills/meta/harness/harness-update.yml claude-skills/harness/harness-update.yml; do echo "# B" >>"$f"; done'
update v9.9.11
check workflow-change-fails test "$rc" = 1
check workflow-change-explains has "GITHUB_TOKEN can't push"
check workflow-change-pushes-nothing test "$(origin_branch)" = "$first"

exit "$fail"
