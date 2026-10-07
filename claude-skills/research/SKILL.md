---
name: research
description: >-
  Investigates a question against primary sources (official docs, source code,
  specs, first-party APIs) and writes the findings, with a citation for every
  claim, to a Markdown file. Use when the user wants a
  topic researched or facts gathered from documentation, when a decision waits
  on facts from outside the repo, and when reading legwork should run while
  other work continues.
---

# Research

Delegate the reading to a subagent running in the background where the host
supports one (Claude Code's Agent tool, Codex's spawned agents), so other work
continues; otherwise do the reading yourself. The brief carries the question
and any constraints from where it came from (a ticket, the conversation), and
asks it to:

1. Answer the question from **primary sources**: official documentation,
   source code, specifications, first-party APIs. Follow each claim back to the
   source that owns it rather than a secondary write-up of it.
2. Write the findings to one Markdown file, citing the source of every claim,
   and say plainly what couldn't be verified.
3. Save it where the repo already keeps such notes; with no convention, pick a
   sensible place and report the path.

Done when the file exists, every claim in it carries a citation, and its path
is reported back.
