---
name: research
description: >-
  Investigates a question against primary sources (official docs, source code,
  specs, first-party APIs) in a background agent and writes the findings, with
  a citation for every claim, to a Markdown file. Use when the user wants a
  topic researched or facts gathered from documentation, when a decision waits
  on facts from outside the repo, and when reading legwork should run while
  other work continues.
---

# Research

Dispatch a background agent so the reading happens while you keep working.
Its brief:

1. Answer the question from **primary sources**: official documentation,
   source code, specifications, first-party APIs. Follow each claim back to the
   source that owns it rather than a secondary write-up of it.
2. Write the findings to one Markdown file, citing the source of every claim,
   and say plainly what couldn't be verified.
3. Save it where the repo already keeps such notes; with no convention, pick a
   sensible place and report the path.

Done when the file exists, every claim in it carries a citation, and its path
is reported back.
