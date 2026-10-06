# Skill and agent templates

Starting points, not schemas. Delete any heading the skill does not need.

## Skill

```markdown
---
name: skill-name
description: >-
  What it does, and when to use it — third person, with trigger terms.
allowed-tools: Read, Write, Bash(git add*), Bash(git commit*)
---

# /skill-name — Short Title

One or two sentences: what this is for and when it applies.

## <Named step, e.g. "Pin the fixed point">

What to do, in prose. Done when <checkable condition>.

## <Next named step>

## <Exception, named so a skimmer can tell if they are in one>

## Related

- `/other-skill` — how it connects
```

Beside it, `agents/openai.yaml` declares the Codex picker text and, for a
user-invoked skill, the invocation policy:

```yaml
interface:
  display_name: "Skill Name"
  short_description: "One line for the picker."
policy:
  allow_implicit_invocation: false   # user-invoked skills only
```

## Agent

```markdown
---
name: agent-name
description: >-
  What this agent analyzes or does, and when to dispatch it. Include
  <example> blocks showing the invoking exchange.
tools: Read, Grep, Glob
---

# Agent Name

What this agent is for, and what it returns to its caller.

## <How it works — checklist, dimensions, or procedure>

## Output format

<The exact shape of the report the caller receives>
```
