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
#   .github/workflows/harness-update.yml  the scheduled update workflow, its
#                             cron from the config's [update] schedule if set
# A skill with a [sources.skills] entry is instead fetched at its ref from
# its own repository (HARNESS_SOURCE_BASE_URL, default https://github.com;
# https and file only, so ssh is reachable only through the user's own
# url.insteadOf rewrite) and its one tree written byte for byte to both skill
# directories; the lock records the commit it resolved to. A source may not
# take a harness-kit skill's name (fork that skill instead), and its SKILL.md
# frontmatter name, if any, must match. Each git call times out after 300s
# and a sourced tree may hold 2000 files and 50 MB; the environment overrides
# HARNESS_SOURCE_FETCH_TIMEOUT, HARNESS_SOURCE_MAX_FILES, and
# HARNESS_SOURCE_MAX_BYTES are test hooks, never config.
# The harness skill is always included; forked skills and agents are the
# project's own and are never written or removed. The plugin's hook entries
# are merged into .claude/settings.json, harness-kit is set to false there,
# and .harness/lock.json records the version, each file's sha256, the hook
# entries, and the plugin's catalog, so the next run replaces exactly what
# this one wrote. Files the lock doesn't own are never touched, and a re-run
# at the same version writes nothing. It does no merging: when the current
# snapshot fails check-snapshot.sh (an edited, added, or deleted vendored
# file, or a changed hook entry) it exits 1 and writes nothing, unless
# --discard-edits says to overwrite those changes.
#
# It reports, as Markdown (or JSON with --json; --json-out FILE also writes
# the JSON to FILE, so one run yields both): chosen skills and agents the
# release removed (dropped from the snapshot), ones new since the last
# snapshot (offered, not installed), each third-party source's commit and
# whether it moved, and, for each fork, which of its files
# changed upstream since the version it was forked from. That comparison reads
# the fork's version from tag v<version> when <plugin-dir> is a git checkout.
#
# Usage: vendor-snapshot.sh [--json] [--json-out FILE] [--discard-edits] <plugin-dir> [project-dir]
#   <plugin-dir>   this plugin's installed root, or a release checkout
#   [project-dir]  the project holding .harness/config.toml (default: .)
set -euo pipefail

usage="usage: vendor-snapshot.sh [--json] [--json-out FILE] [--discard-edits] <plugin-dir> [project-dir]"
as_json=0 discard=0 json_out=
while [ $# -gt 0 ]; do
  case $1 in
    --json) as_json=1 ;;
    --json-out)
      if [ $# -lt 2 ] || [ -z "$2" ]; then echo "$usage" >&2; exit 2; fi
      json_out=$2
      shift
      ;;
    --discard-edits) discard=1 ;;
    -*) echo "$usage" >&2; exit 2 ;;
    *) break ;;
  esac
  shift
done
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "$usage" >&2
  exit 2
fi

# Refuse to overwrite an edited snapshot: the edit check against the current
# lock must pass first. It passes when there is no lock yet.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$discard" = 0 ] && ! "$SCRIPT_DIR/check-snapshot.sh" "${2:-.}" >/dev/null; then
  cat >&2 <<'MSG'
vendor-snapshot: refusing to update: the current snapshot was changed (above),
and updating would overwrite those changes. Move the project-specific part into
facts or declare a fork first, or pass --discard-edits to overwrite them.
MSG
  exit 1
fi

python3 - "$as_json" "$json_out" "$1" "${2:-.}" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def die(msg):
    print(f"vendor-snapshot: {msg}", file=sys.stderr)
    sys.exit(1)


try:
    import tomllib
except ImportError:
    die("needs Python 3.11 or later (tomllib)")

as_json, json_out = sys.argv[1] == "1", sys.argv[2]
plugin, project = Path(sys.argv[3]).resolve(), Path(sys.argv[4]).resolve()
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


def valid(where, names_):
    """Every name becomes a path component, so it must be exactly one. The
    leading letter or digit already rules out '.' and '..'."""
    for n in names_:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", n):
            die(f"{config_path}: {where}: \"{n}\" is not a valid name "
                "(starts with a letter or digit, then letters, digits, '.', '_', '-'; no '/')")
    return names_


