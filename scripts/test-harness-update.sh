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
check workflow-checkout-keeps-no-credentials grep -qE '^ +persist-credentials: false$' "$wf"
# One optional secret, HARNESS_UPDATE_TOKEN, passed as itself; no other.
check workflow-only-the-update-token-secret test "$(grep -oE 'secrets\.[A-Za-z0-9_]+' "$wf" | sort -u)" = secrets.HARNESS_UPDATE_TOKEN
check workflow-update-token-env grep -qxE ' +HARNESS_UPDATE_TOKEN: \$\{\{ secrets\.HARNESS_UPDATE_TOKEN \}\}' "$wf"
check workflow-update-token-once test "$(grep -c 'secrets\.' "$wf")" = 1
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

# B drops the Stop hook and adds a SessionEnd hook whose command has a
# mention and a run of backticks, which the PR body must render safely.
cat >"$scratch/edit-hooks.py" <<'PY'
import json
p = "hooks/hooks.json"
d = json.load(open(p))
del d["hooks"]["Stop"]
d["hooks"]["SessionEnd"] = [{"hooks": [{"type": "command", "command": 'echo "@hubot ``` done"'}]}]
open(p, "w").write(json.dumps(d, indent=2))
PY
release 9.9.9 sh -c 'echo "B change" >>skills/engineering/tdd/SKILL.md; echo "B change" >>claude-skills/tdd/SKILL.md
  python3 "$1"' _ "$scratch/edit-hooks.py"

# --- A stub gh ------------------------------------------------------------------
mkdir -p "$scratch/bin"
cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh: the latest release is $STUB_TAG; open PRs are in $STUB_DIR/prs.
echo "$*" >>"$STUB_DIR/log"
case "${GH_TOKEN:-}" in
  test-token-s3cret) token=github ;;
  test-app-s3cret) token=app ;;
  *) echo "stub gh: no GH_TOKEN" >&2; exit 1 ;;
esac
echo "$1 $2 token=$token" >>"$STUB_DIR/gh-tokens"
body() {
  while [ $# -gt 0 ]; do
    if [ "$1" = --body-file ]; then cp "$2" "$STUB_DIR/body.md"; fi
    shift
  done
}
case "$1 $2" in
  "api repos/dougborg/harness-kit/releases/latest")
    printf '{"tag_name": "%s", "html_url": "https://github.com/dougborg/harness-kit/releases/tag/%s", "body": "### Features\\n\\n* the B change, thanks @octocat"}\n' "$STUB_TAG" "$STUB_TAG" ;;
  "pr list")
    # Only the --jq form harness-update.sh uses: the first number, or nothing.
    [ "${*: -2:1}" = --jq ] && [ "${*: -1}" = '.[0].number // empty' ] || { echo "stub gh: want --jq" >&2; exit 1; }
    python3 -c 'import json,sys; prs=json.load(open(sys.argv[1])) if len(sys.argv) > 1 else []; print(prs[0]["number"]) if prs else None' \
      $([ -f "$STUB_DIR/prs" ] && echo "$STUB_DIR/prs") ;;
  "pr create") body "$@"; echo '[{"number": 7}]' >"$STUB_DIR/prs"; echo "https://github.com/o/r/pull/7" ;;
  "pr edit") body "$@" ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$scratch/bin/gh"
# A git wrapper that records, for each push, whether the token reached it as
# an Authorization header and whether the caller's own GIT_CONFIG_* survived.
REAL_GIT=$(command -v git)
export REAL_GIT
cat >"$scratch/bin/git" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = push ]; then
  header=$("$REAL_GIT" config --get-all http.extraheader || true)
  auth=$(python3 -c 'import base64,sys; print(base64.b64decode(sys.argv[1].rsplit(" ", 1)[-1]).decode())' "$header" 2>/dev/null || true)
  case $auth in
    x-access-token:test-token-s3cret) auth=ok ;;
    x-access-token:test-app-s3cret) auth=app ;;
    *) auth=missing ;;
  esac
  echo "push auth=$auth keep=$("$REAL_GIT" config --get test.keep || true)" >>"$STUB_DIR/git-log"
fi
exec "$REAL_GIT" "$@"
STUB
chmod +x "$scratch/bin/git"
export STUB_DIR="$scratch/stub"
mkdir -p "$STUB_DIR"
: >"$STUB_DIR/log"

