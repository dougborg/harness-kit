# Bootstrap Mode

Analyze the project, install skills/agents from the harness-kit plugin, and generate project-specific additions. **Auto-triggers when `.claude/` doesn't exist or is empty.**

## Workflow

1. **Spawn `harness-builder` agent** — It analyzes the codebase and returns:
   - Stack summary (language, toolchain, verification command)
   - Draft CLAUDE.md skeleton
   - **Recommended architecture pattern** (from `agents/references/architecture-patterns.md`)
   - **Recommended agents** with model + `tools:` (agents use `tools:`, not the skill-only `allowed-tools:`) (always includes code-reviewer, verifier, test-writer, domain-advisor; adds project-manager if GitHub detected)
   - **Recommended skills from harness-kit:** which of the plugin's base skills to copy into the project
   - **Bundled skills to delegate to:** matches from the bundled-skills table in `agents/references/external-plugins.md` — no install required
   - **Recommended official Anthropic plugins:** stack-matched picks from the marketplace catalog in `agents/references/external-plugins.md`, with overlap flags against harness-kit skills
   - **Recommended external sources:** additional plugin marketplaces based on stack (e.g., Vercel skills for React, impeccable for frontend)
   - **Project-specific skills** to generate (domain workflows, custom checks)
   - Recommended hooks (PostToolUse: formatters → validators → guidance; Stop: session-end guidance)
   - Domain knowledge (entity types, ownership model, business rules)

2. **Present recommendations for approval:**
   - **Stack:** one-line summary + architecture pattern
   - **Skills from harness-kit to install:** table with name, purpose, why this project needs it
   - **Bundled skills already available (no install):** the matching rows from the bundled-skills table in `agents/references/external-plugins.md`, one line each. Present these *before* anything installable — never propose installing a plugin or generating a project skill for a job a bundled skill already does
   - **Official Anthropic plugins to install (optional):** for each stack-matched plugin from `agents/references/external-plugins.md`, show one-line rationale plus the install command (`/plugin install <name>@claude-plugins-official`). Where a plugin overlaps a harness-kit skill (e.g., `code-review` vs `code-reviewer`, `commit-commands` vs `/commit`), flag the overlap and ask the user to pick one or accept the documented composition — never install both sides of an overlap silently
   - **External sources to add:** marketplace repos with rationale
   - **Project-specific skills to generate:** table with name, purpose
   - **Agents to create:** table with name, purpose, model
   - **Domain knowledge:** institutional rules the harness should encode
   - **Hooks to configure:** execution order and commands

3. **Do NOT write any files until the user approves.**

4. **After approval, install and generate:**
   - Copy approved skills from `${CLAUDE_PLUGIN_ROOT}/skills/` to `.claude/skills/` — copy each skill's **whole directory**, including sibling reference `.md` files and scripts, not just `SKILL.md`
   - Copy approved agents from `${CLAUDE_PLUGIN_ROOT}/agents/` to `.claude/agents/`
   - Copy `skills/shared/` scripts to `.claude/skills/shared/`
   - Rewrite `${CLAUDE_PLUGIN_ROOT}` references to `.claude` in copied files
   - Generate project-specific agents (domain-advisor, etc.) in `.claude/agents/`
   - Generate project-specific skills in `.claude/skills/`
   - Write `CLAUDE.md` with all sections filled in, including an "External plugins" section recording which official plugins were installed or deliberately skipped, with rationale (external plugins are installed via `/plugin install`, not copied — they are NOT tracked in `.harness-lock.json`)
   - Configure hooks in `.claude/settings.local.json`
   - Create `.harness-lock.json` tracking provenance of every installed file
   - Write `.claude/harness-upstream` (one line: `owner/repo`) so `/harness-issue` knows where to file feedback. Use the source repo from the lock file (default `dougborg/harness-kit`).
   - Update `.gitignore` (add `.claude/settings.local.json` if it contains secrets)
   - Never generate `.claude/commands/` — commands are legacy

5. **Run verification command** to confirm nothing broke.

6. **Tell the user how to keep it healthy.** Two complementary tools, named in the closing summary:
   - `/doctor` (bundled with Claude Code, alias `/checkup`) — ongoing setup hygiene: installation and PATH problems, unused skills and MCP servers, slow hooks, CLAUDE.md bloat. Run it periodically; no install needed.
   - `/harness audit` — harness-kit structure, frontmatter validity, and provenance. Advisory, not a gate.

   Also recommend running `/run-skill-generator` once, to record this project's real build/launch recipe as a `run-<name>` skill that `/run` and `/verify` then follow. See the bundled-skills table in `agents/references/external-plugins.md` for the rest.

## Lock File Creation

The `.harness-lock.json` file is created during bootstrap and tracks every file's provenance:

```json
{
  "sources": {
    "harness-kit": { "version": "0.1.0", "installed": "2026-04-04", "repo": "dougborg/harness-kit" }
  },
  "files": {
    ".claude/skills/commit/SKILL.md": { "source": "harness-kit", "modified": false },
    ".claude/agents/code-reviewer.md": { "source": "harness-kit", "modified": false },
    ".claude/agents/domain-advisor.md": { "source": "local" }
  }
}
```

Track every copied file, including a skill's sibling reference files (e.g. `.claude/skills/harness/audit.md`), so `/harness update` can refresh them.

The `repo` field on each source records the GitHub upstream so `/harness-issue` and `/harness hoist` can route feedback and proposed changes to the right place. Omit `repo` for purely local sources.

This file should be committed — it lets teammates run `/harness update` to sync.

## Agent Recommendations

- **Always include:** `code-reviewer` (6D review), `verifier` (validation), `test-writer` (testing), `domain-advisor` (read-only business rules)
- **If GitHub:** Add `project-manager` (issue/PR/sprint management via `gh` CLI)
- **If frontend:** Add `/ui-review` skill for accessibility audits