def names(key):
    value = config.get(key, [])
    if not isinstance(value, list) or not all(isinstance(n, str) for n in value):
        die(f"{config_path}: {key} must be an array of names")
    return set(valid(key, value))


def table(*keys):
    value = config
    for key in keys:
        value = value.get(key, {}) if isinstance(value, dict) else None
    if not isinstance(value, dict) or not all(isinstance(v, str) for v in value.values()):
        die(f"{config_path}: [{'.'.join(keys)}] must map names to strings")
    valid(f"[{'.'.join(keys)}]", value)
    return value


forks = {"skills": table("forks", "skills"), "agents": table("forks", "agents")}

# [update] schedule: the update workflow's cron, five fields of digits and
# * , - / separated by single spaces. It is written into the workflow, so
# nothing else is accepted.
update = config.get("update", {})
if not isinstance(update, dict):
    die(f"{config_path}: [update] must be a table")
schedule = update.get("schedule")
if schedule is not None and not (isinstance(schedule, str)
                                 and re.fullmatch(r"[0-9*,/-]+( [0-9*,/-]+){4}", schedule)):
    die(f"{config_path}: [update] schedule must be a five-field cron string such as "
        f"\"23 7 * * 1\" (digits and * , - / only), got {json.dumps(schedule)}")
skills = sorted((names("skills") | {"harness"}) - set(forks["skills"]))
agents = sorted(names("agents") - set(forks["agents"]))

# What the last run vendored. Only these paths may be replaced or removed.
lock_path = project / ".harness/lock.json"
old_lock = json.loads(lock_path.read_text()) if lock_path.is_file() else {}

# The release's catalog. A chosen name the last snapshot had and this release
# lacks was removed upstream: it is dropped and reported, not an error, for as
# long as the config lists it. Names new since the last catalog are offered.
available = {
    "skills": sorted({p.parent.name for p in (plugin / "skills").glob("*/*/SKILL.md")}),
    "agents": sorted(p.stem for p in (plugin / "agents").glob("*.md")),
}

# Third-party skills name their source; the rest come from this plugin.
sources = table("sources", "skills")
SOURCE = re.compile(r"([A-Za-z0-9][A-Za-z0-9_.-]*)/([A-Za-z0-9][A-Za-z0-9_.-]*)"
                    r"@([A-Za-z0-9][A-Za-z0-9_./-]*):([^\s]+)")
parsed = {}
for name, source in sorted(sources.items()):
    # A sourced skill must not shadow one of this plugin's: the harness skill
    # runs the update itself, and the others are replaced by forking.
    if name == "harness" or name in available["skills"]:
        die(f"{config_path}: [sources.skills] {name} is a harness-kit skill and can't be "
            "sourced elsewhere; to replace it, fork it under [forks.skills] instead")
    if name not in names("skills"):
        die(f"{config_path}: [sources.skills] {name} is not in skills")
    m = SOURCE.fullmatch(source)
    parts = m.group(4).rstrip("/").split("/") if m else []
    if not m or ".." in m.group(3) or m.group(3).endswith("/") \
            or any(p in ("", ".", "..") for p in parts):
        die(f"{config_path}: [sources.skills] {name} must be \"owner/repo@ref:path\" "
            f"(a ref or commit, and a relative path inside the repository), got \"{source}\"")
    parsed[name] = (m.group(1), m.group(2), m.group(3), "/".join(parts))

removed = {}
for kind, chosen in (("skills", skills), ("agents", agents)):
    before = set(old_lock.get(kind, {})) | set(old_lock.get("removed", {}).get(kind, []))
    removed[kind] = [n for n in chosen if n not in available[kind] and n in before and n not in sources]
skills = [n for n in skills if n not in removed["skills"]]
agents = [n for n in agents if n not in removed["agents"]]
old_available = old_lock.get("available")
new = {
    kind: sorted(set(available[kind]) - set(old_available.get(kind, [])) - names(kind) - set(forks[kind]))
    if old_available else []
    for kind in ("skills", "agents")
}

