---
name: grilling
description: >-
  Interviews the user relentlessly about a plan, design, decision, or idea
  until every branch of the decision tree is resolved and nothing is silently
  assumed. Use when the user wants to stress-test their thinking or be
  "grilled", before building something whose requirements are still fuzzy, and
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

Each round reshapes the tree: settled decisions push the frontier outward and
unblock what depended on them. Recompute the frontier and ask the next round.

## Facts are yours; decisions are the user's

When a frontier question needs a fact from the environment (the code, the
docs, a config value, how a tool behaves), find it yourself, by reading or by
dispatching a subagent. Only the questions downstream of a running lookup
wait for it; ask the rest of the frontier now. Put every decision to the user
and wait for their answer.

## Asking a round

**Claude Code:** ask through `AskUserQuestion`. It takes up to 4 questions per
call and 2-4 options per question, and the user can always type their own
answer instead. Put your recommended answer first, labelled
"(Recommended)", and make the other options genuinely different directions. A
round with more than 4 questions becomes several calls in the same round. A
question with no sensible preset answers (a name, a number, a free-form
constraint) goes in plain text after the tool call.

**Codex and other hosts:** ask the round as numbered plain text:

```text
Q1 — <question title>: <question, with the options if there are any>
   Recommended: <your answer and the one-clause reason>

Q2 — ...
```

## Done

The session is done when the frontier is empty: every branch visited, nothing
left silently assumed. Summarize the decisions, and act on them only after the
user confirms the summary matches their understanding.
