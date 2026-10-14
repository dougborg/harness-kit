#!/usr/bin/env bash
# Scratch-repo tests for skills/meta/harness/vendor-snapshot.sh: vendor a
# chosen subset from a scratch copy of this plugin into scratch projects and
# check both host trees, the lock, settings, hooks, and re-run behavior.
# The assertions grep for literal ${...} text, so single quotes are meant.
# shellcheck disable=SC2016
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

# The plugin: the working tree's tracked and new files, like a release checkout.
plugin="$scratch/plugin"
mkdir -p "$plugin"
(
  cd "$repo_root"
  git ls-files -z -co --exclude-standard | while IFS= read -r -d '' f; do
    if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
  done | xargs -0 tar cf -
) | tar xf - -C "$plugin"
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
expected=$(cd "$proj" && find .claude/skills .agents/skills .claude/agents .codex/agents .agents/scripts .claude/hooks/harness-kit \
  -type f ! -path '*/local-thing/*' ! -name 'domain-advisor.*' | sed 's#^\./##' | LC_ALL=C sort)
recorded=$(json "'\n'.join(sorted(d['files']))" "$lock")
check lock-lists-every-vendored-file test "$expected" = "$recorded"
hashes_ok=true
while IFS= read -r f; do
  want=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["files"][sys.argv[2]])' "$lock" "$f")
  got=$(shasum -a 256 "$proj/$f" | cut -d' ' -f1)
  [ "$want" = "$got" ] || hashes_ok=false
done <<<"$recorded"
check lock-hash-per-file "$hashes_ok"
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

# An edited vendored file is restored to the pristine copy.
echo 'local edit' >>"$proj/.claude/skills/tdd/SKILL.md"
run "$proj" >/dev/null
check edited-file-restored cmp "$plugin/claude-skills/tdd/SKILL.md" "$proj/.claude/skills/tdd/SKILL.md"

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
proj=$(new_project third-party '["frontend-design"]' '[]')
printf '\n[sources.skills]\nfrontend-design = "anthropics/skills@main:skills/frontend-design"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal third-party-source-not-fetched "$proj" "not implemented"
proj=$(new_project orphan-source '["tdd"]' '[]')
printf '\n[sources.skills]\nfrontend-design = "anthropics/skills@main:skills/frontend-design"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal source-for-unchosen-skill "$proj" "not in skills"
proj=$(new_project bad-source '["frontend-design"]' '[]')
printf '\n[sources.skills]\nfrontend-design = "frontend-design"\n' >>"$proj/.harness/config.toml"
commit_all "$proj"
expect_refusal malformed-source "$proj" "owner/repo@ref:path"

# A forked skill is the project's own: listed in skills, never vendored.
proj=$(new_project forked '["tdd", "commit"]' '[]')
printf '\n[forks.skills]\ntdd = "1.0.0"\n' >>"$proj/.harness/config.toml"
mkdir -p "$proj/.claude/skills/tdd" && echo fork >"$proj/.claude/skills/tdd/SKILL.md"
run "$proj" >/dev/null
check fork-left-alone test "$(cat "$proj/.claude/skills/tdd/SKILL.md")" = fork
check fork-not-in-lock test "$(json "'tdd' in d['skills']" "$proj/.harness/lock.json")" = False

exit "$fail"
