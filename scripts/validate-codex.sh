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
assert manifest["name"] == root.name
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
names = [skill.name for skill in skills]
duplicates = sorted({name for name in names if names.count(name) > 1})
assert not duplicates, f"skill names must be unique across areas: {duplicates}"
assert len(list((root / "skills").rglob("SKILL.md"))) == len(skills), "a SKILL.md is nested below a skill folder"

for skill in skills:
    skill_md = skill / "SKILL.md"
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
PY

"$repo_root/scripts/generate-claude-skills.sh" --check
