# Retro Mode

Post-session retrospective to identify gaps and improvements in the harness. **Run after significant sessions to capture learnings.**

Scope: this mode audits the *harness* (skills, agents, hooks) and the environment around it (checks, steering files, tools, information access). To document the *session's work* — goal, narrative, issues filed, lessons — point the user at `/session-retro`; the two compose and are best run back-to-back at end-of-session.

## Procedure

1. **Analyze recent changes:**

   ```bash
   git log --since="8 hours ago" --oneline
   ```

   What domains were touched? What changed?

2. **Reflect on skill usage:**
   - Which skills/agents were used?
   - Which were needed but missing?
   - Which gave wrong or outdated guidance?

3. **Look at the environment, not just the skills.** Read the session itself
   (the conversation, or its log when retro runs later) and look for:
   - **Navigation**: the agent took a long time to find a file or fact.
     Would a pointer in `AGENTS.md`/`CLAUDE.md` or a doc have saved it?
   - **Automated checks**: the agent made a mistake a lint rule, type check,
     test, or hook could catch. Read the repo's existing check command and CI
     first: a check that exists but isn't wired in, or is silently broken, is
     the finding. A repo with no guardrail at all (no pre-commit hook and no
     CI running lint, typecheck, and tests) is itself a finding.
   - **Coding standards**: the reviewer missed something. A **mechanical**
     violation (a banned API, an import shape, a file-location rule) becomes
     a deterministic check, never a written rule. Only a **judgement call**
     (consistency across files, matching the surrounding style) becomes a
     written standard in `CODING_STANDARDS.md` (or the repo's existing
     standards file), which the review agent's standards pass reads: the
     reviewer sees a diff with little context pressure, so standards belong
     with review, not in the implementer's always-loaded instructions.
   - **Steering files**: always-loaded instructions, in the repo or the
     user's global scope, that are large or that should be standards or
     checks instead.
   - **No-ops**: instructions that don't change the agent's behaviour from
     its default. Look when steering files or skills are long.
   - **Tool economy**: expensive or token-heavy tool calls that a script, a
     narrower command, or a better tool would make cheap.
   - **Information access**: something the agent needed but couldn't see:
     dev-server logs, read-only access to a service, a test database.

   Done when every category has been checked against the session and each
   finding names a concrete change.

4. **Identify gaps and classify:**
   - Type A: Existing skill needs content update. For a project-local skill, fix it. For a vendored one, route the lesson (below); never edit the vendored file
   - Type B: New skill needed. A project-specific one goes in the project's `.claude/skills/` or `.agents/skills/` as project-local content; a generic one goes upstream
   - Type C: Builder template would not have generated this correctly → fix the upstream harness (most valuable — prevents the gap in every future project)
   - Type D: Lightweight pattern — a learned heuristic that doesn't warrant a full skill (store in memory or `.claude/patterns/`)
   - Type E: Environment change from step 3 — a check, hook, CI job, standard, doc pointer, or access grant, made in the project. It is also Type C when the builder should have recommended it for every project.

   **Promotion heuristic:** Before classifying as Type D, ask: *would this prevent the same mistake in another project, or for another agent?* If yes, escalate to A/B/C — encode it in a skill, not memory. Memories are session/user-scoped and fade; skills persist and ship to every consumer of the harness. Type D is for pattern learnings genuinely scoped to *this* project's quirks.

   **Route each A and B lesson** by what it is. A vendored file is any file listed in `.harness/lock.json`; the edit check fails on any change to one, so no lesson lands there (ADR 0001):

   | The lesson is | It goes to |
   | --- | --- |
   | A project fact (the gate command, a path, a convention, a term) | `.harness/config.toml` when a generic skill reads that key, otherwise the `## Project facts` section of `AGENTS.md` (`<skill-dir>/project-facts.md`) |
   | A project-specific capability | A project-local skill or agent, outside the lock |
   | Generic: it would help every project | Upstream, as a hoist PR or a `/harness-issue`; it returns through the next update PR |

   A fork is the escape hatch when a vendored skill must behave differently here and facts can't express it: propose it as an explicit decision for the user, recorded in `[forks.skills]` or `[forks.agents]` with the forked-from version, never as a side effect of a fix. Done when every A and B lesson names its destination.

5. **Propose the most severe improvements first** (usually one to three) as
   specific, actionable changes; list the rest so they aren't lost.

6. **Promotion pass — what belongs upstream?** For *every* finding (not just Type C), ask: would this prevent the same problem in another harness-kit consumer? If yes, mark it as upstream-worthy. Common cases:
   - Type C — by definition belongs upstream
   - Type A on a vendored file (listed in `.harness/lock.json`) or a fork — the upstream skill is wrong, and the fix belongs there
   - Type B that's generic — a new skill that has nothing project-specific in it should be proposed upstream as a new skill, not kept local
   - Type D — patterns rarely belong upstream; keep local unless the pattern is genuinely cross-project

7. **Surface upstream candidates and confirm with the user before filing.** Show each upstream-worthy finding and ask per item: file as Issue, open as PR, hoist a local fix, or skip. Then act:
   - **Issue / PR** → invoke `/harness-issue` (configurable upstream; defaults to harness-kit)
   - **Hoist** → invoke `/harness hoist` when the improvement already exists in the project: a project-local skill, a facts pattern, or a fork
   - **Skip / keep local** → no upstream action; leave a note in the retro summary so it's not forgotten next session

8. **For Type D patterns:** Save as a brief markdown note. Patterns are lighter than skills — they capture heuristics like "in this codebase, always check X before Y" or "this API returns 404 for deleted resources, not 410." Store in memory files or a `.claude/patterns/` directory.
