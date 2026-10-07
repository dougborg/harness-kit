---
name: harness
description: >-
  Audits, bootstraps, updates, and improves a project's agent harness: the
  skills, agents, hooks, and instructions for Claude Code and Codex. Modes:
  audit, bootstrap, update, add, retro, hoist; each reads its own protocol
  reference.
when_to_use: >-
  When the user asks to audit, bootstrap, update, or retro a harness; when
  setting up Claude Code and Codex project harnesses; when adding skills from
  another marketplace; and when a harness mode hands off to another mode
  (retro to hoist).
argument-hint: "[audit|bootstrap|update|add|retro|hoist]"
allowed-tools: Bash(ls*), Bash(grep*), Bash(git*), Bash(claude plugin*), Bash(${CLAUDE_SKILL_DIR}/discover-verification-cmd.sh*), Read, Glob, Write, Edit
---

# Harness

Quality gates for an agent harness: the skills, agents, hooks, and docs that
teach agents how to work in a project. Harness quality is agent quality; a
stale or badly structured skill gets followed exactly as written.

The skill works on a project that has harness content in `.claude/`,
`.agents/`, or `.codex/`, or one you are bootstrapping. It expects the
harness-kit plugin to be installed (it supplies the base skills and agents),
the project's verification command to be runnable, and `.harness-lock.json`
to record which files came from upstream and which are project-local.

## Pick the mode

On Claude Code the modes are `/harness <mode>`; on Codex, `$harness <mode>`.

```text
harness              Auto-detect: bootstrap if no harness, audit if one exists
harness audit        Audit the current harness (delegates setup health to /doctor)
harness bootstrap    Analyze the project, install skills and agents from the plugin, generate project-specific additions
harness update       Pull the latest from upstream sources and smart-merge with local changes
harness add <repo>   Add skills from another plugin marketplace
harness retro        Post-session retrospective on the environment
harness hoist        Propose generic local improvements back upstream
```

With no mode given, run `bootstrap` if none of `.claude/`, `.agents/`, or
`.codex/` holds harness content, and `audit` otherwise.

Read the file for the selected mode before doing any work, and only that one;
each is self-contained.

| Mode | Read | What it covers |
| --- | --- | --- |
| `audit` | `${CLAUDE_SKILL_DIR}/audit.md` | Audit protocol, `/doctor` division of labor, gap classification, output format |
| `bootstrap` | `${CLAUDE_SKILL_DIR}/bootstrap.md` | harness-builder handoff, approval gate, install steps, `.harness-lock.json` creation |
| `update` | `${CLAUDE_SKILL_DIR}/update.md` | Smart-merge with upstream using lock-file provenance |
| `add` | `${CLAUDE_SKILL_DIR}/update.md` | Installing skills from another marketplace (second half of the file) |
| `retro` | `${CLAUDE_SKILL_DIR}/retro.md` | Environment audit, gap classification A/B/C/D/E, upstream promotion pass |
| `hoist` | `${CLAUDE_SKILL_DIR}/hoist.md` | Proposing project-local improvements back upstream |

Done when the mode's file is read and its protocol has run to its own end.

## Topic references

Read these as needed from any mode. Each is linked only from here; none links
to another.

| Topic | Read | When |
| --- | --- | --- |
| Skill and agent design patterns | `${CLAUDE_SKILL_DIR}/design-principles.md` | Writing or reviewing a skill or agent; deciding what belongs upstream vs local |
| Hook staging and exit codes | `${CLAUDE_SKILL_DIR}/hooks-patterns.md` | Configuring or auditing hooks (PostToolUse stages, Stop hooks); a hook that exits non-zero on a no-op is covered under Hook Exit Code Safety |
| Bundled skills and official plugin catalog | `${CLAUDE_SKILL_DIR}/external-plugins.md` | Bootstrap or audit needs bundled-skill delegation targets, stack-matched plugin recommendations, and overlap flags |
| Multi-agent architecture patterns | `${CLAUDE_SKILL_DIR}/architecture-patterns.md` | Bootstrap picks an architecture pattern for the project |
| Plugin `hooks.json` schema | `${CLAUDE_SKILL_DIR}/hooks-reference.md` | Writing or debugging a plugin's `hooks/hooks.json` |
| Release Please setup | `${CLAUDE_SKILL_DIR}/release-please-reference.md` | Recommending automated semver releases for a Conventional Commits + GitHub project |

