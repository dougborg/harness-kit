---
name: code-reviewer
description: >-
  Reviews a diff across six dimensions — correctness, design, readability,
  performance, testing, security — plus the repo's documented standards, code
  smells, and what the diff could delete, and returns findings classified
  BLOCKING / SUGGESTION / NITPICK. Runs in a forked context so the diff
  reading stays out of the main conversation. Use when the user asks for a
  code review, feedback on changes, or a pre-PR check of the working diff.
context: fork
agent: harness-kit:code-reviewer
background: false
effort: high
allowed-tools: Read, Grep, Glob, Bash(git diff*), Bash(git log*)
---

# Code Reviewer

This is the **standards pass**: the six dimensions, the repo's documented
standards, the smell baseline, and the complexity lens. Checking the diff
against its spec (the issues a PR closes) is a separate pass that needs its
own context, so the review-pr skill runs both in parallel and reports them
side by side.

Report findings; leave the edits to whoever acts on the review. Skip anything
a linter, type checker, or automated reviewer already flags, and add context
rather than noise.

## 1. Gather the change

This skill runs forked, with no conversation history, so take everything from
git and the files themselves rather than from "the change we just discussed".

```bash
git diff HEAD~1 HEAD --stat
git diff HEAD~1 HEAD
git diff -- path/to/file.js   # one file
```

Use the range or paths the prompt names when it names one. Done when you have
read every changed file and can say what the change does and why.

## 2. Review it

Apply each dimension; [dimensions.md](dimensions.md) holds the questions, red
flags, and example feedback for each.

- **Correctness**: logic, semantic correctness, type safety. Correctness
  comes first: a type error, logic bug, or data race blocks approval.
- **Design**: architecture, interfaces, patterns. Design decisions propagate,
  so a poor one blocks downstream work.
- **Readability**: naming, clarity, documentation.
- **Performance**: efficiency, algorithms, resource usage.
- **Testing**: coverage, edge cases, test quality.
- **Security**: injection, auth, secrets. Any vulnerability (injection, auth
  bypass, secret exposure) is BLOCKING.

**Documented standards.** Cite the repo's written standards (`CLAUDE.md`,
`AGENTS.md`, `CONTRIBUTING.md`, `CODING_STANDARDS.md`, path-scoped rule
files) by file and rule. A documented standard is the strongest evidence a
finding can have.

**Smells.** Flag Fowler code smells as judgement calls (SUGGESTION or
NITPICK), and let a documented standard that endorses the pattern override
them: mysterious name, duplicated code, feature envy, data clumps, primitive
obsession, repeated switches, shotgun surgery, divergent change, speculative
generality, message chains, middle man, refused bequest. Name the smell and
quote the hunk; skip a hunk already reported under Complexity.

**Complexity lens.** Report what the diff could delete, one line each,
numbered `C1.`, `C2.`, ... so they don't collide with other findings and the
user can say "fix 2 and C3". Tag each:

- `delete:` dead or speculative; nothing replaces it.
- `reuse:` duplicates a helper already in the repo; name its path.
- `stdlib:` hand-rolls what the standard library ships; name the function.
- `native:` does what the platform already does; name the feature.
- `yagni:` one implementation, config nobody sets, a single-caller layer.
- `shrink:` the same logic in fewer lines; show the shorter form.

End with `net: -N lines possible` or "Lean already." Leave alone what the
minimal-change skill always keeps: trust-boundary validation, data-loss error
handling, security, accessibility, hardware calibration, explicit
requirements, and the one runnable check that non-trivial logic keeps.

```text
C1. src/repo.py:88 — yagni: AbstractRepository has one implementation. Inline it until a second exists.
C2. src/dates.ts:4 — native: moment.js imported for one format call. Intl.DateTimeFormat, no dependency.
net: -40 lines possible
```

Some changes need more depth: read [special-cases.md](special-cases.md) for a
large PR, a design that touches several systems, a refactor or migration of
legacy code, or a new or changed third-party dependency.

Done when every changed file has been weighed against all six dimensions, the
documented standards, the smells, and the complexity lens.

## 3. Classify and report

Classify each finding:

- **BLOCKING**: cannot merge without fixing (correctness, security, design
  that breaks contracts).
- **SUGGESTION**: worth addressing; improves quality (minor design, a
  performance optimization).
- **NITPICK**: nice to have (naming, a formatting edge case).

Report:

1. A verdict: "Approved", "Request changes", or "Comment".
2. BLOCKING items first.
3. Findings grouped by dimension, listing only dimensions that have findings.
4. Suggestions, which stay optional when the code is otherwise solid.
5. The Complexity findings and their `net:` line.

Done when every finding carries a severity and a `file:line`, and the report
opens with the verdict.

## Related

- `/review-pr`: the full PR review lifecycle, running this standards pass and
  the spec pass side by side.
- The `code-reviewer` agent: the forked context this skill runs in
  (harness-kit plugin, or project `.claude/agents/code-reviewer.md`). If it is
  unavailable, drop `context: fork` and `agent:` from this file's frontmatter
  and apply the review inline.
- `CLAUDE.md`: project-specific review standards.
