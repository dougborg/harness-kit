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

# The vendored discovery helpers put the check in front of the gate, and the
# command they print runs the vendored check.
want='.claude/skills/harness/check-snapshot.sh && make ci'
for helper in .agents/scripts/shared .claude/skills/commit; do
  got=$("$dir/$helper/discover-verification-cmd.sh" "$dir")
  if [ "$got" = "$want" ]; then
    echo "PASS: gate-from-$helper"
  else
    echo "FAIL: gate-from-$helper: got '$got', want '$want'"
    fail=1
  fi
done
if (cd "$dir" && .claude/skills/harness/check-snapshot.sh >/dev/null); then
  echo "PASS: gate-runs-vendored-check"
else
  echo "FAIL: gate-runs-vendored-check"
  fail=1
fi

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

# --- An older python3 -----------------------------------------------------------
# macOS's system python3 is 3.9, which has no tomllib. The stub reports 3.9 and
# runs the real interpreter with tomllib shadowed, so the import fails as it
# does there. The check reads forks without tomllib, so it still runs.
real_python=$(command -v python3)
old="$scratch/python39"
mkdir -p "$old/shadow"
echo 'raise ImportError("No module named tomllib (stub Python 3.9)")' >"$old/shadow/tomllib.py"
cat >"$old/python3" <<SH
#!/bin/sh
case "\$1" in --version | -V) echo "Python 3.9.6"; exit 0 ;; esac
PYTHONPATH="$old/shadow" exec "$real_python" "\$@"
SH
chmod +x "$old/python3"
if PATH="$old:$PATH" python3 -c 'import tomllib' 2>/dev/null; then
  echo "FAIL: python39-stub: the stub imports tomllib"
  fail=1
fi
dir=$(vendored old-python)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
printf '\n[forks.skills]\n"commit" = "1.0.0" # re-synced by hand\n' >>"$dir/.harness/config.toml"
PATH="$old:$PATH" expect old-python-fork-passes 0 "$dir" "snapshot is unedited"
echo x >>"$dir/.claude/skills/tdd/SKILL.md"
PATH="$old:$PATH" expect old-python-edit-fails 1 "$dir" "edited: .claude/skills/tdd/SKILL.md"

# Vendoring needs tomllib, so it finds a newer interpreter (find-python.sh)
# when python3 is too old.
newer="$scratch/python311"
mkdir -p "$newer"
ln -s "$real_python" "$newer/python3.11"
if out=$(PATH="$old:$newer:$PATH" "$plugin/skills/meta/harness/vendor-snapshot.sh" --discard-edits "$plugin" "$dir" 2>&1); then
  echo "PASS: old-python-vendors"
else
  echo "FAIL: old-python-vendors"
  printf '%s\n' "$out" | sed 's/^/  | /'
  fail=1
fi
PATH="$old:$PATH" expect old-python-revendored-passes 0 "$dir" "snapshot is unedited"

# The stub has the new interpreter's syntax, so it can't catch 3.10+-only
# syntax. Where the machine's own /usr/bin/python3 predates 3.11 (macOS's
# 3.9), run the check on it too.
if [ -x /usr/bin/python3 ] && /usr/bin/python3 -c 'import sys; sys.exit(sys.version_info >= (3, 11))' 2>/dev/null; then
  system="$scratch/system-python"
  mkdir -p "$system"
  ln -s /usr/bin/python3 "$system/python3"
  dir=$(vendored system-python)
  echo x >>"$dir/.claude/skills/commit/SKILL.md"
  printf '\n[forks.skills]\ncommit = "1.0.0"\n' >>"$dir/.harness/config.toml"
  PATH="$system:$PATH" expect system-python-fork-passes 0 "$dir" "snapshot is unedited"
  echo x >>"$dir/.claude/skills/tdd/SKILL.md"
  PATH="$system:$PATH" expect system-python-edit-fails 1 "$dir" "edited: .claude/skills/tdd/SKILL.md"
else
  echo "SKIP: system-python: no /usr/bin/python3 older than 3.11"
fi

# Only the [forks.skills] and [forks.agents] tables name forks: a key of that
# name elsewhere doesn't.
dir=$(vendored fork-elsewhere)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
printf '\n[facts.forks]\ncommit = "x"\n\n[forks.agents]\ncommit = "1.0.0"\n' >>"$dir/.harness/config.toml"
expect fork-of-other-table-fails 1 "$dir" "edited: .claude/skills/commit/SKILL.md"

