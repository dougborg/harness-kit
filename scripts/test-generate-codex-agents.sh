#!/usr/bin/env bash
# Regression tests for scripts/generate-codex-agents.sh against fixture agents
# in a scratch copy of the repo layout.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/scripts" "$scratch/agents"
cp "$repo_root/scripts/generate-codex-agents.sh" "$scratch/scripts/"
gen="$scratch/scripts/generate-codex-agents.sh"
out="$scratch/.codex/agents"

cat >"$scratch/agents/verifier.md" <<'MD'
---
name: verifier
description: >-
  Checks work. Examples: in prose stay.

  Examples:

  <example>
  user: "verify"
  </example>
# a comment
disallowedTools: Write
tools:
  - Read
  - Bash
---
Body with \backslash and """ triple quotes.
MD
cat >"$scratch/agents/reader.md" <<'MD'
---
name: reader
description: Reads files.
tools: Read, Grep
---
Read things.
MD
cat >"$scratch/agents/writer.md" <<'MD'
---
name: writer
description: Edits files.
tools: [Read, Edit]
---
Write things.
MD

fail=0
# expect <name> <command...>: the command succeeds.
expect() {
  local name=$1
  shift
  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    fail=1
  fi
}
# rejects <name>: generate-codex-agents.sh --check fails.
rejects() {
  if "$gen" --check 2>/dev/null; then
    echo "FAIL: $1"
    fail=1
  else
    echo "PASS: $1"
  fi
}
field() { python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb")).get(sys.argv[2],""))' "$out/$1.toml" "$2"; }

"$gen"
expect description [ "$(field verifier description)" = "Checks work. Examples: in prose stay." ]
expect read-only-sandbox [ "$(field reader sandbox_mode)" = read-only ]
expect sandbox-override [ "$(field verifier sandbox_mode)" = workspace-write ]
expect effort [ "$(field verifier model_reasoning_effort)" = low ]
expect writer-no-sandbox [ -z "$(field writer sandbox_mode)" ]
expect body-round-trip [ "$(field verifier developer_instructions)" = 'Body with \backslash and """ triple quotes.' ]
expect fresh-check "$gen" --check

echo "# edit" >>"$out/verifier.toml"
rejects stale-detected
"$gen"
touch "$out/orphan.toml"
rejects orphan-detected
"$gen"
expect orphan-removed [ ! -e "$out/orphan.toml" ]

printf -- '---\nname: odd\ndescription: x\ntools: Read, {Edit}\n---\nx\n' >"$scratch/agents/odd.md"
rejects unreadable-tool-fails
rm "$scratch/agents/odd.md"

# A mistyped sandbox override fails here, not at Codex runtime.
cp "$gen" "$gen.orig"
sed -i.bak 's/"verifier": "workspace-write"/"verifier": "workspace_write"/' "$gen"
rejects bad-sandbox-mode-fails
cp "$gen.orig" "$gen"

# An override for an agent that doesn't exist fails too.
mv "$scratch/agents/verifier.md" "$scratch/verifier.md"
rejects override-for-unknown-agent-fails
mv "$scratch/verifier.md" "$scratch/agents/verifier.md"

exit "$fail"
