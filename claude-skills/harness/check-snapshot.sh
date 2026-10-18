#!/usr/bin/env bash
# Check that a vendored harness snapshot is unedited (ADR 0001).
#
# Compares the project with .harness/lock.json, which vendor-snapshot.sh
# writes: every file the lock lists must exist with its recorded sha256, a
# vendored skill directory must hold no file the lock doesn't list, and each
# hook entry the lock records must still be in .claude/settings.json. Skills
# and agents named in the config's [forks.*] tables are the project's own and
# are skipped, even before the next vendor run drops them from the lock.
# Project-local files, the config, and AGENTS.md are never checked. It runs on
# any python3 3.8 or later: it reads only the fork names from the config, and
# needs no tomllib.
#
# --paths prints, instead, each file the snapshot owns (the lock's files,
# less forks), one project-relative path per line, for excluding them from a
# project's formatters and linters; it prints nothing without a lock.
#
# Usage: check-snapshot.sh [--paths] [project-dir]   (default: .)
# Exit: 0 when the snapshot is unedited, or when there is no lock (not a
#       vendored project), or --paths printed the list; 1 when a vendored
#       file or hook entry changed, or the lock, config, or settings can't be
#       read; 2 on bad usage.
set -euo pipefail

paths=0
if [ "${1:-}" = --paths ]; then
  paths=1
  shift
fi
arg=${1:-}
if [ $# -gt 1 ] || [ "${arg#-}" != "$arg" ]; then
  echo "usage: check-snapshot.sh [--paths] [project-dir]" >&2
  exit 2
fi

python3 - "$paths" "${1:-.}" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path

list_paths, project = sys.argv[1] == "1", Path(sys.argv[2]).resolve()
lock_path = project / ".harness/lock.json"
config_path = project / ".harness/config.toml"
settings_path = project / ".claude/settings.json"


def die(msg):
    print(f"check-snapshot: {msg}", file=sys.stderr)
    sys.exit(1)


def load_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as e:
        die(f"{path}: {e}")


if not lock_path.is_file():
    if not list_paths:
        print("check-snapshot: not a vendored project (no .harness/lock.json); nothing to check")
    sys.exit(0)
lock = load_json(lock_path)
files = lock.get("files", {})

# The fork names are the keys of the config's [forks.skills] and
# [forks.agents] tables. They are read line by line rather than with tomllib,
# so the check runs on any python3 (macOS ships 3.9). Lines inside a
# multi-line string (""" or ''') are skipped, and only a bare header,
# [forks.skills] or [forks.agents], opens a fork table. A fork written another
# way isn't seen, so its files are still checked: the check fails, never
# passes, on a form it can't read.
# shortcut: bare [forks.<kind>] headers and one bare or quoted key per line
# only (no quoted headers, dotted keys, or inline tables) | revisit when a
# project needs them
forks = {"skills": set(), "agents": set()}
HEADER = re.compile(r"\s*\[\s*forks\s*\.\s*(skills|agents)\s*\]\s*(?:#.*)?$")
KEY = re.compile(r"""\s*(?:"([^"\\]*)"|'([^']*)'|([A-Za-z0-9_-]+))\s*=""")
TRIPLE = re.compile(r'"""|\'\'\'')


def string_after(line, delim):
    """The multi-line string delimiter still open at the end of a line, given
    the one open at its start (None for none)."""
    pos = 0
    while True:
        if delim is None:
            m = TRIPLE.search(line, pos)
            if not m:
                return None
            delim, pos = m.group(), m.end()
            continue
        end = line.find(delim, pos)
        # In a basic string, \""" is an escaped quote, not the close.
        while end != -1 and delim == '"""' and (len(line[:end]) - len(line[:end].rstrip("\\"))) % 2:
            end = line.find(delim, end + 1)
        if end == -1:
            return delim
        delim, pos = None, end + 3


if config_path.is_file():
    try:
        lines = config_path.read_text().splitlines()
    except (OSError, UnicodeDecodeError) as e:
        die(f"{config_path}: {e}")
    table, open_string = None, None
    for line in lines:
        if open_string is None:
            if line.lstrip().startswith("["):
                m = HEADER.match(line)
                table = m.group(1) if m else None
            elif table and (m := KEY.match(line)):
                forks[table].add(next(g for g in m.groups() if g is not None))
        open_string = string_after(line, open_string)

SKILL = re.compile(r"\.(?:claude|agents)/skills/([^/]+)/")
AGENT = re.compile(r"\.(?:claude|codex)/agents/([^/]+)\.(?:md|toml)$")


def owner(path):
    """The (kind, name) a vendored path belongs to, or None."""
    for kind, pattern in (("skills", SKILL), ("agents", AGENT)):
        m = pattern.match(path)
        if m:
            return kind, m.group(1)
    return None


def forked(path):
    o = owner(path)
    return o is not None and o[1] in forks[o[0]]


if list_paths:
    print("".join(f"{path}\n" for path in sorted(files) if not forked(path)), end="")
    sys.exit(0)

problems = []  # (label, path)
for path, digest in sorted(files.items()):
    if forked(path):
        continue
    p = project / path
    if p.is_symlink():
        problems.append(("edited", path))
    elif not p.is_file():
        problems.append(("deleted", path))
    elif hashlib.sha256(p.read_bytes()).hexdigest() != digest:
        problems.append(("edited", path))

for name in sorted(set(lock.get("skills", {})) - forks["skills"]):
    for root in (f".claude/skills/{name}", f".agents/skills/{name}"):
        d = project / root
        if not d.is_dir():
            continue
        for f in sorted(d.rglob("*")):
            rel = f.relative_to(project).as_posix()
            if (f.is_file() or f.is_symlink()) and rel not in files:
                problems.append(("added", rel))

hooks = lock.get("hooks", {}).get("claude", {})
settings = load_json(settings_path) if hooks and settings_path.is_file() else {}
present = settings.get("hooks", {}) if isinstance(settings, dict) else {}
for event, entries in sorted(hooks.items()):
    for entry in entries:
        if entry not in present.get(event, []):
            commands = [h.get("command", "") for h in entry.get("hooks", []) if isinstance(h, dict)]
            problems.append(("hook", f"{event} {' '.join(commands)}".strip()))

if not problems:
    print(f"check-snapshot: harness-kit {lock.get('version', '?')} snapshot is unedited")
    sys.exit(0)

print("check-snapshot: the vendored harness snapshot was changed:", file=sys.stderr)
for label, path in problems:
    o = owner(path) if label != "hook" else None
    suffix = f" ({o[0][:-1]} {o[1]})" if o else ""
    print(f"  {label}: {path}{suffix}", file=sys.stderr)
print("""
Vendored files are replaced on every update, so an edit there is lost. Either:
  - move the project-specific part into facts: .harness/config.toml, or the
    "## Project facts" section of AGENTS.md; or
  - declare a fork: name the skill under [forks.skills], or the agent under
    [forks.agents], in .harness/config.toml, with the version it came from.
To discard the change, restore the file from git. A "hook:" line is a vendored
entry in .claude/settings.json that was edited or removed: restore it, and add
project hooks as entries of their own.""", file=sys.stderr)
sys.exit(1)
PY
