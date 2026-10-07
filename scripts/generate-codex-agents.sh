#!/usr/bin/env bash
# Generate .codex/agents/*.toml from the canonical agents/*.md.
#
# name and the description (minus Claude's <example> blocks) carry over; an
# agent whose tools can't edit files gets sandbox_mode = "read-only"; the
# Markdown body becomes developer_instructions. model_reasoning_effort is
# Codex-only and set per agent below.
#
# Usage: generate-codex-agents.sh [--check]
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_root" "${1:-}" <<'PY'
import re
import sys
import tomllib
from pathlib import Path

root, mode = Path(sys.argv[1]), sys.argv[2]
out_dir = root / ".codex/agents"
# Codex reasoning effort per agent; the rest get "high".
effort = {"verifier": "low"}
writers = {"Edit", "Write", "MultiEdit", "NotebookEdit"}


def frontmatter(text, path):
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    assert match, f"{path}: missing frontmatter"
    fields, key = {}, None
    for line in match.group(1).splitlines():
        if line.startswith("#"):
            continue
        top = re.match(r"([a-z-]+):\s*(.*)", line)
        if top:
            key, value = top.groups()
            fields[key] = [] if value in (">-", ">", "|", "") else [value]
        elif key:
            fields[key].append(line.strip())
    return fields, text[match.end():]


def basic_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(path):
    fields, body = frontmatter(path.read_text(), path)
    name = " ".join(fields["name"])
    description = " ".join(fields["description"])
    description = re.split(r"\s*Examples:", description)[0]
    description = re.sub(r"\s+", " ", description).strip()
    tools = {t.strip(" -") for line in fields.get("tools", []) for t in line.split(",")}
    tools.discard("")
    instructions = body.strip().replace("\\", "\\\\").replace('"""', '""\\"')
    lines = [
        "# Generated from agents/%s by scripts/generate-codex-agents.sh; do not edit." % path.name,
        f"name = {basic_string(name)}",
        f"description = {basic_string(description)}",
        f"model_reasoning_effort = {basic_string(effort.get(name, 'high'))}",
    ]
    if tools and not tools & writers:
        lines.append('sandbox_mode = "read-only"')
    lines.append(f'developer_instructions = """\n{instructions}\n"""')
    text = "\n".join(lines) + "\n"
    assert tomllib.loads(text)["developer_instructions"].strip() == body.strip(), f"{path}: TOML round trip changed the body"
    return name, text


wanted = dict(render(p) for p in sorted((root / "agents").glob("*.md")))
stale = []
for name, text in wanted.items():
    target = out_dir / f"{name}.toml"
    if not target.is_file() or target.read_text() != text:
        stale.append(target.name)
        if mode != "--check":
            target.write_text(text)
for extra in sorted(out_dir.glob("*.toml")):
    if extra.stem not in wanted:
        stale.append(extra.name)
        if mode != "--check":
            extra.unlink()
if mode == "--check" and stale:
    sys.exit("Codex agents are stale (%s); run scripts/generate-codex-agents.sh" % ", ".join(stale))
PY
