#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
profile=$(mktemp -d)
trap 'rm -rf "$profile"' EXIT

CODEX_HOME="$profile" codex plugin marketplace add "$repo_root" >/dev/null
CODEX_HOME="$profile" codex plugin add harness-kit@harness-kit >/dev/null

version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' \
  "$repo_root/.codex-plugin/plugin.json")
installed="$profile/plugins/cache/harness-kit/harness-kit/$version"
test -f "$installed/skills/project-management/feature-spec/SKILL.md"
test -f "$installed/skills/meta/harness/SKILL.md"
test -x "$installed/scripts/shared/discover-verification-cmd.sh"
grep -F '<shared-scripts-dir>/discover-verification-cmd.sh' \
  "$installed/skills/engineering/commit/SKILL.md" >/dev/null

# Codex discovers skills recursively under the area folders; confirm a nested
# model-invoked skill reaches the model under its unchanged name.
prompt=$(cd "$profile" && CODEX_HOME="$profile" codex debug prompt-input "hi")
grep -F 'harness-kit:commit' <<<"$prompt" >/dev/null
grep -F 'engineering/commit/SKILL.md' <<<"$prompt" >/dev/null
