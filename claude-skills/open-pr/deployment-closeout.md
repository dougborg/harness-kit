# Deployment closeout

For a task that already authorizes merging to a branch that deploys
automatically. Follow the project's deployment workflow.

1. Record the merged commit SHA. A squash merge differs from the reviewed PR
   head.
2. Track the deploy and post-deploy checks for that commit and environment. A
   healthy endpoint serving the previous commit verifies nothing.
3. Confirm the live service reports that SHA (or the project's release
   identity) and the smoke or canary checks pass. PR CI proves the build, not
   the deploy.
4. Report merged, deployed, and verified as separate states. If a check is
   pending, say so and keep watching. If one fails, inspect and report it; don't
   declare completion or start an unapproved rollback or deploy.

Use the project's polling and timeout policy. With no release identity or
post-deploy check available, say so rather than claim a check passed.