# A source is fetched from <base>/<owner>/<repo>, GitHub unless the
# environment (never the config) names another base, such as a mirror or a
# directory of local repos in tests. Only the https and file transports are
# allowed, so a URL can't run a command; ssh is reachable only through the
# user's own url.<base>.insteadOf rewrite of an https base.
SOURCE_BASE = os.environ.get("HARNESS_SOURCE_BASE_URL", "https://github.com").rstrip("/")
if not re.match(r"(https|file)://", SOURCE_BASE):
    die(f"HARNESS_SOURCE_BASE_URL must start with https:// or file://, got \"{SOURCE_BASE}\"")
SHA = re.compile(r"[0-9a-fA-F]{40}")


def limit(var, default):
    """A fetch bound. The environment override is a test hook only; the
    config can't change it."""
    value = os.environ.get(var, str(default))
    if not value.isdigit() or int(value) < 1:
        die(f"{var} must be a positive whole number, got \"{value}\"")
    return int(value)


# Each git call gets FETCH_TIMEOUT seconds, and a sourced skill's tree may
# hold at most MAX_FILES files and MAX_BYTES bytes, checked before any blob
# is read.
FETCH_TIMEOUT = limit("HARNESS_SOURCE_FETCH_TIMEOUT", 300)
MAX_FILES = limit("HARNESS_SOURCE_MAX_FILES", 2000)
MAX_BYTES = limit("HARNESS_SOURCE_MAX_BYTES", 50 * 1024 * 1024)
GIT_ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_ALLOW_PROTOCOL": "https:ssh:file"}
fetch_dir = tempfile.TemporaryDirectory()  # removed when the run exits
fetched = {}  # (owner, repo, ref) -> (scratch repo, commit): one fetch each


def git_in(repo_dir, *args):
    """git in a scratch repo, killed with its children after FETCH_TIMEOUT."""
    p = subprocess.Popen(["git", "-C", repo_dir, *args], stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, env=GIT_ENV, start_new_session=True)
    try:
        out, err = p.communicate(timeout=FETCH_TIMEOUT)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, 9)
        p.communicate()
        raise
    if p.returncode:
        raise subprocess.CalledProcessError(p.returncode, args, out, err)
    return out


def fetch_commit(name, owner, repo, ref):
    key = (owner, repo, ref)
    if key not in fetched:
        url = f"{SOURCE_BASE}/{owner}/{repo}"
        repo_dir = os.path.join(fetch_dir.name, str(len(fetched)))
        os.mkdir(repo_dir)
        try:
            git_in(repo_dir, "init", "-q")
        except subprocess.CalledProcessError as e:
            die(f"[sources.skills] {name}: can't create a scratch repository: {e.stderr.decode(errors='replace').strip()}")
        except subprocess.TimeoutExpired:
            die(f"[sources.skills] {name}: git init timed out after {FETCH_TIMEOUT}s")
        try:
            git_in(repo_dir, "fetch", "-q", "--depth", "1", "--no-tags", "--", url, ref)
            commit = git_in(repo_dir, "rev-parse", "--verify", "-q", "FETCH_HEAD^{commit}").decode().strip()
        except subprocess.CalledProcessError as e:
            die(f"[sources.skills] {name}: can't fetch {ref} from {url}: {e.stderr.decode(errors='replace').strip()}")
        except subprocess.TimeoutExpired:
            die(f"[sources.skills] {name}: fetching {ref} from {url} timed out after {FETCH_TIMEOUT}s")
        fetched[key] = (repo_dir, commit)
    return fetched[key]


