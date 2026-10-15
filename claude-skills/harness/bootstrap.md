# Bootstrap Mode

Set up a project on the vendored model (ADR 0001): state its facts, write its
project-specific skills and agents, and vendor harness-kit's generic set as an
unedited snapshot for Claude Code and Codex. Auto-trigger only when `.claude/`,
`.agents/`, and `.codex/` contain no harness content. A project with a
`.harness-lock.json` from an older bootstrap is not fresh; migrate mode
converts it.

## Find the plugin root

Below, `${CLAUDE_PLUGIN_ROOT}` is the harness-kit tree the snapshot is copied from.
Bootstrap of a new project runs from the installed plugin, since the project
has no snapshot yet, so the path is the plugin's root: Claude Code fills it in,
and on Codex it is three levels above this skill's folder, which sits at
`skills/meta/harness/` in the plugin.

When this skill was loaded from a vendored snapshot (`.claude/skills/harness/`
or `.agents/skills/harness/`), the plugin is turned off and that path is empty
or points nowhere. Clone the release to vendor from, `git clone --depth 1
--branch vX.Y.Z https://github.com/dougborg/harness-kit /tmp/harness-kit`, and
use `/tmp/harness-kit` wherever this file says `${CLAUDE_PLUGIN_ROOT}`. `${CLAUDE_SKILL_DIR}`
is this skill's folder either way.

Done when `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` exists.

## Workflow

1. **Spawn the `harness-builder` agent.** Pass it the absolute paths of this
   skill's catalogs (`${CLAUDE_SKILL_DIR}/architecture-patterns.md`,
   `external-plugins.md`, `hooks-reference.md`, `release-please-reference.md`)
   and the generic names it can choose from: the folders in
   `${CLAUDE_PLUGIN_ROOT}/claude-skills/` and the files in `${CLAUDE_PLUGIN_ROOT}/agents/`. It
   returns the stack, a recommended architecture pattern, and its
   recommendations sorted into three kinds:
   - **Facts**: the verification command first, then the prose facts for
     `AGENTS.md`'s `## Project facts` section (`${CLAUDE_SKILL_DIR}/project-facts.md`).
   - **Project-local content**: skills and agents that exist only for this
     project (domain workflows, `test-writer`, `domain-advisor`), plus hooks.
   - **The generic set**: harness-kit skills and agents to vendor by name,
     unedited. `harness` is always included.

   It also lists bundled skills to delegate to, official Anthropic plugins,
   and external marketplaces. Done when the report names a verification
   command and doesn't say the catalogs were missing.

2. **Present the recommendations for approval:**
   - **Stack:** one-line summary and architecture pattern.
   - **Facts:** the verification command, then the `## Project facts` bullets.
   - **Generic set:** the skills and agents to vendor, each with why this
     project needs it.
   - **Bundled skills already available (no install):** the matching rows from
     `${CLAUDE_SKILL_DIR}/external-plugins.md`, one line each, before anything
     installable. Never propose a plugin or a project skill for a job a
     bundled skill already does.
   - **Official Anthropic plugins (optional):** each stack-matched plugin with
     a one-line rationale and `/plugin install <name>@claude-plugins-official`.
     Flag each overlap with a harness-kit skill (`code-review` vs
     `code-reviewer`, `commit-commands` vs `/commit`) and have the user pick
     one side or accept the documented composition.
   - **External sources to add:** marketplace repos with rationale.
   - **Project-local skills and agents:** name, purpose, and model for agents.
     None may share a name with the generic set.
   - **Hooks:** execution order and commands.

   A project quirk that a generic skill should honor is a fact, not a reason
   to copy or edit that skill. Done when the user approves the list. Write no
   files before then.

3. **Write the facts and the project-local content:**
   - `.harness/config.toml`: the generic set as `skills` and `agents`, and
     `[facts] verification_command` (format in `${CLAUDE_SKILL_DIR}/project-facts.md`).
     Leave out `harness`; it is always vendored.
   - `AGENTS.md`: shared rules plus the `## Project facts` section. `CLAUDE.md`
     holds Claude-only additions and an `@AGENTS.md` import.
   - Project-local skills as open-format skills in both `.claude/skills/<name>/`
     and `.agents/skills/<name>/`; project-local agents as Claude Markdown in
     `.claude/agents/` and Codex TOML in `.codex/agents/`.
   - Project hooks in `.claude/settings.json` (or `.claude/settings.local.json`
     when they hold secrets or machine paths) and `.codex/hooks.json`, sharing
     invoked scripts where semantics match.
   - Merge the project's Codex defaults into `.codex/config.toml`.
   - `.harness-upstream`, and `.claude/harness-upstream` as a compatibility
     copy, naming the upstream repo.
   - `.gitignore`: commit `.harness/`, `.agents/`, `.codex/`, and `.claude/`'s
     `skills/`, `agents/`, `hooks/`, `settings.json`, and `harness-upstream`;
     ignore `.claude/settings.local.json`. Never generate `.claude/commands/`;
     commands are legacy.

   Done when every approved fact and project-local file is written.

4. **Vendor the snapshot:**

   ```bash
   ${CLAUDE_SKILL_DIR}/vendor-snapshot.sh ${CLAUDE_PLUGIN_ROOT} .
   ```

   It writes the generic set into `.claude/`, `.agents/`, and `.codex/` as
   real files, vendors the plugin's hooks, sets harness-kit to `false` in
   `.claude/settings.json`, and records it all in `.harness/lock.json`
   (`${CLAUDE_SKILL_DIR}/vendoring.md`), the project's only lock. Nothing is copied
   by hand. If it exits 1, fix what it names (an
   unknown name in the config, a project-local file on a vendored path) and
   run it again. Done when it exits 0 and `.harness/lock.json` exists.

5. **Run the gate.** Run
   `${CLAUDE_SKILL_DIR}/discover-verification-cmd.sh` and then the command
   it prints. With the lock in place, it starts with
   `.claude/skills/harness/check-snapshot.sh &&`, so the edit check is part of
   the gate from the first commit. If the project's CI runs the verification
   command directly rather than the discovered one, add the check there too.
   On a Nix flake, `git add` the new files first. Done when the command
   passes.

6. **Offer the GitHub Action (optional).** If the project wants Claude in CI,
   set up `claude-code-action` per `${CLAUDE_SKILL_DIR}/github-action.md`: `Skill` in
   `--allowedTools`, and no harness-kit in the Action's `plugins` input.

7. **Tell the user how to keep it healthy.** Name both in the closing
   summary:
   - `/doctor` (bundled with Claude Code, alias `/checkup`): ongoing setup
     hygiene such as installation and PATH problems, unused skills and MCP
     servers, slow hooks, and CLAUDE.md bloat. No install needed.
   - The `harness` skill's audit mode (`/harness audit` in Claude Code,
     `$harness audit` in Codex): harness structure, frontmatter validity,
     and the snapshot. Advisory, not a gate.

   Also recommend running `/run-skill-generator` once, to record this
   project's real build and launch recipe as a `run-<name>` skill that `/run`
   and `/verify` then follow. The bundled-skills table in
   `${CLAUDE_SKILL_DIR}/external-plugins.md` has the rest. Done when the summary lists
   what was written, the snapshot version, and these next steps.

## Agent recommendations

- **Generic, vendored:** `code-reviewer` and `verifier` always;
  `project-manager` when the project uses GitHub.
- **Project-local, generated:** `test-writer` (the project's testing
  conventions) and `domain-advisor` (read-only business rules) always, plus
  any domain-specific agents.
- **Frontend:** add the `ui-review` skill to the generic set.
