# Vendoring a Snapshot

`${CLAUDE_SKILL_DIR}/vendor-snapshot.sh` writes a pristine snapshot of harness-kit's
generic skills, agents, and hooks into a project (ADR 0001). It reads the
project's `.harness/config.toml` (keys in `${CLAUDE_SKILL_DIR}/project-facts.md`),
copies real files, never symlinks, and records what it wrote in
`.harness/lock.json`. It does no merging. Read this when a mode vendors or
re-vendors a project, updates it to a new release, checks that a snapshot is
unedited, explains what the snapshot owns, or sets up or debugs the scheduled
update PR.

- [Run it](#run-it)
- [What it writes](#what-it-writes)
- [What the snapshot owns](#what-the-snapshot-owns)
- [Updating to a new release](#updating-to-a-new-release)
- [The update workflow](#the-update-workflow)
- [Third-party skills](#third-party-skills)
- [The edit check](#the-edit-check)

## Run it

```bash
${CLAUDE_SKILL_DIR}/vendor-snapshot.sh [--json] [--discard-edits] ${CLAUDE_PLUGIN_ROOT} .
```

The first argument is a harness-kit plugin root: the installed plugin, or a
release checkout (`git clone --depth 1 --branch vX.Y.Z
https://github.com/dougborg/harness-kit`). The snapshot takes that root's
version. The second is the project directory, which defaults to `.`. It needs
`python3` 3.11 or later and exits 1 with a message, writing nothing, when the
config names an unknown skill or agent or a vendored path holds a
project-local file. It prints a Markdown report, or the same report as JSON
with `--json` (see [Updating to a new release](#updating-to-a-new-release)).

When a lock exists, it first runs [the edit check](#the-edit-check) against
it. If the current snapshot was changed (a vendored file edited, added, or
deleted, or a vendored hook entry changed), it prints the check's findings and
exits 1 without writing anything: move the project-specific part into facts,
or declare a fork, and run it again. `--discard-edits` skips the check and
overwrites those changes with the pristine snapshot; use it only when the
changes are meant to be thrown away.

Each file is written to a temporary file beside it and renamed into place,
so a file is never left half-written, and the script refuses to write through
a directory inside the project that is a symlink. A run that is interrupted
part-way (killed, or out of disk) can still leave the snapshot mixed: some
files from the new release, the lock still at the old one. The edit check
then reports the new files as edited. Run the same command again with
`--discard-edits` to re-vendor cleanly.

## What it writes

| Path | From the plugin root |
| --- | --- |
| `.claude/skills/<skill>/` | `claude-skills/<skill>/` (the Claude projection) |
| `.claude/agents/<agent>.md` | `agents/<agent>.md` |
| `.agents/skills/<skill>/` | `skills/<area>/<skill>/`, flat by name, with `agents/openai.yaml` |
| `.agents/scripts/shared/<name>` | each `scripts/shared/` helper a vendored open-format skill names |
| `.codex/agents/<agent>.toml` | `.codex/agents/<agent>.toml` (generated Codex agents) |
| `.claude/hooks/harness-kit/<name>` | the `scripts/shared/` scripts the plugin's hooks run |
| `.github/workflows/harness-update.yml` | the harness skill's `harness-update.yml` ([The update workflow](#the-update-workflow)) |
| `.claude/settings.json` | sets `"harness-kit@harness-kit": false` and adds the plugin's hook entries |
| `.harness/lock.json` | the record of all of the above |

The chosen set is the config's `skills` and `agents` plus `harness`, which is
always vendored. A name in `[forks.skills]` or `[forks.agents]` is the
project's own: its files are never written or removed, even ones an earlier
snapshot vendored, and the shared scripts it names stay vendored. Other keys
in `settings.json`, and its other hook entries, are kept.

Hooks are vendored because disabling the plugin also disables its
`hooks/hooks.json`. With the plugin off, `${CLAUDE_PLUGIN_ROOT}` is unset, so
the script rewrites plugin-root paths to `scripts/shared/` files: in hook
commands and skill text, `${CLAUDE_PLUGIN_ROOT}/scripts/shared/<name>` becomes
`${CLAUDE_PROJECT_DIR}/.claude/hooks/harness-kit/<name>`, and in open-format
skills the plugin-root form becomes the shared-script directory. The hook
scripts live under `.claude/` so a pull request run by the GitHub Action uses
the base branch's copies (`${CLAUDE_SKILL_DIR}/github-action.md`). The plugin ships no
Codex hook config, so none is written.

## What the snapshot owns

The lock lists every file the script wrote, and only those files are the
snapshot's. On a re-run it overwrites them, removes the ones the new set no
longer includes, and replaces the hook entries it added last time, in place.
Anything else under `.claude/`, `.agents/`, `.codex/`, or `.github/` is
project-local and never touched. A re-run at the same version and config writes nothing.

```json
{
  "version": "1.0.0",
  "skills": {"commit": "harness-kit", "harness": "harness-kit"},
  "agents": {"verifier": "harness-kit"},
  "hooks": {"claude": {"Stop": [{"hooks": [{"type": "command", "command": "..."}]}]}},
  "available": {"skills": ["commit", "harness", "tdd"], "agents": ["verifier"]},
  "removed": {"skills": [], "agents": []},
  "files": {".claude/skills/commit/SKILL.md": "<sha256 hex>"}
}
```

- `version`: the plugin manifest's version the snapshot came from.
- `skills`, `agents`: each vendored name and its source, `harness-kit` or a
  third-party source string.
- `hooks.claude`: the entries added to `.claude/settings.json`, by event.
- `available`: every skill and agent that release ships, so the next update
  can tell which are new.
- `removed`: chosen names the release no longer ships, still listed in the
  config.
- `files`: each vendored file's SHA-256, which the edit check compares against.

## Updating to a new release

Updating is the same command against a newer plugin root. The snapshot is
replaced wholesale: every vendored file is rewritten from the new release,
files the release dropped are removed, and the lock is rewritten to the new
version. Three cases are reported rather than acted on:

- **Removed upstream.** A chosen skill or agent the last snapshot had and the
  release no longer ships is dropped from the snapshot and listed. The config
  is not edited; the name is reported (and kept in the lock's `removed`) on
  every run until someone removes it from the config. A name no snapshot ever
  had is still an unknown name, and the script exits 1.
- **New upstream.** A skill or agent the release ships that the last
  snapshot's catalog lacked, and the config doesn't name, is offered, not
  installed. The first snapshot offers nothing.
- **Forks.** Each fork is left byte-for-byte unchanged, and the report lists
  which of its files changed upstream between the version it was forked from
  and the new release, as project paths (`.claude/skills/<skill>/...`) with
  `A`, `M`, or `D`. The forked-from version is read from tag `v<version>` in
  the plugin root, so the comparison needs a git checkout holding that tag; a
  shallow release clone has only its own tag. When the plugin root isn't a
  git checkout, or the tag is missing, the fork is reported as not compared,
  with the reason and the `git fetch` that adds the tag. A fork whose name
  the release no longer ships is reported as removed upstream.

The text report is Markdown meant for a pull request body: a summary line,
then `## Removed upstream`, `## New upstream`, and `## Forks` sections, each
printed only when it has entries. For example:

```markdown
vendored harness-kit 1.1.0 (from 1.0.0): 12 skills, 2 agents, 230 files

## New upstream

Not installed; add them to `.harness/config.toml` to vendor them:

- skill `wayfinder`

## Forks

Left unchanged. Upstream changes since each was forked:

- skill `review-pr` (forked from 1.0.0): 1 file changed upstream
  - M `.agents/skills/review-pr/SKILL.md`
- agent `verifier` (forked from 1.0.0): no upstream changes
```

`--json` prints the same facts for a workflow to read: `from` (the previous
version, or `null`), `to`, `skills`, `agents`, `files` (a count), `removed`
and `new` (each `{"skills": [...], "agents": [...]}`), and `forks`, a list of
`{kind, name, forked_from, status, changes}` where `status` is `changed`,
`unchanged`, `removed`, or `not-compared` (with a `reason`), and `changes` is
a list of `{status, path}`.

## The update workflow

The snapshot includes `.github/workflows/harness-update.yml`, so every
vendored repo updates itself through a pull request that its own CI and
review gate. It runs weekly and on `workflow_dispatch`, on the default branch
only, and calls the vendored `.claude/skills/harness/harness-update.sh`,
which:

1. Resolves the upstream repository: the `HARNESS_UPSTREAM` repository
   variable, then `.claude/harness-upstream`, then `dougborg/harness-kit`.
2. Reads the upstream's latest release (`gh api repos/<upstream>/releases/latest`)
   and stops, writing nothing, unless it is newer than the lock's `version`.
   Only `vX.Y.Z` tags are followed: a pre-release or build tag such as
   `v1.2.0-rc.1` fails the job with a message rather than being compared.
3. Shallow-clones the release tag, fetches the `v<version>` tag of each fork
   in the config so the fork report can compare it, and runs that release's
   `vendor-snapshot.sh`. An edited snapshot fails here, as it would locally.
   The job also fails when the version the release vendored isn't its tag's
   (a manifest that doesn't match its tag), and exits 0 without a commit when
   vendoring changed nothing.
4. Runs the diff guard (below).
5. Commits to the branch `harness-kit/update`, force-pushes it, and opens a
   pull request, or edits the open one, so there is only ever one. The body
   links the release notes, includes them (with each `@` followed by a
   zero-width joiner, so the notes mention no one), and ends with the
   update's Markdown report (removed, new, and forks). A run whose result
   matches the branch already pushed doesn't push again.

**The diff guard.** The update PR changes only snapshot-owned paths: files the
old or new lock lists, `.harness/lock.json`, and the hook entries in
`.claude/settings.json`. If anything else changed, the job lists the paths and
fails without pushing. A pull request can change `.harness/config.toml`,
whose `verification_command` the base branch's skills then run
(`${CLAUDE_SKILL_DIR}/github-action.md`), so an update PR never touches the config or
`AGENTS.md`; review any PR that does like code.

It uses only `GITHUB_TOKEN`, with `contents: write` and
`pull-requests: write`, which has three consequences:

- The repository must allow it: Settings > Actions > General > "Allow GitHub
  Actions to create and approve pull requests".
- GitHub doesn't start `pull_request` workflows for a PR pushed with
  `GITHUB_TOKEN`. Close and reopen the PR to run CI; the PR body says so.
- `GITHUB_TOKEN` can't push a change to a workflow file. The workflow is a
  thin wrapper so it rarely changes; when a release does change it, the job
  fails and says so, and someone runs the update locally (the command in
  [Run it](#run-it), from a clone of the release tag) and opens the PR.

The workflow is snapshot-owned, so the edit check fails if it is edited. To
follow a fork of harness-kit, set `HARNESS_UPSTREAM` rather than editing it.
A release must be published as a GitHub release whose tag is `v<version>`;
a private upstream needs a token this workflow doesn't have.

## Third-party skills

A skill from another repository is listed in `skills` and given a source in
`[sources.skills]` (format in `${CLAUDE_SKILL_DIR}/project-facts.md`). Its lock entry
records that source in place of `harness-kit`. Fetching sources isn't
implemented yet: a chosen skill with a source makes the script exit 1 and
name it, and a source must be for a name in `skills`.

## The edit check

`${CLAUDE_SKILL_DIR}/check-snapshot.sh [project-dir]` compares the project with
`.harness/lock.json` and fails on any change to the snapshot, naming each
file and the fix: move the project-specific part into facts
(`.harness/config.toml` or the `## Project facts` section of `AGENTS.md`), or
declare a fork. It reports:

- `edited:` a vendored file whose SHA-256 differs from the lock, or that was
  replaced by a symlink.
- `deleted:` a vendored file that is gone.
- `added:` a file in a vendored skill's directory that the lock doesn't list.
- `hook:` a vendored hook entry edited or removed in `.claude/settings.json`.

Skills and agents named in `[forks.skills]` or `[forks.agents]` pass, even
before the next vendoring run drops them from the lock. Project-local files,
other hook entries, the config, and `AGENTS.md` are never checked. It needs
`python3`, and 3.11 or later when the config exists.

| Exit | Meaning |
| --- | --- |
| 0 | The snapshot is unedited, or there is no lock: not a vendored project, nothing to check |
| 1 | A vendored file or hook entry changed, or the lock, config, or settings can't be parsed |
| 2 | Bad usage |

It runs as part of the project's gate without a config change.
`discover-verification-cmd.sh` prints
`.claude/skills/harness/check-snapshot.sh && <command>` whenever
`.harness/lock.json` exists (the `.agents/skills/harness/` copy when the
Claude tree lacks one), so every skill that runs the discovered gate (commit,
open-pr, review-pr, rebase) and the verifier agent run the check first. A
project without a lock gets the same output as before. A lock with no
vendored check script makes discovery exit 1. A CI workflow that runs the
gate command directly, rather than the discovered one, adds the check itself.

Inside the GitHub Action, a pull request runs the base branch's `.claude/`
against the PR's lock (`${CLAUDE_SKILL_DIR}/github-action.md`), so the check reports
an update PR's new files as edited there. Run it in the project's own CI.
