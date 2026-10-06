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
   (the conversation, or its log when retro runs later) and look for these,
   most severe first:
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
     written standard the review agent enforces: the reviewer reads a diff
     with little context pressure, so standards belong with review, not in
     the implementer's always-loaded instructions.
   - **Steering files**: always-loaded instructions that are large, that
     should be standards or checks instead, or that no longer change
     behaviour (no-ops).
   - **Tool economy**: expensive or token-heavy tool calls that a script, a
     narrower command, or a better tool would make cheap.
   - **Information access**: something the agent needed but couldn't see:
     dev-server logs, read-only access to a service, a test database.

   Done when every category has been checked against the session and each
   finding names a concrete change.

4. **Identify gaps and classify:**
   - Type A: Existing skill needs content update (fix the local skill, mark as modified in lock file)
   - Type B: New skill needed (create in `.claude/skills/`, add to lock as `source: "local"`)
   - Type C: Builder template would not have generated this correctly → fix the upstream harness (most valuable — prevents the gap in every future project)
   - Type D: Lightweight pattern — a learned heuristic that doesn't warrant a full skill (store in memory or `.claude/patterns/`)

   **Promotion heuristic:** Before classifying as Type D, ask: *would this prevent the same mistake in another project, or for another agent?* If yes, escalate to A/B/C — encode it in a skill, not memory. Memories are session/user-scoped and fade; skills persist and ship to every consumer of the harness. Type D is for pattern learnings genuinely scoped to *this* project's quirks.

5. **Propose 1-3 improvements** as specific, actionable changes, most severe
   first.

6. **Promotion pass — what belongs upstream?** For *every* finding (not just Type C), ask: would this prevent the same problem in another harness-kit consumer? If yes, mark it as upstream-worthy. Common cases:
   - Type C — by definition belongs upstream
   - Type A on a file sourced from upstream (per `.harness-lock.json`) — the upstream skill is wrong, not just your local copy
   - Type B that's generic — a new skill that has nothing project-specific in it should be proposed upstream as a new skill, not kept local
   - Type D — patterns rarely belong upstream; keep local unless the pattern is genuinely cross-project

7. **Surface upstream candidates and confirm with the user before filing.** Show each upstream-worthy finding and ask per item: file as Issue, open as PR, hoist a local fix, or skip. Then act:
   - **Issue / PR** → invoke `/harness-issue` (configurable upstream; defaults to harness-kit)
   - **Hoist local fix** → invoke `/harness hoist` for cases where you already have a working local diff to propose back
   - **Skip / keep local** → no upstream action; leave a note in the retro summary so it's not forgotten next session

8. **For Type D patterns:** Save as a brief markdown note. Patterns are lighter than skills — they capture heuristics like "in this codebase, always check X before Y" or "this API returns 404 for deleted resources, not 410." Store in memory files or a `.claude/patterns/` directory.
