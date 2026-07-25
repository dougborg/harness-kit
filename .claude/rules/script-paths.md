---
paths:
  - "skills/**"
  - "hooks/**"
---

# Script Path Convention

Skills address their own files as `${CLAUDE_SKILL_DIR}/<script>.sh` — the runtime substitutes the directory the skill was actually loaded from, so the same path works in the plugin cache and in a project's `.claude/skills/`. Nothing rewrites paths at install time.

A script used by one skill lives in that skill's directory. A script used by several stays canonical in `skills/shared/`, and each consumer gets a **relative** symlink:

```bash
ln -s ../shared/discover-verification-cmd.sh skills/commit/discover-verification-cmd.sh
```

Git stores these as mode `120000`, so they survive clone and `/plugin install`; `cp -R` preserves them, and the relative target resolves in either layout because `shared/` is always copied alongside. Never dereference them (`cp -RL`) — that reintroduces the duplicate copies this avoids.

Two rules that fail silently if broken:

- The `allowed-tools` Bash rule and the body must spell the path **identically**. The rule is matched as a literal string after substitution; any divergence prompts for permission on every invocation while still appearing to work.
- A shared script that invokes a sibling must resolve `$0` through symlinks before taking its `dirname` (see `skills/shared/resolve-all-threads.sh`), or it will look for the sibling in the consuming skill's directory.

`${CLAUDE_PLUGIN_ROOT}` remains correct in `hooks/hooks.json` (no skill context) and where a skill genuinely means the plugin tree — `/harness bootstrap` copying from it, `/harness update` comparing against it.
