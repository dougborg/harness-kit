#!/usr/bin/env bash
# Helpers run indirectly through check(), which ShellCheck cannot see.
# shellcheck disable=SC2317
# Scratch-repo tests for skills/meta/harness/vendor-snapshot.sh: vendor a
# chosen subset from a scratch copy of this plugin into scratch projects and
# check both host trees, the lock, settings, hooks, re-run behavior, and an
# update from release A to B with forks, removed skills, and new ones.
# The assertions grep for literal ${...} text, so single quotes are meant, and
# some helpers are only called through check.
# shellcheck disable=SC2016,SC2329
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
pass() { echo "PASS: $1"; }
flunk() {
  echo "FAIL: $1"
  fail=1
}
# check <name> <command...>: PASS when the command succeeds.
check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else flunk "$name"; fi
}

# new_plugin <dir>: the working tree's tracked and new files, like a release
# checkout without its git history.
new_plugin() {
  mkdir -p "$1"
  (
    cd "$repo_root"
    git ls-files -z -co --exclude-standard | while IFS= read -r -d '' f; do
      if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
    done | xargs -0 tar cf -
  ) | tar xf - -C "$1"
}
plugin="$scratch/plugin"
new_plugin "$plugin"
vendor="$plugin/skills/meta/harness/vendor-snapshot.sh"
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$plugin/.claude-plugin/plugin.json")

# new_project <name> <skills toml> <agents toml>: a git repo with a config,
# settings with keys of its own, and project-local skills, agents, and hooks.
new_project() {
  local dir="$scratch/$1"
  mkdir -p "$dir/.harness" "$dir/.claude/skills/local-thing" "$dir/.agents/skills/local-thing" \
    "$dir/.claude/agents" "$dir/.codex/agents" "$dir/.claude/hooks"
  printf 'skills = %s\nagents = %s\n\n[facts]\nverification_command = "make ci"\n' "$2" "$3" >"$dir/.harness/config.toml"
  cat >"$dir/.claude/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Bash(make ci)"]},
  "enabledPlugins": {"other@market": true, "harness-kit@harness-kit": true},
  "hooks": {
    "PostToolUse": [
      {"matcher": "Edit", "hooks": [{"type": "command", "command": "./.claude/hooks/fmt.sh"}]}
    ]
  }
}
JSON
  echo 'local skill' >"$dir/.claude/skills/local-thing/SKILL.md"
  echo 'local skill' >"$dir/.agents/skills/local-thing/SKILL.md"
  echo 'local agent' >"$dir/.claude/agents/domain-advisor.md"
  echo 'name = "domain-advisor"' >"$dir/.codex/agents/domain-advisor.toml"
  echo 'echo fmt' >"$dir/.claude/hooks/fmt.sh"
  git -C "$dir" init -q
  git -C "$dir" add -A
  git -C "$dir" -c user.name=t -c user.email=t@t commit -qm init
  echo "$dir"
}
run() { "$vendor" "$plugin" "$1"; }
commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm vendor
}
dirs() { /bin/ls "$1" | tr '\n' ' '; }
json() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print($1)" "$2"; }

# --- A chosen subset into a fresh project -----------------------------------
proj=$(new_project subset '["commit", "tdd"]' '["verifier"]')
local_sum=$(cd "$proj" && shasum .claude/skills/local-thing/SKILL.md .agents/skills/local-thing/SKILL.md \
  .claude/agents/domain-advisor.md .codex/agents/domain-advisor.toml .claude/hooks/fmt.sh .harness/config.toml)
if run "$proj" >/dev/null; then pass "vendor-subset-runs"; else flunk "vendor-subset-runs"; fi

check exactly-the-chosen-set-plus-harness test \
  "$(dirs "$proj/.claude/skills")|$(dirs "$proj/.agents/skills")|$(dirs "$proj/.claude/agents")|$(dirs "$proj/.codex/agents")" = \
  "commit harness local-thing tdd |commit harness local-thing tdd |domain-advisor.md verifier.md |domain-advisor.toml verifier.toml "
check claude-skill-is-the-projection diff -r "$plugin/claude-skills/tdd" "$proj/.claude/skills/tdd"
check codex-skill-is-canonical diff -r "$plugin/skills/engineering/tdd" "$proj/.agents/skills/tdd"
check codex-skill-keeps-openai-yaml test -f "$proj/.agents/skills/commit/agents/openai.yaml"
check claude-agent-copied cmp "$plugin/agents/verifier.md" "$proj/.claude/agents/verifier.md"
check codex-agent-copied cmp "$plugin/.codex/agents/verifier.toml" "$proj/.codex/agents/verifier.toml"
check codex-helper-vendored cmp "$plugin/scripts/shared/discover-verification-cmd.sh" \
  "$proj/.agents/scripts/shared/discover-verification-cmd.sh"
