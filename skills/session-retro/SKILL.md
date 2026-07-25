---
name: session-retro
description: Capture a work session as a structured retro doc in docs/sessions/
disable-model-invocation: true
allowed-tools: Bash(git log*), Bash(git config*), Bash(gh issue*), Bash(gh pr*), Bash(gh search*), Bash(ls*), Read, Glob, Write
---

# /session-retro — Session Retrospective Document

Walk through the current session and produce a permanent cause-and-effect record:
what the user set out to do, what happened, what worked, what didn't, and what
issues came out of it.

## PURPOSE

Capture live-session learnings as a structured doc plus pending-issue checklist.

## CRITICAL

- **Audits the session, not the harness** — harness gaps go to `/harness retro`; run both at end-of-session
- **Never invent activity** — every entry must trace to conversation context, `git log`, or `gh` output
- **Respect the project's docs layout** — default `docs/sessions/`, but follow existing conventions

## ASSUMES

- You're in a git repository; `gh` is installed and authenticated
- The session's conversation context is available (it is the primary source for chronology and observations)

## STANDARD PATH

### 1. Reconstruct the Session

Combine conversation context with recorded activity. Use the session start time
(or "today") as the window:

```bash
git log --since="8 hours ago" --oneline --author="$(git config user.email)"
gh issue list --author="@me" --state=all --search "created:>=$(date +%Y-%m-%d)"
gh pr list --author="@me" --state=all --search "created:>=$(date +%Y-%m-%d)"
```

### 2. Draft the Doc

Write `docs/sessions/YYYY-MM-DD-<slug>.md` (slug = 2-4 word kebab-case session
theme) using DETAIL: Output Template. Sections: Goal, What happened, What
worked, What didn't, Issues filed, Lessons / patterns.

### 3. Pending-Issues Checklist

List observations from the session that deserve an issue but haven't been filed
yet, as a `- [ ]` checklist at the end of the doc. Offer to file each via
`/issue-create` (project issues) or `/harness-issue` (harness gaps).

### 4. Close the Loop

Show the doc to the user, then suggest `/harness retro` if it hasn't run yet —
the two together capture both the work and the tooling learnings.

## EDGE CASES

- [No docs/ directory or different layout] — read DETAIL: Output Location
- [Session spans days or start unclear] — read DETAIL: Session Window
- [Overlap with /harness retro findings] — read DETAIL: Composition with /harness retro

---

## DETAIL: Output Template

```markdown
# Session YYYY-MM-DD — <one-line session theme>

## Goal

What the user was trying to do, in one or two sentences.

## What happened

1. Chronological narrative of agent + user actions — shipped changes,
   live testing, bugs surfaced (with issue links), decisions made.

## What worked

- Patterns that earned their keep (workflows, tools, review passes).

## What didn't

- Bugs surfaced, agent fall-backs (e.g. "gave up and went to the browser"),
  confusing UX, wrong guidance from skills.

## Issues filed

- [#NNN](link) — one-line description (repeat per issue/PR from this session)

## Lessons / patterns

- Generalizable observations for future sessions.

## Pending issues

- [ ] Observation still needing an issue — file with /issue-create
```

---

## DETAIL: Output Location

Default is `docs/sessions/`. Before writing, check the project's actual layout:

- If docs live elsewhere (`documentation/`, `doc/`, a wiki directory), put
  `sessions/` under that root instead.
- If a session/journal/log directory already exists (e.g. `docs/journal/`,
  `notes/sessions/`), use it and match its filename convention.
- Only create `docs/sessions/` when nothing comparable exists.

---

## DETAIL: Session Window

The conversation context defines the session, not the clock. If the session
spans midnight or resumed from a previous day, widen `--since` to cover the
real start, and date the doc by the day the session ended. If multiple distinct
sessions happened today, scope the doc to the current one and note the others
under "What happened" only if they fed into it.

---

## DETAIL: Composition with /harness retro

The two retros are complements, run back-to-back at end-of-session:

| | `/session-retro` | `/harness retro` |
| --- | --- | --- |
| Audits | The session's work | The harness (skills/agents/hooks) |
| Output | `docs/sessions/` doc + project issues | Harness fixes + harness-kit issues |

A finding can surface in both: "the agent fell back to the browser" is a
session fact (record it under *What didn't*) and possibly a harness gap (let
`/harness retro` classify and route it). Record here; route there.

---

## RELATED

- `/harness retro` — harness-side retrospective; run both at end-of-session
- `/standup` — daily activity summary (report, not a permanent doc)
- `/issue-create` — file project issues from the pending checklist
- `/harness-issue` — file harness gaps upstream