def frontmatter_name(text):
    """The name: in a SKILL.md's leading --- frontmatter, or None."""
    m = re.match(r"---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    n = m and re.search(r"^name:[ \t]*(.*?)[ \t]*$", m.group(1), re.M)
    return n.group(1).strip("\"'") if n else None


def fetch(name):
    """The sourced skill's commit and files, {relative path: (bytes, mode)},
    read from git objects at the pinned ref; nothing is checked out."""
    owner, repo, ref, path = parsed[name]
    repo_dir, commit = fetch_commit(name, owner, repo, ref)
    where = f"{path} of {owner}/{repo} at {commit}"
    try:
        raw = git_in(repo_dir, "ls-tree", "-r", "-l", "-z", f"{commit}:{path}")
    except subprocess.CalledProcessError:
        die(f"[sources.skills] {name}: {path} is not a directory in {owner}/{repo} at {commit}")
    except subprocess.TimeoutExpired:
        die(f"[sources.skills] {name}: listing {where} timed out after {FETCH_TIMEOUT}s")
    try:
        listing = raw.decode()
    except UnicodeDecodeError:
        die(f"[sources.skills] {name}: a file name in {where} is not UTF-8; refusing to vendor it")
    entries, total = [], 0
    for line in filter(None, listing.split("\0")):
        meta, rel = line.split("\t", 1)
        mode, _, obj, size = meta.split()
        if mode == "120000":
            die(f"[sources.skills] {name}: {path}/{rel} is a symlink; a snapshot holds real files only")
        if mode == "160000" or any(p.lower() in ("", ".", "..", ".git") for p in rel.split("/")):
            die(f"[sources.skills] {name}: refusing to vendor {path}/{rel}")
        entries.append((rel, mode, obj))
        total += int(size)
        if len(entries) > MAX_FILES:
            die(f"[sources.skills] {name}: {where} has more than {MAX_FILES} files")
        if total > MAX_BYTES:
            die(f"[sources.skills] {name}: {where} has more than {MAX_BYTES} bytes")
    files = {}
    for rel, mode, obj in entries:
        try:
            files[rel] = (git_in(repo_dir, "cat-file", "blob", obj), 0o755 if mode == "100755" else 0o644)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            die(f"[sources.skills] {name}: can't read {path}/{rel} of {owner}/{repo} at {commit}")
    if "SKILL.md" not in files:
        die(f"[sources.skills] {name}: no SKILL.md in {where}")
    declared = frontmatter_name(files["SKILL.md"][0].decode(errors="replace"))
    if declared is not None and declared != name:
        die(f"[sources.skills] {name}: {where} declares itself \"{declared}\"; "
            f"list it as {declared} in skills and [sources.skills]")
    return commit, files

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
vendored_hook = re.compile(re.escape(HOOK_DIR) + r"/([\w.-]+)")


# rewrite() also records the shared scripts each file names into hook_scripts
# and codex_helpers, so every add_file() call must run before the loop below
# that copies those scripts.
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


commits = {}
for name in skills:
    if name in sources:
        # One open-format tree serves both hosts, copied byte for byte: its
        # paths belong to its own repository, so nothing is rewritten.
        commits[name], tree = fetch(name)
        for dest in (f".claude/skills/{name}", f".agents/skills/{name}"):
            roots.append(dest)
            for rel, entry in tree.items():
                want[f"{dest}/{rel}"] = entry
        continue
    add_tree(need(plugin / "claude-skills" / name, f"skill {name}"), f".claude/skills/{name}")
    found = [p for p in (plugin / "skills").glob(f"*/{name}") if (p / "SKILL.md").is_file()]
    if len(found) != 1:
        die(f"skill {name} not found once in {plugin}/skills/<area>/")
    add_tree(found[0], f".agents/skills/{name}", scan_helpers=True)
# The scheduled workflow that opens the next update PR (harness-update.sh),
# with its cron from [update] schedule when the config sets one. The lock
# hashes the templated file, so the edit check passes it.
WORKFLOW = ".github/workflows/harness-update.yml"
roots.append(WORKFLOW)
add_file(need(plugin / "claude-skills/harness/harness-update.yml", "the update workflow"), WORKFLOW)
if schedule is not None:
    data, mode = want[WORKFLOW]
    text, n = re.subn(r'^(\s+- cron: )"[^"\n]*"$', lambda m: f'{m.group(1)}"{schedule}"', data.decode(), flags=re.M)
    if n != 1:
        die(f"the update workflow in {plugin} has {n} cron lines, not one; can't apply [update] schedule")
    want[WORKFLOW] = (text.encode(), mode)
for name in agents:
    for src, dest in ((f"agents/{name}.md", f".claude/agents/{name}.md"),
                      (f".codex/agents/{name}.toml", f".codex/agents/{name}.toml")):
        roots.append(dest)
        add_file(need(plugin / src, f"agent {name} ({src})"), dest)


def fork_paths(kind, name):
    if kind == "skills":
        return [f".claude/skills/{name}", f".agents/skills/{name}"]
    return [f".claude/agents/{name}.md", f".codex/agents/{name}.toml"]


fork_roots = [p for kind in forks for name in forks[kind] for p in fork_paths(kind, name)]


def in_fork(path):
    return any(path == r or path.startswith(r + "/") for r in fork_roots)


# A fork keeps the shared scripts it names, though nothing vendored may.
for root in fork_roots:
    p = project / root
    for f in [p] if p.is_file() else sorted(p.rglob("*")) if p.is_dir() else []:
        if f.is_file() and not f.is_symlink():
            text = f.read_bytes().decode(errors="replace")
            codex_helpers.update(codex_helper.findall(text))
            hook_scripts.update(vendored_hook.findall(text))

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

owned = set(old_lock.get("files", {}))
for path in owned:
    if not (re.match(r"\.(claude|agents|codex)/", path) or path == WORKFLOW) or ".." in Path(path).parts:
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
    "available": available,
    "removed": removed,
    "files": {path: hashlib.sha256(data).hexdigest() for path, (data, _) in sorted(want.items())},
}
if commits:
    lock["source_commits"] = commits


