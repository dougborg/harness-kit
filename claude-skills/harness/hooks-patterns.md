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

**Schema reference:** For the correct shape of plugin `hooks/hooks.json` (including the common plugin-vs-`settings.json` gotcha), see `${CLAUDE_SKILL_DIR}/hooks-reference.md`. Validate locally with `just validate-hooks`.

## PostToolUse Hooks: 3-Stage Pattern

Configure in `.claude/settings.local.json` to auto-fix on every file edit.
Hooks on the same event run in parallel, so one script runs the three stages
in order:

1. **Formatter**: silent and zero-token. It rewrites the file on disk after
   the edit; Claude sees the result the next time it reads the file. Examples:
   `nix run ".#format"`, `prettier --write`, `ruff check --fix`. Never ask
   users to fix lint by hand.
2. **Validator**: bounded output (30 lines at most), only for files it
   applies to. Report real errors, not noise.
3. **Guidance**: short context reminders (20 lines at most), such as "this
   touches auth, see domain-advisor".

A command hook reads its input as JSON on stdin (the edited path is
`.tool_input.file_path`); there is no `{file_path}` substitution. Its plain
stdout, and its stderr on exit 0, go only to the debug log, so validator and
guidance output must be returned as
`{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "..."}}`.
Exit 2 sends stderr to Claude as an error instead; it blocks nothing, since
the tool has already run. The harness-builder agent's recommendations
reference has a worked script.

## Stop Hooks

A Stop hook's plain stdout also goes only to the debug log. To show the user
a note without making the agent carry on, print
`{"systemMessage": "..."}`; `additionalContext` would make the agent continue
instead. The harness-kit plugin ships a retro nudge, `scripts/shared/retro-nudge.sh`:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/shared/retro-nudge.sh\""
      }
    ]
  }
]
```

After a session that touched more than three files (unstaged, staged, or
committed in the last four hours), it suggests the harness skill's retro mode
to capture learnings before context is lost. Stop fires after every turn,
so the script shows the nudge once per session, keyed on the hook input's
`session_id`. Projects override it in
`.claude/settings.local.json` only if they want different behavior.

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

So put rules that general-purpose and custom agents need in `CLAUDE.md` or `AGENTS.md`, and pass anything `Explore` or `Plan` must know in the prompt you dispatch them with. When a rule has to be injected by a hook (it is dynamic, or computed at start), pair the `SessionStart` hook with a `SubagentStart` hook. `SubagentStart` takes a `matcher` on the agent type (`general-purpose`, `Explore`, a plugin agent name) and cannot block the subagent.

Codex differs in one way: a spawned agent copies the parent's conversation by default. Verified on codex-cli 0.160 (2026-10-07) with the same three-codeword test, run through `codex exec`. "In the copied history" means the spawned agent sees the main session's earlier context, not a fresh injection:

| Source | Main session | Spawned agent, default (`fork_turns: "all"`) | Spawned agent, `fork_turns: "none"` |
| --- | --- | --- | --- |
| `SessionStart` hook output | Yes | Yes (in the copied history) | No |
| `SubagentStart` hook `additionalContext` | — | Yes | Yes |
| `AGENTS.md` | Yes | Yes | Yes |

So the same rule holds: put what every agent needs in `AGENTS.md`, or inject it with `SubagentStart`, and don't rely on `SessionStart` reaching a spawned agent. `SubagentStart` matches on `agent_type` and cannot block the agent, per the [hooks docs](https://learn.chatgpt.com/docs/hooks).

On codex-cli 0.160, Codex runs a hook only after it is trusted, and this applies to user-level hooks in `~/.codex/` as well as project hooks in `.codex/hooks.json` (which also need the project's `.codex/` layer trusted). Review and trust them once in an interactive session. For a one-off test in a throwaway `CODEX_HOME`, `codex exec --dangerously-bypass-hook-trust` runs them without stored trust.

## Why This Matters

- Formatters fix files silently → zero tokens, no suggestion waste
- Tests and linters enforce rules; harness provides guidance
- Stop hooks capture learnings that would otherwise be lost between sessions
- Users only see real problems and useful guidance, never pedantic style issues

Use `/documentation-writer` and `/skill-writer` to create well-structured docs that scale context-efficiently. Update CLAUDE.md with an "Automation Philosophy" section documenting this approach.
