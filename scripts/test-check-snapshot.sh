#!/usr/bin/env bash
# Scratch-repo tests for skills/meta/harness/check-snapshot.sh: vendor a
# snapshot with vendor-snapshot.sh, then edit, add, and delete files and
# expect the check to fail on vendored files and pass on everything else.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail=0
# expect <name> <want exit> <dir> [text the output must contain]
expect() {
  local out got
  set +e
  out=$("$check" "$3" 2>&1)
  got=$?
  set -e
  if [ "$got" -ne "$2" ]; then
    echo "FAIL: $1: exit $got, want $2"
    printf '%s\n' "$out" | sed 's/^/  | /'
    fail=1
  elif [ -n "${4:-}" ] && ! grep -qF -- "$4" <<<"$out"; then
    echo "FAIL: $1: output lacks '$4'"
    printf '%s\n' "$out" | sed 's/^/  | /'
    fail=1
  else
    echo "PASS: $1"
  fi
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
check="$plugin/skills/meta/harness/check-snapshot.sh"

# vendored <name>: a fresh project with commit, tdd, and verifier vendored.
vendored() {
  local dir="$scratch/$1"
  mkdir -p "$dir/.harness"
  printf 'skills = ["commit", "tdd"]\nagents = ["verifier"]\n\n[facts]\nverification_command = "make ci"\n' \
    >"$dir/.harness/config.toml"
  "$plugin/skills/meta/harness/vendor-snapshot.sh" "$plugin" "$dir" >/dev/null
  echo "$dir"
}

# --- Not vendored -------------------------------------------------------------
mkdir -p "$scratch/plain"
expect no-lock-passes 0 "$scratch/plain" "not a vendored project"

# --- A clean snapshot and the edits that keep it clean --------------------------
dir=$(vendored clean)
expect clean-passes 0 "$dir"

mkdir -p "$dir/.claude/skills/local-thing" "$dir/.agents/skills/local-thing"
echo 'local' >"$dir/.claude/skills/local-thing/SKILL.md"
echo 'local' >"$dir/.agents/skills/local-thing/SKILL.md"
echo 'local agent' >"$dir/.claude/agents/domain-advisor.md"
echo 'local helper' >"$dir/.agents/scripts/shared/local-helper.sh"
echo '## Project facts' >"$dir/AGENTS.md"
sed 's/make ci/make all/' "$dir/.harness/config.toml" >"$scratch/config.toml"
mv "$scratch/config.toml" "$dir/.harness/config.toml"
python3 - "$dir/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
s = json.load(open(path))
s["permissions"] = {"allow": ["Bash(make ci)"]}
s["hooks"].setdefault("PostToolUse", []).append(
    {"matcher": "Edit", "hooks": [{"type": "command", "command": "./fmt.sh"}]})
json.dump(s, open(path, "w"), indent=2)
PY
expect project-local-and-config-pass 0 "$dir"

# --- Edited, added, deleted ---------------------------------------------------
dir=$(vendored edited)
echo 'run moon ci' >>"$dir/.claude/skills/commit/SKILL.md"
expect edited-fails 1 "$dir" "edited: .claude/skills/commit/SKILL.md"
expect edited-names-fix 1 "$dir" "Project facts"
expect edited-names-fork 1 "$dir" "[forks.skills]"

dir=$(vendored edited-agent)
echo 'run pnpm check' >>"$dir/.codex/agents/verifier.toml"
expect edited-agent-fails 1 "$dir" "edited: .codex/agents/verifier.toml"
expect edited-agent-names-fork 1 "$dir" "[forks.agents]"

dir=$(vendored added)
echo 'extra' >"$dir/.agents/skills/tdd/extra.md"
expect added-fails 1 "$dir" "added: .agents/skills/tdd/extra.md"

dir=$(vendored deleted)
rm "$dir/.claude/skills/tdd/SKILL.md"
expect deleted-fails 1 "$dir" "deleted: .claude/skills/tdd/SKILL.md"

dir=$(vendored symlinked)
mv "$dir/.claude/agents/verifier.md" "$dir/verifier.md"
ln -s ../../verifier.md "$dir/.claude/agents/verifier.md"
expect symlink-fails 1 "$dir" "edited: .claude/agents/verifier.md"

dir=$(vendored several)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
rm "$dir/.agents/skills/harness/SKILL.md"
expect several-names-first 1 "$dir" "edited: .claude/skills/commit/SKILL.md"
expect several-names-second 1 "$dir" "deleted: .agents/skills/harness/SKILL.md"

# --- Hook entries in settings.json --------------------------------------------
dir=$(vendored hook-edited)
python3 - "$dir/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
s = json.load(open(path))
event = sorted(s["hooks"])[0]
s["hooks"][event][0]["hooks"][0]["command"] = "true"
json.dump(s, open(path, "w"), indent=2)
PY
expect hook-edited-fails 1 "$dir" "hook: "

dir=$(vendored hook-removed)
python3 - "$dir/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
s = json.load(open(path))
del s["hooks"]
json.dump(s, open(path, "w"), indent=2)
PY
expect hook-removed-fails 1 "$dir" "hook: "

# --- Forks --------------------------------------------------------------------
# A fork declared after vendoring is the project's from then on, even before
# the next vendor run takes it out of the lock.
dir=$(vendored forked)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
echo x >"$dir/.agents/skills/commit/extra.md"
echo x >>"$dir/.claude/agents/verifier.md"
printf '\n[forks.skills]\ncommit = "1.0.0"\n\n[forks.agents]\nverifier = "1.0.0"\n' >>"$dir/.harness/config.toml"
expect declared-fork-passes 0 "$dir"
"$plugin/skills/meta/harness/vendor-snapshot.sh" "$plugin" "$dir" >/dev/null
expect revendored-fork-passes 0 "$dir"

# --- Broken inputs ------------------------------------------------------------
dir=$(vendored bad-lock)
echo '{' >"$dir/.harness/lock.json"
expect bad-lock-fails 1 "$dir" "lock.json"

dir=$(vendored bad-config)
echo 'skills = [' >"$dir/.harness/config.toml"
expect bad-config-fails 1 "$dir" "config.toml"

exit $fail
