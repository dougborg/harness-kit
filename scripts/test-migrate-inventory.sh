#!/usr/bin/env bash
# Scratch-repo tests for skills/meta/harness/migrate-inventory.sh: build a
# plugin repo with a 0.7.0-style release (flat skills/, symlinked shared
# script) and a 1.0.0-style one (claude-skills/, skills/<area>/, Codex
# agents), then classify the files in v1 and v2 .harness-lock.json projects.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
inventory="$repo_root/skills/meta/harness/migrate-inventory.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
pass() { echo "PASS: $1"; }
flunk() {
  echo "FAIL: $1"
  printf '%s\n' "$2" | sed 's/^/  | /'
  fail=1
}

# run <name> <want exit> <text the output must contain> <args...>
run() {
  local name=$1 want=$2 text=$3 out got
  shift 3
  set +e
  out=$("$inventory" "$@" 2>&1)
  got=$?
  set -e
  if [ "$got" -ne "$want" ]; then
    flunk "$name: exit $got, want $want" "$out"
  elif ! grep -qF -- "$text" <<<"$out"; then
    flunk "$name: output lacks '$text'" "$out"
  else
    pass "$name"
  fi
}

# json_is <name> <project> <python expression over `r`, the JSON report>
json_is() {
  local out
  out=$("$inventory" --json "$plugin" "$2" 2>&1) || {
    flunk "$1: exited non-zero" "$out"
    return
  }
  if python3 -c 'import json, sys; r = json.loads(sys.argv[1]); sys.exit(0 if eval(sys.argv[2]) else 1)' \
    "$out" "$3"; then
    pass "$1"
  else
    flunk "$1: not true: $3" "$out"
  fi
}

put() { mkdir -p "$(dirname "$1")" && printf '%s\n' "$2" >"$1"; }

gate='#!/usr/bin/env bash
if [ -f justfile ]; then echo "just check"; exit 0; fi
exit 1'
patched='#!/usr/bin/env bash
if [ -f moon.yml ]; then echo "moon ci"; exit 0; fi
if [ -f justfile ]; then echo "just check"; exit 0; fi
exit 1'

# --- The plugin: two releases, tagged ------------------------------------------
plugin="$scratch/plugin"
mkdir -p "$plugin"
git -C "$plugin" init -q
put "$plugin/.claude-plugin/plugin.json" '{"name": "harness-kit", "version": "0.7.0"}'
put "$plugin/skills/commit/SKILL.md" 'commit 0.7.0'
put "$plugin/skills/open-pr/SKILL.md" 'open-pr 0.7.0'
put "$plugin/skills/tdd/SKILL.md" 'tdd 0.7.0'
put "$plugin/skills/shared/discover-verification-cmd.sh" "$gate"
ln -s ../shared/discover-verification-cmd.sh "$plugin/skills/commit/discover-verification-cmd.sh"
ln -s ../shared/discover-verification-cmd.sh "$plugin/skills/open-pr/discover-verification-cmd.sh"
ln -s ../shared/discover-verification-cmd.sh "$plugin/skills/tdd/discover-verification-cmd.sh"
put "$plugin/agents/verifier.md" 'Run the discovered verification command.'
git -C "$plugin" add -A
git -C "$plugin" -c user.name=t -c user.email=t@t commit -qm 0.7.0
git -C "$plugin" tag v0.7.0

git -C "$plugin" rm -rq skills
put "$plugin/.claude-plugin/plugin.json" '{"name": "harness-kit", "version": "1.0.0"}'
put "$plugin/claude-skills/commit/SKILL.md" 'commit 1.0.0 (claude)'
put "$plugin/claude-skills/commit/discover-verification-cmd.sh" "$gate"
put "$plugin/skills/engineering/commit/SKILL.md" 'commit 1.0.0'
put "$plugin/skills/engineering/commit/agents/openai.yaml" 'interface: {}'
put "$plugin/scripts/shared/discover-verification-cmd.sh" "$gate"
put "$plugin/.codex/agents/verifier.toml" 'name = "verifier"'
git -C "$plugin" add -A
git -C "$plugin" -c user.name=t -c user.email=t@t commit -qm 1.0.0
git -C "$plugin" tag v1.0.0

