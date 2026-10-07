---
name: implement
description: Build a ticket or small spec in this session, test-first, through to an open PR.
argument-hint: "[ticket or spec issue]"
allowed-tools: Read, Grep, Glob, Bash(gh issue *), Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git switch*)
disable-model-invocation: true
---

# Implement

Build the work a ticket or spec describes, in this session, and take it to an
open pull request.

## 1. Read the work

Read the issue with its comments (`gh issue view <n> --comments`), its parent
spec if it has one, and any decisions it links. Work on a feature branch named
for the issue. Done when you can state the acceptance criteria and the agreed
test seams; if the issue names no seams, agree them with the user first.

## 2. Build it

Call the Skill tool with "tdd" and build one vertical slice at a time at the
agreed seams. Before adding a dependency, an abstraction, or a new module, call
the Skill tool with "minimal-change". Run the type checker and the single test
file you're working in often, and the full verification command once at the
end. Done when every acceptance criterion is met and verification passes.

## 3. Ship it

Call the Skill tool with "commit" to commit, then with "open-pr": it
simplifies the diff, links the issue, runs the standards and spec review
against it, and waits for CI. Done when the PR is open with the review's
findings resolved.

For a spec with several tickets that can run in parallel, suggest the user run
the implement-spec skill instead.
