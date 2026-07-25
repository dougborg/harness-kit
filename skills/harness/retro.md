# Retro Mode

Post-session retrospective to identify gaps and improvements in the harness. **Run after significant sessions to capture learnings.**

Scope: this mode audits the *harness* (skills, agents, hooks). To document the *session's work* — goal, narrative, issues filed, lessons — point the user at `/session-retro`; the two compose and are best run back-to-back at end-of-session.

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

3. **Identify gaps and classify:**
   - Type A: Existing skill needs content update (fix the local skill, mark as modified in lock file)
   - Type B: New skill needed (create in `.claude/skills/`, add to lock as `source: "local"`)
   - Type C: Builder template would not have generated this correctly → fix the upstream harness (most valuable — prevents the gap in every future project)
   - Type D: Lightweight pattern — a learned heuristic that doesn't warrant a full skill (store in memory or `.claude/patterns/`)

   **Promotion heuristic:** Before classifying as Type D, ask: *would this prevent the same mistake in another project, or for another agent?* If yes, escalate to A/B/C — encode it in a skill, not memory. Memories are session/user-scoped and fade; skills persist and ship to every consumer of the harness. Type D is for pattern learnings genuinely scoped to *this* project's quirks.

4. **Propose 1-3 improvements** as specific, actionable changes.

5. **Promotion pass — what belongs upstream?** For *every* finding (not just Type C), ask: would this prevent the same problem in another harness-kit consumer? If yes, mark it as upstream-worthy. Common cases:
   - Type C — by definition belongs upstream
   - Type A on a file sourced from upstream (per `.harness-lock.json`) — the upstream skill is wrong, not just your local copy
   - Type B that's generic — a new skill that has nothing project-specific in it should be proposed upstream as a new skill, not kept local
   - Type D — patterns rarely belong upstream; keep local unless the pattern is genuinely cross-project

6. **Surface upstream candidates and confirm with the user before filing.** Show each upstream-worthy finding and ask per item: file as Issue, open as PR, hoist a local fix, or skip. Then act:
   - **Issue / PR** → invoke `/harness-issue` (configurable upstream; defaults to harness-kit)
   - **Hoist local fix** → invoke `/harness hoist` for cases where you already have a working local diff to propose back
   - **Skip / keep local** → no upstream action; leave a note in the retro summary so it's not forgotten next session

7. **For Type D patterns:** Save as a brief markdown note. Patterns are lighter than skills — they capture heuristics like "in this codebase, always check X before Y" or "this API returns 404 for deleted resources, not 410." Store in memory files or a `.claude/patterns/` directory.
