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
test -f "$installed/skills/feature-spec/SKILL.md"
test -f "$installed/skills/harness/SKILL.md"
test -x "$installed/scripts/shared/discover-verification-cmd.sh"
grep -F '<shared-scripts-dir>/discover-verification-cmd.sh' \
  "$installed/skills/commit/SKILL.md" >/dev/null
