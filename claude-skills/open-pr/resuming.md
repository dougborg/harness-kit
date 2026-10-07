# Resuming a backgrounded poll

Read this when you come back to the PR through a scheduled wakeup or a task
notification, after backgrounding `poll-ci.sh` or `poll-review.sh`.

The prompt you wrote was frozen when you scheduled it. By the time it fires,
task IDs and the state it describes are often stale: a force-push starts a new
CI run, and a finished poll task no longer exists.

## On resume

1. Ignore remembered task IDs and the state the wakeup prompt claims.
2. Re-derive state from GitHub:

   ```bash
   gh pr checks <number>
   gh pr view <number> --json state,reviews,mergeStateStatus
   ```

3. Continue from the step the fresh state points to: CI running, keep
   waiting; CI failed, fix it; CI green, run the agent review. The agent
   review is already done if the PR has an `## Agent review` comment newer
   than the latest push (`gh pr view <number> --json comments,commits`); then
   go on to outside reviews.

Done when you have acted on state read from GitHub in this session, not on
the wakeup prompt.

## Scheduling a wakeup

Phrase the prompt as the goal, not a task reference:
`"PR #<n>: continue the open-pr skill's CI wait — re-check gh pr checks and proceed"`,
not `"check poll task <id>"`. The same applies to every long poll in the
skill, including the outside-review wait.
