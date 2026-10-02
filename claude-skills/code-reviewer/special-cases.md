# Changes that need more depth

How to adjust the review for a large change, a deep design, a refactor, or a
dependency change.

## Large changes

For a PR with many files or thousands of lines:

1. **Group by file type**, and review similar files together.
2. **Start with critical paths**: auth, payments, data mutation.
3. **Ask for a split** when the review runs past about an hour.
4. **Sample a large refactor**: verify the pattern across 3–5 representative
   files, then assume consistency.

```text
This PR is quite large. I've reviewed:
- Core auth changes (6/8 files) — LGTM
- Utility refactor (sampled 5 files) — Consistent pattern, approved
- Tests (spot-check) — Coverage looks good

Recommendation: For next round, consider splitting refactors by domain
(auth, API, database) so reviews can be focused.
```

## Design depth

For architectural decisions, designs that touch several systems, or complex
patterns:

1. **Understand the rationale**: why this design over the alternatives?
2. **Challenge core assumptions**: is the problem statement correct?
3. **Check downstream impact**: what depends on this interface?
4. **Review maintainability**: will future developers understand and extend
   it?
5. **Weigh performance, security, and scalability**, not only correctness.

```text
Design question: Why direct user-to-database model vs. service layer?

This works for current scale, but will make caching and multi-tenant
support hard later. Worth discussing if those are on the roadmap.

If you expect to cache: add a service layer now.
If you expect to stay monolithic: fine as-is.
```

## Refactors and migrations

For refactors or migrations of existing code:

1. **Behavior is unchanged**: the same scenarios behave the same before and
   after.
2. **Edge cases survive**: the refactor handles every original case.
3. **No accidental simplification**: no important complexity was lost.
4. **Original tests still pass.**
5. **Performance impact is known**: faster, slower, or the same.

```text
BLOCKING: In the refactor from Map to Object, iteration order is lost.
If code depends on insertion order, this breaks behavior.
→ Verify all callers don't assume order, or use Map.

SUGGESTION: The new version is ~20% faster (good!), but readability
dropped. Consider adding a comment explaining the performance trade-off.
```

## Vendor and dependency changes

For changes to external code or dependencies:

1. **Supply chain**: is the package from a known, trusted maintainer?
2. **Version**: does it match the intended update and pinned runtimes?
3. **Security**: any known CVEs in this version?
4. **Surface area**: import only what is needed.
5. **Necessity**: does it add value, or only complexity?

For updates touching persistence, authentication, serialization, or
telemetry, read the target's release notes. For a major upgrade or a minor
release documented as changing behavior, read the upstream migration guide
and compare changed defaults with what the application does now. A clean
install and typecheck don't prove that database type inference,
serialization, authentication, or telemetry and privacy defaults survived.
Check the runtime behavior and add a regression test for any compatibility
fix: a migration drift check for ORM inference changes, an explicit
collection-policy check for telemetry SDKs.

For a consolidated update, review the combined dependency graph and the
lockfile's peer contexts, transitive changes included. The original PRs'
separate green checks don't cover how they interact.

```text
BLOCKING: Package `left-pad` has a known supply chain attack history.
Use built-in padStart() instead.

SUGGESTION: Consider lighter dependency (2kb vs 50kb).
Similar functionality in `tiny-validator` or as 10-line utility function.
```
