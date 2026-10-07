# The six review dimensions

Questions, red flags, and example feedback for each dimension of the
standards pass.

## Contents

- [Correctness](#correctness)
- [Design](#design)
- [Readability](#readability)
- [Performance](#performance)
- [Testing](#testing)
- [Security](#security)

## Correctness

Semantic correctness, logic, and type safety.

Questions:

- Does the code do what the commit message says it does?
- Are all variables initialized before use?
- Do conditionals cover all cases (missing `else`, incomplete `switch`)?
- Are there off-by-one errors in loops?
- Do type signatures match implementations?
- Are race conditions or deadlocks possible?
- Can the code throw exceptions, and are they handled?
- Are null and undefined values handled?
- Is the control flow clear (no hidden returns or confusing nesting)?
- In doc sweeps, does every "Look up via `<tool>`" (or "see `<endpoint>`")
  hint reference a tool whose return type actually matches the field? Check
  each against the tool's signature: copy-pasted hints on structurally similar
  sibling fields are a common category error.

- Does any function return the same value for "nothing there" and "could
  not tell"? An empty list, `None`, zero, or a sentinel that means both
  empty and failed (an empty result vs a failed query, a missing file vs an
  unreadable one, no matches vs a timed-out search, 404 vs a request never
  sent) lets every caller read an unknown as a negative. Where the
  difference matters, the indeterminate case is raised or returned as a
  distinct value.

Red flags:

- Unchecked error returns
- `except: pass` or `if bad: continue` inside a loop that accumulates
  results, which turns "couldn't measure this one" into "this one is empty"
- Shadowed variables
- Logic inversions (`if !valid` instead of `if valid`)
- Type assertions without runtime checks
- Silent failures (error caught but not re-raised or logged)

```text
BLOCKING: In line 45, `user.email` is accessed without null check.
If user creation fails mid-transaction, email will be undefined.

SUGGESTION: Add early return on line 32:
if (!validateInput(data)) return null;
instead of wrapping entire function in if-block.
```

## Design

Architecture, interfaces, and design patterns.

Questions:

- Does this follow the project's established patterns?
- Are responsibilities separated (one thing per module)?
- Are interfaces clean (parameters, return types, public API)?
- Does this violate any contracts or invariants?
- Is this change a special case, or a second instance of an existing pattern
  that should reuse it?
- Would this be hard to extend or maintain?
- Are dependencies one-way (no circular imports)?
- Does this introduce coupling where it shouldn't?

Red flags:

- Mixed concerns (HTTP and business logic in the same function)
- God objects (classes doing too many things)
- Leaky abstractions (internal details visible to callers)
- Naming or patterns inconsistent with the rest of the codebase
- Silently changing the behavior of existing APIs
- Hardcoded values that genuinely vary by environment or deployment (a config
  knob for a value nobody changes is the opposite smell, reported as
  `yagni:` under the complexity lens)

```text
BLOCKING: Adding `user.role` check in the API route breaks the
permission-at-boundary pattern. Auth should be enforced in middleware,
not scattered across handlers.

SUGGESTION: Extract email parsing into a standalone utility function
rather than inline regex. Makes it reusable and testable.
```

## Readability

Naming, clarity, and documentation.

Questions:

- Are variable and function names clear (no abbreviations or unclear terms)?
- Is the code flow obvious (no surprising jumps, clear intent)?
- Are comments present where the code is non-obvious, and absent where it is
  obvious?
- Is the code formatted consistently?
- Would a new team member understand this on first read?
- Are magic numbers named constants?
- Are complex expressions broken into simpler steps?

Red flags:

- Single-letter variables outside loops (except `x`, `y` for coordinates)
- Unclear abbreviations (`usr`, `proc`, `calc`)
- Missing blank lines between logical sections
- Very long functions (over 50 lines is a smell)
- Deeply nested code (over 3 levels)
- Comments that restate the code instead of explaining why

```text
SUGGESTION: Rename `processData` to `validateAndTransformUserInput`.
Current name doesn't explain what kind of data or what kind of processing.

SUGGESTION: Break this 8-line conditional into a helper function:
if (user.status === 'active' && user.verified && !user.suspended) {
  // ... 20 lines ...
}
→ helper: isUserEligible(user)
```

## Performance

Efficiency, algorithms, and resource usage.

Questions:

- Are there obvious inefficiencies (O(n²) where O(n) is possible)?
- Are expensive operations cached (DB queries, API calls, computation)?
- Is more data loaded than needed (lazy versus eager)?
- Would a better data structure help (a Set where an Array is scanned)?
- Is memory proportional to input (no leaks or unbounded growth)?
- Are large objects copied unnecessarily?
- Could this block (sync where async is needed)?

Red flags:

- Nested loops fetching from a DB or API per iteration
- Loading an entire dataset, then filtering in memory
- Regex compiled inside loops
- Large objects passed by value instead of reference
- Synchronous operations blocking the event loop
- Missing indexes on database queries

```text
SUGGESTION: Move `JSON.parse(config)` outside the loop (line 12).
Currently parsing the same config every iteration.

SUGGESTION: Use Set instead of Array for user lookup (line 8).
Current O(n) lookup inside loop → O(n²) overall. Set gives O(1).
```

## Testing

Coverage, edge cases, and test quality.

Questions:

- Are new functions and features covered by tests?
- Do tests cover the happy path and the error cases?
- Are edge cases tested (empty, null, boundary values)?
- Are mocks used appropriately (mock collaborators, not the thing under
  test)?
- Is each test clear about what it tests?
- Do tests isolate the unit under test?
- Could these tests pass with a wrong implementation (a mock too loose)?
- Does each assertion measure the thing its name claims? Trace the subject,
  not the syntax: a "header height" check that measures the footer passes
  and means nothing.
- For a probe over spatial or structural state, is the sampled region inside
  the feature under test, and clear of everything else?
- Could something else satisfy the assertion? Aggregates (a size, count,
  bounding box, hash, or status code) are prone to it: unrelated material
  can hold them steady while the feature is missing.
- Does the assertion encode a real requirement? A check that a region stays
  empty is wrong if parts must cross it for the thing to work.

Red flags:

- No tests added for new code
- Only happy-path tests
- Mocking the function under test
- Assertions on side effects instead of return values
- Brittle tests that fail when internals change though behavior is the same
- Copy-pasted test code that should be parameterized

```text
BLOCKING: No tests added for the new `parseEmail` function.
Add tests for: valid email, invalid format, empty string, null.

SUGGESTION: Test error case on line 5. What happens if API fails?
Currently only testing happy path.
```

## Security

Vulnerabilities, auth, secrets, and injection risks. Any vulnerability is
BLOCKING.

Questions:

- Could this code be exploited (injection, XSS, CSRF)?
- Is user input validated before use?
- Are secrets hardcoded or in git history (they belong in environment
  variables)?
- Are authentication and authorization enforced?
- Could this expose internal implementation details?
- Are external APIs called safely (rate limiting, error handling)?
- Is sensitive data logged or exposed?
- Are dependencies known to be safe (no malicious packages)?

Red flags:

- User input used in SQL, shell, or HTML without escaping
- Secrets in code (API keys, passwords, tokens)
- Missing authentication on sensitive endpoints
- Authorization bypass (trusting a user after one auth check)
- `eval`, dynamic code execution, or similar
- Disabled CSRF, CORS, or CSP protections
- Dependencies with known vulnerabilities

```text
BLOCKING: User ID on line 18 is used directly in SQL query without
parameterization. Vulnerable to SQL injection.
→ Use parameterized query: db.query('SELECT * FROM users WHERE id = ?', [userId])

BLOCKING: API key hardcoded on line 5. This will leak if pushed to repo.
→ Move to environment variable: process.env.OPENAI_API_KEY
```
