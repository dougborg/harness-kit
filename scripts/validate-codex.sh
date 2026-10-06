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

for skill in sorted((root / "skills").iterdir()):
    if not skill.is_dir():
        continue
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
