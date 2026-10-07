---
name: improve-codebase-architecture
description: >-
  Scans a codebase for deepening opportunities (shallow modules that would be
  easier to test and navigate if their interfaces shrank), presents them as a
  visual HTML report, then grills through whichever one the user picks. Use
  when the user asks for an architecture review, wants to find refactoring
  opportunities, or says the codebase is getting hard to change.
disable-model-invocation: true
---

# Improve Codebase Architecture

Find architectural friction and propose **deepening opportunities**:
refactors that turn shallow modules into deep ones, for testability and so
agents can navigate the code.

Two vocabularies drive every suggestion:

- **Architecture.** Call the Skill tool with "codebase-design" for its terms
  (module, interface, implementation, depth, seam, adapter, leverage,
  locality) and principles (the deletion test, "the interface is the test
  surface", "one adapter is a hypothetical seam, two make it real"). Use
  those terms exactly; don't drift into "component", "service", "API", or
  "boundary".
- **Domain.** The project's `GLOSSARY.md` (or the one `GLOSSARY-MAP.md`
  points to for the area) names the good seams, and ADRs in `docs/adr/`
  record decisions this review doesn't re-litigate.

## 1. Explore

**Scope before you scan.** Deepening pays off by making future changes
easier, so weight the parts of the code that change often:

- If the user named a direction (a module, a subsystem, a pain point), take
  it and skip the next bullet.
- Otherwise read a good stretch of `git log --oneline --name-only` for hot
  spots, the files and areas that keep coming up, and look there first. If
  changes are scattered with no hot spot, widen the net.

Read the glossary and any ADRs for the area. Then send a subagent to walk the
code: on Claude Code the `Explore` agent, which doesn't load `CLAUDE.md`, so
put the glossary terms and the questions below in its prompt; on Codex a
spawned agent. Have it explore freely and report where it hits friction:

- Where does one concept mean bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the
  implementation?
- Where were pure functions extracted for testability while the bugs hide in
  how they're called (no **locality**)?
- Where do tightly coupled modules leak across their seams?
- What is untested, or hard to test through its current interface?

Apply the **deletion test** to every suspect: would deleting it concentrate
complexity, or just move it? "Concentrates" is the signal you want.

Done when you have a short list of candidates, each with its files and the
friction it causes.

## 2. Present candidates as an HTML report

Write one self-contained HTML file to the OS temp directory, so nothing lands
in the repo: `${TMPDIR:-/tmp}/architecture-review-<timestamp>.html` (`%TEMP%`
on Windows). Open it (`open` on macOS, `xdg-open` on Linux, `start` on
Windows) and give the user the absolute path, since opening a browser can
fail inside a sandbox.

Each candidate gets a card with its files, the problem, the solution in
plain English, the wins in terms of locality, leverage, and tests, a
before/after diagram, and a strength badge: `Strong`, `Worth exploring`, or
`Speculative`. End with a **Top recommendation**: which candidate to tackle
first and why. [HTML-REPORT.md](HTML-REPORT.md) has the scaffold, the diagram
patterns, and the tone.

Name things with the glossary. If `GLOSSARY.md` defines "Order", write "the
Order intake module", not "the FooBarHandler" or "the Order service".

If a candidate contradicts an ADR, include it only when the friction is real
enough to reopen the decision, and mark it in the card ("contradicts
ADR-0007, but worth reopening because…"). Don't list every refactor an ADR
rules out.

Don't propose interfaces yet. Ask which candidate to explore: through
`AskUserQuestion` on Claude Code, with the top candidates as options; as a
plain question on Codex.

Done when the report is open or its path is shared, and the user has picked
a candidate.

## 3. Grill the chosen candidate

Call the Skill tool with "grilling" to walk the decision tree with the user:
constraints, dependencies, the shape of the deepened module, what sits
behind the seam, which tests survive.

Call the Skill tool with "domain-modeling" to keep the domain model current
as decisions land:

- **A deepened module named after a concept not in `GLOSSARY.md`?** Add the
  term, creating the file if needed.
- **A fuzzy term sharpened in conversation?** Update `GLOSSARY.md` there and
  then.
- **The user rejects the candidate for a load-bearing reason?** Offer an ADR:
  "Want me to record this as an ADR so future architecture reviews don't
  suggest it again?" Offer only when a future reviewer would need the
  reason; skip passing reasons ("not now") and obvious ones.
- **Want alternative interfaces for the deepened module?** Use
  `codebase-design`'s design-it-twice pattern.

Done when the candidate is settled (a chosen interface, or a recorded
rejection) and the glossary and ADRs reflect what was decided.
