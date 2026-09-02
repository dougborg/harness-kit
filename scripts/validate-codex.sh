#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_root" <<'PY'
import json
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / ".codex-plugin/plugin.json").read_text())
assert manifest["name"] == root.name
assert manifest["skills"] == "./skills/"

market = json.loads((root / ".agents/plugins/marketplace.json").read_text())
entry = next(item for item in market["plugins"] if item["name"] == manifest["name"])
assert entry["source"] == "./"
assert entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}

for skill in sorted((root / "skills").iterdir()):
    if not skill.is_dir():
        continue
    skill_md = skill / "SKILL.md"
    assert skill_md.is_file(), f"{skill} is not a skill; move utilities outside skills/"
    frontmatter = skill_md.read_text().split("\n---\n", 1)[0]
    assert "disable-model-invocation: true" not in frontmatter, f"{skill} is not Codex-compatible"

for agent in sorted((root / ".codex/agents").glob("*.toml")):
    data = tomllib.loads(agent.read_text())
    for key in ("name", "description", "developer_instructions"):
        assert data.get(key), f"{agent}: missing {key}"
    if "read-only" in data["description"].lower():
        assert data.get("sandbox_mode") == "read-only", f"{agent}: read-only promise not enforced"
PY

"$repo_root/scripts/generate-claude-skills.sh" --check
