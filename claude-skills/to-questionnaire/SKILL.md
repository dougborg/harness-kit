---
name: to-questionnaire
description: >-
  Turn a decision you can't make alone into a questionnaire for the one person
  who can answer it, filled in async or together in a meeting.
disable-model-invocation: true
---

# To Questionnaire

Turn something the user can't answer alone into a Markdown **questionnaire**
for one recipient who holds the missing knowledge. Interview the user only
about the **send** (who it is for and what they need back), which they can
always answer. The questions in the document then aim at the **gap** between
what the recipient knows and what the user needs.

## 1. Who is it for?

Ask for the recipient's role, expertise, and relationship to the user, in one
exchange. Done when you know who they are and what they know that the user
doesn't; that fixes the tone and how much context the document must carry.

## 2. What do you need back?

Ask for the specific decisions or facts the user can't settle alone. Done when
you have a concrete list of what the user must be able to decide or do once
the answers come back.

## 3. Write it

Write `to-questionnaire-<topic-slug>.md` in the current directory with the
template below and report its path. Done when the file exists and every item
from step 2 is covered by a question.

Order questions most important first, since an async recipient may give you
one pass, and group them under themed headings once there are more than a
handful. Each question asks one thing, with an answer stub beneath it. Add a
one-line reason only where the question could be misread or invite a
throwaway answer.

```md
# <Title>

**Purpose:** why this exists and the decision riding on it.
**From:** <user> · **To:** <recipient> · **Answers will be used for:** <where they go>

## Context

One paragraph for someone who wasn't in the user's head: enough to answer
well, not a page.

## How to answer

Deadline and rough effort. Partial answers and "I don't know" are useful;
flag what you're unsure of rather than skipping it.

## <Theme>

### What load must the system handle at launch?

_Why this matters: it decides whether we provision for bursts now or later._

>

## Anything else?

Anything we didn't ask that we should know?
```
