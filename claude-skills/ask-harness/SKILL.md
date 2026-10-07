---
name: ask-harness
description: Find which skill or flow fits your situation, with a map of every harness-kit skill.
disable-model-invocation: true
---

# Ask Harness

You don't need to remember every skill. This is the map: one **main flow**
most work travels, the **on-ramps** that feed it, the lifecycle around pull
requests and issues, and the standalone tools. A name with a slash is one you
type to start (`/name` on Claude Code, `$name` on Codex); a bare name is one
the agent also picks up on its own when the task fits, and you can still ask
for it by name.

## The main flow: idea to merged change

1. **Align.** `/grill-with-docs` interviews you until every branch of the
   design is settled, and records the project's terms in `GLOSSARY.md` and
   hard-to-reverse decisions as ADRs. Use `/grill-me` when there's no repo to
   record into. Both run the `grilling` skill underneath.
2. **Settle what talk can't.** When a question needs a runnable answer, build a
   cheap throwaway artifact to react to with `prototype` (a state-model demo
   or UI variants; in a bigger effort, a wayfinder prototype ticket); when it
   needs outside facts, the `research` skill reads
   primary sources and cites them.
3. **Specify.** For work that spans sessions, `/to-spec` turns the
   conversation into a spec issue, and `/to-tickets` splits it into
   tracer-bullet sub-issues with blocking links. Small work skips straight to
   step 4.
4. **Build.** `/implement` takes one ticket test-first (`tdd`, `minimal-change`)
   to an open PR. `/implement-spec` builds a whole spec's tickets in parallel
   worktrees onto one integration branch.
5. **Ship.** `open-pr` simplifies the diff, writes the body (`pr-body`), runs
   the standards and spec review passes (`review-pr`, `code-reviewer`), and
   waits for CI.
6. **Improve the environment.** `/harness retro` looks back over the session
   for missing checks, standards, pointers, and access, and `/session-retro`
   records what the work itself taught. Run them in the session they look
   back on, before you clear it.

Keep steps 1 to 3 in one context window so the spec builds on the actual
reasoning; each `/implement` can then start fresh from its ticket. If the
window fills before `/to-tickets` (reasoning gets noticeably weaker past
roughly 150k tokens on current models), compact at the nearest phase boundary
rather than pushing on.

## On-ramps

- **Issues and PRs piling up from others**: `/triage` moves them through
  triage states to agent-ready briefs, which `/implement` later picks up.
  Tickets from `/to-tickets` are ready already.
- **Something's broken**: `diagnosing-bugs` builds a fast check that goes red
  on the bug before any theory, then fixes the root cause with a regression
  test.
- **The code has got hard to change**: `/improve-codebase-architecture`
  finds shallow modules worth deepening, shows them in a visual report, and
  grills through the one you pick.
- **Too big and foggy for one session**: `/wayfinder` charts a map of decision
  tickets and settles them one per session; when the way is clear, it hands
  off to `/to-spec`.

## Around pull requests and issues

| You want to | Use |
| --- | --- |
| Commit with the project's checks | `commit` |
| Open a PR and see it through review and CI | `open-pr` |
| Review a PR, or answer its review comments | `review-pr`; `/pr-comments` for a reply-only pass |
| Bring a branch up to date | `/rebase` |
| File, update, or close an issue | `issue-create`, `issue-update`, `issue-close` |
| Split or merge issues | `/issue-restructure` |
| Decide what to work on next | `/groom` (it also surveys `shortcut-ledger`) |
| Recap your day | `/standup` |
| Coordinate several agents or people | `agent-standup`; on Claude Code, `budget` before a big fan-out |

## Vocabulary underneath

- `domain-modeling`: sharpen the project's terms and record them.
- `codebase-design`: the deep-module vocabulary (module, interface, depth,
  seam) for shaping a module.

## Standalone

- `/to-questionnaire`: when the answer is in someone else's head, write them a
  questionnaire.
- `/wait-what`: the last message didn't land; re-explain it plainly.
- `/adhd-mode`: action-first responses for the rest of the session (on
  Claude Code, the ADHD output style does it without invoking anything).
- `/handoff`: move the work to another host, directory, or person.
- `/teach`: learn a topic over several sessions, with lessons and a record
  of what you've learned.
- `/loop-me` (experimental): find recurring work worth delegating and spec
  it as workflows.
- `ui-review`: accessibility and UX audit of web UI.
- `wizard`: a script that walks a person through steps only they can do,
  such as creating accounts and copying API keys into `.env` and CI secrets.
- `documentation-writer` and `/svg-logo-designer`: docs and logos.
- `skill-writer`, `/harness`, `/harness-builder`, `harness-issue`: maintain
  the harness itself.

## Between phases

At the boundary between two chunks of work (grilling done, implementation
done), choose how to carry on: continue, clear, hand off, send it to a
subagent, or compact. [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) has the
order to ask in and why. Mid-phase, keep going or split the rest into
subagents.
