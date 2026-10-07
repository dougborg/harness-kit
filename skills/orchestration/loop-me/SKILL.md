---
name: loop-me
description: "Experimental: find the recurring work worth delegating, and grill you into workflow specs for it."
---

# Loop Me

Experimental: ported from an upstream skill still in progress, so expect the
shape to change.

Run a stateful interview whose only output is **workflow** specs. Call the
Skill tool with "grilling" and aim it at the vocabulary and goal below.
Create, edit, and delete specs as the grilling settles things.

## The loop lens

A **loop** is a recurring pattern in the user's life: their career, their
week, their morning, one repeated activity. Seeing a life as loops within
loops shows how predictable its activities are, and predictable work is worth
**delegating**. Use the lens to find loops worth specifying, and propose ones
the user hasn't noticed.

A **workflow** is the spec of one loop. You run a workflow on a loop: the
loop is its running instance.

## Vocabulary

Reach for these only when a workflow needs them; they are a shared language,
not a checklist. A workflow needs no AI, no checkpoint, and no schedule
unless the grilling shows it does.

- **Trigger**: what starts each run, an **event** (a new email, a new issue)
  or a **schedule** (every morning). An event trigger is usually the more
  efficient.
- **Checkpoint**: a point where the user verifies or decides. Some workflows
  run with none.
- **Push right**: put the checkpoint as late as it will go, so the user is
  asked once, with everything prepared.
- **Brief**: what a checkpoint shows, a decision-ready summary (what was
  produced, why, and a link to the thing itself), never the raw output.
  Review speed is the point.

## The workspace

The current directory is the workspace.

- `workflows/*.md`: one spec per workflow, the source of truth.
- `NOTES.md`: the user's world: the tools they use, the channels they
  process, and their own names for both. Record each fuzzy term as its
  canonical name as it is sharpened.

## Run a session

1. **Map the user's world.** Read `NOTES.md`. When it is empty or thin,
   interview the user about their tools and channels before specifying
   anything. Done when `NOTES.md` names the tools and channels the candidate
   loops run through.
2. **Find the loops.** If the user named a workflow, start there. Otherwise
   use the loop lens to list candidates, including ones the user hasn't
   noticed, and let them pick. Done when the user has chosen the loop to
   specify.
3. **Write the spec.** Grill the chosen loop into `workflows/<name>.md`,
   editing or deleting existing specs as answers change them. Done when an
   agent could build the workflow without asking a single question.

Building and scheduling the workflow is a separate job; this skill stops at
the spec.