## Treat the audit as advice

Run `harness audit` before shipping a skill. It catches what nothing else
does: invalid frontmatter, unrestricted "read-only" agents, oversized or vague
skills. Fix its defects (a frontmatter field the runtime silently ignores is a
defect) and weigh its recommendations (whether a description reads vague is
your call). It is advisory, not a gate.

## Classify every finding

Every finding from audit or retro gets a type, which decides where the fix
goes:

- **Type A**: content gap in an existing skill. Fix the skill.
- **Type B**: skill missing entirely. Add it.
- **Type C**: the builder template would not have generated this. Fix the
  builder; this double loop is the most valuable fix.
- **Type D**: a lightweight pattern not worth a skill. Store it in memory or
  `.claude/patterns/` (retro only).
- **Type E**: an environment change (a check, hook, CI job, standard, doc
  pointer, or access grant) made in the project; also Type C when the builder
  should have recommended it (retro only).

For a file sourced from upstream (per `.harness-lock.json`), a Type A or a
generic Type B is usually an upstream fix, not only a local one.

## Fix gaps as you meet them

When any session (not only harness work) exposes a behavioral gap in the
harness:

1. Fix the immediate issue in the current task.
2. Decide the scope: upstream (a generic workflow that helps every project) or
   project-local (domain-specific).
3. Hand the fix to a background subagent and keep working.

An upstream fix clones harness-kit (or the other upstream source), fixes it,
and opens a PR. On Claude Code:

```text
Agent(
  description: "fix harness gap: [brief description]",
  run_in_background: true,
  prompt: "Fix [gap] in harness-kit.
    1. git clone --depth 1 https://github.com/dougborg/harness-kit /tmp/harness-fix
    2. cd /tmp/harness-fix && git checkout -b fix/[name]
    3. Fix skills/<area>/[skill]/SKILL.md (find it with ls skills/*/[skill])
       or agents/[agent].md, then run scripts/generate-claude-skills.sh.
       A new skill goes in a topic-area folder and that area's README.md.
       If fixing inline bash, extract it to a script instead of patching
       in place.
    4. Commit, push, open PR with gh
    5. Clean up: rm -rf /tmp/harness-fix"
)
```

On Codex, give the same prompt to a subagent. A project-local fix edits the
host-specific file tracked in `.harness-lock.json`, commits normally, and
marks the file `modified: true`.

The upstream PR is reviewed and merged separately; `harness update` then pulls
the fix into every project. Encode behavioral gaps in skills through PRs
rather than memories, because memories fade and skills persist. Done when the
current task is unblocked and the fix is either committed locally or running
in a background subagent.

## Flag suspect guidance

Whenever guidance in a skill looks outdated or wrong, flag it in your reply
and carry on working:

```markdown
> ⚠️ FLAGGED: [brief reason this guidance may be outdated or wrong]
```

The flag is a lightweight in-flight signal that feeds the next audit.

## Related

- The `harness-builder` agent: bootstrap mode dispatches it to analyze a
  codebase and recommend a harness.
- `/session-retro`: the session-side retrospective (documents the work, not
  the harness); run it alongside retro mode.
- `/documentation-writer`: scannable, progressive-disclosure docs.
- `/skill-writer`: authoring guidance for skills and agents; audit checks
  against what it teaches.
- `/doctor` (bundled with Claude Code, alias `/checkup`): generic setup health
  such as installation, PATH, unused skills, slow hooks, and CLAUDE.md bloat.
  Audit invokes it rather than duplicating it.
