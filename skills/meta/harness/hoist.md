# Hoist Mode

Propose improvements to the upstream harness-kit plugin (or another upstream
source) when something a project built for itself is generic enough to help
every project. In a vendored project (ADR 0001) this is the only way a generic
lesson reaches the snapshot: it lands upstream, then returns through the next
update PR.

## Procedure

1. **Find the candidates.** Vendored files are the ones listed in
   `.harness/lock.json`; they match upstream, so they hold nothing to hoist.
   The candidates are:
   - **Project-local content**: skills and agents in `.claude/`, `.agents/`,
     and `.codex/` that the lock doesn't list.
   - **Facts patterns**: entries in `AGENTS.md`'s `## Project facts` or in
     `.harness/config.toml` that several projects would state the same way,
     or that a generic skill keeps needing and can't read (a candidate config
     key).
   - **Forks**: each name in `[forks.skills]` and `[forks.agents]`. Diff it
     against the upstream version it was forked from to see what the project
     changed.

   Done when every candidate has been read.

2. **For each candidate, ask:**
   - Is this improvement generic (no domain entities, no project paths)?
   - If yes: which upstream source should it go to? A fork or a sourced
     skill goes back to its source (the lock's `skills` entry, or
     `[sources.skills]`); everything else defaults to harness-kit.
   - If partially generic: extract the generic improvement, keep project-specific parts local

3. **Classify** each candidate:
   - **Fork change**: propose it as a PR to the forked skill or agent upstream
   - **New generic skill**: propose it as an addition to the upstream repo
   - **Facts pattern**: propose the generic skill reading it, and a config
     key when a script needs the value
   - **Partially generic**: Extract generic principles into a PR, keep domain parts local
   - **Project-specific**: Stays local, no hoist needed

4. **Propose changes** (prefer fewer, better upstream skills over more):
   - PRs to existing upstream skills (merge useful patterns)
   - New upstream skills only when nothing existing covers the area
   - Project-local files and forks to retire after upstream accepts the improvement

5. **After approval**: Clone the upstream repo, create a branch, apply changes, open a PR via `gh`. For harness-kit, edit the canonical skill under `skills/<area>/<skill>/` (find it with `ls skills/*/<skill>`), never `claude-skills/`, and run `scripts/generate-claude-skills.sh`. A new skill goes in a topic-area folder and gets a line in that area's `README.md`.

## Principles

- The upstream harness grows by getting *better*, not *bigger*. Prefer improving existing skills over adding new ones.
- A mature harness is smaller than a young one — upstream AND in projects.
- After the upstream change ships, recommend retiring what it covers: drop
  the fork from the config so update vendors the skill again, or delete the
  project-local skill. Fewer project-owned files = less drift.
- **Facts over forks**: a project shapes a generic skill by stating facts it
  reads, not by owning a copy. A fork that exists only to carry a fact is a
  hoist candidate for a new fact the skill reads.
