# Hook Patterns

Automation-first hook staging, the Stop-hook retro nudge, and exit-code safety. Applies to hooks configured in `.claude/settings.local.json` and to plugin `hooks/hooks.json`.

## Contents

- [Principle](#principle)
- [PostToolUse Hooks: 3-Stage Pattern](#posttooluse-hooks-3-stage-pattern)
- [Stop Hooks](#stop-hooks)
- [Hook Exit Code Safety](#hook-exit-code-safety)
- [Context Injection and Subagents](#context-injection-and-subagents)
- [Why This Matters](#why-this-matters)

## Principle

Don't ask users to do things we can automate.

**Schema reference:** For the correct shape of plugin `hooks/hooks.json` (including the common plugin-vs-`settings.json` gotcha), see `<skill-dir>/hooks-reference.md`. Validate locally with `just validate-hooks`.

## PostToolUse Hooks: 3-Stage Pattern

Configure in `.claude/settings.local.json` to auto-fix on every file edit:

1. **Formatters** (stage 1) — Silent, zero-token cost
   - Run formatters auto-fix before Claude sees edited files
   - Examples: `nix run ".#format"`, `prettier --write`, `ruff check --fix`
   - Never ask users to fix linting errors manually

2. **Validators** (stage 2) — Bounded output (≤30 lines), gated with conditions
   - Check for errors after formatting
   - Examples: `nix flake check`, `type checking`, `test running`
   - Only show real problems, not noise
   - Use conditions to surface only relevant checks

3. **Guidance** (stage 3) — Context reminders (≤20 lines)
   - Orient developers with skill/doc references
   - Examples: "Check CLAUDE.md for domain constraints", "This touches auth — see domain-advisor"
   - Always helpful, never noisy

## Stop Hooks

Configure session-end hooks for retrospective nudges:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "changed=$( { git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null; git log --diff-filter=ACMR --name-only --pretty=format: --since='4 hours ago' 2>/dev/null; } | sort -u | wc -l | tr -d ' '); if [ \"$changed\" -gt 3 ]; then echo \"💡 Session touched $changed files — consider /harness retro to capture learnings\"; fi"
      }
    ]
  }
]
```

**Purpose:** After large sessions (>3 files changed), remind the user to run `/harness retro` to capture learnings before context is lost. Counts unstaged, staged, and recently committed files to capture the full session scope.

**Note:** This hook is provided by the harness-kit plugin. Projects only need to override it in `.claude/settings.local.json` if they want different behavior.

## Hook Exit Code Safety

Claude Code treats any non-zero exit code from a hook as a failure. This is a common pitfall with conditional hooks — the command works correctly but reports an error.

**The problem:**

```bash
# BAD: exits 1 when condition is false ([ ] returns 1, && short-circuits)
[ "$changed" -gt 3 ] && echo "message"
```

**The fix — use `if/then/fi`:**

```bash
# GOOD: if/then/fi always exits 0 when condition is false
if [ "$changed" -gt 3 ]; then echo "message"; fi
```

**Alternative — append `|| true`:**

```bash
# OK: forces exit 0, but less readable
[ "$changed" -gt 3 ] && echo "message" || true
```

**Audit rule:** For every hook command, ask: "What happens when this has nothing to do?" If the answer is "it exits non-zero," it needs fixing.

**Common patterns that silently fail:**

| Pattern | Problem | Fix |
| --- | --- | --- |
| `[ test ] && action` | Exit 1 when test is false | `if [ test ]; then action; fi` |
| `grep pattern file` | Exit 1 when no match | `grep pattern file \|\| true` |
| `command \| head -1` | Exit 141 (SIGPIPE) on some systems | Pipe to `head -1 \|\| true` |

## Context Injection and Subagents

Context a `SessionStart` hook injects reaches the main session only. Subagents start later with their own context, so they never see it. Verified on Claude Code 2.1.289 (2026-10-06) with a codeword test: each source injected a different codeword and each kind of agent was asked to list what it saw. The [sub-agents docs](https://code.claude.com/docs/en/sub-agents.md) agree.

| Source | Main session | Subagent |
| --- | --- | --- |
| `SessionStart` hook output | Yes | No |
| `SubagentStart` hook `additionalContext` | — | Yes |
| `CLAUDE.md` / `AGENTS.md` | Yes | General-purpose and custom agents: yes. Built-in `Explore` and `Plan`: no |

So put rules that general-purpose and custom agents need in `CLAUDE.md` or `AGENTS.md`, and pass anything `Explore` or `Plan` must know in the prompt you dispatch them with. When a rule has to be injected by a hook (it is dynamic, or computed at start), pair the `SessionStart` hook with a `SubagentStart` hook. `SubagentStart` takes a `matcher` on the agent type (`general-purpose`, `Explore`, a plugin agent name) and cannot block the subagent. Codex behaviour is not yet verified.

## Why This Matters

- Formatters fix before Claude reads → zero tokens, no suggestion waste
- Tests and linters enforce rules; harness provides guidance
- Stop hooks capture learnings that would otherwise be lost between sessions
- Users only see real problems and useful guidance, never pedantic style issues

Use `/documentation-writer` and `/skill-writer` to create well-structured docs that scale context-efficiently. Update CLAUDE.md with an "Automation Philosophy" section documenting this approach.
