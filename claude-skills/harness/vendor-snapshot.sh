#!/usr/bin/env bash
# Vendor a pristine harness-kit snapshot into a project (ADR 0001).
#
# Reads the project's .harness/config.toml and writes, as real files:
#   .claude/skills/<skill>/   the Claude projection (claude-skills/<skill>/)
#   .claude/agents/<a>.md     Claude agents (agents/<a>.md)
#   .agents/skills/<skill>/   the open-format skills (skills/<area>/<skill>/)
#   .agents/scripts/shared/   shared helpers those skills name
#   .codex/agents/<a>.toml    generated Codex agents (.codex/agents/<a>.toml)
#   .claude/hooks/harness-kit/  the plugin's hook scripts
# The harness skill is always included; forked skills and agents are the
# project's own and are skipped. The plugin's hook entries are merged into
# .claude/settings.json, harness-kit is set to false there, and
# .harness/lock.json records the version, each file's sha256, and the hook
# entries, so the next run replaces exactly what this one wrote. Files the
# lock doesn't own are never touched, and a re-run at the same version writes
# nothing. It does no merging: an edited vendored file is overwritten.
#
# Usage: vendor-snapshot.sh <plugin-dir> [project-dir]
#   <plugin-dir>   this plugin's installed root, or a release checkout
#   [project-dir]  the project holding .harness/config.toml (default: .)
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: vendor-snapshot.sh <plugin-dir> [project-dir]" >&2
  exit 2
fi

python3 - "$1" "${2:-.}" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path


def die(msg):
    print(f"vendor-snapshot: {msg}", file=sys.stderr)
    sys.exit(1)


try:
    import tomllib
except ImportError:
    die("needs Python 3.11 or later (tomllib)")

plugin, project = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
manifest = plugin / ".claude-plugin/plugin.json"
if not manifest.is_file():
    die(f"{plugin} is not a harness-kit plugin root (no .claude-plugin/plugin.json)")
version = json.loads(manifest.read_text())["version"]

config_path = project / ".harness/config.toml"
if not config_path.is_file():
    die(f"{config_path} not found")
try:
    config = tomllib.loads(config_path.read_text())
except tomllib.TOMLDecodeError as e:
    die(f"{config_path}: {e}")


def names(key):
    value = config.get(key, [])
    if not isinstance(value, list) or not all(isinstance(n, str) for n in value):
        die(f"{config_path}: {key} must be an array of names")
    return set(value)


def table(*keys):
    value = config
    for key in keys:
        value = value.get(key, {}) if isinstance(value, dict) else None
    if not isinstance(value, dict) or not all(isinstance(v, str) for v in value.values()):
        die(f"{config_path}: [{'.'.join(keys)}] must map names to strings")
    return value


forks_skills, forks_agents = table("forks", "skills"), table("forks", "agents")
skills = sorted((names("skills") | {"harness"}) - set(forks_skills))
agents = sorted(names("agents") - set(forks_agents))

# Third-party skills name their source; the rest come from this plugin.
sources = table("sources", "skills")
for name, source in sorted(sources.items()):
    if name not in names("skills"):
        die(f"{config_path}: [sources.skills] {name} is not in skills")
    if not re.fullmatch(r"[\w.-]+/[\w.-]+@[^\s:]+:[^\s]+", source):
        die(f"{config_path}: [sources.skills] {name} must be \"owner/repo@ref:path\", got \"{source}\"")
third_party = [s for s in skills if s in sources]
if third_party:
    # shortcut: sources are recorded but not fetched | revisit when harness add vendors third-party skills (#173)
    die("fetching third-party skill sources is not implemented yet: " + ", ".join(third_party))

# The vendored repo has no plugin root, so plugin-root paths to shared
# scripts are rewritten into the snapshot: the Claude form to the vendored
# hook scripts, the open-format form to the Codex shared-script directory.
# The patterns are spelled with escapes so this file survives its own rewrite
# and the Claude projection's placeholder substitution.
HOOK_DIR = ".claude/hooks/harness-kit"
claude_root = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}/scripts/shared/([\w.-]+)")
codex_root = re.compile(r"\x3cplugin-root\x3e/scripts/shared/([\w.-]+)")
codex_helper = re.compile(r"\x3cshared-scripts-dir\x3e/([\w.-]+\.sh)")
hook_scripts, codex_helpers = set(), set()


def rewrite(text):
    hook_scripts.update(claude_root.findall(text))
    text = claude_root.sub(r"${CLAUDE_PROJECT_DIR}/" + HOOK_DIR + r"/\1", text)
    return codex_root.sub("\x3cshared-scripts-dir\x3e/\\1", text)


want = {}  # project-relative path -> (bytes, mode)
roots = []  # owned paths whose existing files must all be in the lock


