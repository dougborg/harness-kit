#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

mkdir -p "$scratch/bin"
cat >"$scratch/bin/claude" <<'EOF'
#!/usr/bin/env bash
touch "$HOOK_TEST_CLAUDE_CALLED"
EOF
chmod +x "$scratch/bin/claude"

HOOK_TEST_CLAUDE_CALLED="$scratch/claude-called" PATH="$scratch/bin:$PATH" \
  "$repo_root/scripts/shared/claude-usage-check.sh" --hook <<'EOF'
{"turn_id":"codex-turn","tool_name":"spawn_agent","tool_input":{}}
EOF
test ! -e "$scratch/claude-called"

cat >"$scratch/bin/markdownlint-cli2" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$2" >>"$HOOK_TEST_MARKDOWN_FILES"
EOF
chmod +x "$scratch/bin/markdownlint-cli2"
touch "$scratch/one.md" "$scratch/two.md"

HOOK_TEST_MARKDOWN_FILES="$scratch/markdown-files" PATH="$scratch/bin:$PATH" \
  "$repo_root/scripts/shared/markdownlint-fix.sh" <<EOF
{"turn_id":"codex-turn","tool_name":"apply_patch","tool_input":{"command":"*** Update File: $scratch/one.md\n*** Add File: $scratch/two.md"}}
EOF

grep -Fx "$scratch/one.md" "$scratch/markdown-files" >/dev/null
grep -Fx "$scratch/two.md" "$scratch/markdown-files" >/dev/null
