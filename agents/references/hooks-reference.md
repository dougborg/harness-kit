# Plugin Hooks Reference

Schema, event types, and patterns for writing Claude Code plugin `hooks.json`.

> ⚠ **Plugin `hooks.json` is NOT the same shape as `settings.json` hooks.**
>
> The most common mistake — and the one that bit harness-kit itself in v0.1.0 and v0.2.0 — is copying the `hooks` key contents from `settings.json` directly into `hooks/hooks.json`. The plugin format wraps everything in a top-level `"hooks"` key.
>
> If Claude Code reports `Hook load failed: expected 'record' at path ['hooks'], received undefined` at plugin load time, you're hitting this bug.

## Schema Shape

Plugin `hooks.json` is a **dedicated file** whose entire root object is `{"hooks": { ... }}`. Inside the `hooks` key, the shape is the same as `settings.json`'s `hooks` value — event types map to arrays of matcher/handler entries.

**Rule of thumb:** a valid plugin `hooks.json` has exactly one top-level key: `"hooks"`.

### Valid

```json
{
  "hooks": {
    "<EventType>": [
      {
        "matcher": "<optional-matcher>",
        "hooks": [
          {
            "type": "command",
            "command": "<shell-command>"
          }
        ]
      }
    ]
  }
}
```

### The bug we keep hitting

Dropping the outer `hooks` wrapper and putting event types at the root — this is the shape `settings.json`'s `hooks` value takes, but at the root of `hooks.json` it's wrong:

```json
{
  "PostToolUse": [],
  "Stop": []
}
```

Claude Code loads this and reports `Hook load failed: expected 'record' at path ['hooks'], received undefined`. Run `just validate-hooks` locally to catch this before release.

## Manifest Registration

Hooks have *additive* semantics across plugin sources, unlike `skills`/`agents`/`commands` where a custom path in `plugin.json` *replaces* the default. This means a `hooks` field in `plugin.json` adds to (not replaces) the file auto-discovered at `hooks/hooks.json`.

### The duplicate-registration trap

Declaring `"hooks": "./hooks/hooks.json"` in `plugin.json` **and** placing the file at the auto-discovery path `hooks/hooks.json`. Both registrations load, Claude Code reports `Duplicate hooks file detected`, and refuses to load the plugin.

**Rule of thumb:** never set the `hooks` field in `plugin.json` if the file lives at the conventional `hooks/hooks.json` path. Pick one — and auto-discovery is the canonical choice. `validate-hooks-schema.sh` enforces this on every `just check`.

## Event Types

| Event | When it fires | Matcher support |
| --- | --- | --- |
| `PreToolUse` | Before a tool is invoked | Yes (tool name regex) |
| `PostToolUse` | After a tool completes | Yes (tool name regex) |
| `UserPromptSubmit` | When the user sends a prompt | No |
| `UserMessageSubmit` | Synonym variant in some versions | No |
| `Stop` | When the session/turn ends | No |
| `SubagentStop` | When a spawned subagent ends | No |
| `SessionStart` | When a session begins | No |
| `Notification` | When a notification would be shown | No |
| `PreCompact` | Before automatic context compaction | No |

## Matcher Syntax

For `PreToolUse` and `PostToolUse`, the `matcher` field is a regex against the tool name. Common patterns:

```json
"matcher": "Edit|Write"           // either Edit or Write tool
"matcher": "Bash"                  // only Bash
"matcher": ".*"                    // everything (equivalent to omitting the field)
```

Events without matcher support (`Stop`, `UserPromptSubmit`, etc.) omit the `matcher` field entirely.

## Variable Substitution

Inside a `command` string:

- **`${CLAUDE_PLUGIN_ROOT}`** — expands to the plugin's cache directory at runtime. Use this for any path inside your plugin:

  ```json
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh"
  ```

- **`{file_path}`** — for `PostToolUse` hooks matching `Edit|Write`, substitutes the path of the file that was just edited:

  ```json
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh {file_path}"
  ```

## Exit Code Safety

Claude Code treats any non-zero exit code from a hook as a failure. Common pitfall: `[ cond ] && action` exits 1 when the condition is false. For the full rundown (common patterns, fixes, audit rule), see `skills/harness/SKILL.md` → `DETAIL: Hook Exit Code Safety`.

## The 3-Stage PostToolUse Pattern

When writing multiple `PostToolUse` hooks, order them as **Formatters → Validators → Guidance**:

1. **Formatters** — silent, zero-token cost. Fix issues before Claude reads the file. (e.g. `prettier --write`, `ruff format`)
2. **Validators** — bounded output (≤30 lines), gated with conditions. Surface real errors only. (e.g. `typecheck`, `test`)
3. **Guidance** — context reminders (≤20 lines). Nudge the developer with domain info. (e.g. "this touches auth — see domain-advisor")

See `skills/harness/SKILL.md` → `Automation-First Hooks` for the full rationale.

## Fully Worked Example

This is the correct shape of `hooks/hooks.json` for a plugin with a formatter hook on Edit/Write and a session-end reminder:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/skills/shared/markdownlint-fix.sh {file_path}"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "if [ \"$(git diff --name-only | wc -l)\" -gt 3 ]; then echo '💡 Large session — consider /harness retro'; fi"
          }
        ]
      }
    ]
  }
}
```

## Local Testing

Before publishing a plugin, test it locally:

```bash
# Load the plugin from a path without installing it
claude --plugin-dir /path/to/your-plugin

# Inside the session, verify hooks are registered
/plugin list

# See detailed plugin load diagnostics
claude --debug
```

If hooks fail to load, `claude --debug` surfaces the exact error, including the schema path that's wrong (e.g. `path: ['hooks']`).

## Validation in CI

harness-kit ships `skills/shared/validate-hooks-schema.sh` — a minimal `jq`-based check that enforces the top-level `hooks` object shape and ensures each event value is an array. Run it via `just validate-hooks` or as part of `just check`.

This check would have caught both v0.1.0 and v0.2.0 releases before they shipped.

## Related

- `skills/harness/SKILL.md` — harness audit/update/bootstrap flows reference this doc
- `agents/harness-builder.md` — stack-detection-driven hook recommendations
- [Claude Code docs: hooks](https://code.claude.com/docs/en/hooks.md)
- [Claude Code docs: plugins reference](https://code.claude.com/docs/en/plugins-reference.md)
