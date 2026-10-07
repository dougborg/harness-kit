---
paths:
  - "skills/**"
  - "claude-skills/**"
  - "hooks/**"
---

# Script Path Convention

Canonical skills use `<skill-dir>`, `<plugin-root>`, and
`<shared-scripts-dir>` placeholders. The generated Claude projection copies
each required shared helper into the consuming skill and rewrites the placeholder
to `${CLAUDE_SKILL_DIR}` so installed and project-local skills behave identically.

A script used by one skill lives in that skill's directory. A script used by
several stays canonical in `scripts/shared/` and is referenced as
`<shared-scripts-dir>/<name>`.

Do not use skill symlinks for shared helpers: Codex plugin packaging omits them.

Two rules that fail silently if broken:

- The `allowed-tools` Bash rule and the body must spell the path **identically**. The rule is matched as a literal string after substitution; any divergence prompts for permission on every invocation while still appearing to work.
- A script that calls another script by `$SCRIPT_DIR/<name>.sh` needs that
  file beside it in every copy. The Claude projection copies only the helpers
  a skill names, so keep each shared helper self-contained; `just check`
  fails on a `$SCRIPT_DIR/` reference with nothing beside it.

`${CLAUDE_PLUGIN_ROOT}` remains correct in `hooks/hooks.json` (no skill context) and where a skill genuinely means the plugin tree — `/harness bootstrap` copying from it, `/harness update` comparing against it.
