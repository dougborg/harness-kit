# harness-kit

A self-improving agent harness for
[Claude Code](https://code.claude.com) and
[Codex](https://developers.openai.com/codex), distributed with native plugin
packaging for both hosts. [`SCOPE.md`](SCOPE.md) says what it takes on and
what it has already decided against.

## What's included

**Meta-harness** (`/harness`) with 6 modes:

- `bootstrap` — Analyze your project, install relevant skills/agents, generate project-specific additions
- `update` — Pull latest upstream changes, smart-merge with local modifications
- `add` — Install skills from external plugin marketplaces
- `audit` — 10-step quality gate on your project's harness
- `retro` — Post-session environment audit and gap identification (Type A–E classification)
- `hoist` — Propose upstream PRs for generic improvements

**Selected skills:**

| Skill | Purpose |
| --- | --- |
| `/ask-harness` | Find which skill or flow fits your situation |
| `/handoff` | Write a handoff document for another session, host, or person |
| `/harness` | Meta-harness management |
| `/grill-me` | Relentless interview to sharpen a plan, a round of questions at a time |
| `/grill-with-docs` | The same interview, also maintaining `GLOSSARY.md` and ADRs |
| `/commit` | Conventional commits with quality gates |
| `/open-pr` | PR creation with CI polling and review monitoring |
| `/review-pr` | PR review with a standards pass and a spec pass, or work through review feedback |
| `/pr-comments` | Reply to PR review comments in thread context |
| `/rebase` | Rebase with conflict resolution and validation |
| `/code-reviewer` | Standards review: six dimensions, documented standards, smells, complexity |
| `/skill-writer` | Create well-structured skills with progressive disclosure |
| `/documentation-writer` | Write scannable, layered documentation |
| `/harness-builder` | Analyze codebases and recommend harness setup |
| `/to-spec` | Turn the conversation into a spec issue |
| `/wayfinder` | Plan work too big for one session as a map of decision tickets |
| `/implement` | Build a ticket test-first, through to an open PR |
| `/implement-spec` | Build a spec's tickets in parallel subagents onto one integration branch |
| `/to-tickets` | Split a spec into tracer-bullet sub-issues with blocking links |
| `/standup` | Generate daily standup from git history |
| `/agent-standup` | Reconcile ownership, handoffs, and merge order across agents and operators |
| `/triage` | Move incoming issues through triage states to agent-ready briefs |
| `/groom` | Backlog grooming: theme buckets, PR train, stale flags, gaps |
| `/ui-review` | Accessibility and UX audit (WCAG 2.1 AA) |
| `/svg-logo-designer` | Generate SVG logos |
| `/adhd-mode` | Action-first responses for a reader with ADHD; on Claude Code also the `harness-kit:adhd` output style |
| `/teach` | Learn a topic over several sessions: lessons, references, and learning records |
| `/loop-me` | Experimental: spec the recurring workflows worth delegating |

**4 agents**, provided as Claude Markdown definitions and Codex project TOML:

| Agent | Model | Purpose |
| --- | --- | --- |
| `code-reviewer` | sonnet | Standards pass (six dimensions, documented standards, smells, complexity) and spec pass |
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

This analyzes your project, writes its facts (starting with the verification
command) and any project-specific skills and agents, and vendors the generic
skills and agents you choose as a snapshot in `.claude/`, `.agents/`, and
`.codex/`. Commit the result; the repo then works without the plugin.

Upgrading a project bootstrapped before 2.0.0 (one with a
`.harness-lock.json`): run `/harness migrate` once (`$harness migrate` in
Codex). It turns edited copies into facts or forks and vendors the snapshot.

## Install for Codex CLI

```bash
codex plugin marketplace add dougborg/harness-kit
codex plugin add harness-kit@harness-kit
```

Start a new Codex session after installation. Invoke skills with `$`, for
example `$harness audit` or `$code-reviewer`. Claude Code uses `/harness audit`
and `/code-reviewer`.

Codex plugins are available in the CLI but not loaded directly by the IDE
extension. Run `$harness bootstrap` once to vendor repository-local
`AGENTS.md`, `.agents/skills/`, and `.codex/agents/` content for both CLI and
IDE use. Bootstrap vendors both Claude and Codex destinations by default.

Each skill's `agents/openai.yaml` declares whether the agent may start it on
its own. User-invoked skills (such as `/groom`, `/rebase`, `/standup`) run only
when you type them, on both hosts. The `budget` skill is Claude Code-only
because it reads Claude's local usage panel. Codex will not invoke it
implicitly and reports it unsupported when selected explicitly.

## How it works

Each project carries a vendored snapshot of harness-kit's generic skills and
agents that nobody edits, and customizes them through facts. The reasons and
the rejected alternatives are in
[ADR 0001](docs/adr/0001-vendored-harness-snapshots.md).

1. **The snapshot is committed.** Bootstrap vendors the chosen skills, agents,
   and hooks into `.claude/`, `.agents/`, and `.codex/`, and sets
   `"harness-kit@harness-kit": false` in `.claude/settings.json` so only the
   snapshot loads. Collaborators, cloud sessions, CI, and the Codex IDE
   extension get the harness with no install.
2. **Facts say what is specific to the project.** `.harness/config.toml`
   lists the chosen skills and holds machine-read keys such as
   `verification_command`; prose facts go in a `## Project facts` section of
   `AGENTS.md`. Generic skills read both.
3. **An edit check keeps the snapshot pristine.** `.harness/lock.json` records
   the snapshot's version and a hash for every file, and the verification
   command fails when a vendored file changes, naming the fix.
4. **A fork is the escape hatch.** When facts can't express a need, the
   project declares a fork in the config and owns that skill or agent
   outright. Updates leave it alone and report what changed upstream since.
5. **Update PRs keep every project on one version.** A scheduled workflow
   re-vendors the snapshot on each release and opens a PR, which goes through
   the project's own CI and review. `harness update` does the same by hand.
6. **Lessons go upstream.** `harness retro` sends a project lesson to facts or
   a project-local skill, and a generic one upstream as a hoist PR, which
   returns to every project in the next update PR.

## Third-party skills

`harness add <repo>` adds skills from another repository to the snapshot,
recorded with their source in the config's `[sources.skills]` and covered by
the same lock, edit check, and forks:

```bash
/harness add anthropics/skills
```

Fetching third-party sources is not implemented yet: the vendoring script
validates and records a source, then stops with an error naming the skill.

## Philosophy

- **Quality over quantity** — a focused catalog, not a sprawling one. Each skill is well-structured with progressive disclosure.
- **Self-improving** — `/harness retro` identifies gaps after sessions; `/harness hoist` proposes upstream improvements.
- **Scripts over inline bash** — Shell logic is extracted to testable scripts, not inlined in skills.
- **Facts over forks** — projects shape generic skills by stating facts the skills read, not by editing copies. Project-local skills add workflows upstream doesn't have.

## Compatibility model

`skills/` is the canonical open-format catalog used by Codex, grouped into
topic areas (`skills/<area>/<skill>/`); Codex discovers skills recursively,
and the generator flattens them for Claude, so invocation names don't depend
on the area. Claude Code
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

1. Create a GitHub App (e.g. `harness-kit-release-bot`) under your account: <https://github.com/settings/apps/new>. Disable webhooks. Repository permissions: **Contents: Read and write**, **Pull requests: Read and write**, **Issues: Read and write** (release-please's autorelease labels), **Metadata: Read-only**. The workflow scopes each minted token to exactly those write permissions.
2. Install the App on this repository (App settings → Install App).
3. Generate a private key for the App (App settings → Private keys) and note the App ID.
4. Store both in the repo:

   ```bash
   gh variable set RELEASE_PLEASE_APP_ID --body <app-id>
   gh secret set RELEASE_PLEASE_APP_PRIVATE_KEY < private-key.pem
   ```

Until these are set, the Release Please workflow fails loudly at its credential check, before the token-mint step, on every push to `main` — it never silently falls back to `GITHUB_TOKEN`.

## License

Apache-2.0
