# Deployment closeout

Use only when merging or deployment is already part of the authorized task.
Follow the project's deployment workflow and approval requirements; opening a
PR alone does not authorize production changes.

After merging to a branch that deploys automatically:

1. Record the actual merged commit SHA. A squash merge produces a different
   SHA from the reviewed PR head.
2. Track the deployment and post-deploy checks for that commit and environment.
   A healthy endpoint serving the previous commit does not verify this deploy.
3. Confirm the live service reports that SHA (or the project's equivalent
   release identity) and the configured smoke/canary checks pass. PR CI is
   evidence about the build; it does not establish that production is updated.
4. Report merged, deployed, and verified as distinct states. If deployment or
   smoke checks remain pending, say so and continue within the authorized task.
   If a check fails, inspect and report the failure; do not declare completion
   or invent an unapproved rollback/deployment action.

Use the project's bounded polling and timeout policy. If no release identity
or post-deploy check is available, state that verification limit rather than
claiming a check passed.