# A form the line reader can't read leaves the fork unseen, so its edited
# files still fail the check: never a pass on a form it misreads.
# misread_case <name> <config text>: commit is edited; the check must fail.
misread_case() {
  local dir
  dir=$(vendored "$1")
  echo x >>"$dir/.claude/skills/commit/SKILL.md"
  printf '%s\n' "$2" >>"$dir/.harness/config.toml"
  expect "$1-fails" 1 "$dir" "edited: .claude/skills/commit/SKILL.md"
}
# A header inside a multi-line string, basic or literal, opens no table.
misread_case header-in-basic-string '
[facts]
note = """
[forks.skills]
"""
commit = "1.0.0"'
misread_case header-in-literal-string "
[facts]
note = '''
[forks.skills]
'''
commit = '1.0.0'"
# A key line inside a fork's multi-line value is not a fork.
misread_case key-in-multiline-value '
[forks.skills]
tdd = """1.0.0
commit = "1.0.0"
"""'
# Opened and closed on one line, then opened again: still inside the string.
misread_case string-reopened-on-one-line "
[facts]
a = '''x''' # then
b = '''
[forks.skills]
commit = '1.0.0'
'''"
# A """ or ''' in a comment or a one-line string opens no multi-line string,
# so a later one can't close a phantom and hand [facts]' keys to a fork table.
misread_case triple-in-comment '
[forks.skills]
tdd = "1" # """
[facts]
x = 1 # """
commit = "x"'
misread_case triple-in-literal-string "
[forks.skills]
tdd = '\"\"\"'
[facts]
x = '\"\"\"'
commit = 'x'"
dir=$(vendored triple-in-string-then-fork)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
printf '%s\n' '' '[facts]' "a = '\"\"\"'" 'b = "x \" # \"\"\""' '[forks.skills]' 'commit = "1.0.0"' \
  >>"$dir/.harness/config.toml"
expect triple-in-string-then-fork-passes 0 "$dir"
# Quotes next to a delimiter belong to the string: """" opens one whose text
# starts with a quote, and """a""""" closes with a"" as its text.
misread_case four-quotes-open '
[facts]
a = """"
[forks.skills]
commit = "1.0.0"
"""'
dir=$(vendored five-quotes-close)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
printf '%s\n' '' '[forks.skills]' 'tdd = """a"""""' 'commit = "1.0.0"' >>"$dir/.harness/config.toml"
expect five-quotes-close-passes 0 "$dir"
# Keys after a multi-line string closes are a fork only under a new header.
misread_case key-after-multiline-value '
[forks.skills]
tdd = """
1.0.0
"""
commit = "1.0.0"'
# A quoted header names another table (or one this reader doesn't parse).
misread_case quoted-header '
["forks.skills"]
commit = "1.0.0"'
misread_case quoted-header-part '
[forks."skills"]
commit = "1.0.0"'
# Whitespace around the dot is still [forks.skills].
dir=$(vendored spaced-header)
echo x >>"$dir/.claude/skills/commit/SKILL.md"
printf '\n[ forks . skills ]\ncommit = "1.0.0"\n' >>"$dir/.harness/config.toml"
expect spaced-header-fork-passes 0 "$dir"

# --- The snapshot's paths, for formatter and linter excludes -------------------
# --paths prints every file the lock owns, one per line, and nothing else: no
# fork, no project-local file. It lists the files whether or not they were
# edited, and follows the lock across a re-vendor.
# paths_case <name> <dir> <want file>: --paths output must equal the file.
paths_case() {
  local got
  if ! got=$("$check" --paths "$2" 2>&1); then
    echo "FAIL: $1: exit nonzero"
    printf '%s\n' "$got" | sed 's/^/  | /'
    fail=1
  elif [ "$got" != "$(cat "$3")" ]; then
    echo "FAIL: $1: paths differ from the want list"
    diff <(printf '%s\n' "$got") "$3" | sed 's/^/  | /'
    fail=1
  else
    echo "PASS: $1"
  fi
}
dir=$(vendored paths)
mkdir -p "$dir/.claude/skills/local-thing"
echo local >"$dir/.claude/skills/local-thing/SKILL.md"
echo x >>"$dir/.claude/skills/tdd/SKILL.md"
python3 -c 'import json,sys; print("\n".join(sorted(json.load(open(sys.argv[1]))["files"])))' \
  "$dir/.harness/lock.json" >"$scratch/paths-want"
for p in .claude/skills/tdd/SKILL.md .codex/agents/verifier.toml .github/workflows/harness-update.yml \
  .claude/skills/harness/check-snapshot.sh; do
  grep -qxF "$p" "$scratch/paths-want" || {
    echo "FAIL: paths-fixture: the lock lacks $p"
    fail=1
  }
done
paths_case paths-lists-the-lock "$dir" "$scratch/paths-want"
if grep -q 'local-thing' <("$check" --paths "$dir"); then
  echo "FAIL: paths-omit-project-local"
  fail=1
else
  echo "PASS: paths-omit-project-local"
fi
printf '\n[forks.skills]\ntdd = "1.0.0"\n' >>"$dir/.harness/config.toml"
grep -v '/tdd/' "$scratch/paths-want" >"$scratch/paths-want-forked"
paths_case paths-omit-forks "$dir" "$scratch/paths-want-forked"
"$plugin/skills/meta/harness/vendor-snapshot.sh" "$plugin" "$dir" >/dev/null
paths_case paths-follow-revendor "$dir" "$scratch/paths-want-forked"
: >"$scratch/empty"
paths_case paths-without-lock-empty "$scratch/plain" "$scratch/empty"

# --- Broken inputs ------------------------------------------------------------
dir=$(vendored bad-lock)
echo '{' >"$dir/.harness/lock.json"
expect bad-lock-fails 1 "$dir" "lock.json"
dir=$(vendored bad-config)
printf '\377\n' >>"$dir/.harness/config.toml"
expect unreadable-config-fails 1 "$dir" "config.toml"
# expect passes its third argument to the check as is, so this runs
# `check-snapshot.sh --bogus`.
expect unknown-flag-is-usage 2 --bogus "usage: check-snapshot.sh"

exit $fail
