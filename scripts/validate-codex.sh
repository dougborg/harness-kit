#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_root" <<'PY'
import json
import pathlib
import re
import sys

if sys.version_info < (3, 11):
    raise SystemExit("validate-codex.sh requires Python 3.11 or newer (for tomllib)")

import tomllib

root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / ".codex-plugin/plugin.json").read_text())
# The Codex and Claude manifests name the same plugin. (Not the checkout's
# folder name: worktrees and forks live in differently named directories.)
claude_name = json.loads((root / ".claude-plugin/plugin.json").read_text())["name"]
assert manifest["name"] == claude_name, (
    f".codex-plugin name {manifest['name']!r} differs from .claude-plugin name {claude_name!r}"
)
assert manifest["skills"] == "./skills/"

market = json.loads((root / ".agents/plugins/marketplace.json").read_text())
entry = next(item for item in market["plugins"] if item["name"] == manifest["name"])
assert entry["source"] == "./"
assert entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}

# skills/<area>/<skill>/: areas hold only skill directories and a README.md.
# Codex discovers SKILL.md recursively, so a stray SKILL.md anywhere would ship.
skills = []
def visible(path):
    return sorted(p for p in path.iterdir() if not p.name.startswith("."))

for area in visible(root / "skills"):
    assert area.is_dir(), f"{area}: only topic-area folders belong directly under skills/"
    assert not (area / "SKILL.md").exists(), f"{area}: skills live one level down, in skills/<area>/<skill>/"
    for entry in visible(area):
        if entry.name == "README.md":
            continue
        assert entry.is_dir(), f"{entry}: areas hold only skill folders and README.md"
        skills.append(entry)
# The Claude manifest names each generated claude-skills/<skill> explicitly.
claude_manifest = json.loads((root / ".claude-plugin/plugin.json").read_text())
projected = sorted(f"./claude-skills/{name}" for name in {skill.name for skill in skills})
assert sorted(claude_manifest["skills"]) == projected, (
    ".claude-plugin/plugin.json skills must list every generated claude-skills/<skill>: "
    f"missing {sorted(set(projected) - set(claude_manifest['skills']))}, "
    f"extra {sorted(set(claude_manifest['skills']) - set(projected))}"
)

# Each area README lists exactly its skills, under the section matching the
# invocation policy. Claude-only skills (the generator's claude_only set) are
# hidden from Codex for host availability but model-invoked on Claude.
generator = (root / "scripts/generate-claude-skills.sh").read_text()
claude_only = set(re.search(r'^claude_only="([^"]*)"', generator, re.M).group(1).split())
for area in {skill.parent for skill in skills}:
    readme = area / "README.md"
    assert readme.is_file(), f"{area}: missing README.md listing the area's skills"
    section, listed = None, {}
    for line in readme.read_text().splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
        for name in re.findall(r"\]\(\./([^/]+)/SKILL\.md\)", line):
            listed[name] = section
    present = {skill.name for skill in skills if skill.parent == area}
    assert set(listed) == present, f"{readme}: lists {sorted(set(listed) - present)} missing {sorted(present - set(listed))}"
    for name, section in listed.items():
        gated = "allow_implicit_invocation: false" in (area / name / "agents/openai.yaml").read_text()
        want = "User-invoked" if gated and name not in claude_only else "Model-invoked"
        assert section == want, f"{readme}: {name} belongs under '## {want}'"
# The ask-harness router must name every skill, so it never sends people to a
# skill that's gone or leaves a new one out.
router = (root / "skills/meta/ask-harness/SKILL.md").read_text()
routed = set(re.findall(r"`/?([a-z][a-z0-9-]*)(?: [^`]*)?`", router))
skill_names = {skill.name for skill in skills}
unrouted = sorted(skill_names - routed - {"ask-harness"})
assert not unrouted, f"skills/meta/ask-harness/SKILL.md doesn't mention: {unrouted}"
not_skills = {"name"}  # placeholders the router uses in prose
stale = sorted(name for name in routed - skill_names - not_skills if "-" in name or f"`/{name}" in router)
assert not stale, f"skills/meta/ask-harness/SKILL.md names skills that don't exist: {stale}"