# --- A v1 project at 0.7.0, parametric-building style --------------------------
v1="$scratch/v1"
put "$v1/.claude/skills/commit/SKILL.md" 'commit 0.7.0'
put "$v1/.claude/skills/commit/discover-verification-cmd.sh" "$patched"
put "$v1/.claude/skills/open-pr/SKILL.md" 'open-pr 0.7.0'
put "$v1/.claude/skills/open-pr/discover-verification-cmd.sh" "$patched"
put "$v1/.claude/skills/shared/discover-verification-cmd.sh" "$patched"
put "$v1/.claude/skills/tdd/discover-verification-cmd.sh" "$gate"
put "$v1/.claude/skills/retired/SKILL.md" 'a skill 0.7.0 never shipped'
put "$v1/.claude/agents/verifier.md" 'Run moon ci.'
put "$v1/.claude/agents/domain-advisor.md" 'Project rules.'
put "$v1/.claude/skills/deploy/SKILL.md" 'Our deploy steps.'
put "$v1/.harness-lock.json" '{
  "sources": {"harness-kit": {"version": "0.7.0", "repo": "dougborg/harness-kit"}},
  "files": {
    ".claude/skills/commit/SKILL.md": {"source": "harness-kit", "modified": false},
    ".claude/skills/commit/discover-verification-cmd.sh": {"source": "harness-kit", "modified": true},
    ".claude/skills/open-pr/SKILL.md": {"source": "harness-kit", "modified": false},
    ".claude/skills/open-pr/discover-verification-cmd.sh": {"source": "harness-kit", "modified": false},
    ".claude/skills/shared/discover-verification-cmd.sh": {"source": "harness-kit", "modified": true},
    ".claude/skills/tdd/SKILL.md": {"source": "harness-kit", "modified": false},
    ".claude/skills/tdd/discover-verification-cmd.sh": {"source": "harness-kit", "modified": false},
    ".claude/skills/retired/SKILL.md": {"source": "harness-kit", "modified": false},
    ".claude/agents/verifier.md": {"source": "harness-kit", "modified": true},
    ".claude/agents/domain-advisor.md": {"source": "local"}
  }
}'

status() { echo "{f['path']: f['status'] for f in r['files']}['$1'] == '$2'"; }

json_is v1-schema "$v1" "r['schema'] == 1 and r['version'] == '0.7.0'"
json_is v1-pristine-skill "$v1" "$(status .claude/skills/commit/SKILL.md pristine)"
json_is v1-modified-through-symlink "$v1" "$(status .claude/skills/open-pr/discover-verification-cmd.sh modified)"
json_is v1-pristine-copy-of-symlink "$v1" "$(status .claude/skills/tdd/discover-verification-cmd.sh pristine)"
json_is v1-modified-agent "$v1" "$(status .claude/agents/verifier.md modified)"
json_is v1-missing "$v1" "$(status .claude/skills/tdd/SKILL.md missing)"
json_is v1-no-upstream "$v1" "$(status .claude/skills/retired/SKILL.md no-upstream)"
json_is v1-local "$v1" "$(status .claude/agents/domain-advisor.md local)"
json_is v1-untracked "$v1" "$(status .claude/skills/deploy/SKILL.md untracked)"
json_is v1-upstream-path "$v1" \
  "{f['path']: f['upstream'] for f in r['files']}['.claude/skills/commit/SKILL.md'] == 'skills/commit/SKILL.md'"
json_is v1-owner "$v1" \
  "{f['path']: f['owner'] for f in r['files']}['.claude/agents/verifier.md'] == 'agent verifier'"
