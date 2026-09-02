---
name: documentation-writer
description: >-
  Writes and revises human-facing documentation — READMEs, contributor and
  setup guides, reference pages, architecture notes, CLAUDE.md, and changelog
  entries. Covers picking the right document type for the question being
  asked, structuring for skimming, writing examples that actually run, and
  keeping docs from going stale. Use when creating or rewriting docs, when a
  README has drifted from the code, or when deciding where a piece of
  information belongs. For SKILL.md and agent files, use /skill-writer instead.
allowed-tools: Read, Write, Edit, Glob, Grep
disable-model-invocation: true
---

# /documentation-writer — Human-Facing Documentation

Documentation fails in two directions: it does not answer the question the
reader arrived with, or it answers it somewhere the reader never looks. Most of
the work is deciding what kind of document you are writing and who is reading
it, before writing a line.

## Identify the document before writing it

Readers arrive with one of four questions. Mixing the answers into one page is
the most common documentation failure — a tutorial interrupted by API tables
serves neither reader.

| Reader's question | Document type | Shape |
| --- | --- | --- |
| "Get me to a first success" | Tutorial / quickstart | Ordered steps, one path, no options |
| "How do I accomplish X?" | How-to guide | Task-titled, assumes basics, may branch |
| "What are the exact parameters?" | Reference | Complete, structured, alphabetical or grouped |
| "Why is it built this way?" | Explanation / ADR | Prose, trade-offs, alternatives rejected |

If a page is trying to be two of these, split it and cross-link.

## Write for scanning

Readers scan before they read. Every structural choice should reward a reader
who only looks at headings and the first line of each section.

- **Headings state the answer, not the topic.** "Run migrations before starting
  the server" beats "Migrations."
- **Front-load.** The first sentence of a section carries its conclusion; the
  rest supports it.
- **One idea per paragraph**, and prefer a table or list when the content is
  genuinely parallel — but not when it is prose wearing a list costume.
- **Link out instead of inlining depth.** Name what is on the other side of the
  link so the reader can judge whether to follow it.

Length follows the content. A README for a small tool may be thirty lines; a
reference page may be five hundred. There is no target word count — the test is
whether a reader can find their answer, not how long the page is.

## Examples must run

Copy-pasteable examples are the highest-value content in most documentation,
and wrong ones are the highest-cost.

- Show real commands and real output, not placeholders the reader must decode.
- Verify examples against the current code before publishing. If you cannot run
  it, say what version it was checked against.
- Prefer a complete small example over a fragment with elisions.
- Include the failure case when it is common — the error message a reader will
  paste into a search box is worth documenting verbatim.

## Put information where it will be found

The right location beats the right words. Before writing, check whether the
information already lives somewhere and is simply stale.

- **README** — what this is, who it is for, how to run it, where to go next.
  Not a manual.
- **Code comments** — why this line is surprising. Never what the line does.
- **`CLAUDE.md`** — the conventions an agent must hold to work in this repo.
  Keep it short; it loads on every session.
- **Reference docs next to the code they describe**, so a change and its
  documentation land in the same diff.
- **Changelog / release notes** — what changed for a consumer, in their terms,
  not commit subjects.

Duplicating content across locations guarantees divergence. Pick one home and
link to it.

## Keep it from rotting

Stale documentation is worse than none, because readers trust it.

- Avoid time-relative phrasing — "currently", "new", "recently", "for now",
  "the upcoming release". Write what is true, or date the claim.
- Do not document unreleased or intended behavior as if it exists.
- When you change behavior, grep for the old behavior in the docs in the same
  change.
- Prefer generated reference material (CLI `--help`, schema dumps) over
  hand-maintained tables that will drift.
- If you find documentation that is wrong, fix it or delete it. Leaving it with
  a caveat is the worst of the three options.

## Voice

- Second person and active voice: "run the migration", not "the migration
  should be run."
- Present tense for behavior: "the hook blocks the commit."
- Define a term once, then use exactly that term — synonyms read as new
  concepts.
- Say what a thing does before saying what it is called.
- Cut hedges ("simply", "just", "of course", "obviously"). They add nothing and
  make a stuck reader feel worse.

## Before you ship

- Does the first paragraph tell a stranger whether this page is for them?
- Can a reader who skims only the headings get the gist?
- Does every command and code block run as written?
- Is anything here duplicated from another document?
- Would this still be correct in six months, or does it need a date?

## Related

- `/skill-writer` — SKILL.md and agent files, which have different constraints
  (they load into a model's context and carry frontmatter contracts)
- `CLAUDE.md` — this project's own conventions
