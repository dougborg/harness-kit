#!/usr/bin/env bash
# Inventory a copy-and-edit harness before migrating it to a vendored
# snapshot (ADR 0001). Reads .harness-lock.json (v1 or v2), finds each
# tracked file's counterpart in the plugin at the lock's version (tag
# v<version>, so <plugin-dir> must be a git checkout holding it), and
# classifies every file:
#   pristine      identical to upstream at that version
#   modified      differs from upstream; its diff is one of the changes
#   missing       tracked but no longer on disk
#   no-upstream   tracked as harness-kit but with no counterpart at that version
#   other-source  tracked from a source other than harness-kit
#   local         tracked as project-local (source "local")
#   untracked     under a harness directory but not in the lock
# Modified files whose diffs are identical (the same patch applied to several
# copies) are grouped into one change. Upstream symlinks are followed, so a
# project's real-file copy of a symlinked shared script compares to its target.
# It only reads; nothing in the project is changed.
#
# Usage: migrate-inventory.sh [--json] <plugin-dir> [project-dir]
#   <plugin-dir>   a harness-kit git checkout holding tag v<lock version>
#   [project-dir]  the project holding .harness-lock.json (default: .)
# Exit: 0 on a report; 1 when the lock, the plugin, or the tag is unusable;
#       2 on bad usage.
set -euo pipefail

as_json=0
if [ "${1:-}" = --json ]; then
  as_json=1
  shift
fi
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: migrate-inventory.sh [--json] <plugin-dir> [project-dir]" >&2
  exit 2
fi

python3 - "$as_json" "$1" "${2:-.}" <<'PY'
import difflib
import hashlib
import json
import posixpath
import re
import subprocess
import sys
from pathlib import Path


def die(msg):
    print(f"migrate-inventory: {msg}", file=sys.stderr)
    sys.exit(1)


as_json = sys.argv[1] == "1"
plugin, project = Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve()

lock_path = project / ".harness-lock.json"
if not lock_path.is_file():
    die(f"no .harness-lock.json in {project}; nothing to migrate")
try:
    lock = json.loads(lock_path.read_text())
except json.JSONDecodeError as e:
    die(f"{lock_path}: {e}")
schema = lock.get("schemaVersion", 1)
version = lock.get("sources", {}).get("harness-kit", {}).get("version")
if not version:
    die(f"{lock_path}: no sources.harness-kit.version")
tracked = lock.get("files", {})


def git(*args):
    return subprocess.run(["git", "-C", str(plugin), *args], capture_output=True, check=True).stdout


tag = f"v{version}"
try:
    top = Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
except (OSError, subprocess.CalledProcessError):
    top = None
if top != plugin:
    die(f"{plugin} is not a git checkout, so {tag} can't be read; "
        "clone https://github.com/dougborg/harness-kit and pass that")
try:
    git("rev-parse", "-q", "--verify", f"refs/tags/{tag}^{{commit}}")
except subprocess.CalledProcessError:
    die(f"tag {tag} is not in {plugin}; fetch it with `git -C {plugin} fetch --depth 1 origin tag {tag}`")

# The release as git stores it: path -> (mode, blob id).
tree = {}
for row in git("ls-tree", "-r", "-z", tag).decode().split("\0"):
    if row:
        meta, path = row.split("\t", 1)
        mode, _, blob = meta.split()
        tree[path] = (mode, blob)


def resolve(path):
    """Follow upstream symlinks to the file they name, or None."""
    for _ in range(10):
        if path not in tree:
            return None
        mode, blob = tree[path]
        if mode != "120000":
            return path
        target = git("cat-file", "blob", blob).decode()
        path = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
    return None


def counterpart(path):
    """The release path a project path was copied from, across layouts:
    flat skills/<skill>/ (0.x) and claude-skills/ plus skills/<area>/ (1.x)."""
    rules = [
        (r"\.claude/skills/([^/]+)/(.+)", lambda s, r: [f"claude-skills/{s}/{r}", f"skills/{s}/{r}"]),
        (r"\.agents/skills/([^/]+)/(.+)", lambda s, r: sorted(
            p for p in tree if re.fullmatch(rf"skills/[^/]+/{re.escape(s)}/{re.escape(r)}", p)) + [f"skills/{s}/{r}"]),
        (r"\.agents/scripts/shared/(.+)", lambda n: [f"scripts/shared/{n}"]),
        (r"\.claude/agents/(.+)", lambda r: [f"agents/{r}"]),
        (r"\.codex/agents/(.+)", lambda n: [f".codex/agents/{n}"]),
    ]
    for pattern, paths in rules:
        m = re.fullmatch(pattern, path)
        if m:
            for candidate in paths(*m.groups()):
                if resolve(candidate):
                    return candidate
    return None


