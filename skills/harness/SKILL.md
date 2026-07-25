---
name: harness
description: Self-improving meta-harness for auditing, bootstrapping, and improving agent harnesses
allowed-tools: Bash(ls*), Bash(grep*), Bash(git*), Bash(claude plugin*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh*), Read, Glob, Write, Edit
---

# /harness — Self-Improving Meta-Harness

Unified command for harness management. Auto-detects mode or use subcommands to audit, bootstrap, retro, or hoist agent harnesses.

## PURPOSE

Establish quality gates on agent harnesses — skills, agents, hooks, and documentation — to catch gaps and inconsistencies before they affect productivity.

## CRITICAL

- **Run `/harness audit` before shipping a skill** — it catches the failures nothing else does: invalid frontmatter, unrestricted "read-only" agents, oversized or vague skills. Audit is advisory, not a gate; weigh its judgment calls rather than obeying them
- **Fix audit defects, weigh audit recommendations** — a frontmatter field that is silently ignored is a defect; a description that reads vague is a call you make
- **Harness quality === agent quality** — Skills teach and guide; if skills are poorly structured or out-of-date, agents will follow bad patterns

## ASSUMES

- You have `.claude/` directory with agents, skills, or both (or you're bootstrapping a new project)
- You can run the verification command for your project stack (cargo test, npm test, nix flake check, etc.)
- The harness-kit plugin is installed (provides base skills/agents and this `/harness` skill)
- `.harness-lock.json` tracks which files came from upstream vs project-local

## STANDARD PATH

Auto-detect and run the appropriate mode:

```bash
/harness              # Auto-detect: bootstrap if no harness, audit if exists
/harness audit        # Audit the current harness (delegates setup health to /doctor)
/harness bootstrap    # Analyze project, install skills/agents from plugin, generate project-specific additions
/harness update       # Pull latest from upstream sources, smart-merge with local changes
/harness add <repo>   # Add skills from another plugin marketplace
/harness retro        # Post-session retrospective
/harness hoist        # Propose upstream PR for generic improvements
```

If no `.claude/` → runs `bootstrap` (generates harness). If `.claude/` exists → runs `audit` (validates quality).

**Read the file for the selected mode before doing any work.** Each is self-contained; do not read the others.

| Mode | Read | What it covers |
| --- | --- | --- |
| `audit` | `${CLAUDE_PLUGIN_ROOT}/skills/harness/audit.md` | Audit protocol, `/doctor` division of labor, gap classification, output format |
| `bootstrap` | `${CLAUDE_PLUGIN_ROOT}/skills/harness/bootstrap.md` | harness-builder handoff, approval gate, install steps, `.harness-lock.json` creation |
| `update` | `${CLAUDE_PLUGIN_ROOT}/skills/harness/update.md` | Smart-merge with upstream using lock-file provenance |
| `add` | `${CLAUDE_PLUGIN_ROOT}/skills/harness/update.md` | Installing skills from another marketplace (second half of the file) |
| `retro` | `${CLAUDE_PLUGIN_ROOT}/skills/harness/retro.md` | Gap classification A/B/C/D, upstream promotion pass |
| `hoist` | `${CLAUDE_PLUGIN_ROOT}/skills/harness/hoist.md` | Proposing project-local improvements back upstream |

Topic references, read as needed from any mode (all reachable in one hop from here — no reference file links to another):

| Topic | Read | When |
| --- | --- | --- |
| Skill/agent design patterns | `${CLAUDE_PLUGIN_ROOT}/skills/harness/design-principles.md` | Writing or reviewing a skill or agent; deciding what belongs upstream vs local |
| Hook staging and exit codes | `${CLAUDE_PLUGIN_ROOT}/skills/harness/hooks-patterns.md` | Configuring or auditing hooks (PostToolUse stages, Stop hooks, exit-code safety) |
| Bundled skills + official plugin catalog | `${CLAUDE_PLUGIN_ROOT}/agents/references/external-plugins.md` | Bootstrap or audit needs bundled-skill delegation targets, stack-matched plugin recommendations, and overlap flags |
| Multi-agent architecture patterns | `${CLAUDE_PLUGIN_ROOT}/agents/references/architecture-patterns.md` | Bootstrap picks an architecture pattern for the project |
| Plugin `hooks.json` schema | `${CLAUDE_PLUGIN_ROOT}/agents/references/hooks-reference.md` | Writing or debugging a plugin's `hooks/hooks.json` |

## EDGE CASES

- [Auditing existing harness] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/audit.md`
- [Setting up new project] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/bootstrap.md`
- [Syncing with upstream, or adding external skills] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/update.md`
- [Session reflection] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/retro.md`
- [Sharing generic tools upstream] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/hoist.md`
- [Design guidance for skills/agents] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/design-principles.md`
- [Hook exits non-zero on no-op] — Read `${CLAUDE_PLUGIN_ROOT}/skills/harness/hooks-patterns.md` → Hook Exit Code Safety

---

## Gap Classification (all modes)

Every finding from audit or retro gets a type — it determines where the fix goes:

- **Type A** — Content gap in an existing skill → fix the skill
- **Type B** — Skill missing entirely → add the skill
- **Type C** — The builder template would not have generated this → fix the builder (double-loop; most valuable)
- **Type D** — Lightweight pattern, not worth a skill → store in memory or `.claude/patterns/` (retro only)

For a file sourced from upstream (per `.harness-lock.json`), a Type A or generic Type B is usually an upstream fix, not just a local one.

## Self-Corrective Improvement

When you encounter a behavioral gap during any session (not just harness work):

1. **Fix the immediate issue** in the current task
2. **Determine scope** — upstream (generic workflow, benefits all projects) or project-local (domain-specific)?
3. **Spawn a background subagent** to make the fix while you continue working:

**Upstream fix** — clone the harness-kit repo (or other upstream source), fix, and open a PR:

```text
Agent(
  description: "fix harness gap: [brief description]",
  run_in_background: true,
  prompt: "Fix [gap] in harness-kit.
    1. git clone --depth 1 https://github.com/dougborg/harness-kit /tmp/harness-fix
    2. cd /tmp/harness-fix && git checkout -b fix/[name]
    3. Fix skills/[skill]/SKILL.md or agents/[agent].md. If fixing inline bash,
       extract to a script instead of patching in place.
    4. Commit, push, open PR with gh
    5. Clean up: rm -rf /tmp/harness-fix"
)
```

**Project-local fix** — fix `.claude/{skills,agents}/` directly in the current repo, commit normally. Mark the file as `modified: true` in `.harness-lock.json`.

**Continue working** — the upstream PR will be reviewed and merged separately. After merge, `/harness update` will pull the fix into all projects.

Behavioral gaps get encoded in skills via PRs, not memories. Memories fade; skills persist. Inline bash gets extracted into scripts.

## Andon Cord Pattern

Any time during a session, flag a suspect skill:

```markdown
> ⚠️ FLAGGED: [brief reason this guidance may be outdated or wrong]
```

Lightweight in-flight signal that feeds the next audit. Don't stop work — just flag it.

---

## RELATED

- Siblings of this file in `${CLAUDE_PLUGIN_ROOT}/skills/harness/`: `audit.md`, `bootstrap.md`, `update.md`, `retro.md`, `hoist.md` (mode protocols); `design-principles.md`, `hooks-patterns.md` (cross-mode topics). All are one level deep — none of them link to each other.
- `harness-builder` agent — Used by bootstrap mode to analyze codebases and recommend harness setup
- `/session-retro` — Session-side retrospective (documents the work, not the harness); run alongside retro mode
- `/documentation-writer` — Write scannable, progressive-disclosure docs
- `/skill-writer` — Authoring guidance for skills and agents; audit checks against what it teaches
- `/doctor` (bundled with Claude Code, alias `/checkup`) — Generic setup health: installation, PATH, unused skills, slow hooks, CLAUDE.md bloat. Audit invokes it rather than duplicating it
