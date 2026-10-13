# Vendor generic skills as pristine snapshots; customize through facts

Status: accepted (2026-10-12). Implementation: #164.

Projects get harness-kit's generic skills and agents as a vendored snapshot
that nobody edits. Each project states its own facts in `AGENTS.md` and
`.harness/config.toml`, which the generic skills read. When the facts can't
express a need, the project declares a fork it owns outright. A scheduled
workflow in each repo replaces the snapshot wholesale on every release, so all
projects run one version. This replaces bootstrap's copy-and-edit model and
update's three-way merge.

## Why

Across the four bootstrapped projects at 0.7.0–0.8.0, copy-and-edit did not
produce per-project customization, only drift and merge debt:

- `dougborg-dot-net` carried 83 untouched copies, stuck at 0.7.0.
- `parametric-building`'s 8 edits were one fact ("the gate is `moon ci`")
  patched into six copies of one script and into the verifier.
- `resume` rewrote its verifier to say "run `pnpm check`".
- `nix-config` was the most self-improving project (63 harness commits), and
  it had no upstream copies at all.

Customization was real but lived in the wrong layer: project facts were
edited into generic files, so every release turned into a merge conflict.

## Considered options

- **Plugin only, no copies.** Rejected: cloud sessions load neither installed
  nor repo-enabled plugins, the Codex IDE extension doesn't load plugins, and
  Codex subagents can't come from a plugin. The harness must work for
  collaborators, cloud and CI, so generic content has to be in the repo.
- **Plugin plus a vendored copy.** Rejected: a project skill and a plugin
  skill with the same name both load (`/open-pr` and `/harness-kit:open-pr`),
  which leaves two sources to keep in step.
- **Keep copy-and-edit, fix update.** Rejected: the merge cost grows with
  every release, and the data shows the edits were mostly facts.

## Consequences

- Vendored repos set harness-kit to `false` in `.claude/settings.json`, so
  only the snapshot loads. The `harness` skill is vendored, so retro and hoist
  still work there.
- `.harness/lock.json` records the snapshot version and file hashes. A check in
  the project's verification command fails when a vendored file is edited.
- Update becomes a deterministic script. Judgment (is this a fact or a fork?)
  moves to retro and a one-time migrate mode.
- Generic lessons go upstream through hoist and come back through the update
  PR. Nothing is patched locally first.
- One version everywhere means a bad release reaches every repo. Each update
  PR goes through that repo's own CI and review before it lands.
- This supersedes the "modify the local copy and mark it `modified: true`"
  extension pattern in the harness skill's design principles.
