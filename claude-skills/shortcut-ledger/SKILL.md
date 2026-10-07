---
name: shortcut-ledger
description: >-
  Collects every `shortcut:` comment in the codebase into a ledger of
  deliberate simplifications, each with its ceiling and the trigger for
  revisiting it, and flags the ones with no trigger. Use when grooming the
  backlog, when the user asks what shortcuts or deferred work the code
  carries, and before planning work in an area with marked shortcuts.
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scan-shortcuts.sh*), Bash(git blame *)
---

# Shortcut Ledger

The minimal-change skill marks deliberate simplifications with a comment:

```text
<comment> shortcut: <the ceiling> | revisit when <the trigger>
```

This collects them into one ledger, so a deferral can't quietly become
permanent. It reads and reports; it changes nothing.

## Scan

```bash
${CLAUDE_SKILL_DIR}/scan-shortcuts.sh [dir]
```

It greps for the marker after a comment leader (`#`, `//`, `--`, `/*`,
`<!--`), skipping Markdown and dependency and build folders; the groom skill
runs the same script. Requiring a comment leader keeps prose and config keys that merely contain
the word out of the ledger, and excluding Markdown keeps documentation that
shows example markers out. If your stack uses another comment leader (`;`,
`%`, `'`), extend the script's pattern.

## Report

One row per marker, grouped by file:

```text
src/locks.py:41  ceiling: one global lock  revisit when: write throughput matters
src/dedupe.ts:12 ceiling: O(n²) dedupe     revisit when: (none)  no-trigger
```

Tag a marker with no `| revisit when` as `no-trigger`: those rot first. For an
owner per row, add `git blame -L<line>,<line> <file>`. End with
`<N> shortcuts, <M> with no trigger`, or "No shortcuts marked." when the scan
finds none.

Done when every marker is a row and every row without a trigger is tagged.
Rows whose trigger has plainly fired, and `no-trigger` rows, are candidates
for issues; recommend them, and let the user decide what to file.
