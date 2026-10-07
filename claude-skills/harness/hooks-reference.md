# Plugin Hooks Reference

Schema, event types, and patterns for writing Claude Code plugin `hooks.json`.

> ⚠ **Plugin `hooks.json` is NOT the same shape as `settings.json` hooks.**
>
> The most common mistake — and the one that bit harness-kit itself in v0.1.0 and v0.2.0 — is copying the `hooks` key contents from `settings.json` directly into `hooks/hooks.json`. The plugin format wraps everything in a top-level `"hooks"` key.
>
> If Claude Code reports `Hook load failed: expected 'record' at path ['hooks'], received undefined` at plugin load time, you're hitting this bug.

## Contents

- [Schema Shape](#schema-shape)
- [Manifest Registration](#manifest-registration)
- [Event Types](#event-types)
- [Matcher Syntax](#matcher-syntax)
- [Variable Substitution](#variable-substitution)
- [Hook Output](#hook-output)
- [Exit Code Safety](#exit-code-safety)
- [The 3-Stage PostToolUse Pattern](#the-3-stage-posttooluse-pattern)
- [Fully Worked Example](#fully-worked-example)
- [Local Testing](#local-testing)
- [Validation in CI](#validation-in-ci)
- [Related](#related)

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
| `Stop` | When Claude finishes responding | No |
| `SubagentStart` | When a subagent is spawned | Yes (agent type) |
| `SubagentStop` | When a spawned subagent ends | Yes (agent type) |
| `SessionStart` | When a session begins or resumes | Yes (`startup`, `resume`, `clear`, `compact`, `fork`) |
| `Notification` | When a notification would be shown | Yes (notification type) |
| `PreCompact` | Before context compaction | Yes (`manual`, `auto`) |

## Matcher Syntax

For `PreToolUse` and `PostToolUse`, the `matcher` field is a regex against the tool name; other events match their own field, as the table shows. Common patterns:

```json
"matcher": "Edit|Write"           // either Edit or Write tool
"matcher": "Bash"                  // only Bash
"matcher": ".*"                    // everything (equivalent to omitting the field)
```

Events without matcher support (`Stop`, `UserPromptSubmit`, etc.) omit the `matcher` field entirely.

## Variable Substitution

Inside a `command` string, these placeholders expand at runtime:

- **`${CLAUDE_PLUGIN_ROOT}`**: the plugin's install directory. Use it for any
  path inside your plugin, quoted in case the path has spaces:

  ```json
  "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh\""
  ```

- **`${CLAUDE_PLUGIN_DATA}`**: a persistent data directory for the plugin.
- **`${CLAUDE_PROJECT_DIR}`**: the project root, for hooks in
  `.claude/settings*.json`.

There is no `{file_path}` or other per-event substitution. A command hook
gets the event as JSON on stdin; read the edited path with
`jq -r '.tool_input.file_path // empty'`.

## Hook Output

Where a hook's output goes depends on the event:

- **Plain stdout** reaches Claude's context only for `SessionStart`,
  `UserPromptSubmit`, `UserPromptExpansion`, and `PostModelSwitch`. For `PostToolUse`, `Stop`, and most other events it
  goes only to the debug log, as does stderr on exit 0.
- **`additionalContext`** in `hookSpecificOutput` adds text to Claude's
  context. On `Stop`, it makes Claude continue the turn.
- **`systemMessage`** shows a note to the user without changing what Claude
  does.

Audit rule: a `PostToolUse` or `Stop` hook whose only output is plain stdout
never reaches anyone.

## Exit Code Safety

Exit 0 is success. Exit 2 is the feedback code: stderr goes to Claude, and on
`PreToolUse` the tool call is blocked; on `PostToolUse` nothing is blocked,
since the tool has already run. Any other non-zero exit is a non-blocking
error shown in the transcript. Common pitfall: `[ cond ] && action` exits 1
when the condition is false. Use `if [ cond ]; then action; fi` instead, or
append `|| true`.

Audit rule: for every hook command, ask "what happens when this has nothing to do?" If the answer is "it exits non-zero," it needs fixing.

## The 3-Stage PostToolUse Pattern

Hooks on the same event run in parallel, so one script runs the stages in
order: **Formatter → Validator → Guidance**.

1. **Formatter**: silent, zero-token cost. Rewrites the file on disk after
   the edit. (e.g. `prettier --write`, `ruff format`)
2. **Validator**: bounded output (30 lines at most), only for files it
   applies to. Surface real errors only. (e.g. `typecheck`, `test`)
3. **Guidance**: context reminders (20 lines at most). (e.g. "this touches
   auth, see domain-advisor")

The script returns validator and guidance output as `additionalContext`. The
harness skill's hooks-patterns reference has the full rationale, and the
harness-builder agent's recommendations reference a worked script.

## Fully Worked Example

This is the correct shape of `hooks/hooks.json` for a plugin with a formatter hook on Edit/Write and a session-end reminder. The reminder script prints `{"systemMessage": "..."}`, since a Stop hook's plain stdout is never shown:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/shared/markdownlint-fix.sh\""
          }
        ]
      }
    ],
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

harness-kit ships `scripts/shared/validate-hooks-schema.sh` — a minimal `jq`-based check that enforces the top-level `hooks` object shape and ensures each event value is an array. Run it via `just validate-hooks` or as part of `just check`.

This check would have caught both v0.1.0 and v0.2.0 releases before they shipped.

## Related

- The harness skill — its audit, update, and bootstrap flows link this doc, alongside its hooks-patterns reference (hook staging and exit-code safety)
- The `harness-builder` agent — stack-detection-driven hook recommendations
- [Claude Code docs: hooks](https://code.claude.com/docs/en/hooks.md)
- [Claude Code docs: plugins reference](https://code.claude.com/docs/en/plugins-reference.md)