# Never write or remove through a symlinked directory: it could point out of
# the project. Checked for every path before anything is written.
for path in sorted(owned | set(want) | {".claude/settings.json", ".harness/lock.json"}):
    for parent in Path(path).parents:
        if parent != Path(".") and (project / parent).is_symlink():
            die(f"{parent.as_posix()} is a symlink; the snapshot is written as real files only. "
                "Replace it with a directory, then run this again")


def write(path, data, mode=0o644):
    """Write atomically: a temp file in the same directory, then a rename, so
    an interrupted run leaves each file whole (old or new). A symlink at the
    path is replaced, not followed."""
    if not path.is_symlink() and path.is_file() and path.read_bytes() == data \
            and path.stat().st_mode & 0o777 == mode:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


# Directories the snapshot shares with the project. Emptying one never
# removes it, or anything above it.
SHARED_DIRS = {".claude", ".agents", ".codex", ".github", ".github/workflows",
               ".claude/skills", ".agents/skills", ".claude/agents", ".codex/agents",
               ".claude/hooks", ".agents/scripts"}
for path in sorted(owned - set(want)):
    if in_fork(path):
        continue  # the project's own now; it leaves the lock untouched
    p = project / path
    if p.is_file() or p.is_symlink():
        p.unlink()
    for parent in Path(path).parents:
        d = project / parent
        if parent == Path(".") or parent.as_posix() in SHARED_DIRS or not d.is_dir() or any(d.iterdir()):
            break
        d.rmdir()
for path, (data, mode) in sorted(want.items()):
    write(project / path, data, mode)
if new_settings != settings:
    write(settings_path, (json.dumps(new_settings, indent=2, ensure_ascii=False) + "\n").encode())
