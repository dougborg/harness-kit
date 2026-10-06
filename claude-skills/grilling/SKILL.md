---
name: grilling
description: >-
  Interviews the user relentlessly about a plan, design, decision, or idea
  until every branch of the decision tree is resolved and nothing is silently
  assumed. Use when the user says "grill me" or wants to stress-test their
  thinking, before building something whose requirements are still fuzzy, and
  when another skill needs a structured interview.
---

# Grilling

Interview the user until you share an understanding of the plan. Map it as a
**design tree**: each decision branches into the decisions that hang off it.

## Work the tree in rounds

The **frontier** is every decision whose prerequisites are already settled:
the questions you can ask now without guessing at answers you haven't heard.
Ask the whole frontier in one round, give your recommended answer for each,
then wait. A question that depends on another question still open in this
round belongs to a later round.

A round is done when every question in it has an answer, or the user has
explicitly deferred it. Each round reshapes the tree: settled decisions push
the frontier outward and unblock what depended on them. Recompute the frontier
and ask the next round.

## Facts are yours; decisions are the user's

When a frontier question needs a fact from the environment (the code, the
docs, a config value, how a tool behaves), find it yourself, by reading or by
dispatching a subagent. Only the questions downstream of a running lookup
wait for it; ask the rest of the frontier now. Put every decision to the user
and wait for their answer. An interview is the one place where asking is the
work: the harness rule to ask only when necessary still holds for facts, never
for the decisions themselves.

## Asking a round

**Claude Code:** ask through `AskUserQuestion`. Each call takes up to 4
questions, each with a short header and 2-4 options, and the user can always
type their own answer instead. Put your recommended answer first, labelled
"(Recommended)", and make the other options genuinely different directions;
when more than 4 candidates exist, offer the strongest 4. The call waits for
the answers, so:

- Write any question with no sensible preset answers (a name, a number, a
  free-form constraint) as plain text in the same message, before the call,
  and collect its answer alongside the picker's.
- A round with more than 4 picker questions takes consecutive calls; ask the
  most consequential questions first.

If `AskUserQuestion` is unavailable (a headless run, a subagent, or the user
declined it), use the plain-text format below.

**Codex and other hosts:** ask the round as numbered plain text:

```text
Q1 — <question title>: <question, with the options if there are any>
   Recommended: <your answer and the one-clause reason>

Q2 — ...
```

## Done

The session is done when the frontier is empty: every branch visited, and
every assumption you are relying on has been stated to the user and confirmed
or corrected. Summarize the decisions, and act on them only after the
user confirms the summary matches their understanding.
