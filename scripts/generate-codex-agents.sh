#!/usr/bin/env bash
# Generate .codex/agents/*.toml from the canonical agents/*.md. Every TOML in
# .codex/agents/ is generated: one without a matching agents/*.md is removed.
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


def fail(message):
    sys.exit(message)


def frontmatter(text, path):
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        fail(f"{path}: missing frontmatter")
    fields, key = {}, None
    for line in match.group(1).splitlines():
        if line.lstrip().startswith("#"):
            continue
        top = re.match(r"([A-Za-z][\w-]*):\s*(.*)", line)
        if top:
            key, value = top.groups()
            fields[key] = [] if value in (">-", ">", "|", "") else [value]
        elif key:
            fields[key].append(line.strip())
    return fields, text[match.end():]


def tool_names(lines, path):
    names = set()
    for line in lines:
        for raw in line.strip().strip("[]").split(","):
            name = raw.strip().lstrip("- ").strip("'\"")
            if not name:
                continue
            if not re.fullmatch(r"[A-Za-z]\w*(\(.*\))?", name):
                fail(f"{path}: can't read tool {raw.strip()!r}")
            names.add(name.split("(")[0])
    return names


def basic_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(path):
    fields, body = frontmatter(path.read_text(), path)
    name = " ".join(fields["name"])
    description = "\n".join(fields["description"])
    description = re.split(r"\n\s*Examples:\s*\n", description)[0]
    description = re.sub(r"<example>.*?</example>", "", description, flags=re.S)
    description = re.sub(r"\s+", " ", description).strip()
    tools = tool_names(fields.get("tools", []), path)
    body = body.strip() + "\n"
    instructions = body.replace("\\", "\\\\").replace('"""', '""\\"')
    lines = [
        "# Generated from harness-kit's agents/%s; edit that, not this file." % path.name,
        f"name = {basic_string(name)}",
        f"description = {basic_string(description)}",
        f"model_reasoning_effort = {basic_string(effort.get(name, 'high'))}",
    ]
    # No tools: field means every tool on Claude, so no sandbox here either.
    if tools and not tools & writers:
        lines.append('sandbox_mode = "read-only"')
    lines.append(f'developer_instructions = """\n{instructions}"""')
    text = "\n".join(lines) + "\n"
    try:
        parsed = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        fail(f"{path}: generated TOML doesn't parse: {error}")
    if parsed["developer_instructions"] != body:
        fail(f"{path}: TOML round trip changed the body")
    return name, text


sources = sorted((root / "agents").glob("*.md"))
if not sources:
    fail("no agents/*.md found")
wanted = dict(render(p) for p in sources)
unknown = sorted(set(effort) - set(wanted))
if unknown:
    fail("effort set for unknown agents: " + ", ".join(unknown))

stale = []
if mode != "--check":
    out_dir.mkdir(parents=True, exist_ok=True)
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
    fail("Codex agents are stale (%s); run scripts/generate-codex-agents.sh" % ", ".join(stale))
PY