write(lock_path, (json.dumps(lock, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode())


# --- The report: forks against upstream, and removed and new names -----------
def git(*args):
    return subprocess.run(["git", "-C", str(plugin), *args], capture_output=True, check=True).stdout


def upstream(kind, name, rev=None):
    """The snapshot's files for a name, {project path: bytes}, from the plugin
    at a git revision, or as it is on disk when rev is None."""
    if kind == "skills":
        tops = ("claude-skills", "skills")
        pattern = rf"(claude-skills|skills/[^/]+)/{re.escape(name)}/.+"
    else:
        tops = ("agents", ".codex/agents")
        pattern = rf"agents/{re.escape(name)}\.md|\.codex/agents/{re.escape(name)}\.toml"
    if rev is None:
        paths = [f.relative_to(plugin).as_posix() for t in tops for f in (plugin / t).rglob("*") if f.is_file()]
    else:
        paths = git("ls-tree", "-r", "-z", "--name-only", rev, "--", *tops).decode().split("\0")
    out = {}
    for path in (p for p in paths if re.fullmatch(pattern, p)):
        if path.startswith("claude-skills/"):
            dest = ".claude/skills/" + path.removeprefix("claude-skills/")
        elif path.startswith("skills/"):
            dest = f".agents/skills/{name}/" + path.split(f"/{name}/", 1)[1]
        elif path.startswith("agents/"):
            dest = ".claude/" + path
        else:
            dest = path
        out[dest] = (plugin / path).read_bytes() if rev is None else git("cat-file", "blob", f"{rev}:{path}")
    return out


def fork_report(kind, name, forked_from):
    entry = {"kind": kind[:-1], "name": name, "forked_from": forked_from, "status": "unchanged", "changes": []}
    if kind == "skills" and name in sources:
        entry.update(status="not-compared", reason=f"from {sources[name]}, not harness-kit; compare with it by hand")
        return entry
    now = upstream(kind, name)
    if not now:
        entry["status"] = "removed"
        return entry
    if forked_from == version:
        return entry
    tag = f"v{forked_from}"
    try:
        top = Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
    except (OSError, subprocess.CalledProcessError):
        top = None
    if top != plugin:
        entry.update(status="not-compared", reason=f"{plugin} is not a git checkout, so {tag} can't be read")
        return entry
    try:
        git("rev-parse", "-q", "--verify", f"refs/tags/{tag}^{{commit}}")
    except subprocess.CalledProcessError:
        entry.update(status="not-compared", reason=f"tag {tag} is not in {plugin}; "
                     f"fetch it with `git -C {plugin} fetch --depth 1 origin tag {tag}`")
        return entry
    then = upstream(kind, name, tag)
    for path in sorted(set(then) | set(now)):
        status = "A" if path not in then else "D" if path not in now else "M" if then[path] != now[path] else None
        if status:
            entry["changes"].append({"status": status, "path": path})
    if entry["changes"]:
        entry["status"] = "changed"
    return entry


report = {
    "from": old_lock.get("version"),
    "to": version,
    "skills": skills,
    "agents": agents,
    "files": len(want),
    "removed": removed,
    "new": new,
    "forks": [fork_report(kind, name, v) for kind in ("skills", "agents") for name, v in sorted(forks[kind].items())],
    "sources": [{"name": name, "source": sources[name], "commit": commit,
                 "previous": old_lock.get("source_commits", {}).get(name),
                 "pinned": bool(SHA.fullmatch(parsed[name][2]))}
                for name, commit in sorted(commits.items())],
}
if json_out:
    Path(json_out).write_text(json.dumps(report, indent=2) + "\n")
if as_json:
    print(json.dumps(report, indent=2))
    sys.exit(0)

since = f" (from {report['from']})" if report["from"] else ""
print(f"vendored harness-kit {version}{since}: {len(skills)} skills, {len(agents)} agents, {len(want)} files")


def name_section(heading, intro, groups):
    items = [f"- {kind[:-1]} `{n}`" for kind in ("skills", "agents") for n in groups[kind]]
    if items:
        print(f"\n## {heading}\n\n{intro}\n")
        print("\n".join(items))


name_section("Removed upstream", "Dropped from the snapshot; remove them from `.harness/config.toml`:", removed)
name_section("New upstream", "Not installed; add them to `.harness/config.toml` to vendor them:", new)
if report["sources"]:
    print("\n## Third-party sources\n\nFetched from their own repositories; review their changes like code:\n")
for s in report["sources"]:
    line = f"- skill `{s['name']}`: {s['source']} at {s['commit']}"
    if s["previous"] and s["previous"] != s["commit"]:
        line += f", moved from {s['previous']} to {s['commit']}"
    if not s["pinned"]:
        line += " (the ref is not a commit SHA, so it can move; pin it to a full SHA)"
    print(line)
if report["forks"]:
    print("\n## Forks\n\nLeft unchanged. Upstream changes since each was forked:\n")
for f in report["forks"]:
    head = f"- {f['kind']} `{f['name']}` (forked from {f['forked_from']})"
    if f["status"] == "removed":
        print(f"{head}: removed upstream in {version}")
    elif f["status"] == "not-compared":
        print(f"{head}: not compared: {f['reason']}")
    elif f["status"] == "unchanged":
        print(f"{head}: no upstream changes")
    else:
        n = len(f["changes"])
        print(f"{head}: {n} file{'s' if n != 1 else ''} changed upstream")
        for c in f["changes"]:
            print(f"  - {c['status']} `{c['path']}`")
PY
