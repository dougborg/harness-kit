# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies.
Uses the vocabulary in [SKILL.md](SKILL.md).

## Classify the dependencies

The category decides how the deepened module is tested across its seam.

1. **In-process.** Pure computation or in-memory state, no I/O. Always
   deepenable: merge the modules and test through the new interface. No
   adapter needed.
2. **Local-substitutable.** Dependencies with local test stand-ins (PGLite for
   Postgres, an in-memory filesystem). Deepenable when the stand-in exists;
   tests run against it. The seam stays internal, with no port on the
   module's interface.
3. **Remote but owned.** Your own services across a network. Define a
   **port** at the seam; the deep module owns the logic and the transport is
   an injected adapter. Tests use an in-memory adapter; production uses HTTP,
   gRPC, or a queue.
4. **True external.** Third-party services you don't control (Stripe, Twilio).
   Take the dependency as an injected port; tests provide a mock adapter.

## Seam discipline

- Introduce a port only when at least two adapters are justified (typically
  production and test). A single-adapter seam is just indirection.
- Keep internal seams internal. Don't expose them through the interface
  because tests use them.

## Replace tests; don't layer them

- Once tests exist at the deepened module's interface, the old unit tests on
  the shallow modules are waste: delete them.
- Write new tests at the interface, asserting observable outcomes, not
  internal state.
- A test that must change when the implementation changes is testing past the
  interface.
