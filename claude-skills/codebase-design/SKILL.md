---
name: codebase-design
description: >-
  Shared vocabulary and principles for designing deep modules: a lot of
  behaviour behind a small interface, at a clean seam, testable through that
  interface. Use when designing or reshaping a module's interface, deciding
  where a seam goes, making code more testable or easier for agents to
  navigate, and when another skill needs the deep-module vocabulary.
---

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, placed at
a clean seam, testable through that interface. The aim is leverage for
callers, locality for maintainers, and testability for everyone.

## Vocabulary

Use these terms exactly; consistent words are the point.

- **Module**: anything with an interface and an implementation, at any scale:
  a function, class, package, or slice across tiers. _Avoid_: unit,
  component, service.
- **Interface**: everything a caller must know to use the module correctly:
  the signature plus invariants, ordering constraints, error modes, required
  configuration, and performance characteristics. _Avoid_: API, signature
  (both name only the type-level surface).
- **Implementation**: the code inside a module.
- **Depth**: leverage at the interface, the behaviour a caller or test can
  exercise per unit of interface they have to learn. The deep-module idea is
  Ousterhout's; measuring it as leverage rather than as a ratio of
  implementation lines to interface lines is deliberate, since a line ratio
  rewards padding. **Deep**: much behaviour
  behind a small interface. **Shallow**: the interface is nearly as complex as
  the implementation.
- **Seam** (Michael Feathers): a place where behaviour can change without
  editing that place; where a module's interface lives. Where to put it is a
  design decision of its own. _Avoid_: boundary (overloaded with DDD's bounded
  context).
- **Adapter**: a concrete thing that satisfies an interface at a seam. It names
  a role, not a size: a thin adapter can wrap a large implementation.
- **Leverage**: what callers gain from depth; one implementation pays back
  across many call sites and tests.
- **Locality**: what maintainers gain from depth; change, bugs, and knowledge
  concentrate in one place.

## Principles

- **Depth belongs to the interface.** A deep module can be built from small,
  swappable parts inside; they just aren't part of its interface. A module can
  have internal seams for its own tests as well as the external seam callers
  use.
- **The deletion test.** Imagine deleting the module. If complexity vanishes,
  it was a pass-through. If complexity reappears across many callers, it was
  earning its keep.
- **The interface is the test surface.** Callers and tests cross the same
  seam. Wanting to test past the interface means the module is the wrong
  shape.
- **One adapter means a hypothetical seam; two adapters mean a real one.**
  Introduce a seam only when something actually varies across it (typically
  production and test).

## Designing for testability

- **Accept dependencies; don't construct them.** `processOrder(order,
  paymentGateway)` is testable; a function that builds its own gateway is not.
- **Return results rather than producing side effects** where the caller can
  apply them: `calculateDiscount(cart): Discount` over
  `applyDiscount(cart): void`.
- **Keep the surface small.** Fewer methods mean fewer tests; fewer
  parameters mean simpler setup. For any interface, ask: can it have fewer
  methods, simpler parameters, or hide more inside?

## Going deeper

- Deepening a cluster of shallow modules given their dependencies (in-process,
  local stand-in, remote but owned, true external), seam discipline, and
  replacing old tests rather than layering on them:
  [DEEPENING.md](DEEPENING.md).
- Exploring alternative interfaces with parallel subagents, each designing
  under a different constraint, then comparing on depth, locality, and seam
  placement: [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md).
