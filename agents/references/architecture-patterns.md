# Agent Architecture Patterns

Six patterns for organizing multi-agent coordination. Select based on task structure.

## Decision Criteria (4 Axes)

| Axis | Question | High → Pattern |
| --- | --- | --- |
| **Specialization** | Do subtasks need different expertise? | Expert Pool or Fan-out |
| **Parallelism** | Can subtasks run independently? | Fan-out/Fan-in |
| **Context** | Do subtasks need shared state? | Pipeline or Supervisor |
| **Reusability** | Will these agents serve multiple workflows? | Expert Pool |

## 1. Pipeline

Sequential workflow where each stage depends on the prior stage's output.

**When:** Strictly ordered dependencies. Output of one step is input to the next.
**When NOT:** Steps can run independently (use Fan-out instead).
**Example:** Plan → Build → Review → Release

```text
[Planner] → [Builder] → [Reviewer] → [Releaser]
```

## 2. Fan-out/Fan-in

Parallel processing: identical input goes to multiple specialists, results merge.

**When:** Independent analysis from different perspectives. Most natural pattern.
**When NOT:** Steps depend on each other (use Pipeline).
**Example:** Multi-file review, multi-language lint, parallel test suites.

```text
         ┌→ [Reviewer A] →┐
[Input] →├→ [Reviewer B] →├→ [Merger]
         └→ [Reviewer C] →┘
```

## 3. Expert Pool

Dynamic routing: input type determines which specialist handles it.

**When:** Different input types need different processing. Not all agents run every time.
**When NOT:** All inputs need the same processing (use Fan-out).
**Example:** Route to language-specific reviewer based on file extension.

```text
[Router] →── [Go Expert]
         ├── [Python Expert]
         └── [TypeScript Expert]
```

## 4. Producer-Reviewer

Quality assurance through paired agents with feedback loops.

**When:** Generation + validation cycle. Iterative improvement.
**When NOT:** No quality criteria or single-pass is sufficient.
**Constraint:** Max 2-3 retry attempts to prevent infinite loops.

```text
[Producer] → [Reviewer] → approve/reject → [Producer] (retry)
```

## 5. Supervisor

Central coordinator that manages task state and dynamically distributes work.

**When:** Runtime task allocation needed. Workload distribution varies.
**When NOT:** Tasks are predetermined (use Fan-out).
**Difference from Fan-out:** Supervisor adjusts at runtime; Fan-out is predetermined.

```text
         ┌→ [Worker A]
[Super] →├→ [Worker B]  (dynamic assignment)
         └→ [Worker C]
```

## 6. Hierarchical Delegation

Recursive subdivision: senior agents delegate to junior tiers.

**When:** Complex task decomposition across abstraction levels.
**When NOT:** Flat task structure (unnecessary overhead).
**Constraint:** Max 2 levels deep to avoid latency and context loss.

```text
[Architect] → [Module Lead A] → [Worker A1, A2]
             → [Module Lead B] → [Worker B1, B2]
```

---

## Default Recommendation

For most projects, start with **Fan-out/Fan-in** (parallel independent analysis). It's the most natural pattern and works well for code review, testing, and documentation tasks.

Upgrade to **Pipeline** when you need ordered stages (e.g., plan → implement → review → release).

Add **Producer-Reviewer** loops for quality-critical outputs (e.g., code generation with review gates).

*Inspired by [revfactory/harness](https://github.com/revfactory/harness) architecture patterns.*