def owner(path):
    for pattern, kind in ((r"\.(?:claude|agents)/skills/([^/]+)/", "skill"),
                          (r"\.(?:claude|codex)/agents/([^/]+)\.(?:md|toml)$", "agent")):
        m = re.match(pattern, path)
        if m:
            return f"{kind} {m.group(1)}"
    return "shared scripts" if path.startswith(".agents/scripts/shared/") else None


def blob_id(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


files, diffs = [], {}  # diffs: diff text -> paths
for path, entry in sorted(tracked.items()):
    source = entry.get("source") if isinstance(entry, dict) else None
    row = {"path": path, "owner": owner(path), "source": source, "upstream": None, "change": None}
    p = project / path
    if source == "local":
        row["status"] = "local"
    elif source != "harness-kit":
        row["status"] = "other-source"
    elif not p.is_file():
        row["status"] = "missing"
    elif not (up := counterpart(path)):
        row["status"] = "no-upstream"
    else:
        row["upstream"] = up
        data, blob = p.read_bytes(), tree[resolve(up)][1]
        if blob_id(data) == blob:
            row["status"] = "pristine"
        else:
            row["status"] = "modified"
            then = git("cat-file", "blob", blob).decode(errors="replace").splitlines(keepends=True)
            now = data.decode(errors="replace").splitlines(keepends=True)
            diff = "".join(difflib.unified_diff(then, now, "upstream", "project"))
            diffs.setdefault(diff, []).append(path)
    files.append(row)

for root in (".claude/skills", ".claude/agents", ".agents/skills", ".agents/scripts", ".codex/agents"):
    d = project / root
    for f in sorted(d.rglob("*")) if d.is_dir() else []:
        rel = f.relative_to(project).as_posix()
        if f.is_file() and rel not in tracked:
            files.append({"path": rel, "owner": owner(rel), "source": None, "upstream": None,
                          "change": None, "status": "untracked"})

changes = []
for n, (diff, paths) in enumerate(sorted(diffs.items(), key=lambda kv: (-len(kv[1]), kv[1][0])), 1):
    changes.append({"id": n, "paths": paths, "diff": diff})
    for row in files:
        if row["path"] in paths:
            row["change"] = n

if as_json:
    print(json.dumps({"schema": schema, "version": version, "files": files, "changes": changes}, indent=2))
    sys.exit(0)

print(f"harness-kit {version}, .harness-lock.json schema v{schema}: {len(tracked)} tracked files")


def label(row):
    who = f" ({row['owner']})" if row["owner"] else ""
    return f"- `{row['path']}`{who}"


if changes:
    print(f"\n## Modified: {len(changes)} change{'s' if len(changes) != 1 else ''}\n\n"
          f"Each change is one diff from upstream {version}, applied to every file listed.")
    for c in changes:
        n = len(c["paths"])
        print(f"\n### Change {c['id']}: {n} file{'s' if n != 1 else ''}\n")
        for row in files:
            if row["change"] == c["id"]:
                print(f"{label(row)}, upstream `{row['upstream']}`")
        print(f"\n```diff\n{c['diff'].rstrip()}\n```")

sections = [
    ("pristine", "Pristine", f"Identical to upstream {version}."),
    ("missing", "Missing", "Tracked, but no longer on disk."),
    ("no-upstream", "No upstream counterpart", f"Tracked as harness-kit, but {version} has no such file."),
    ("other-source", "Other sources", "Tracked from a source other than harness-kit."),
    ("local", "Local", "Tracked as project-local."),
    ("untracked", "Untracked", "In a harness directory, but not in the lock."),
]
for status, heading, meaning in sections:
    rows = [r for r in files if r["status"] == status]
    if rows:
        print(f"\n## {heading}: {len(rows)}\n\n{meaning}\n")
        print("\n".join(label(r) + (f" from `{r['source']}`" if status == "other-source" else "") for r in rows))
PY