# The same moon ci patch in three copies is one change; the verifier's is another.
json_is v1-one-change-for-identical-patches "$v1" \
  "len(r['changes']) == 2 and sorted(len(c['paths']) for c in r['changes']) == [1, 3]"
json_is v1-change-diff "$v1" \
  "any('+if [ -f moon.yml ]' in c['diff'] and len(c['paths']) == 3 for c in r['changes'])"
run v1-text-groups 0 '### Change 1: 3 files' "$plugin" "$v1"
run v1-text-diff 0 '+if [ -f moon.yml ]; then echo "moon ci"; exit 0; fi' "$plugin" "$v1"

# --- A v2 project at 1.0.0, both hosts ------------------------------------------
v2="$scratch/v2"
put "$v2/.claude/skills/commit/SKILL.md" 'commit 1.0.0 (claude)'
put "$v2/.agents/skills/commit/SKILL.md" 'commit 1.0.0'
put "$v2/.agents/skills/commit/agents/openai.yaml" 'interface: {}'
put "$v2/.agents/scripts/shared/discover-verification-cmd.sh" "$gate"
put "$v2/.codex/agents/verifier.toml" 'name = "verifier" # run pnpm check'
put "$v2/.claude/skills/frontend-design/SKILL.md" 'third party'
put "$v2/.harness-lock.json" '{
  "schemaVersion": 2,
  "hosts": ["claude", "codex"],
  "sources": {
    "harness-kit": {"version": "1.0.0", "repo": "dougborg/harness-kit"},
    "anthropics": {"version": "main"}
  },
  "files": {
    ".claude/skills/commit/SKILL.md": {"source": "harness-kit", "modified": false, "host": "claude", "component": "skill"},
    ".agents/skills/commit/SKILL.md": {"source": "harness-kit", "modified": false, "host": "codex", "component": "skill"},
    ".agents/skills/commit/agents/openai.yaml": {"source": "harness-kit", "modified": false, "host": "codex", "component": "skill"},
    ".agents/scripts/shared/discover-verification-cmd.sh": {"source": "harness-kit", "modified": false, "host": "codex", "component": "skill"},
    ".codex/agents/verifier.toml": {"source": "harness-kit", "modified": false, "host": "codex", "component": "agent"},
    ".claude/skills/frontend-design/SKILL.md": {"source": "anthropics", "modified": false, "host": "claude", "component": "skill"}
  }
}'

json_is v2-schema "$v2" "r['schema'] == 2 and r['version'] == '1.0.0'"
json_is v2-claude-projection "$v2" "$(status .claude/skills/commit/SKILL.md pristine)"
json_is v2-codex-skill-by-area "$v2" \
  "{f['path']: f['upstream'] for f in r['files']}['.agents/skills/commit/SKILL.md'] == 'skills/engineering/commit/SKILL.md'"
json_is v2-codex-sibling "$v2" "$(status .agents/skills/commit/agents/openai.yaml pristine)"
json_is v2-shared-script "$v2" "$(status .agents/scripts/shared/discover-verification-cmd.sh pristine)"
json_is v2-codex-agent "$v2" "$(status .codex/agents/verifier.toml modified)"
json_is v2-other-source "$v2" "$(status .claude/skills/frontend-design/SKILL.md other-source)"

# --- Refusals --------------------------------------------------------------------
mkdir -p "$scratch/plain"
run no-lock 1 'no .harness-lock.json' "$plugin" "$scratch/plain"

old="$scratch/old"
put "$old/.harness-lock.json" '{"sources": {"harness-kit": {"version": "0.6.0"}}, "files": {}}'
run missing-tag 1 'fetch --depth 1 origin tag v0.6.0' "$plugin" "$old"

notgit="$scratch/notgit"
mkdir -p "$notgit"
run plugin-not-git 1 'not a git checkout' "$notgit" "$v1"

run usage 2 'usage:' "$plugin" "$v1" extra

exit "$fail"
