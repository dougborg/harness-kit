#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output="$repo_root/claude-skills"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

gated=" documentation-writer feature-spec groom harness-builder issue-close issue-create issue-restructure issue-update pr-comments rebase session-retro skill-writer svg-logo-designer "

for source in "$repo_root"/skills/*; do
  [ -f "$source/SKILL.md" ] || continue
  name=$(basename "$source")
  cp -R "$source" "$staging/$name"
  rm -rf "$staging/$name/agents"
  while IFS= read -r helper; do
    [ -n "$helper" ] || continue
    [ -f "$repo_root/scripts/shared/$helper" ] || continue
    cp "$repo_root/scripts/shared/$helper" "$staging/$name/$helper"
  done < <(
    grep -rhoE '<shared-scripts-dir>/[A-Za-z0-9._-]+\.sh' "$staging/$name" |
      sed 's#<shared-scripts-dir>/##' | sort -u
  )
  find "$staging/$name" -type f \( -name '*.md' -o -name '*.sh' \) -exec \
    perl -pi -e 's#<skill-dir>#\${CLAUDE_SKILL_DIR}#g; s#<plugin-root>#\${CLAUDE_PLUGIN_ROOT}#g; s#<shared-scripts-dir>#\${CLAUDE_SKILL_DIR}#g' {} +
  if [[ "$gated" == *" $name "* ]]; then
    perl -0pi -e 's/\n---\n/\ndisable-model-invocation: true\n---\n/' \
      "$staging/$name/SKILL.md"
  fi
done

if [ "${1:-}" = "--check" ]; then
  if ! diff -qr "$staging" "$output"; then
    echo "Claude skill projection is stale; run scripts/generate-claude-skills.sh" >&2
    exit 1
  fi
  exit
fi

rm -rf "$output"
mv "$staging" "$output"
trap - EXIT
