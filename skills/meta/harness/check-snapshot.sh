#!/usr/bin/env bash
# Check that a vendored harness snapshot is unedited (ADR 0001).
#
# Compares the project with .harness/lock.json, which vendor-snapshot.sh
# writes: every file the lock lists must exist with its recorded sha256, a
# vendored skill directory must hold no file the lock doesn't list, and each
# hook entry the lock records must still be in .claude/settings.json. Skills
# and agents named in the config's [forks.*] tables are the project's own and
# are skipped, even before the next vendor run drops them from the lock.
# Project-local files, the config, and AGENTS.md are never checked.
#
# Usage: check-snapshot.sh [project-dir]   (default: .)
# Exit: 0 when the snapshot is unedited, or when there is no lock (not a
#       vendored project); 1 when a vendored file or hook entry changed, or
#       the lock, config, or settings can't be read; 2 on bad usage.
set -euo pipefail

if [ $# -gt 1 ]; then
  echo "usage: check-snapshot.sh [project-dir]" >&2
  exit 2
fi

python3 - "${1:-.}" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path

project = Path(sys.argv[1]).resolve()
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
    print("check-snapshot: not a vendored project (no .harness/lock.json); nothing to check")
    sys.exit(0)
lock = load_json(lock_path)
files = lock.get("files", {})

forks = {"skills": set(), "agents": set()}
if config_path.is_file():
    try:
        import tomllib
    except ImportError:
        die("needs Python 3.11 or later (tomllib)")
    try:
        config = tomllib.loads(config_path.read_text())
    except tomllib.TOMLDecodeError as e:
        die(f"{config_path}: {e}")
    for kind in forks:
        forks[kind] = set(config.get("forks", {}).get(kind, {}))

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