def add_file(src, dest, scan_helpers=False):
    data = src.read_bytes()
    if src.suffix in (".md", ".sh"):
        text = rewrite(data.decode())
        if scan_helpers:
            codex_helpers.update(codex_helper.findall(text))
        data = text.encode()
    want[dest] = (data, 0o755 if src.stat().st_mode & 0o111 else 0o644)


def add_tree(src, dest, scan_helpers=False):
    roots.append(dest)
    for f in sorted(src.rglob("*")):
        if f.is_file():
            add_file(f, f"{dest}/{f.relative_to(src).as_posix()}", scan_helpers)


def need(path, what):
    if not path.exists():
        die(f"{what} not found in {plugin}")
    return path


for name in skills:
    add_tree(need(plugin / "claude-skills" / name, f"skill {name}"), f".claude/skills/{name}")
    found = [p for p in (plugin / "skills").glob(f"*/{name}") if (p / "SKILL.md").is_file()]
    if len(found) != 1:
        die(f"skill {name} not found once in {plugin}/skills/<area>/")
    add_tree(found[0], f".agents/skills/{name}", scan_helpers=True)
for name in agents:
    for src, dest in ((f"agents/{name}.md", f".claude/agents/{name}.md"),
                      (f".codex/agents/{name}.toml", f".codex/agents/{name}.toml")):
        roots.append(dest)
        add_file(need(plugin / src, f"agent {name} ({src})"), dest)

hooks_file = plugin / "hooks/hooks.json"
hooks = json.loads(rewrite(hooks_file.read_text()))["hooks"] if hooks_file.is_file() else {}
# Like the Claude projection, a name with no file in scripts/shared/ is an
# example in prose, not a helper.
for names_, dest_dir in ((codex_helpers, ".agents/scripts/shared"), (hook_scripts, HOOK_DIR)):
    for name in sorted(names_):
        src = plugin / "scripts/shared" / name
        if src.is_file():
            roots.append(f"{dest_dir}/{name}")
            add_file(src, f"{dest_dir}/{name}")

# What the last run vendored. Only these paths may be replaced or removed.
lock_path = project / ".harness/lock.json"
old_lock = json.loads(lock_path.read_text()) if lock_path.is_file() else {}
owned = set(old_lock.get("files", {}))
for path in owned:
    if not re.match(r"\.(claude|agents|codex)/", path) or ".." in Path(path).parts:
        die(f"{lock_path}: refusing to manage {path}")
for root in roots:
    p = project / root
    existing = [p] if p.is_file() else [f for f in p.rglob("*") if f.is_file()] if p.is_dir() else []
    for f in existing:
        rel = f.relative_to(project).as_posix()
        if rel not in owned:
            die(f"{rel} is a project-local file in the way of the snapshot; move it or fork the skill")

# Settings: harness-kit off so only the snapshot loads, and the plugin's hook
# entries in place of the ones the last run added. Other keys are kept.
settings_path = project / ".claude/settings.json"
try:
    settings = json.loads(settings_path.read_text()) if settings_path.is_file() else {}
except json.JSONDecodeError as e:
    die(f"{settings_path}: {e}")
new_settings = json.loads(json.dumps(settings))
new_settings.setdefault("enabledPlugins", {})["harness-kit@harness-kit"] = False
old_hooks = old_lock.get("hooks", {}).get("claude", {})
merged = dict(new_settings.get("hooks", {}))
for event in sorted(set(old_hooks) | set(hooks)):
    kept, at = [], None
    for entry in merged.get(event, []):
        if entry in old_hooks.get(event, []):
            at = len(kept) if at is None else at
        else:
            kept.append(entry)
    at = len(kept) if at is None else at
    kept[at:at] = hooks.get(event, [])
    if kept:
        merged[event] = kept
    else:
        merged.pop(event, None)
if merged:
    new_settings["hooks"] = merged
else:
    new_settings.pop("hooks", None)

lock = {
    "version": version,
    "skills": {name: sources.get(name, "harness-kit") for name in skills},
    "agents": {name: "harness-kit" for name in agents},
    "hooks": {"claude": hooks},
    "files": {path: hashlib.sha256(data).hexdigest() for path, (data, _) in sorted(want.items())},
}


def write(path, data, mode=0o644):
    if path.is_symlink():
        path.unlink()
    if path.is_file() and path.read_bytes() == data and path.stat().st_mode & 0o777 == mode:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    path.chmod(mode)


for path in sorted(owned - set(want)):
    p = project / path
    if p.is_file() or p.is_symlink():
        p.unlink()
    for parent in p.parents:
        if parent == project or not parent.is_dir() or any(parent.iterdir()):
            break
        parent.rmdir()
for path, (data, mode) in sorted(want.items()):
    write(project / path, data, mode)
if new_settings != settings:
    write(settings_path, (json.dumps(new_settings, indent=2, ensure_ascii=False) + "\n").encode())
write(lock_path, (json.dumps(lock, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode())
print(f"vendored harness-kit {version}: {len(skills)} skills, {len(agents)} agents, {len(want)} files")
PY
