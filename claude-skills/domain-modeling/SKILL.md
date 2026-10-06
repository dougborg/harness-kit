---
name: domain-modeling
description: >-
  Builds and sharpens a project's domain language as decisions are made:
  challenges fuzzy or conflicting terms, stress-tests concepts with edge-case
  scenarios, and records resolved terms in GLOSSARY.md and hard-to-reverse
  decisions as ADRs. Use when discussing what the project's terms mean, when
  writing or editing a glossary or an ADR, and during design interviews.
---

# Domain Modeling

Build the project's **ubiquitous language** while you design: one precise word
per concept, used the same way in conversation, docs, and code. This skill is
the active discipline of changing that language. Reading `GLOSSARY.md` for
vocabulary is a habit any skill can have; this is for when the model itself
is moving.

## Where the files live

Follow the repo's existing convention when it has one. Otherwise:

- **One context (most repos):** `GLOSSARY.md` at the root, ADRs in `docs/adr/`.
- **Several contexts:** a root `GLOSSARY-MAP.md` lists each context, where its
  `GLOSSARY.md` lives, and how the contexts relate. System-wide ADRs stay in
  `docs/adr/`; context-specific ones sit beside that context's glossary.

Create files lazily: the glossary when the first term is resolved, the ADR
directory when the first ADR is written.

## During the conversation

- **Challenge against the glossary.** When the user uses a term in a way that
  conflicts with its glossary definition, say so at once: "The glossary
  defines cancellation as X; you seem to mean Y. Which is it?"
- **Sharpen fuzzy words.** When one word is doing several jobs ("account" for
  both Customer and User), propose a canonical term for each concept.
- **Stress-test with scenarios.** Invent concrete edge cases that force a
  precise boundary between two concepts.
- **Check the code.** When the user says how something works, look at whether
  the code agrees, and surface any contradiction.

## Recording

- **Glossary:** update it the moment a term is resolved, not in a batch at the
  end, following [GLOSSARY-FORMAT.md](GLOSSARY-FORMAT.md). The glossary holds
  definitions only: implementation details, plans, and specs go elsewhere.
- **ADRs:** offer one only when a decision is hard to reverse, would surprise
  a future reader, and came from a real trade-off. All three, or skip it.
  Format and examples are in [ADR-FORMAT.md](ADR-FORMAT.md).

Done when every term resolved in the session is in the glossary with its
avoided synonyms, and every decision that met the ADR bar was offered as one.
