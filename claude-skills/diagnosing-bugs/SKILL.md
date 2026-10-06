---
name: diagnosing-bugs
description: >-
  A disciplined diagnosis loop for hard bugs and performance regressions:
  build a tight feedback loop that goes red on this bug, minimise, hypothesise,
  instrument, fix at the root cause with a regression test, and clean up. Use
  when the user says "debug" or "diagnose", or reports something broken,
  throwing, failing, flaky, or slow.
---

# Diagnosing Bugs

A discipline for hard bugs. Skip a phase only when you can say why.

Read the project's `GLOSSARY.md` (if any) for a clear model of the modules
involved, and check ADRs in the area.

**Redact as you go.** This loop shows commands, output, and captured artifacts.
Write `<REDACTED>` in place of every secret, keep credentials in environment
variables the loop reads, and quote only the lines of a captured artifact that
carry the signal. If redacted output isn't enough to diagnose, say so and ask.

## Phase 1: Build a feedback loop

This is the skill. With a **tight** pass/fail signal that goes **red** on this
bug, bisection, hypotheses, and instrumentation all just consume it. Without
one, no amount of reading code will find the cause. Spend disproportionate
effort here, and keep at it.

Ways to build one, roughly in this order:

1. A failing test at whatever seam reaches the bug: unit, integration, or
   end-to-end.
2. A curl or HTTP script against a running dev server.
3. A CLI run with a fixture input, diffing output against a known-good
   snapshot.
4. A headless browser script (Playwright, Puppeteer) asserting on the DOM,
   console, or network.
5. Replaying a captured trace: save a real request, payload, or event log and
   run it through the code path in isolation.
6. A throwaway harness: the smallest subset of the system (one service, stub
   dependencies) that reaches the bug's path in one call.
7. A property or fuzz loop for "sometimes wrong": many random inputs, looking
   for the failure mode.
8. A bisection harness when the bug appeared between two known states
   (commits, datasets, versions), so `git bisect run` can drive it.
9. A differential loop: the same input through the old and new version (or two
   configs), diffing the output.
10. A human-in-the-loop script, as a last resort when a person must click.
    Copy `${CLAUDE_SKILL_DIR}/hitl-loop.template.sh`, edit its steps, and run it: it
    prompts the person and prints what they report as `KEY=VALUE` lines for
    you to read.

**Tighten it.** Make it faster (cache setup, narrow the scope), sharper (assert
the exact symptom, not "didn't crash"), and more deterministic (pin time, seed
randomness, isolate the filesystem and network). For a flaky bug, aim for a
higher reproduction rate rather than a clean repro: loop the trigger,
parallelise, add stress. A 50% flake is debuggable; 1% is not yet.

**If you cannot build one,** stop and say so, list what you tried, and ask for
access to an environment that reproduces it, a redacted captured artifact (HAR
file, log dump, core dump, timestamped recording), or permission to add
temporary production instrumentation.

Done when you can name **one command**, already run at least once (show it and
its redacted output), that is:

- **Red-capable:** it drives the real bug path and asserts the user's exact
  symptom, so it goes red on this bug and green once it is fixed.
- **Deterministic:** the same verdict every run, or for a flaky bug a pinned,
  high reproduction rate.
- **Fast:** seconds, not minutes.
- **Agent-runnable:** you can run it unattended (a person only through the
  HITL script).

Reading code to build a theory before this command exists is the exact failure
this skill prevents. No red-capable command, no Phase 2.

## Phase 2: Reproduce and minimise

Run the loop and watch it go red. Confirm the failure is the one the user
described, not a nearby different one; that it reproduces across runs (or at a
debuggable rate); and capture the exact symptom so later phases can check the
fix against it.

Then cut inputs, callers, config, data, and steps one at a time, re-running
after each cut, keeping only what the failure needs. A minimal repro shrinks
the hypothesis space and becomes the regression test. Done when every
remaining element is load-bearing: removing any one turns the loop green.

## Phase 3: Hypothesise

Write 3-5 ranked hypotheses before testing any; a single hypothesis anchors on
the first plausible idea. Each must be falsifiable: "If X is the cause, then
changing Y makes the bug disappear and changing Z makes it worse." A
hypothesis with no prediction is a hunch: sharpen it or drop it.

Show the ranked list to the user before testing. They often know something
that re-ranks it at once ("we changed #3 yesterday"), or what's already been
ruled out. Proceed on your own ranking if they're away.

## Phase 4: Instrument

Each probe tests one prediction from Phase 3; change one variable at a time.
Prefer a debugger or REPL over logs, and targeted logs at the boundaries that
separate hypotheses over logging everything. Tag every debug line with one
unique prefix (`[DEBUG-a4f2]`) so cleanup is a single grep.

For performance regressions, measure before fixing: establish a baseline
(timing harness, profiler, query plan), then bisect.

## Phase 5: Fix at the root, with a regression test

A report names a symptom. Before editing, find every caller of the function
you're about to change: one guard in the shared function is a smaller diff
than a guard in each caller, and patching only the path the report names
leaves the others broken.

Write the regression test before the fix, at a **correct seam**: one where the
test reproduces the bug as it happens at the call site. If the only seam
available is too shallow (one caller when the bug needs several, a unit test
that can't reproduce the chain), a test there gives false confidence; note
that the architecture prevents locking the bug down, and say so in the
report. With a correct seam:

1. Turn the minimised repro into a failing test there, and watch it fail.
2. Apply the fix, and watch it pass.
3. Re-run the Phase 1 loop against the original, un-minimised scenario.

## Phase 6: Clean up

Done when:

- [ ] The Phase 1 loop no longer reproduces the bug
- [ ] The regression test passes, or the missing seam is documented
- [ ] No `[DEBUG-...]` lines remain (grep the prefix)
- [ ] Throwaway harnesses are deleted or moved somewhere clearly marked
- [ ] The commit or PR message states the hypothesis that proved correct, so
      the next person learns from it
