# Project Facts

Generic skills and agents are vendored into a project unedited (ADR 0001). What
is specific to the project is stated as **facts**, in two places: prose in a
`## Project facts` section of `AGENTS.md`, and machine-read keys in
`.harness/config.toml`. Generic skills read both; nobody patches a vendored
file to teach it a project's quirk.

## Prose or config

Put a fact in `.harness/config.toml` only when a generic skill or script reads
that exact key. Everything else is prose in `AGENTS.md`. State each fact once:
when prose needs a config value, point at the key rather than repeating it.

| Fact | Where |
| --- | --- |
| The command that gates every commit and PR | `[facts] verification_command` |
| Which generic skills and agents the project vendors, and which it forks | `skills`, `agents`, `[forks.*]` |
| Domain terms, conventions, where things live, what is off-limits | `AGENTS.md` prose |
| How to deploy, release, or run the app; who reviews what | `AGENTS.md` prose |
| Why the gate is what it is ("`moon ci` runs every workspace's checks") | `AGENTS.md` prose |

A new config key is added upstream only when a generic skill needs to read
it. If a project needs a value no skill reads, it is prose.

## The `AGENTS.md` section

```markdown
## Project facts

- The verification command is set in `.harness/config.toml`
  (`[facts] verification_command`); it runs every workspace's checks.
- Domain terms are defined in `GLOSSARY.md`; decisions are in `docs/adr/`.
- Deploys go through the `release` workflow; never push tags by hand.
```

Keep it to statements an agent acts on. Workflow guidance belongs in a
project-local skill, not here.

## `.harness/config.toml`

The file is edited by people and committed. `.harness/lock.json`, beside it,
is generated; never edit the lock by hand.

```toml
# Generic skills and agents this project vendors. `harness` is always vendored.
skills = ["commit", "open-pr", "review-pr", "tdd"]
agents = ["code-reviewer", "verifier"]

# Forks the project owns. Each maps a name to the harness-kit version it was
# forked from; update leaves forks alone and reports upstream changes since.
[forks.skills]
review-pr = "1.0.0"

[forks.agents]

# Skills from another repository, each listed in `skills` above.
[sources.skills]
frontend-design = "anthropics/skills@main:skills/frontend-design"

# Facts generic skills read.
[facts]
verification_command = "moon ci"
```

| Key | Type | Read by | Status |
| --- | --- | --- | --- |
| `[facts] verification_command` | string | `discover-verification-cmd.sh`, the verifier agent | Implemented |
| `skills` | array of skill names | `vendor-snapshot.sh` | Implemented |
| `agents` | array of agent names | `vendor-snapshot.sh` | Implemented |
| `[forks.skills]` | table, name = forked-from version | `vendor-snapshot.sh` never touches these and reports upstream changes since the version | Implemented |
| `[forks.agents]` | table, name = forked-from version | `vendor-snapshot.sh` never touches these and reports upstream changes since the version | Implemented |
| `[sources.skills]` | table, name = `"owner/repo@ref:path"` | `vendor-snapshot.sh` validates and records it; fetching is not implemented yet | Partial |

Forks are split by kind because a skill and an agent can share a name
(`code-reviewer` is both). Write the forked-from version as the release
number without the `v` (`"1.0.0"`); the update report reads that release from
tag `v1.0.0`. A source names the repository, the ref, and the
skill's directory in that repository; a skill without one comes from
harness-kit. `${CLAUDE_SKILL_DIR}/vendoring.md` covers what the vendoring script
writes from these keys.

### The verification command

`verification_command` wins over discovery. When the file or the key is
absent, `discover-verification-cmd.sh` and the verifier fall back to
discovering the command from `justfile`, `Makefile`, `pyproject.toml`,
`package.json`, `Cargo.toml`, or `flake.nix`, unchanged from before.

Write the value as a one-line TOML string, basic (`"..."`, with `\"`, `\\`,
and `\t` escapes) or literal (`'...'`), on its own line under `[facts]`.
An unquoted, empty, or multi-line value makes the script exit 1 with the file
and line, rather than silently falling back to a different gate. So does the
key written anywhere it isn't read: an inline `facts = { ... }` table, a
dotted `facts.verification_command` key, or another table.