names = [skill.name for skill in skills]
duplicates = sorted({name for name in names if names.count(name) > 1})
assert not duplicates, f"skill names must be unique across areas: {duplicates}"
assert len(list((root / "skills").rglob("SKILL.md"))) == len(skills), "a SKILL.md is nested below a skill folder"

for skill in skills:
    skill_md = skill / "SKILL.md"
    # An unquoted scalar containing ": " is invalid YAML (the loaders reject it).
    for line in skill_md.read_text().split("\n---\n", 1)[0].splitlines()[1:]:
        match = re.match(r"^[a-z_-]+: (.+)$", line)
        assert not (match and match.group(1)[0] not in "\"'>|[{" and ": " in match.group(1)), (
            f"{skill_md}: quote this frontmatter value or use >-, it contains ': ': {line}"
        )
    assert skill_md.is_file(), f"{skill} is not a skill; move utilities outside skills/"
    frontmatter = skill_md.read_text().split("\n---\n", 1)[0]
    assert "disable-model-invocation: true" not in frontmatter, f"{skill} is not Codex-compatible"
    policy = skill / "agents/openai.yaml"
    assert policy.is_file(), f"{skill}: missing agents/openai.yaml (the invocation source of truth)"
    policy_text = policy.read_text()
    for key in ("display_name:", "short_description:"):
        assert key in policy_text, f"{policy}: missing interface.{key[:-1]}"
    # The Claude generator matches this line literally, so a quoted or
    # capitalised value would silently diverge between hosts.
    for line in policy_text.splitlines():
        if "allow_implicit_invocation" in line:
            assert re.fullmatch(r"\s+allow_implicit_invocation: (true|false)", line), (
                f"{policy}: allow_implicit_invocation must be a bare true or false: {line!r}"
            )
            assert "\npolicy:\n" in policy_text, f"{policy}: allow_implicit_invocation outside policy:"

for agent in sorted((root / ".codex/agents").glob("*.toml")):
    data = tomllib.loads(agent.read_text())
    for key in ("name", "description", "developer_instructions"):
        assert data.get(key), f"{agent}: missing {key}"
    if "read-only" in data["description"].lower():
        assert data.get("sandbox_mode") == "read-only", f"{agent}: read-only promise not enforced"

# A script that calls a sibling through $SCRIPT_DIR needs that file beside it
# in every copy: the Claude projection copies only the helpers a skill names,
# so a sibling call can break there without failing anywhere else. The check
# relies on the house convention of naming the script's own directory
# SCRIPT_DIR; it matches "$SCRIPT_DIR/x.sh", "${SCRIPT_DIR}/x.sh", and
# "$SCRIPT_DIR"/x.sh.
sibling_call = re.compile(r'\$\{?SCRIPT_DIR\}?"?/([A-Za-z0-9._-]+\.sh)')
missing = sorted(
    f"{script.relative_to(root)} calls {name}"
    for top in ("skills", "claude-skills")
    for script in (root / top).rglob("*.sh")
    for name in set(sibling_call.findall(script.read_text()))
    if not (script.parent / name).is_file()
)
assert not missing, "sibling scripts missing beside their caller: " + "; ".join(missing)

# scripts/shared/ ships into projects (bootstrap copies it), so it holds only
# what a skill or hook uses: each file named by a skill's <shared-scripts-dir>
# reference or by hooks/hooks.json, and no subdirectories. Repo tests and
# fixtures live in scripts/.
shared = root / "scripts/shared"
users = "\n".join(
    [p.read_text() for p in (root / "skills").rglob("*") if p.is_file() and p.suffix in (".md", ".sh")]
    + [(root / "hooks/hooks.json").read_text()]
)
stray = sorted(
    p.name for p in shared.iterdir()
    if p.is_dir() or not (f"<shared-scripts-dir>/{p.name}" in users or f"scripts/shared/{p.name}" in users)
)
assert not stray, "scripts/shared/ holds files no skill or hook uses (move repo tooling to scripts/): " + ", ".join(stray)
PY

"$repo_root/scripts/generate-claude-skills.sh" --check
"$repo_root/scripts/generate-codex-agents.sh" --check
