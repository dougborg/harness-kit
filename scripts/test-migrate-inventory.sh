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

# --- Project tooling that reads what migrate removes ----------------------------
# nix-config style: a pre-commit hook and a Renovate custom manager read the
# old lock's version, the latter through a regex-escaped file pattern, and a
# doc names a tracked copy. Each is reported as file:line; the harness's own
# directories, the lock itself, and files git doesn't track are not searched.
refs="$scratch/refs"
cp -R "$v1" "$refs"
put "$refs/.pre-commit-config.yaml" 'repos:
  - repo: local
    hooks:
      - id: harness-lock
        entry: jq -r ".sources[\"harness-kit\"].version" .harness-lock.json'
put "$refs/renovate.json5" '{
  customManagers: [
    {
      customType: "regex",
      managerFilePatterns: ["/^\\.harness-lock\\.json$/"],
    },
    {
      customType: "regex",
      managerFilePatterns: ["/^\\.claude\\/agents\\/verifier\\.md$/"],
    },
  ],
}'
put "$refs/docs/gate.md" 'The gate is .claude/skills/shared/discover-verification-cmd.sh.
Upstream is in .harness-upstream.
Backups like .harness-lock.json.bak and foo.harness-upstream-x are not it.'
put "$refs/.claude/skills/deploy/notes.md" 'reads .harness-lock.json'
git -C "$refs" init -q
git -C "$refs" add -A
git -C "$refs" -c user.name=t -c user.email=t@t commit -qm init
put "$refs/scratch-notes.md" 'untracked: .harness-lock.json'

ref_is() { echo "sorted((x['file'], x['line'], x['term']) for x in r['references']) == $1"; }
json_is refs-found "$refs" "$(ref_is "[
  ('.pre-commit-config.yaml', 5, '.harness-lock.json'),
  ('docs/gate.md', 1, '.claude/skills/shared/discover-verification-cmd.sh'),
  ('docs/gate.md', 2, '.harness-upstream'),
  ('renovate.json5', 5, '.harness-lock.json'),
  ('renovate.json5', 9, '.claude/agents/verifier.md'),
]")"
json_is refs-carry-text "$refs" \
  "any(x['file'] == 'renovate.json5' and 'managerFilePatterns' in x['text'] for x in r['references'])"
# shellcheck disable=SC2016 # the backticks are Markdown, not a substitution
run refs-text 0 '- `.pre-commit-config.yaml:5` names `.harness-lock.json`' "$plugin" "$refs"
json_is refs-none-without-git "$v1" "r['references'] is None"
run refs-text-without-git 0 'not searched' "$plugin" "$v1"

# Many tracked copies against a few MB of dot-heavy text stays quick; a file
# over 1 MB is skipped, and a long line's text is cut short.
big="$scratch/big"
mkdir -p "$big"
python3 - "$big" <<'PY'
import json, sys
from pathlib import Path
d = Path(sys.argv[1])
files = {f".claude/skills/s{i}/ref.{i}.md": {"source": "harness-kit"} for i in range(500)}
(d / ".harness-lock.json").write_text(json.dumps(
    {"sources": {"harness-kit": {"version": "0.7.0"}}, "files": files}))
line = "harness a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.claude.skills.s1.ref " * 8 + "\n"
for n in range(3):
    (d / f"dots{n}.txt").write_text(line * (950_000 // len(line)))
(d / "huge.txt").write_text("x\n" * 600_000 + ".harness-lock.json\n")
(d / "long.txt").write_text("." * 5000 + " .harness-lock.json " + "." * 5000 + "\n")
PY
git -C "$big" init -q
git -C "$big" add -A
git -C "$big" -c user.name=t -c user.email=t@t commit -qm init
start=$(date +%s)
json_is big-skips-huge-file "$big" "[x['file'] for x in r['references']] == ['long.txt']"
elapsed=$(($(date +%s) - start))
if [ "$elapsed" -le 10 ]; then
  pass "big-within-10s (${elapsed}s)"
else
  flunk "big-within-10s: took ${elapsed}s" ""
fi
json_is big-text-cut-short "$big" "all(len(x['text']) <= 200 for x in r['references'])"

# A run of tens of thousands of slashes is searched in linear time, and a term
# at its end is still found.
slashes="$scratch/slashes"
cp -R "$v1" "$slashes"
python3 -c 'import sys; open(sys.argv[1], "w").write(("harness " + "a/" * 20000 + ".harness-lock.json\n") * 20)' \
  "$slashes/slashes.txt"
git -C "$slashes" init -q
git -C "$slashes" add -A
git -C "$slashes" -c user.name=t -c user.email=t@t commit -qm init
start=$(date +%s)
json_is refs-long-slash-run "$slashes" \
  "[(x['file'], x['term']) for x in r['references']] == [('slashes.txt', '.harness-lock.json')] * 20"
elapsed=$(($(date +%s) - start))
if [ "$elapsed" -le 5 ]; then
  pass "slashes-within-5s (${elapsed}s)"
else
  flunk "slashes-within-5s: took ${elapsed}s" ""
fi

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

# --- A plugin clone in SHA-256 object format ---------------------------------------
p256="$scratch/plugin256"
mkdir -p "$p256"
git -C "$p256" init -q --object-format=sha256
put "$p256/.claude-plugin/plugin.json" '{"name": "harness-kit", "version": "1.0.0"}'
put "$p256/claude-skills/commit/SKILL.md" 'commit 1.0.0 (claude)'
git -C "$p256" add -A
git -C "$p256" -c user.name=t -c user.email=t@t commit -qm 1.0.0
git -C "$p256" tag v1.0.0
s256="$scratch/s256"
put "$s256/.claude/skills/commit/SKILL.md" 'commit 1.0.0 (claude)'
put "$s256/.harness-lock.json" '{"sources": {"harness-kit": {"version": "1.0.0"}},
  "files": {".claude/skills/commit/SKILL.md": {"source": "harness-kit"}}}'
out=$("$inventory" --json "$p256" "$s256" 2>&1 || true)
if python3 -c 'import json, sys; sys.exit(json.loads(sys.argv[1])["files"][0]["status"] != "pristine")' "$out" 2>/dev/null; then
  pass sha256-plugin-pristine
else
  flunk sha256-plugin-pristine "$out"
fi

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