check codex-helper-executable test -x "$proj/.agents/scripts/shared/discover-verification-cmd.sh"
check unused-helper-not-vendored test ! -e "$proj/.agents/scripts/shared/pr-threads.sh"
check no-symlinks test -z "$(find "$proj" -type l)"

# --- The lock ----------------------------------------------------------------
lock="$proj/.harness/lock.json"
check lock-records-version test "$(json "d['version']" "$lock")" = "$version"
expected=$(cd "$proj" && find .claude/skills .agents/skills .claude/agents .codex/agents .agents/scripts .claude/hooks/harness-kit .github \
  -type f ! -path '*/local-thing/*' ! -name 'domain-advisor.*' | sed 's#^\./##' | LC_ALL=C sort)
recorded=$(json "'\n'.join(sorted(d['files']))" "$lock")
check lock-lists-every-vendored-file test "$expected" = "$recorded"
# hashes_match <project>: every file in the lock is on disk with its hash.
hashes_match() {
  python3 - "$1" <<'PY'
import hashlib, json, sys
from pathlib import Path
root = Path(sys.argv[1])
files = json.loads((root / ".harness/lock.json").read_text())["files"]
sys.exit(any(hashlib.sha256((root / f).read_bytes()).hexdigest() != h for f, h in files.items()))
PY
}
check lock-hash-per-file hashes_match "$proj"
check update-workflow-vendored cmp "$plugin/skills/meta/harness/harness-update.yml" "$proj/.github/workflows/harness-update.yml"
check update-workflow-in-lock test "$(json "'.github/workflows/harness-update.yml' in d['files']" "$lock")" = True
check lock-records-chosen-skills test "$(json "' '.join(sorted(d['skills']))" "$lock")" = "commit harness tdd"
check lock-records-chosen-agents test "$(json "' '.join(sorted(d['agents']))" "$lock")" = "verifier"

# --- Settings and hooks ------------------------------------------------------
settings="$proj/.claude/settings.json"
check settings-disables-plugin test "$(json "d['enabledPlugins']['harness-kit@harness-kit']" "$settings")" = False
check settings-keeps-other-plugins test "$(json "d['enabledPlugins']['other@market']" "$settings")" = True
check settings-keeps-permissions test "$(json "d['permissions']['allow'][0]" "$settings")" = "Bash(make ci)"
check settings-keeps-project-hook test "$(json "d['hooks']['PostToolUse'][0]['hooks'][0]['command']" "$settings")" = "./.claude/hooks/fmt.sh"
hook_cmds=$(json "'\n'.join(h['command'] for e in d['hooks'].values() for x in e for h in x['hooks'])" "$settings")
check settings-gets-plugin-hooks grep -qF '"${CLAUDE_PROJECT_DIR}/.claude/hooks/harness-kit/retro-nudge.sh"' <<<"$hook_cmds"
check settings-gets-command-hooks grep -qF 'Context was just compacted' <<<"$hook_cmds"
check hook-commands-leave-plugin-root sh -c '! grep -q CLAUDE_PLUGIN_ROOT "$1"' _ "$settings"
check hook-script-vendored test -x "$proj/.claude/hooks/harness-kit/retro-nudge.sh"
check hook-script-pristine cmp "$plugin/scripts/shared/markdownlint-fix.sh" "$proj/.claude/hooks/harness-kit/markdownlint-fix.sh"
check lock-records-hook-entries test "$(json "len(d['hooks']['claude']['Stop'])" "$lock")" = 1
check skill-text-leaves-plugin-root-scripts sh -c '! grep -rqE "(CLAUDE_PLUGIN_ROOT\}|plugin-root>)/scripts/shared/[a-z]" "$1/.claude" "$1/.agents"' _ "$proj"
check skill-text-points-into-snapshot grep -qF '${CLAUDE_PROJECT_DIR}/.claude/hooks/harness-kit/retro-nudge.sh' \
  "$proj/.claude/skills/harness/hooks-patterns.md"

# --- Project-local files ------------------------------------------------------
check project-local-untouched test "$local_sum" = "$(cd "$proj" && shasum .claude/skills/local-thing/SKILL.md \
  .agents/skills/local-thing/SKILL.md .claude/agents/domain-advisor.md .codex/agents/domain-advisor.toml \
  .claude/hooks/fmt.sh .harness/config.toml)"