# update <tag>: run the vendored harness-update.sh in the project; sets out, rc.
# $update_token, when set, is passed as HARNESS_UPDATE_TOKEN.
update_token=
summary="$scratch/step-summary.md"
update() {
  set +e
  : >"$summary"
  # The caller's own GIT_CONFIG_* entry must survive the token's.
  out=$(cd "$proj" && PATH="$scratch/bin:$PATH" STUB_TAG=$1 GITHUB_SERVER_URL="file://$srv" \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=test.keep GIT_CONFIG_VALUE_0=kept GITHUB_ACTIONS=true \
    GITHUB_STEP_SUMMARY="$summary" HARNESS_UPDATE_TOKEN="$update_token" \
    HARNESS_UPSTREAM='' GH_TOKEN=test-token-s3cret .claude/skills/harness/harness-update.sh 2>&1)
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
check body-neutralises-mentions sh -c '! grep -qF "@octocat" "$1" && grep -qF "octocat" "$1"' _ "$STUB_DIR/body.md"
check body-has-report body_has "vendored harness-kit 9.9.9 (from $version)"
check body-hook-section body_has "## Hook changes"
check body-lists-hook-removed body_has '- removed `Stop`:'
check body-shows-removed-command grep -qxF '  "${CLAUDE_PROJECT_DIR}/.claude/hooks/harness-kit/retro-nudge.sh"' "$STUB_DIR/body.md"
check body-lists-hook-added body_has '- added `SessionEnd`:'
# The command is shown byte for byte in a fence longer than its backtick run;
# mentions don't fire inside a code block.
check body-shows-added-command grep -qxF '  echo "@hubot ``` done"' "$STUB_DIR/body.md"
check body-hook-fence-outlasts-command grep -qxF '  ````text' "$STUB_DIR/body.md"
check body-says-close-and-reopen body_has "close and reopen it to run CI"
check pr-uses-github-token test "$(grep -c 'token=app' "$STUB_DIR/gh-tokens")" = 0
check body-reports-fork-with-fetched-tag body_has "skill \`tdd\` (forked from $version): 2 files changed upstream"
check push-gets-token grep -qx 'push auth=ok keep=kept' "$STUB_DIR/git-log"
check token-masked-in-actions has "::add-mask::$(printf 'x-access-token:test-token-s3cret' | base64 | tr -d '\n')"
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
release 9.9.10 sh -c 'echo "echo tampered >>AGENTS.md; env >\"\$STUB_DIR/upstream-env\"" >>skills/meta/harness/vendor-snapshot.sh'
update_token=test-app-s3cret
update v9.9.10
update_token=
check guard-fails test "$rc" = 1
check guard-names-path has "  AGENTS.md"
check guard-pushes-nothing test "$(origin_branch)" = "$first"
check guard-touches-no-pr test "$(pr_calls)" = "$calls"
check upstream-script-ran test -s "$STUB_DIR/upstream-env"
check upstream-script-gets-no-token sh -c '! grep -q s3cret "$1"' _ "$STUB_DIR/upstream-env"
check upstream-script-gets-no-update-token sh -c '! grep -q HARNESS_UPDATE_TOKEN "$1"' _ "$STUB_DIR/upstream-env"
check no-token-in-git-config sh -c '! grep -rq s3cret "$1/.git/config"' _ "$proj"

# --- A release that changes the workflow itself can't be pushed by GITHUB_TOKEN ---
pgit reset -q --hard
pgit clean -qfd
release 9.9.11 sh -c 'git checkout -q v9.9.9 -- skills/meta/harness/vendor-snapshot.sh
  for f in skills/meta/harness/harness-update.yml claude-skills/harness/harness-update.yml; do echo "# B" >>"$f"; done'
update v9.9.11
check workflow-change-fails test "$rc" = 1
check workflow-change-explains has "GITHUB_TOKEN can't push"
# The failure names the exact local commands and the docs, in the log and the
# job summary.
check workflow-change-names-clone has "git clone --depth 1 --branch v9.9.11 file://$srv/dougborg/harness-kit \"\$release\""
check workflow-change-names-vendor has '"$release"/skills/meta/harness/vendor-snapshot.sh "$release" .'
check workflow-change-names-secret has "HARNESS_UPDATE_TOKEN"
check workflow-change-links-docs has "Docs: file://$srv/dougborg/harness-kit/blob/v9.9.11/skills/meta/harness/vendoring.md#the-update-workflow"
check workflow-change-in-summary grep -qF "git clone --depth 1 --branch v9.9.11" "$summary"
check workflow-change-pushes-nothing test "$(origin_branch)" = "$first"

# With HARNESS_UPDATE_TOKEN the same release is delivered: the token pushes
# the branch and edits the PR, so the PR's CI runs; GITHUB_TOKEN does neither.
pgit reset -q --hard
pgit clean -qfd
pgit switch -q main
: >"$STUB_DIR/gh-tokens"
update_token=test-app-s3cret
update v9.9.11
update_token=
check token-workflow-change-exits-0 test "$rc" = 0
[ "$rc" = 0 ] || echo "$out"
check token-workflow-change-pushed sh -c 'git --git-dir "$1" show harness-kit/update:.github/workflows/harness-update.yml | grep -qx "# B"' _ "$scratch/origin.git"
check token-push-uses-update-token test "$(tail -1 "$STUB_DIR/git-log")" = 'push auth=app keep=kept'
check token-pr-uses-update-token grep -qx 'pr edit token=app' "$STUB_DIR/gh-tokens"
check token-release-read-with-github-token grep -qx 'api repos/dougborg/harness-kit/releases/latest token=github' "$STUB_DIR/gh-tokens"
check token-body-says-ci-runs body_has "HARNESS_UPDATE_TOKEN"
check token-body-no-close-and-reopen sh -c '! grep -qF "close and reopen" "$1"' _ "$STUB_DIR/body.md"
check token-masked-in-actions has "::add-mask::$(printf 'x-access-token:test-app-s3cret' | base64 | tr -d '\n')"
# Put back the 9.9.9 branch the later cases build on.
git --git-dir "$scratch/origin.git" update-ref refs/heads/harness-kit/update "$first"

# --- A release whose manifest doesn't match its tag is refused ----------------------
pgit reset -q --hard
pgit clean -qfd
pgit switch -q main
release 9.9.13 git checkout -q v9.9.9 -- skills/meta/harness/harness-update.yml claude-skills/harness/harness-update.yml
ugit tag v9.9.12
update v9.9.12
check tag-mismatch-fails test "$rc" = 1
check tag-mismatch-explains has "9.9.13, not the tag's 9.9.12"
check tag-mismatch-pushes-nothing test "$(origin_branch)" = "$first"
check tag-mismatch-writes-nothing test -z "$(git -C "$proj" status --porcelain)"

# --- Pre-release tags are not followed -----------------------------------------------
pgit reset -q --hard
pgit clean -qfd
update v9.9.14-rc.1
check prerelease-fails test "$rc" = 1
check prerelease-explains has "pre-release"

# --- With B merged, a release that changes no hook says so ----------------------------
pgit reset -q --hard
pgit clean -qfd
pgit fetch -q origin harness-kit/update
pgit merge -q --ff-only FETCH_HEAD
pgit push -q origin main
release 9.9.15 sh -c 'echo "C change" >>skills/engineering/tdd/SKILL.md; echo "C change" >>claude-skills/tdd/SKILL.md'
update v9.9.15
check no-hook-change-exits-0 test "$rc" = 0
[ "$rc" = 0 ] || echo "$out"
check body-says-no-hook-changes body_has "This update changes no harness hook entries"
check body-no-hook-entries-listed sh -c '! grep -qE "^- (added|removed) " "$1"' _ "$STUB_DIR/body.md"

# --- The update token leaves the environment before any child process runs ---------
# A project whose resolver records its environment: the resolver is the first
# script harness-update.sh runs, so it must not see HARNESS_UPDATE_TOKEN.
main_proj=$proj
proj="$scratch/resolver-project"
git clone -q -b main "$scratch/origin.git" "$proj"
cat >"$proj/.claude/skills/harness/resolve-upstream.sh" <<'STUB'
#!/usr/bin/env bash
env >"$STUB_DIR/resolver-env"
echo dougborg/harness-kit
STUB
pgit commit -qam 'stub resolver'
update_token=test-app-s3cret
update v9.9.15
update_token=
check resolver-stub-ran test -s "$STUB_DIR/resolver-env"
check resolver-gets-no-update-token sh -c '! grep -q test-app-s3cret "$1" && ! grep -q HARNESS_UPDATE_TOKEN "$1"' _ "$STUB_DIR/resolver-env"
proj=$main_proj

exit "$fail"
