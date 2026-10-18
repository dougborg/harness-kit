# Migrate Mode

Moves a project from copy-and-edit (`.harness-lock.json`, schema v1 or v2) to
a vendored snapshot (ADR 0001). Each edit made to an upstream copy becomes a
fact or a declared fork, confirmed by the maintainer. Untouched copies are
dropped, or come back fresh when the project keeps that skill. Project-local
files stay. Migrate runs once per project; afterwards update and the edit
check take over.

- [1. Get a plugin checkout](#1-get-a-plugin-checkout)
- [2. Take the inventory](#2-take-the-inventory)
- [3. Choose the set](#3-choose-the-set)
- [4. Turn each change into a fact or a fork](#4-turn-each-change-into-a-fact-or-a-fork)
- [5. Place everything else](#5-place-everything-else)
- [6. Preview, then confirm](#6-preview-then-confirm)
- [7. Apply](#7-apply)
- [8. Verify and report](#8-verify-and-report)

## 1. Get a plugin checkout

Migrate compares each copy with the release it came from, the lock's
`sources.harness-kit.version`, and vendors the release you are moving to. One
full clone serves both: it holds every tag, and its working tree is the
target release.

```bash
git clone https://github.com/dougborg/harness-kit /tmp/harness-kit
git -C /tmp/harness-kit checkout v<target>
```

The project needs a clean working tree on its own branch, so every step
below is reviewable and revertible from git. Done when the clone is at the
target tag and `git status` in the project is clean.

## 2. Take the inventory

```bash
<skill-dir>/migrate-inventory.sh /tmp/harness-kit .
```

It reads the lock and classifies every tracked file against the lock's
version, following the release's symlinks, plus every untracked file under
`.claude/skills`, `.claude/agents`, `.agents/skills`, `.agents/scripts`, and
`.codex/agents`. It changes nothing. Add `--json` for the same data as
`files` (each with `path`, `owner`, `source`, `status`, `upstream`, `change`),
`changes` (each with `id`, `paths`, `diff`), and `references`.

`references` (the "References outside the harness" section) lists each line,
as `file:line`, of a file git tracks outside those directories that names
`.harness-lock.json`, `.harness-upstream`, or a tracked harness-kit copy,
with the `term` it names and its `text` (cut to 200 characters). A regex's
`\.` and `\/` read as `.` and `/`, so they still match, while other escapes,
such as `\b`, end a term; and a term matches only as whole path segments, so
`.harness-lock.json.bak` doesn't. Files over 1 MB
are not searched. These are the project's own tooling that migrate would break:
a pre-commit hook or a Renovate custom manager that reads the old lock's
version, a script that runs an old copy's path. It is null, and the section
says "not searched", when the project is not a git repository.

| Status | Meaning |
| --- | --- |
| `pristine` | Identical to upstream at the lock's version |
| `modified` | Differs; its diff is one of the numbered changes |
| `missing` | Tracked, but gone from disk |
| `no-upstream` | Tracked as harness-kit, but that release has no such file |
| `other-source` | Tracked from another marketplace |
| `local` | Tracked as `source: "local"` |
| `untracked` | In a harness directory but not in the lock |

Trust the content, not the lock's `modified` flags; projects edited copies
without setting them. Identical diffs across copies are grouped into one
change, so the same patch in six files is one decision. Done when the report
is in hand; the script exits 1 naming the fix when the lock is unreadable or
the tag is missing.

## 3. Choose the set

Propose `skills` and `agents` for `.harness/config.toml`: each name the
project kept and uses, which usually means every skill or agent with a
`pristine` or `modified` file, minus ones the maintainer says go unused.
`harness` is always vendored; leave it out of the list. Map each name to the
target release: a name it no longer ships (`ls /tmp/harness-kit/skills/*/<name>`
finds nothing) is dropped, and old layout directories such as
`.claude/skills/shared/` or `.claude/agents/references/` are not names at
all. The chosen set may add skills the old harness never had; offer the
target release's catalog once, briefly.

Done when the maintainer has confirmed the list of skills and agents.

## 4. Turn each change into a fact or a fork

Take the changes one at a time, largest first. For each, read the diff and
then the target release's version of the same file (`claude-skills/<skill>/`,
`skills/<area>/<skill>/`, `agents/`, `.codex/agents/`), since upstream may
already cover it or now read a fact for it. Propose exactly one outcome, with
the diff and your reason, and wait for the maintainer to confirm or change
it:

- **Config fact.** The edit hard-codes a value a generic skill reads from
  `.harness/config.toml`. Today that is `[facts] verification_command`; the
  key table is in `<skill-dir>/project-facts.md`. A key no skill reads is
  not a config fact.
- **Prose fact.** The edit teaches the project's conventions, terms, or
  rules. It becomes a line in the `## Project facts` section of `AGENTS.md`.
- **Fork.** Neither can express it: the edit changes the workflow itself.
  The skill or agent goes under `[forks.skills]` or `[forks.agents]` with
  the target version, and its files become the target release's copy with
  the edit re-applied, for each host the project uses. Update then leaves it
  alone and reports upstream changes since. A fork costs a manual re-sync on
  every release, so reach for it last.
- **Discard.** The edit is obsolete, or the target release already does it.

An edit that would help every project is also a hoist candidate: record it
in the report and suggest `harness hoist` after the migration. It still gets
one of the outcomes above in the meantime.

Worked example, from `parametric-building` at 0.7.0: one change, identical
across six copies of `discover-verification-cmd.sh` (five skills and
`.claude/skills/shared/`), adds a `moon ci` branch, and a second change makes
the verifier say "run `moon ci`". Both say one thing, so they are one config
fact:

```toml
[facts]
verification_command = "moon ci"
```

All six copies and the verifier return as pristine vendored files, and an
`AGENTS.md` line can say why the gate is `moon ci`, pointing at the key
rather than repeating it.

Done when every numbered change has a confirmed outcome.

## 5. Place everything else

| Status | Disposition |
| --- | --- |
| `pristine` | Delete; the snapshot brings back the skills in the set |
| `modified` | Delete once its change has an outcome; a fork's files are rewritten in step 7 |
| `missing` | Nothing to do |
| `no-upstream` | Ask: usually a stale upstream file (delete), sometimes project content filed under harness-kit (keep as local) |
| `other-source` | Keep as project-local files, or, for a skill with a known repository, re-add it as a source with add mode (`<skill-dir>/update.md`) |
| `local`, `untracked` | Keep |

A kept file inside a directory the snapshot will own, such as
`.claude/skills/commit/notes.md` with `commit` in the set, makes
`vendor-snapshot.sh` refuse to run. Move it into a project-local skill, or
make that skill a fork.

Then find the project's tools that rewrite files and would reach the
snapshot: formatters and fixers in `.pre-commit-config.yaml`, `flake.nix`
(git-hooks.nix, treefmt), `treefmt.toml`, `lefthook.yml`, lint-staged,
`.editorconfig`, Prettier and markdownlint config, the justfile or Makefile's
format recipes, and format-on-edit hooks. They were free to reformat the old
copies; a reformatted snapshot file fails the edit check. Plan an exclusion
for each from `<skill-dir>/vendoring.md` ("Keeping formatters off the
snapshot"). Plan an edit, too, for each entry in the inventory's references
outside the harness (step 6 lists the usual ones). Done when every file in
the inventory has a disposition, every such tool has a planned exclusion,
and every reference has a planned edit.

## 6. Preview, then confirm

Before writing or deleting anything, show the maintainer the whole plan:

- the `.harness/config.toml` to write, and the `AGENTS.md` facts to add;
- each fork, with the edit that will be re-applied;
- every file to delete, grouped by skill or agent, with a count;
- every file kept, and every file moved;
- each formatter exclusion to add, by file, or "none found";
- each reference outside the harness, as `file:line`, with the edit that
  keeps it working, or "none found". One that reads the old lock's version
  usually reads `.harness/lock.json`'s top-level `version` instead (`jq -r
  .version .harness/lock.json`; a Renovate manager's file pattern becomes
  `^\.harness/lock\.json$`, with a `"version": "..."` match). One that names
  `.harness-upstream` reads `.claude/harness-upstream`. One that names a
  copy that comes back in the snapshot needs nothing; one whose copy goes
  away points at its vendored successor (`.claude/skills/<skill>/`,
  `.agents/scripts/shared/`) or is removed;
- that `.harness-lock.json` will be removed and harness-kit set to `false`
  in `.claude/settings.json`, so only the snapshot loads;
- the upstream repo `.claude/harness-upstream` will name.

Make no change until the maintainer approves this preview; a change to the
plan means a new preview. Done when the maintainer approves.

## 7. Apply

1. Write `.harness/config.toml` and the `AGENTS.md` facts section. A
   Claude-only project that has no `AGENTS.md` gets one, imported from
   `CLAUDE.md` with `@AGENTS.md`. Add the planned formatter exclusions, and
   make the planned edit to each reference outside the harness.
2. Delete the planned files with `git rm`, and move the kept ones.
3. Write each fork's files from the target release, with its edit
   re-applied.
4. Vendor the set:

   ```bash
   <skill-dir>/vendor-snapshot.sh /tmp/harness-kit .
   ```

   It exits 1, writing nothing, when the config names an unknown skill or a
   kept file is in the snapshot's way; fix that and re-run. Its report lists
   the forks it left alone.
5. Record the upstream, then remove the old files. Once the old lock is
   gone, the update workflow and the `harness-issue` skill read the upstream
   only from `.claude/harness-upstream` (one line, `owner/repo`). Keep that
   file when present; otherwise write it from `.harness-upstream` (a 1.x
   bootstrap wrote both), or from the old lock's first source `repo` when
   that isn't `dougborg/harness-kit`. Ask the maintainer when two of them
   disagree. Then `git rm .harness-lock.json`, and `.harness-upstream` if
   present.
6. Remove hook entries the old harness added for harness-kit's own scripts
   (in `.claude/settings.local.json` or `.codex/hooks.json`) now that the
   snapshot wires them in `.claude/settings.json`; keep the project's own.

Done when all six are applied.

## 8. Verify and report

Run `<skill-dir>/check-snapshot.sh .` and then the project's gate, found by
`<shared-scripts-dir>/discover-verification-cmd.sh`, which now runs the edit
check first. A CI workflow that calls the gate command directly also needs
`.claude/skills/harness/check-snapshot.sh` added (`<skill-dir>/vendoring.md`).
Fix what fails and re-run both.

Commit the migration (call the Skill tool with "commit"), then report: the
version moved from and to, the chosen set, each change and its outcome, the
forks, deletion and keep counts, and any hoist candidates. End with the next
action, usually opening the migration PR.

Done when the edit check and the gate both pass, `git status` shows only the
planned changes, and the report is delivered.
