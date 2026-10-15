# Vendoring a Snapshot

`<skill-dir>/vendor-snapshot.sh` writes a pristine snapshot of harness-kit's
generic skills, agents, and hooks into a project (ADR 0001). It reads the
project's `.harness/config.toml` (keys in `<skill-dir>/project-facts.md`),
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
<skill-dir>/vendor-snapshot.sh [--json] [--discard-edits] <plugin-root> .
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
| `.claude/skills/<skill>/` and `.agents/skills/<skill>/` | for a sourced skill, its directory in its own repository ([Third-party skills](#third-party-skills)) |
| `.agents/scripts/shared/<name>` | each `scripts/shared/` helper a vendored open-format skill names |
| `.codex/agents/<agent>.toml` | `.codex/agents/<agent>.toml` (generated Codex agents) |
| `.claude/hooks/harness-kit/<name>` | the `scripts/shared/` scripts the plugin's hooks run |
| `.github/workflows/harness-update.yml` | the harness skill's `harness-update.yml`, its `cron` set from `[update] schedule` when the config has one ([The update workflow](#the-update-workflow)) |
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
the base branch's copies (`<skill-dir>/github-action.md`). The plugin ships no
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
- `source_commits`: for each third-party skill, the commit its ref resolved
  to. Absent when there are none.
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
review gate. It runs weekly (or on `[update] schedule`) and on
`workflow_dispatch`, on the default branch only, and calls the vendored
`.claude/skills/harness/harness-update.sh`, which:

1. Resolves the upstream repository with
   `<shared-scripts-dir>/resolve-upstream.sh`, the lookup the `harness-issue`
   skill also uses: the `HARNESS_UPSTREAM` repository variable, then
   `.claude/harness-upstream`, then `dougborg/harness-kit`. (The script also
   reads the old `.harness-lock.json`, but only in a project without
   `.harness/lock.json`, so never here.)
2. Reads the upstream's latest release (`gh api repos/<upstream>/releases/latest`)
   and stops, writing nothing, unless it is newer than the lock's `version`.
   Only `vX.Y.Z` tags are followed: a pre-release or build tag such as
   `v1.2.0-rc.1` fails the job with a message rather than being compared.
3. Shallow-clones the release tag and fails, writing nothing, when the
   release's plugin manifest isn't the tag's version. Then it fetches the
   `v<version>` tag of each fork in the config so the fork report can compare
   it, and runs that release's `vendor-snapshot.sh`. An edited snapshot fails
   here, as it would locally. The job exits 0 without a commit when
   vendoring changed nothing.
4. Runs the diff guard (below).
5. Commits to the branch `harness-kit/update`, force-pushes it, and opens a
   pull request, or edits the open one, so there is only ever one. The body
   links the release notes, includes them and the update's Markdown report
   (removed, new, and forks) with each `@` followed by a zero-width joiner,
   so neither mentions anyone. A `## Hook changes` section lists each hook
   entry the update adds to or removes from `.claude/settings.json`, with its
   event, matcher, and commands shown exactly in code, since they run on
   every session; it says so when there are none. A run whose result matches
   the branch already pushed doesn't push again. When the snapshot is
   already current, the job exits without touching an open update PR.

**The diff guard.** The update PR changes only snapshot-owned paths: files the
old or new lock lists, `.harness/lock.json`, and the hook entries in
`.claude/settings.json`. If anything else changed, the job lists the paths and
fails without pushing. A pull request can change `.harness/config.toml`,
whose `verification_command` the base branch's skills then run
(`<skill-dir>/github-action.md`), so an update PR never touches the config or
`AGENTS.md`; review any PR that does like code.

By default it uses only `GITHUB_TOKEN`, with `contents: write` and
`pull-requests: write`, which has three consequences (the
[update token](#the-optional-update-token) removes the last two):

- The repository must allow it: Settings > Actions > General > "Allow GitHub
  Actions to create and approve pull requests".
- GitHub doesn't start `pull_request` workflows for a PR pushed with
  `GITHUB_TOKEN`. Close and reopen the PR to run CI; the PR body says so.
- `GITHUB_TOKEN` can't push a change to a workflow file. The workflow is a
  thin wrapper so it rarely changes. When a release does change it, the job
  fails without pushing, and prints, in its log and its job summary, the
  release's tag, a link to this section at that tag, and the commands to run
  from a clean checkout of the default branch:

  ```bash
  release=$(mktemp -d)
  git clone --depth 1 --branch vX.Y.Z https://github.com/dougborg/harness-kit "$release"
  "$release"/skills/meta/harness/vendor-snapshot.sh "$release" .
  ```

  Commit the result on a branch and open the PR yourself.

The workflow is snapshot-owned, so the edit check fails if it is edited. To
follow a fork of harness-kit, set `HARNESS_UPSTREAM` rather than editing it.
To change when it runs, set `[update] schedule` in `.harness/config.toml`
(`<skill-dir>/project-facts.md`), re-run `vendor-snapshot.sh` against the
plugin root at the snapshot's current version, and commit the workflow, lock,
and config together. The script writes the key into the workflow's `cron`
line and the lock hashes the result, so the edit check passes, and every
later update keeps the schedule. The default is `23 7 * * 1`.
A release must be published as a GitHub release whose tag is `v<version>`;
a private upstream needs a token this workflow doesn't have.

**Choosing the upstream is a code-execution trust decision.** The job runs the
upstream release's own `vendor-snapshot.sh` in a job that can push to the
repository, and the PR it opens changes skills, agents, and hook commands that
run in every later session. Set `HARNESS_UPSTREAM` or `.claude/harness-upstream`
only to a repository whose releases you would merge as code, and review a pull
request that changes the file like code. `.claude/harness-upstream`, one line
`owner/repo`, is the one file bootstrap and migrate write. It lives under
`.claude/`, which the GitHub Action restores from the base branch on a pull
request, so a PR can't redirect the skills the Action runs on it;
`.harness/config.toml` isn't restored, which is why the upstream is not a
fact there. The update PR can't change the file either, since the diff guard
allows only snapshot-owned paths. The checkout
keeps no credentials (`persist-credentials: false`), the release's script runs
with `GH_TOKEN` removed from its environment, and the token reaches git only on
the fetch and push of the update branch. That keeps the token out of
`.git/config` and the release's environment; it isn't a sandbox, since the
release runs in the same job.

### The optional update token

A repository secret named `HARNESS_UPDATE_TOKEN` lets the job deliver a
release that changes the workflow. Make it a fine-grained personal access
token with access to this repository only and the repository permissions
Contents, Pull requests, and Workflows set to read and write. With it, the job
uses the token, in place of `GITHUB_TOKEN`, for exactly two things: the fetch
and force-push of `harness-kit/update`, and the `gh pr` calls that find,
open, or edit the PR. The release is still read with `GITHUB_TOKEN`, and the
diff guard still allows only snapshot-owned paths, so the only workflow it can
change is `harness-update.yml`. Without the secret, nothing changes.

The token stays out of the release's code the same way `GITHUB_TOKEN` does,
and more strictly: `harness-update.sh` copies it into a shell variable and
unsets it before running anything, so no process it starts, the release's
`vendor-snapshot.sh` included, has it in its environment. It reaches git
only as an `http.extraheader` passed through `GIT_CONFIG_*` on the commands
that talk to origin, masked in the log, and `gh` only on the PR calls. As
with `GITHUB_TOKEN`, that isn't a sandbox: the release runs in the same job,
as the same user.

A GitHub App's installation tokens expire within an hour, so one can't be
stored as this secret, and the vendored workflow has no step that mints one.
The PR is opened as the token's owner, who therefore can't approve it;
someone else reviews it.

## Third-party skills

A skill from another repository is listed in `skills` and given a source in
`[sources.skills]` as `"owner/repo@ref:path"` (format in
`<skill-dir>/project-facts.md`); a source must be for a name in `skills`. On
every run the script fetches that ref, shallow, from
`https://github.com/<owner>/<repo>` and reads the files under `path` from git
objects; nothing is checked out and none of it runs. The directory must hold
a `SKILL.md` and only regular files: a symlink or submodule in it is refused.

Third-party repositories ship one open-format tree, so the same files go to
both `.claude/skills/<skill>/` and `.agents/skills/<skill>/`, byte for byte.
Unlike harness-kit's own skills, nothing is rewritten and no shared helper is
added: the skill's paths belong to its repository, not this plugin. Its lock
entry records the source string in place of `harness-kit`, and
`source_commits` the commit the ref resolved to. From there it is a vendored
skill like any other: the edit check covers its files, a fork in
`[forks.skills]` is left alone (the report doesn't compare it with harness-kit;
compare it with its source by hand), and dropping it from `skills` removes it.

A malformed source, an unreachable repository or ref, or a path that isn't a
skill directory makes the script exit 1 before it writes anything. The fetch
never prompts for credentials. It uses the git transports `https`, `ssh` (so a
`url.insteadOf` rewrite for a private repository still works) and `file`
only.

The report lists each source and its commit, under "Third-party sources"
(`sources` in the JSON report, with `commit`, the lock's `previous` commit,
and `pinned`). It says when the commit moved since the last run.

**Adding a source is a trust decision.** A skill is instructions an agent
follows and often scripts it runs, and harness-kit has reviewed none of it.
Pin each source to a full 40-character commit SHA. A branch or tag is
accepted, since every snapshot change still lands through a reviewed commit or
update PR, but it moves without anyone choosing to: the scheduled update would
bring in whatever the branch holds that day. The report marks such a source as
not pinned and names the move, so a reviewer sees it; bump a SHA pin
deliberately, after reading the diff between the two commits.

`HARNESS_SOURCE_BASE_URL` replaces `https://github.com` as the base, for a
mirror or a directory of local repositories (`file:///path/to/repos`, as the
tests use). Only `https://` and `file://` bases are accepted. It is read from
the environment, never from the config, so the config can't point a fetch at
another host.

## The edit check

`<skill-dir>/check-snapshot.sh [project-dir]` compares the project with
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
other hook entries, the config, and `AGENTS.md` are never checked. That
leaves one accepted gap: the GitHub Action doesn't restore the facts from the
base branch, so a PR that changes `verification_command` changes what CI
runs on it, and the check has no base to compare against. Review fact
changes like code (`<skill-dir>/github-action.md`, "Pull requests run the
base branch's harness"). It needs
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
against the PR's lock (`<skill-dir>/github-action.md`), so the check reports
an update PR's new files as edited there. Run it in the project's own CI.