# --- Re-running at the same version ------------------------------------------
commit_all "$proj"
touch "$scratch/marker"
sleep 1
run "$proj" >/dev/null
check rerun-changes-nothing test -z "$(git -C "$proj" status --porcelain)"
check rerun-writes-nothing test -z "$(find "$proj" -path "$proj/.git" -prune -o -type f -newer "$scratch/marker" -print)"

# An edited snapshot is refused, writing nothing, with the edit check's
# findings and the fix; --discard-edits restores the pristine copy.
# expect_guard <name> <message>: the run fails, prints <message>, and leaves
# the working tree as it was.
expect_guard() {
  local out rc before
  before=$(git -C "$proj" status --porcelain; git -C "$proj" diff)
  set +e
  out=$(run "$proj" 2>&1)
  rc=$?
  set -e
  if [ "$rc" = 1 ] && [[ "$out" == *"$2"* ]] && [[ "$out" == *--discard-edits* ]] &&
    [ "$before" = "$(git -C "$proj" status --porcelain; git -C "$proj" diff)" ]; then
    pass "$1"
  else
    flunk "$1: want exit 1 with \"$2\" and no writes, got exit $rc: $out"
  fi
}
echo 'local edit' >>"$proj/.claude/skills/tdd/SKILL.md"
expect_guard edited-file-refused "edited: .claude/skills/tdd/SKILL.md"
check refusal-names-facts-fix sh -c '"$1" "$2" "$3" 2>&1 | grep -qF "declare a fork"' _ "$vendor" "$plugin" "$proj"
"$vendor" --discard-edits "$plugin" "$proj" >/dev/null
check discard-edits-restores cmp "$plugin/claude-skills/tdd/SKILL.md" "$proj/.claude/skills/tdd/SKILL.md"
check discard-edits-leaves-tree-clean test -z "$(git -C "$proj" status --porcelain)"
echo 'stray' >"$proj/.agents/skills/tdd/extra.md"
expect_guard added-file-refused "added: .agents/skills/tdd/extra.md"
rm "$proj/.agents/skills/tdd/extra.md"
sed -i.bak 's/23 7/0 0/' "$proj/.github/workflows/harness-update.yml" && rm "$proj/.github/workflows/harness-update.yml.bak"
expect_guard edited-workflow-refused "edited: .github/workflows/harness-update.yml"
git -C "$proj" checkout -q -- .
rm "$proj/.claude/hooks/harness-kit/retro-nudge.sh"
expect_guard deleted-file-refused "deleted: .claude/hooks/harness-kit/retro-nudge.sh"
git -C "$proj" checkout -q -- .
python3 - "$settings" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); del d["hooks"]["Stop"]; open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
expect_guard hook-drift-refused "hook: Stop"
git -C "$proj" checkout -q -- .

# --- A smaller set and a new release -----------------------------------------
printf 'skills = ["commit"]\nagents = []\n' >"$proj/.harness/config.toml"
python3 - "$plugin" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
for manifest in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
    p = root / manifest
    d = json.loads(p.read_text()); d["version"] = "9.9.9"; p.write_text(json.dumps(d, indent=2) + "\n")
p = root / "hooks/hooks.json"
d = json.loads(p.read_text()); del d["hooks"]["Stop"]; p.write_text(json.dumps(d, indent=2) + "\n")
PY
run "$proj" >/dev/null
check dropped-skill-removed-both-hosts test ! -e "$proj/.claude/skills/tdd" -a ! -e "$proj/.agents/skills/tdd"
check dropped-agent-removed-both-hosts test ! -e "$proj/.claude/agents/verifier.md" -a ! -e "$proj/.codex/agents/verifier.toml"
check new-version-recorded test "$(json "d['version']" "$lock")" = 9.9.9
check dropped-hook-entry-removed test "$(json "'Stop' in d['hooks']" "$settings")" = False
check project-hook-survives-update test "$(json "d['hooks']['PostToolUse'][0]['hooks'][0]['command']" "$settings")" = "./.claude/hooks/fmt.sh"
check local-survives-update test -f "$proj/.claude/skills/local-thing/SKILL.md" -a -f "$proj/.claude/agents/domain-advisor.md"

# --- Updating from release A to B, with forks ----------------------------------
# A release checkout: a git clone holding tag v<A>, whose files then become B.
up_plugin="$scratch/plugin-up"
new_plugin "$up_plugin"
git -C "$up_plugin" init -q
git -C "$up_plugin" add -A
git -C "$up_plugin" -c user.name=t -c user.email=t@t commit -qm release
git -C "$up_plugin" tag "v$version"
proj=$(new_project update '["commit", "tdd", "grilling", "pr-body"]' '["verifier", "code-reviewer"]')
"$vendor" "$up_plugin" "$proj" >/dev/null
commit_all "$proj"

