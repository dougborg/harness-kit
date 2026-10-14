# Vendoring a Snapshot

`${CLAUDE_SKILL_DIR}/vendor-snapshot.sh` writes a pristine snapshot of harness-kit's
generic skills, agents, and hooks into a project (ADR 0001). It reads the
project's `.harness/config.toml` (keys in `${CLAUDE_SKILL_DIR}/project-facts.md`),
copies real files, never symlinks, and records what it wrote in
`.harness/lock.json`. It does no merging. Read this when a mode vendors or
re-vendors a project, checks that a snapshot is unedited, or explains what
the snapshot owns.

## Run it

```bash
${CLAUDE_SKILL_DIR}/vendor-snapshot.sh ${CLAUDE_PLUGIN_ROOT} .
```

The first argument is a harness-kit plugin root: the installed plugin, or a
release checkout (`git clone --depth 1 --branch vX.Y.Z
https://github.com/dougborg/harness-kit`). The snapshot takes that root's
version. The second is the project directory, which defaults to `.`. It needs
`python3` 3.11 or later and exits 1 with a message, writing nothing, when the
config names an unknown skill or agent or a vendored path holds a
project-local file.

## What it writes

| Path | From the plugin root |
| --- | --- |
| `.claude/skills/<skill>/` | `claude-skills/<skill>/` (the Claude projection) |
| `.claude/agents/<agent>.md` | `agents/<agent>.md` |
| `.agents/skills/<skill>/` | `skills/<area>/<skill>/`, flat by name, with `agents/openai.yaml` |
| `.agents/scripts/shared/<name>` | each `scripts/shared/` helper a vendored open-format skill names |
| `.codex/agents/<agent>.toml` | `.codex/agents/<agent>.toml` (generated Codex agents) |
| `.claude/hooks/harness-kit/<name>` | the `scripts/shared/` scripts the plugin's hooks run |
| `.claude/settings.json` | sets `"harness-kit@harness-kit": false` and adds the plugin's hook entries |
| `.harness/lock.json` | the record of all of the above |

The chosen set is the config's `skills` and `agents` plus `harness`, which is
always vendored. A name in `[forks.skills]` or `[forks.agents]` is the
project's own and is skipped. Other keys in `settings.json`, and its other
hook entries, are kept.

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
Anything else under `.claude/`, `.agents/`, or `.codex/` is project-local and
never touched. A re-run at the same version and config writes nothing.

```json
{
  "version": "1.0.0",
  "skills": {"commit": "harness-kit", "harness": "harness-kit"},
  "agents": {"verifier": "harness-kit"},
  "hooks": {"claude": {"Stop": [{"hooks": [{"type": "command", "command": "..."}]}]}},
  "files": {".claude/skills/commit/SKILL.md": "<sha256 hex>"}
}
```

- `version`: the plugin manifest's version the snapshot came from.
- `skills`, `agents`: each vendored name and its source, `harness-kit` or a
  third-party source string.
- `hooks.claude`: the entries added to `.claude/settings.json`, by event.
- `files`: each vendored file's SHA-256, which the edit check compares against.

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
