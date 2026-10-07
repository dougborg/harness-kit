---
name: session-retro
description: Capture a work session as a structured retro doc in docs/sessions/
allowed-tools: Bash(git log*), Bash(git config*), Bash(gh issue*), Bash(gh pr*), Bash(gh search*), Bash(ls*), Read, Glob, Write
disable-model-invocation: true
---

# Session Retro

Turn the current session into a permanent cause-and-effect record: what the
user set out to do, what happened, what worked, what didn't, and which issues
came out of it.

This audits the session's work and produces a doc plus project issues. The
harness itself (skills, agents, hooks, checks, steering files, tools) is the
harness skill's retro mode, which produces harness fixes and harness-kit
issues. The two are complements, best run back-to-back at the end of a
session.

Every entry traces to the conversation, `git log`, or `gh` output. Invent no
activity: a retro that records what didn't happen teaches the wrong lesson.

## 1. Reconstruct the session

The conversation is the primary source for chronology and observations, and
it defines the session, not the clock. Back it with the recorded activity,
using the session's start (or today) as the window:

```bash
git log --since="8 hours ago" --oneline --author="$(git config user.email)"
gh issue list --author="@me" --state=all --search "created:>=$(date +%Y-%m-%d)"
gh pr list --author="@me" --state=all --search "created:>=$(date +%Y-%m-%d)"
```

If the session crossed midnight or resumed from an earlier day, widen
`--since` to the real start. If several distinct sessions happened today,
scope the doc to this one, mentioning the others under "What happened" only
where they fed into it.

Done when every event you plan to record traces to the conversation or to
this output.

## 2. Pick the location

Default to `docs/sessions/YYYY-MM-DD-<slug>.md`, where the slug is a
two-to-four word kebab-case theme, dated by the day the session ended. Check
the project's layout first (`ls`):

- If docs live elsewhere (`documentation/`, `doc/`, a wiki directory), put
  `sessions/` under that root.
- If a session, journal, or log directory already exists (`docs/journal/`,
  `notes/sessions/`), use it and match its filename convention.
- Create `docs/sessions/` only when nothing comparable exists.

Done when you have a path that follows the project's convention.

## 3. Write the doc

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

- [ ] Observation still needing an issue — file with issue-create
```

"Pending issues" lists observations that deserve an issue but haven't been
filed. A finding can belong to both retros: "the agent fell back to the
browser" is a session fact, so record it under "What didn't", and leave it to
the harness retro to classify and route as a possible harness gap.

Done when every section is filled or explicitly empty, and the doc is
written.

## 4. Close the loop

Show the user the doc and offer to file the pending issues. For each one they
pick, call the Skill tool with "issue-create" for a project issue, or with
"harness-issue" for a harness gap. If the harness retro hasn't run this
session, suggest the user run it (`/harness retro` on Claude Code,
`$harness retro` on Codex), so the work and the tooling lessons are both
captured.

Done when the user has seen the doc, each pending issue they chose is filed,
and the harness retro has run or been suggested.

## Related

- `harness` retro mode — the harness-side retrospective.
- `standup` — a daily activity report, not a permanent doc.
- `issue-create` — files project issues from the pending checklist.
- `harness-issue` — files harness gaps upstream.