# The project forks tdd and verifier from A (and edits its copies), forks
# pr-body from a version with no tag, and forks domain-modeling, which B drops.
cat >>"$proj/.harness/config.toml" <<TOML

[forks.skills]
tdd = "$version"
pr-body = "0.0.1"
domain-modeling = "$version"

[forks.agents]
verifier = "$version"
TOML
echo 'fork edit' >>"$proj/.claude/skills/tdd/SKILL.md"
echo 'fork edit' >>"$proj/.claude/agents/verifier.md"
commit_all "$proj"
fork_paths=(.claude/skills/tdd .agents/skills/tdd .claude/skills/pr-body .agents/skills/pr-body
  .claude/agents/verifier.md .codex/agents/verifier.toml)
fork_sum() { (cd "$proj" && find "${fork_paths[@]}" -type f | LC_ALL=C sort | xargs shasum -a 256); }
fork_before=$(fork_sum)

# Release B: commit changes (a file edited, one added, one deleted), tdd
# changes upstream, grilling and domain-modeling are removed, and a skill and
# an agent are new.
(
  cd "$up_plugin"
  for d in skills/engineering/commit claude-skills/commit; do
    echo 'B change' >>"$d/SKILL.md"
    echo 'B reference' >"$d/new-ref.md"
    rm "$d/uv-lock-drift.md"
  done
  echo 'B change' >>skills/engineering/tdd/SKILL.md
  echo 'B change' >>claude-skills/tdd/SKILL.md
  rm -rf skills/thinking/grilling claude-skills/grilling skills/thinking/domain-modeling claude-skills/domain-modeling
  cp -R skills/engineering/tdd skills/engineering/brand-new
  cp -R claude-skills/tdd claude-skills/brand-new
  cp agents/code-reviewer.md agents/new-agent.md
  cp .codex/agents/code-reviewer.toml .codex/agents/new-agent.toml
  for m in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
    sed -i.bak "s/\"version\": \"$version\"/\"version\": \"9.9.9\"/" "$m" && rm "$m.bak"
  done
)
report=$("$vendor" "$up_plugin" "$proj")
lock="$proj/.harness/lock.json"
has() { grep -qF -- "$1" <<<"$report"; }
lacks() { ! has "$1"; }

check update-lock-is-b test "$(json "d['version']" "$lock")" = 9.9.9
check update-replaces-edited-file cmp "$up_plugin/claude-skills/commit/SKILL.md" "$proj/.claude/skills/commit/SKILL.md"
check update-adds-new-file test -f "$proj/.claude/skills/commit/new-ref.md" -a -f "$proj/.agents/skills/commit/new-ref.md"
check update-deletes-dropped-file test ! -e "$proj/.claude/skills/commit/uv-lock-drift.md" -a ! -e "$proj/.agents/skills/commit/uv-lock-drift.md"
check update-lock-hashes-are-b hashes_match "$proj"
check update-codex-skill-is-b diff -r "$up_plugin/skills/engineering/commit" "$proj/.agents/skills/commit"

check forks-byte-for-byte test "$fork_before" = "$(fork_sum)"
check forks-leave-the-lock test "$(json "len([f for f in d['files'] if '/tdd/' in f or '/pr-body/' in f or 'verifier' in f])" "$lock")" = 0
check fork-report-changed has "skill \`tdd\` (forked from $version): 2 files changed upstream"
check fork-report-lists-claude-change has "  - M \`.claude/skills/tdd/SKILL.md\`"
check fork-report-lists-codex-change has "  - M \`.agents/skills/tdd/SKILL.md\`"
check fork-report-unchanged has "agent \`verifier\` (forked from $version): no upstream changes"
check fork-report-missing-tag has "skill \`pr-body\` (forked from 0.0.1): not compared: tag v0.0.1 is not in"
check fork-report-removed has "skill \`domain-modeling\` (forked from $version): removed upstream in 9.9.9"

check removed-skill-dropped test ! -e "$proj/.claude/skills/grilling" -a ! -e "$proj/.agents/skills/grilling"
check removed-skill-reported has "- skill \`grilling\`"
check removed-skill-not-in-lock test "$(json "'grilling' in d['skills']" "$lock")" = False

check new-skill-offered has "- skill \`brand-new\`"
check new-agent-offered has "- agent \`new-agent\`"
check new-not-installed test ! -e "$proj/.claude/skills/brand-new" -a ! -e "$proj/.claude/agents/new-agent.md"
check unchosen-old-skill-not-offered lacks "\`wayfinder\`"
check report-names-both-versions has "vendored harness-kit 9.9.9 (from $version)"

