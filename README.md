# harness-kit

A self-improving agent harness for [Claude Code](https://code.claude.com), distributed as a plugin.

## What's included

**Meta-harness** (`/harness`) with 6 modes:

- `bootstrap` — Analyze your project, install relevant skills/agents, generate project-specific additions
- `update` — Pull latest upstream changes, smart-merge with local modifications
- `add` — Install skills from external plugin marketplaces
- `audit` — 10-step quality gate on your project's harness
- `retro` — Post-session gap identification (Type A/B/C/D classification)
- `hoist` — Propose upstream PRs for generic improvements

**14 skills:**

| Skill | Purpose |
| --- | --- |
| `/harness` | Meta-harness management |
| `/commit` | Conventional commits with quality gates |
| `/open-pr` | PR creation with CI polling and review monitoring |
| `/review-pr` | Structured PR review using 6-dimension code review |
| `/pr-comments` | Reply to PR review comments in thread context |
| `/rebase` | Rebase with conflict resolution and validation |
| `/code-reviewer` | 6-dimension code review reference |
| `/skill-writer` | Create well-structured skills with progressive disclosure |
| `/documentation-writer` | Write scannable, layered documentation |
| `/harness-builder` | Analyze codebases and recommend harness setup |
| `/feature-spec` | Write feature specifications before implementation |
| `/standup` | Generate daily standup from git history |
| `/ui-review` | Accessibility and UX audit (WCAG 2.1 AA) |
| `/svg-logo-designer` | Generate SVG logos |

**3 agents:**

| Agent | Model | Purpose |
| --- | --- | --- |
| `code-reviewer` | sonnet | 6D review: correctness, design, readability, performance, testing, security |
| `verifier` | haiku | Stack-agnostic validation runner |
| `harness-builder` | sonnet | Deep-read codebase and recommend harness |

**Architecture patterns reference** — 6 multi-agent coordination patterns (Pipeline, Fan-out/Fan-in, Expert Pool, Producer-Reviewer, Supervisor, Hierarchical Delegation).

## Install

```bash
/plugin marketplace add dougborg/harness-kit
/plugin install harness-kit@harness-kit
```

Then in your project:

```bash
/harness bootstrap
```

This analyzes your project, recommends which skills/agents to install, copies them to `.claude/`, generates project-specific additions, and creates a `.harness-lock.json` tracking provenance.

## How it works

1. **Plugin provides skills globally** — After install, all skills and agents are available in every project
2. **`/harness bootstrap` copies to your project** — Selected skills/agents go into `.claude/` and are committed to your repo
3. **Every repo is self-contained** — Anyone cloning your repo gets the full harness without needing the plugin
4. **`/harness update` syncs changes** — Smart-merges upstream updates, preserving local modifications
5. **`.harness-lock.json` tracks provenance** — Which files came from where, what's been locally modified

## Multi-source

You can install skills from multiple plugin marketplaces:

```bash
/harness add vercel-labs/agent-skills    # React/Next.js skills
/harness add pbakaus/impeccable          # Frontend design skills
```

The lock file tracks all sources.

## Philosophy

- **Quality over quantity** — 14 skills, not 150. Each one is well-structured with progressive disclosure.
- **Self-improving** — `/harness retro` identifies gaps after sessions; `/harness hoist` proposes upstream improvements.
- **Scripts over inline bash** — Shell logic is extracted to testable scripts, not inlined in skills.
- **Composition over duplication** — Project-local skills extend upstream skills with project-specific flavor.

## Releases

harness-kit uses [Release Please](https://github.com/googleapis/release-please) for automated semver releases driven by [Conventional Commits](https://www.conventionalcommits.org/).

- `feat:` commits bump the **minor** version
- `fix:` commits bump the **patch** version
- `feat!:` or `BREAKING CHANGE:` bump the **major** version
- `chore:`, `docs:`, `ci:`, `refactor:`, `test:` do not bump the version

After merging PRs to `main`, Release Please opens (or updates) a release PR with the proposed version bump and `CHANGELOG.md` entries. Merge that PR to cut a release — the git tag and GitHub Release are created automatically, and the bumped `version` in `.claude-plugin/plugin.json` signals installed clients to update their cached copy.

## License

Apache-2.0
