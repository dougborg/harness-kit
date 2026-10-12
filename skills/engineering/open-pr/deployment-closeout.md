# Deployment closeout

For a task that already authorizes merging to a branch that deploys
automatically. Follow the project's deployment workflow and approval
requirements, and merge only after steps 6-8 are done.

1. Record the merged commit SHA. A squash merge differs from the reviewed PR
   head.
2. Track the deploy and post-deploy checks for that commit and environment. A
   healthy endpoint serving the previous commit verifies nothing.
3. Confirm the live service reports that SHA (or the project's release
   identity) and the smoke or canary checks pass. PR CI proves the build, not
   the deploy.
4. Report merged, deployed, and verified as separate states. If one fails,
   inspect and report it; don't declare completion or start an unapproved
   rollback or deploy.

Poll with a bound: the project's policy, or 15 minutes without one, following
step 6's rules for long waits. On timeout, report "merged, deploy pending" and
stop. With no release identity or post-deploy check available, say so rather
than claim a check passed.