# The machine-readable report. A rerun at B still reports the removed skill
# the config lists, and offers nothing new.
commit_all "$proj"
jreport=$("$vendor" --json "$up_plugin" "$proj")
jq_() { python3 -c "import json,sys; d=json.loads(sys.argv[1]); print($1)" "$jreport"; }
check json-versions test "$(jq_ "d['from'], d['to']")" = "9.9.9 9.9.9"
check json-removed-carried test "$(jq_ "d['removed']")" = "{'skills': ['grilling'], 'agents': []}"
check json-nothing-new test "$(jq_ "d['new']")" = "{'skills': [], 'agents': []}"
check json-fork-status test "$(jq_ "[(f['kind'], f['name'], f['status']) for f in d['forks']]")" = \
  "[('skill', 'domain-modeling', 'removed'), ('skill', 'pr-body', 'not-compared'), ('skill', 'tdd', 'changed'), ('agent', 'verifier', 'unchanged')]"
check json-fork-changes test "$(jq_ "[f['changes'] for f in d['forks'] if f['name'] == 'tdd'][0]")" = \
  "[{'status': 'M', 'path': '.agents/skills/tdd/SKILL.md'}, {'status': 'M', 'path': '.claude/skills/tdd/SKILL.md'}]"
check json-rerun-writes-nothing test -z "$(git -C "$proj" status --porcelain)"

# --- Refusals: nothing is written ---------------------------------------------
# expect_refusal <name> <project> <message>
expect_refusal() {
  local out rc
  set +e
  out=$(run "$2" 2>&1)
  rc=$?
  set -e
  if [ "$rc" != 0 ] && [[ "$out" == *"$3"* ]] && [ ! -e "$2/.harness/lock.json" ] &&
    [ -z "$(git -C "$2" status --porcelain)" ]; then
    pass "$1"
  else
    flunk "$1: want failure with \"$3\" and no writes, got exit $rc: $out"
  fi
}
proj=$(new_project unknown '["no-such-skill"]' '[]')
expect_refusal unknown-skill "$proj" "no-such-skill"
proj=$(new_project unknown-agent '[]' '["no-such-agent"]')
expect_refusal unknown-agent "$proj" "no-such-agent"
proj=$(new_project collide '["tdd"]' '[]')
mkdir -p "$proj/.claude/skills/tdd" && echo mine >"$proj/.claude/skills/tdd/SKILL.md"
commit_all "$proj"
expect_refusal project-local-collision "$proj" "project-local"
proj=$(new_project orphan-source '["tdd"]' '[]')
printf '\n[sources.skills]\nfrontend-design = "anthropics/skills@main:skills/frontend-design"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal source-for-unchosen-skill "$proj" "not in skills"
proj=$(new_project bad-source '["frontend-design"]' '[]')
printf '\n[sources.skills]\nfrontend-design = "frontend-design"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal malformed-source "$proj" "owner/repo@ref:path"
# A name is one path component: anything else could escape the snapshot.
n=0
for bad in '..' '.' '' 'a/b'; do
  n=$((n + 1))
  proj=$(new_project "bad-skill-name-$n" "[\"$bad\"]" '[]')
  expect_refusal "bad-skill-name '$bad'" "$proj" "not a valid name"
done
# '..' inside a name is still one component: it's looked up, not refused.
proj=$(new_project dots-in-name '["a..b"]' '[]')
expect_refusal dots-in-name-is-valid "$proj" "a..b"
check dots-in-name-not-invalid sh -c '! "$1" "$2" "$3" 2>&1 | grep -qF "not a valid name"' _ "$vendor" "$plugin" "$proj"
proj=$(new_project bad-agent-name '[]' '["../verifier"]')
expect_refusal bad-agent-name "$proj" "not a valid name"
proj=$(new_project bad-fork-name '["tdd"]' '[]')
printf '\n[forks.skills]\n"../tdd" = "1.0.0"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal bad-fork-name "$proj" "not a valid name"
proj=$(new_project bad-source-name '["tdd"]' '[]')
printf '\n[sources.skills]\n"a/b" = "anthropics/skills@main:skills/x"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal bad-source-name "$proj" "not a valid name"

# A write that fails after its temp file exists (an empty directory where a
# file goes) exits non-zero and leaves no temp file behind.
proj=$(new_project write-fails '["tdd"]' '[]')
mkdir -p "$proj/.claude/skills/tdd/SKILL.md"
set +e
run "$proj" >/dev/null 2>&1
rc=$?
set -e
check write-failure-exits-nonzero test "$rc" != 0
check write-failure-leaves-no-temp test -z "$(find "$proj" -name '.*.tmp')"

