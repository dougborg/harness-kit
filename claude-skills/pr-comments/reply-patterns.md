# Reply patterns

Worked examples for answering PR review comments, and how to handle batching,
several reviewers, and disagreement.

## Contents

- [Response formats](#response-formats)
- [Batching](#batching)
- [Several reviewers](#several-reviewers)
- [Disagreeing](#disagreeing)

## Response formats

**Code was fixed:**

```text
Fixed — [one sentence what changed].

[If tests added: Also added tests for X.]
```

```text
Fixed — Added null check before accessing user.email on line 45.
Also added test case for when user creation fails mid-transaction.
```

**Already fixed in an earlier commit:**

```text
This was addressed in [commit hash] — [brief explanation].
```

```text
This was addressed in 3bc4e2a — Validation now happens in middleware
before request reaches the handler.
```

**Acknowledged and deferred:**

```text
Acknowledged — [reason for deferring]. Tracked in #NNN.
```

```text
Acknowledged — Migrating to async/await is valuable, but out of scope
for this PR. Tracked in #456 for next quarter.
```

**Asking for clarification:**

```text
I want to make sure I understand. Can you clarify [specific question]?
```

```text
I want to make sure I understand the concern. Are you concerned about
performance at scale, or the maintainability of this pattern in general?
```

**Declining:**

```text
I appreciate the suggestion. However, [reason why we're not doing this].
Let's discuss in [GitHub issue link] if you'd like to revisit.
```

```text
I appreciate the suggestion to use immutable data structures. However,
we've benchmarked this code path and mutation is actually faster here.
See discussion in #789 for performance trade-off analysis.
```

## Batching

Group two or three small, related comments from the same reviewer into one
reply:

```text
Fixed:
1. Added validation on line 45 (comment #1)
2. Extracted to utility function (comment #2)
Both validated locally before push.
```

Reply separately when the answers are long or unrelated, such as an
architectural discussion and a typo fix. Several comments in one thread get
one reply that covers them all.

## Several reviewers

When reviewers comment on the same code, give them one consistent answer, so
neither looks ignored:

```text
Reviewer A: "Extract to function"
Reviewer B: "This function is hard to test"
Reply to both: "Extracted to utility and added tests"
```

Reply to all of them in the same push cycle. If they disagree, settle on one
approach and say why:

```text
Good points from both. We've decided on approach X because [reasoning].
Link to GitHub issue for extended discussion if needed.
```

## Disagreeing

When feedback contradicts the design or project standards, acknowledge the
valid concern before explaining the choice; "That's not how we do things
here" dismisses it.

```text
I understand the concern about [issue]. However, we're using pattern X
because [project constraint]. If you'd like to discuss alternatives,
let's open a separate issue.
```

```text
I see the readability concern. We've chosen approach X
because [trade-off]. Happy to discuss in future PRs.
```

When the feedback touches a documented project standard, link it:

```text
Good catch. This follows pattern documented in CLAUDE.md#section.
Let me know if the guidance is unclear.
```
