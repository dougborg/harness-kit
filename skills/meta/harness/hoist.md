# Hoist Mode

Propose improvements to the upstream harness-kit plugin (or other upstream sources) when a project-local skill improvement is generic enough to benefit all projects.

## Procedure

1. **Read the lock file** — `.harness-lock.json` tells you which files came from which upstream source and whether they've been modified.

2. **Inventory project harness** — Read every file in project `.claude/agents/` and `.claude/skills/`.

3. **For each modified or local file, ask:**
   - Is this improvement generic (no domain entities, no project paths)?
   - If yes: which upstream source should it go to? (check lock file provenance)
   - If partially generic: extract the generic improvement, keep project-specific parts local

4. **Classify** each candidate:
   - **Modified upstream file**: The improvement should be proposed as a PR to the upstream repo
   - **New generic skill**: Should be proposed as an addition to the upstream repo
   - **Partially generic**: Extract generic principles into a PR, keep domain parts local
   - **Project-specific**: Stays local, no hoist needed

5. **Propose changes** (prefer fewer, better upstream skills over more):
   - PRs to existing upstream skills (merge useful patterns)
   - New upstream skills only when nothing existing covers the area
   - Project-local files to simplify after upstream accepts the improvement

6. **After approval**: Clone the upstream repo, create a branch, apply changes, open a PR via `gh`.

## Principles

- The upstream harness grows by getting *better*, not *bigger*. Prefer improving existing skills over adding new ones.
- A mature harness is smaller than a young one — upstream AND in projects.
- After hoisting, actively recommend simplifying project-local skills now covered by the improved upstream. Fewer files = less drift.
- **Composition over duplication**: Project-local skills extend upstream skills with project-specific flavor. The upstream skill defines the protocol; the local skill adds domain checks and context.