# A symlinked directory inside the project is never written through.
proj=$(new_project symlinked-parent '["tdd"]' '[]')
mkdir -p "$scratch/elsewhere"
mv "$proj/.agents/skills" "$scratch/elsewhere/skills"
ln -s "$scratch/elsewhere/skills" "$proj/.agents/skills"
commit_all "$proj"
expect_refusal symlinked-parent-refused "$proj" "symlink"
check symlink-target-untouched test ! -e "$scratch/elsewhere/skills/tdd"

# Dropping the last vendored agent keeps the host directories themselves.
proj=$(new_project last-agent '["tdd"]' '["verifier"]')
rm "$proj/.codex/agents/domain-advisor.toml" "$proj/.claude/agents/domain-advisor.md"
commit_all "$proj"
run "$proj" >/dev/null
commit_all "$proj"
printf 'skills = ["tdd"]\nagents = []\n' >"$proj/.harness/config.toml"
run "$proj" >/dev/null
check last-agent-removed test ! -e "$proj/.codex/agents/verifier.toml" -a ! -e "$proj/.claude/agents/verifier.md"
check host-agent-dirs-kept test -d "$proj/.codex/agents" -a -d "$proj/.claude/agents"
check no-temp-files-left test -z "$(find "$proj" -name '.*.tmp*' -print)"

# A lock that claims a path outside the snapshot's trees is refused before
# anything is removed, even when the edit check is skipped.
proj=$(new_project bad-lock '["tdd"]' '[]')
run "$proj" >/dev/null
commit_all "$proj"
echo keep >"$scratch/outside.txt"
for claimed in '../outside.txt' '.claude/skills/../../../outside.txt' 'AGENTS.md' '.github/workflows/ci.yml'; do
  python3 - "$proj/.harness/lock.json" "$claimed" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d["files"][sys.argv[2]] = "0" * 64; open(p, "w").write(json.dumps(d))
PY
  set +e
  out=$("$vendor" --discard-edits "$plugin" "$proj" 2>&1)
  rc=$?
  set -e
  if [ "$rc" = 1 ] && [[ "$out" == *"refusing to manage $claimed"* ]] && [ -f "$scratch/outside.txt" ]; then
    pass "lock-path-refused $claimed"
  else
    flunk "lock-path-refused $claimed: exit $rc: $out"
  fi
  git -C "$proj" checkout -q -- .
done

# A forked skill is the project's own: listed in skills, never vendored.
proj=$(new_project forked '["tdd", "commit"]' '[]')
printf '\n[forks.skills]\ntdd = "1.0.0"\n' >>"$proj/.harness/config.toml"
mkdir -p "$proj/.claude/skills/tdd" && echo fork >"$proj/.claude/skills/tdd/SKILL.md"
report=$(run "$proj")
check fork-left-alone test "$(cat "$proj/.claude/skills/tdd/SKILL.md")" = fork
check fork-without-git-not-compared grep -qE '^- skill `tdd` \(forked from 1\.0\.0\): not compared: .*/plugin is not a git checkout' <<<"$report"
check fork-not-in-lock test "$(json "'tdd' in d['skills']" "$proj/.harness/lock.json")" = False

# --- The update schedule: [update] schedule templates the workflow's cron -------
cron_line() { grep -E '^ +- cron: ' "$1/.github/workflows/harness-update.yml"; }
proj=$(new_project scheduled '["commit"]' '[]')
run "$proj" >/dev/null
check default-schedule-unchanged test "$(cron_line "$proj")" = "$(grep -E '^ +- cron: ' "$plugin/skills/meta/harness/harness-update.yml")"
printf '\n[update]\nschedule = "5 4 * * 2"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
run "$proj" >/dev/null
check schedule-templated test "$(cron_line "$proj")" = '    - cron: "5 4 * * 2"'
check schedule-only-cron-changes test "$(diff "$plugin/skills/meta/harness/harness-update.yml" \
  "$proj/.github/workflows/harness-update.yml" | grep -c '^[<>]')" = 2
check schedule-lock-hashes-templated hashes_match "$proj"
check schedule-passes-edit-check "$plugin/skills/meta/harness/check-snapshot.sh" "$proj"
commit_all "$proj"
sed -i.bak 's/5 4 \* \* 2/*\/30 * * * */' "$proj/.harness/config.toml" && rm "$proj/.harness/config.toml.bak"
run "$proj" >/dev/null
check schedule-change-revendors test "$(cron_line "$proj")" = '    - cron: "*/30 * * * *"'
check schedule-change-passes-edit-check "$plugin/skills/meta/harness/check-snapshot.sh" "$proj"
n=0
for bad in '"5 4 * *"' '"5 4 * * 1 2"' '"5 4 * * 1\" #"' '"5  4 * * 1"' '"5 4 * * mon"' '""' '5' '["5 4 * * 1"]'; do
  n=$((n + 1))
  proj=$(new_project "bad-schedule-$n" '["commit"]' '[]')
  printf '\n[update]\nschedule = %s\n' "$bad" >>"$proj/.harness/config.toml"
  commit_all "$proj"
  expect_refusal "bad-schedule $bad" "$proj" "[update] schedule"
