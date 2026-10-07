# Phase boundaries

A **phase** is a chunk of work inside a session: the grilling, the
implementation, the QA. It ends when you think "done with that". The gap
between two phases is the only place to decide how to carry on; mid-phase,
continue, or split what's left into subagents. Compacting mid-phase makes the
agent lose the thread.

## Ask in this order; the first yes wins

1. **Can you continue?** Yes when the next phase needs this one as a primary
   source (grilling into implementation wants the reasoning verbatim, not a
   summary), or when there's comfortably enough room left in the context
   window. Continuing costs nothing and loses nothing, so rule it out first.
2. **Is this context irrelevant to what comes next?** Then clear it (`/clear`
   on Claude Code, a new session on Codex). It's the cheapest move, and the
   old session stays resumable. Clearing a context that mattered loses the
   why behind what you built, and reading the diff won't bring it back.
3. **Is the work moving?** To another host, another directory or repo, another
   person, or a side task split off mid-phase: run the handoff skill. What it
   buys is portability; if nothing is moving, you don't need it.
4. **Can the next task run unattended?** Then give it to a subagent and keep
   this session as it is. An automated review is the standard case.
5. **Otherwise, compact** (`/compact` on both hosts), with an instruction about
   what comes next (`/compact we're about to QA the export flow`), so the
   summary keeps what that phase needs.

Compacting is the default, not the first reach: the four questions above are
cheaper or more precise. Starting there gives a fresh session that is
confidently wrong about a decision the summary flattened.

## Why continuing comes first

Every move except continuing turns a primary source (the session as it
happened) into a secondary one (a summary of it): less noise and more room,
but lossy. Pay that loss only when staying costs more than it saves.

These are judgement calls; the value is in asking them in order, at the
boundary.
