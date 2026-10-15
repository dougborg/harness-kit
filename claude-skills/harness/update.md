# Update and Add Modes

Both modes change a project's vendored snapshot (ADR 0001) and nothing else.
`update` moves the snapshot to a newer harness-kit release; `add` brings a
skill from another repository into the chosen set. Neither edits a vendored
file by hand: the snapshot is rewritten by `${CLAUDE_SKILL_DIR}/vendor-snapshot.sh`,
which `${CLAUDE_SKILL_DIR}/vendoring.md` documents in full.

## Update Mode

Updating is a deterministic script run, not a merge. Done when the snapshot
is at the new version, the edit check passes, and the report is in the
commit or PR.

1. **Check the project is vendored.** A `.harness/config.toml` and
   `.harness/lock.json` mean it is. A `.harness-lock.json` (the 0.x/1.x
   copy-and-edit lock) means it isn't yet: stop and run migrate
   (`${CLAUDE_SKILL_DIR}/migrate.md`) instead, which turns its edited copies into
   facts or forks first. A project with neither has no harness; run
   bootstrap.

2. **Get the newer release root**, written `<release-root>` below: the
   installed plugin's directory when it is the release you want, or a
   release checkout:
   `git clone --depth 1 --branch vX.Y.Z https://github.com/dougborg/harness-kit`.
   The lock's `version` is the current snapshot; when it already equals the
   release root's version, there is nothing to sync from upstream. Report that
   and point session-learning improvements to `harness retro`
   (`${CLAUDE_SKILL_DIR}/retro.md`).

3. **Run the vendoring script** against that root:

   ```bash
   ${CLAUDE_SKILL_DIR}/vendor-snapshot.sh <release-root> .
   ```

   It replaces the snapshot wholesale, removes files the release dropped,
   rewrites `.harness/lock.json`, and leaves every fork untouched. It will not
   overwrite a snapshot that fails the edit check: an edited vendored file
   has to move into facts or a declared fork first, or be discarded
   explicitly. Comparing forks with upstream needs the forked-from tag in the
   release root; a shallow clone lacks it, and `${CLAUDE_SKILL_DIR}/vendoring.md` gives the fetch.

4. **Act on the report.** It lists three things the script does not decide:
   - **Removed upstream**: drop the name from the config's `skills` or
     `agents`, or replace it with what superseded it.
   - **New upstream**: offer each to the user; vendor one by adding it to the
     config and re-running the script.
   - **Forks**: for each fork with upstream changes, the owner re-syncs it by
     hand and bumps its forked-from version, or proposes the fork's change
     upstream with hoist mode.

5. **Run the verification command**, which runs the edit check first in a
   vendored project, and commit the snapshot, the lock, and any config change
   together, with the report in the commit or PR body.

In a repo with the scheduled update workflow, steps 2 to 5 happen on their
own: on each release it runs the script and opens a PR carrying the report,
which goes through the project's own CI and review before it lands. Run
update by hand to pick up a release early, when that PR needs redoing, or
when the job fails because the release changes the workflow file and the repo
has no `HARNESS_UPDATE_TOKEN` (`${CLAUDE_SKILL_DIR}/vendoring.md`, "The update
workflow").

## Add Mode

Add a skill from another repository to the vendored set, under the same
lock, edit check, and fork rules as harness-kit's own skills.

```text
/harness add anthropics/skills    (Claude Code)
$harness add anthropics/skills    (Codex)
```

1. **Pick the skills.** Browse the repository (a plugin marketplace or any
   repo with skill directories) and agree with the user which skills to add.
   Prefer a harness-kit skill that already covers the job; adding an
   overlapping one leaves two skills to keep apart.

2. **Decide to trust it.** A vendored skill is instructions an agent follows
   and often scripts it runs; read its `SKILL.md` and any scripts before
   adding it, and say in the report what it can run.

3. **Record each in the config.** Add the name to `skills` and its source to
   `[sources.skills]` as `"owner/repo@ref:path"` (format in
   `${CLAUDE_SKILL_DIR}/project-facts.md`). Pin the ref to the full commit SHA you
   read, from `git ls-remote https://github.com/owner/repo <branch-or-tag>`;
   a branch or tag is accepted but can move under you. The name must not
   clash with a harness-kit skill or a project-local one.

4. **Vendor it** with `vendor-snapshot.sh`, as in update step 3. It fetches
   the source at that ref and writes the skill's directory, unchanged, to
   both `.claude/skills/<name>/` and `.agents/skills/<name>/`. Its lock entry
   records the source in place of `harness-kit`, and `source_commits` the
   commit. A source it can't fetch, or a path that isn't a skill directory,
   stops it with nothing written. `${CLAUDE_SKILL_DIR}/vendoring.md` ("Third-party
   skills") has the details.

5. **Run the verification command** to confirm nothing broke.

A plugin the user installs with `/plugin install` is not added this way:
it stays outside the project and outside the lock.