done
proj=$(new_project bad-update-table '["commit"]' '[]')
printf 'update = "weekly"\n%s\n' "$(cat "$proj/.harness/config.toml")" >"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal "update-not-a-table" "$proj" "[update]"

# --- Third-party skills: fetched from [sources.skills] -------------------------
# Sources resolve under HARNESS_SOURCE_BASE_URL, here a directory of local
# repos, so owner/repo "acme/skills" is $scratch/sources/acme/skills.
export HARNESS_SOURCE_BASE_URL="file://$scratch/sources"
src="$scratch/sources/acme/skills"
mkdir -p "$src/skills/frontend-design/scripts" "$src/skills/no-skill"
cat >"$src/skills/frontend-design/SKILL.md" <<'MD'
---
name: frontend-design
---
Run ${CLAUDE_PLUGIN_ROOT}/scripts/shared/discover-verification-cmd.sh and <plugin-root>/scripts/shared/x.sh.
MD
printf '#!/bin/sh\necho hi\n' >"$src/skills/frontend-design/scripts/run.sh"
chmod +x "$src/skills/frontend-design/scripts/run.sh"
echo 'not a skill' >"$src/skills/no-skill/README.md"
git -C "$src" init -q -b main
git -C "$src" add -A
git -C "$src" -c user.name=t -c user.email=t@t commit -qm one
sha1=$(git -C "$src" rev-parse HEAD)
pristine_src="$scratch/frontend-design-1"
cp -R "$src/skills/frontend-design" "$pristine_src"

# new_sourced <name> <source>: a project vendoring tdd and one sourced skill.
new_sourced() {
  local dir
  dir=$(new_project "$1" "[\"tdd\", \"${3:-frontend-design}\"]" '[]')
  printf '\n[sources.skills]\n%s = "%s"\n' "${3:-frontend-design}" "$2" >>"$dir/.harness/config.toml"
  commit_all "$dir"
  echo "$dir"
}
proj=$(new_sourced sourced "acme/skills@$sha1:skills/frontend-design")
report=$(run "$proj")
lock="$proj/.harness/lock.json"
check sourced-claude-tree-verbatim diff -r "$pristine_src" "$proj/.claude/skills/frontend-design"
check sourced-codex-tree-verbatim diff -r "$pristine_src" "$proj/.agents/skills/frontend-design"
check sourced-keeps-exec-bit test -x "$proj/.agents/skills/frontend-design/scripts/run.sh"
check sourced-no-shared-helper-pulled test ! -e "$proj/.agents/scripts/shared/x.sh"
check sourced-lock-source test "$(json "d['skills']['frontend-design']" "$lock")" = "acme/skills@$sha1:skills/frontend-design"
check sourced-lock-commit test "$(json "d['source_commits']['frontend-design']" "$lock")" = "$sha1"
check sourced-lock-hashes hashes_match "$proj"
check sourced-files-in-lock test "$(json "'.agents/skills/frontend-design/scripts/run.sh' in d['files']" "$lock")" = True
check sourced-edit-check-passes "$plugin/skills/meta/harness/check-snapshot.sh" "$proj"
check sourced-report-pinned grep -qF "skill \`frontend-design\`: acme/skills@$sha1:skills/frontend-design at $sha1" <<<"$report"
check sourced-sha-not-warned sh -c '! printf %s "$1" | grep -qF "not a commit SHA"' _ "$report"
commit_all "$proj"
sleep 1
touch "$scratch/marker"
run "$proj" >/dev/null
check sourced-rerun-writes-nothing test -z "$(find "$proj" -path "$proj/.git" -prune -o -type f -newer "$scratch/marker" -print)"
echo 'local edit' >>"$proj/.claude/skills/frontend-design/SKILL.md"
expect_guard sourced-edit-refused "edited: .claude/skills/frontend-design/SKILL.md"
git -C "$proj" checkout -q -- .

