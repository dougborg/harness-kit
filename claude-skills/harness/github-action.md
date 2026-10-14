# The Claude Code GitHub Action in a Vendored Repo

Whether `anthropics/claude-code-action` loads a vendored snapshot, and the
workflow settings that make it work. Read this when bootstrap, migrate, or
audit sets up or checks a workflow that runs Claude in CI.

Checked on 2026-10-14 against the Claude Code docs and the Action's `main`
branch at `34968b5`. These are documentation and source findings; no
workflow was run to confirm them.

## Answer: yes, with one setting to add

The Action loads a repo's committed `.claude/skills/`, `.claude/agents/`,
`.claude/commands/`, `.claude/settings.json` (and its hooks) and `CLAUDE.md`
from the checkout:

- The Action runs Claude through the Agent SDK and passes
  `settingSources: ["user", "project", "local"]` unless `claude_args` has
  `--setting-sources` (`base-action/src/parse-sdk-options.ts`).
- The SDK's `project` source loads project `settings.json` and hooks from
  `<cwd>/.claude/`, plus skills, commands and subagents from `<cwd>` up to
  the repository root
  ([Use Claude Code features in the SDK](https://code.claude.com/docs/en/agent-sdk/claude-code-features#control-filesystem-settings-with-settingsources)).
- The Action's working directory is `$GITHUB_WORKSPACE`, where
  `actions/checkout` puts the repo (comment in `src/modes/tag/index.ts`).
- The Claude Code docs say so directly: for a skill in the repository's
  `.claude/skills/`, run `actions/checkout` before the Action step, then pass
  `/skill-name` as the `prompt`
  ([Claude Code GitHub Actions: Run a skill](https://code.claude.com/docs/en/github-actions#run-a-skill)).

The setting to add is permission to use the `Skill` tool. The tools reference
marks `Skill` as needing permission
([Tools reference](https://code.claude.com/docs/en/tools-reference)). The
Action's `@claude` mode runs with `--permission-mode acceptEdits` and a fixed
`--allowedTools` list that leaves `Skill` out, and a headless run denies
anything that would prompt (`src/modes/tag/index.ts`). Users on
[claude-code-action#1003](https://github.com/anthropics/claude-code-action/issues/1003)
report that project skills only ran once `Skill` was in `--allowedTools`. A
`prompt` that starts with `/name` runs the skill directly and doesn't need
this, but a skill Claude picks itself, or one skill invoking another, does.
The `Agent` tool needs no permission, so vendored subagents work as they are.

## Workflow configuration

```yaml
steps:
  - uses: actions/checkout@v6        # must come before the Action
    with:
      fetch-depth: 1
  - uses: anthropics/claude-code-action@v1
    with:
      anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
      # Omit `prompt` for @claude mode, or start it with a vendored skill:
      # prompt: "/review-pr ${{ github.event.pull_request.number }}"
      claude_args: |
        --allowedTools "Skill,Bash(git diff:*),Bash(gh pr view:*)"
```

- Add `Skill` to `--allowedTools`, alongside whatever tools the skills need.
  A skill's `allowed-tools` frontmatter pre-approves its own tools in the turn
  that invokes it. A `permissions.allow` entry of `Skill` in the committed
  `.claude/settings.json` works too, but it applies to every session, not just
  CI.
- Don't pass `--setting-sources`. If you must, include `project`.
- Don't install harness-kit through the `plugins` input. The snapshot is the
  harness; adding the plugin would load both copies.

## Pull requests run the base branch's harness

On a pull request, the Action restores `.claude/`, `CLAUDE.md`,
`CLAUDE.local.md`, `.mcp.json` and a few other config paths from the PR's
base branch before Claude starts. It keeps the PR's versions under
`.claude-pr/` for reading only
([the Action's security docs](https://github.com/anthropics/claude-code-action/blob/main/docs/security.md),
`src/github/operations/restore-config.ts`). For a vendored repo, this means:

- An update PR is reviewed by the snapshot already on the base branch. The
  new release's skills take effect in CI only after the PR merges.
- A PR that edits a vendored skill doesn't change what runs on that PR. The
  edit check in the verification command is still what catches the edit.
- `AGENTS.md` and `.harness/config.toml` are not restored, so the facts come
  from the PR head
  ([claude-code-action#1696](https://github.com/anthropics/claude-code-action/issues/1696)).
  A PR can change the verification command that a base-branch skill then
  runs. Review fact changes like code.
- Vendor the snapshot as real files. A symlink inside `.claude/` that points
  outside the restored paths (for example into `.agents/`) crashes the
  restore
  ([claude-code-action#1319](https://github.com/anthropics/claude-code-action/issues/1319)).
