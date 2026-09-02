# harness-kit

A self-improving agent harness for
[Claude Code](https://code.claude.com) and
[Codex](https://developers.openai.com/codex), distributed with native plugin
packaging for both hosts.

## What's included

**Meta-harness** (`/harness`) with 6 modes:

- `bootstrap` — Analyze your project, install relevant skills/agents, generate project-specific additions
- `update` — Pull latest upstream changes, smart-merge with local modifications
- `add` — Install skills from external plugin marketplaces
- `audit` — 10-step quality gate on your project's harness
- `retro` — Post-session gap identification (Type A/B/C/D classification)
- `hoist` — Propose upstream PRs for generic improvements

**Selected skills:**

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
| `/agent-standup` | Reconcile ownership, handoffs, and merge order across agents and operators |
| `/groom` | Backlog grooming: theme buckets, PR train, stale flags, gaps |
| `/ui-review` | Accessibility and UX audit (WCAG 2.1 AA) |
| `/svg-logo-designer` | Generate SVG logos |

**4 agents**, provided as Claude Markdown definitions and Codex project TOML:

| Agent | Model | Purpose |
| --- | --- | --- |
| `code-reviewer` | sonnet | 6D review: correctness, design, readability, performance, testing, security |
| `verifier` | haiku | Stack-agnostic validation runner |
| `harness-builder` | sonnet | Deep-read codebase and recommend harness |
| `project-manager` | sonnet | Read-only backlog grooming: PR train, stale flags, gap analysis |

**Architecture patterns reference** — 6 multi-agent coordination patterns (Pipeline, Fan-out/Fan-in, Expert Pool, Producer-Reviewer, Supervisor, Hierarchical Delegation).

## Install for Claude Code

```bash
/plugin marketplace add dougborg/harness-kit
/plugin install harness-kit@harness-kit
```

Then in your project:

```bash
/harness bootstrap
```

This analyzes your project, recommends which skills/agents to install, copies them to `.claude/`, generates project-specific additions, and creates a `.harness-lock.json` tracking provenance.

## Install for Codex CLI

```bash
codex plugin marketplace add dougborg/harness-kit
codex plugin add harness-kit@harness-kit
```

Start a new Codex session after installation. Invoke skills with `$`, for
example `$harness audit` or `$code-reviewer`. Claude Code uses `/harness audit`
and `/code-reviewer`.

Codex plugins are available in the CLI but not loaded directly by the IDE
extension. Run `$harness bootstrap` once to install repository-local
`AGENTS.md`, `.agents/skills/`, and `.codex/agents/` content for both CLI and
IDE use. Bootstrap installs both Claude and Codex destinations by default.

The `budget` skill is Claude Code-only because it reads Claude's local usage
panel. Codex will not invoke it implicitly and reports it unsupported when
selected explicitly.

## How it works

1. **Plugins provide skills globally** — each host loads its native manifest
2. **`harness bootstrap` copies to your project** — selected skills and agents go into `.claude/`, `.agents/`, and `.codex/` and are committed
3. **Every repo is self-contained** — Anyone cloning your repo gets the full harness without needing the plugin
4. **`harness update` syncs changes** — smart-merges each host destination, preserving local modifications
5. **`.harness-lock.json` tracks provenance** — Which files came from where, what's been locally modified

## Multi-source

You can install skills from multiple plugin marketplaces:

```bash
/harness add vercel-labs/agent-skills    # React/Next.js skills
/harness add pbakaus/impeccable          # Frontend design skills
```

The lock file tracks all sources.

## Philosophy

- **Quality over quantity** — a focused catalog, not a sprawling one. Each skill is well-structured with progressive disclosure.
- **Self-improving** — `/harness retro` identifies gaps after sessions; `/harness hoist` proposes upstream improvements.
- **Scripts over inline bash** — Shell logic is extracted to testable scripts, not inlined in skills.
- **Composition over duplication** — Project-local skills extend upstream skills with project-specific flavor.

## Compatibility model

`skills/` is the canonical open-format catalog used by Codex. Claude Code
requires additional invocation and permission frontmatter, so
`scripts/generate-claude-skills.sh` produces the checked-in `claude-skills/`
projection. Never edit that projection directly; `just check` fails if it
drifts.

Claude `allowed-tools` entries do not restrict Codex. Codex applies its own
sandbox and approval policy, and read-only Codex subagents declare
`sandbox_mode = "read-only"` explicitly.

## Releases

harness-kit uses [Release Please](https://github.com/googleapis/release-please) for automated semver releases driven by [Conventional Commits](https://www.conventionalcommits.org/).

- `feat:` commits bump the **minor** version
- `fix:` commits bump the **patch** version
- `feat!:` or `BREAKING CHANGE:` bump the **major** version
- `chore:`, `docs:`, `ci:`, `refactor:`, `test:` do not bump the version

After merging PRs to `main`, Release Please opens (or updates) a release PR with the proposed version bump and `CHANGELOG.md` entries. Merge that PR to cut a release — the git tag and GitHub Release are created automatically, and the bumped `version` in `.claude-plugin/plugin.json` signals installed clients to update their cached copy.

### GitHub App token for release PRs

The `release-please.yml` workflow does not use the default `GITHUB_TOKEN` — PRs authored with it never trigger downstream `pull_request` workflows, so required CI checks would never run on release PRs. Instead, it mints an installation token from a repo-owned GitHub App via [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token).

One-time setup (repo owner):

1. Create a GitHub App (e.g. `harness-kit-release-bot`) under your account: <https://github.com/settings/apps/new>. Disable webhooks. Repository permissions: **Contents: Read and write**, **Pull requests: Read and write**, **Metadata: Read-only**.
2. Install the App on this repository (App settings → Install App).
3. Generate a private key for the App (App settings → Private keys) and note the App ID.
4. Store both in the repo:

   ```bash
   gh variable set RELEASE_PLEASE_APP_ID --body <app-id>
   gh secret set RELEASE_PLEASE_APP_PRIVATE_KEY < private-key.pem
   ```

Until these are set, the Release Please workflow fails loudly at the token-mint step on every push to `main` — it never silently falls back to `GITHUB_TOKEN`.

## License

Apache-2.0