# A branch is followed: the report warns it isn't a SHA and says when it moved.
proj=$(new_sourced sourced-branch "acme/skills@main:skills/frontend-design")
report=$(run "$proj" 2>&1)
check branch-vendored diff -r "$pristine_src" "$proj/.claude/skills/frontend-design"
check branch-warned grep -qF "not a commit SHA" <<<"$report"
commit_all "$proj"
echo 'v2' >>"$src/skills/frontend-design/SKILL.md"
git -C "$src" -c user.name=t -c user.email=t@t commit -qam two
sha2=$(git -C "$src" rev-parse HEAD)
report=$(run "$proj" 2>&1)
check branch-follows-move cmp "$src/skills/frontend-design/SKILL.md" "$proj/.agents/skills/frontend-design/SKILL.md"
check branch-move-reported grep -qF "moved from $sha1 to $sha2" <<<"$report"
check branch-lock-commit test "$(json "d['source_commits']['frontend-design']" "$proj/.harness/lock.json")" = "$sha2"
jreport=$("$vendor" --json "$plugin" "$proj")
check json-sources test "$(jq_ "[(s['name'], s['commit'], s['previous'], s['pinned']) for s in d['sources']]")" = \
  "[('frontend-design', '$sha2', '$sha2', False)]"

# Dropping a sourced skill from the config removes it like any vendored skill.
commit_all "$proj"
printf 'skills = ["tdd"]\nagents = []\n' >"$proj/.harness/config.toml"
run "$proj" >/dev/null
check sourced-dropped test ! -e "$proj/.claude/skills/frontend-design" -a ! -e "$proj/.agents/skills/frontend-design"
check sourced-dropped-from-lock test "$(json "'frontend-design' in d.get('source_commits', {})" "$proj/.harness/lock.json")" = False

# A forked sourced skill is left alone and not compared with harness-kit.
proj=$(new_sourced sourced-fork "acme/skills@$sha1:skills/frontend-design")
printf '\n[forks.skills]\nfrontend-design = "1.0.0"\n' >>"$proj/.harness/config.toml"
mkdir -p "$proj/.claude/skills/frontend-design" && echo fork >"$proj/.claude/skills/frontend-design/SKILL.md"
report=$(run "$proj")
check sourced-fork-left-alone test "$(cat "$proj/.claude/skills/frontend-design/SKILL.md")" = fork
check sourced-fork-not-compared grep -qF "skill \`frontend-design\` (forked from 1.0.0): not compared: from acme/skills" <<<"$report"

# Unreachable or malformed sources, or a tree that isn't a plain skill, fail
# with nothing written.
missing=0123456789abcdef0123456789abcdef01234567
proj=$(new_sourced sourced-no-ref "acme/skills@$missing:skills/frontend-design")
expect_refusal unreachable-ref "$proj" "can't fetch"
proj=$(new_sourced sourced-no-repo "acme/nope@$sha1:skills/frontend-design")
expect_refusal unreachable-repo "$proj" "can't fetch"
proj=$(new_sourced sourced-no-path "acme/skills@$sha1:skills/absent")
expect_refusal missing-path "$proj" "skills/absent"
proj=$(new_sourced sourced-no-skill-md "acme/skills@$sha1:skills/no-skill" no-skill)
expect_refusal path-without-skill-md "$proj" "no SKILL.md"
n=0
for bad in "acme/skills@--upload-pack=x:skills/frontend-design" "acme/skills@$sha1:../skills" \
  "acme/skills@$sha1:/etc" "-x/skills@$sha1:skills/frontend-design" "acme/skills@a..b:skills/frontend-design"; do
  n=$((n + 1))
  proj=$(new_sourced "sourced-malformed-$n" "$bad")
  expect_refusal "malformed-source $bad" "$proj" "owner/repo@ref:path"
done
proj=$(new_sourced sourced-bad-base "acme/skills@$sha1:skills/frontend-design")
set +e
out=$(HARNESS_SOURCE_BASE_URL="ext::sh -c touch% $scratch/pwned" "$vendor" "$plugin" "$proj" 2>&1)
rc=$?
set -e
if [ "$rc" = 1 ] && [[ "$out" == *HARNESS_SOURCE_BASE_URL* ]] && [ ! -e "$scratch/pwned" ] &&
  [ ! -e "$proj/.harness/lock.json" ]; then
  pass "base-url-must-be-https-or-file"
else
  flunk "base-url-must-be-https-or-file: exit $rc: $out"
fi
ln -s ../../../../outside "$src/skills/frontend-design/escape"
git -C "$src" add -A
git -C "$src" -c user.name=t -c user.email=t@t commit -qm symlink
proj=$(new_sourced sourced-symlink "acme/skills@main:skills/frontend-design")
expect_refusal symlink-in-source-refused "$proj" "symlink"

exit "$fail"
