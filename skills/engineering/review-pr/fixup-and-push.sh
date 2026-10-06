#!/usr/bin/env bash
# Stage files, create fixup commit, autosquash rebase, and push.
#
# Usage:
#   fixup-and-push.sh <base-branch> [--subject <subject> | --infer] <files...>
#   fixup-and-push.sh <base-branch> <subject> <files...>          # legacy positional
#   fixup-and-push.sh <base-branch> <files...>                    # infer subject
#
# If <subject> is omitted (or passed as `--infer`), it is inferred from:
#   git log "origin/<base>..HEAD" --no-merges --format=%s | grep -v '^fixup!' | head -1
# i.e. the latest non-merge, non-fixup commit in the rebase range — typically what
# you want. The `fixup!` filter prevents `fixup! fixup! …` chains when retrying.
#
# Backwards compatibility: legacy positional form (subject as 2nd positional arg)
# still works. The 2nd positional is treated as a file path if it points to an
# existing file on disk; otherwise it is treated as a commit subject. Pass
# `--subject "..."` to disambiguate when a subject happens to look like a path.
#
# After autosquash, this script verifies that no `fixup!`-prefixed commits remain
# in the rebase range. If any do, it prints a manual-recovery snippet and exits
# non-zero rather than failing silently — see harness-kit#40 and harness-kit#42.
#
# The force-push uses a lease that's robust against the remote PR branch having
# moved (e.g. a GitHub "Update branch" merge commit) — see harness-kit#46.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  fixup-and-push.sh <base-branch> [--subject <subject> | --infer] <files...>
  fixup-and-push.sh <base-branch> <subject> <files...>   # legacy positional
  fixup-and-push.sh <base-branch> <files...>             # infer subject

If <subject> is omitted (or --infer), the subject is taken from the latest
non-merge, non-fixup commit in `origin/<base>..HEAD`.
USAGE
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

base="$1"
shift

subject=""
infer_subject=0

# Parse optional --subject / --infer flag, or detect legacy positional subject.
if [ "${1:-}" = "--subject" ]; then
  if [ $# -lt 2 ]; then
    echo "ERROR: --subject requires a value" >&2
    usage
    exit 1
  fi
  subject="$2"
  shift 2
elif [ "${1:-}" = "--infer" ]; then
  infer_subject=1
  shift
elif [ -e "$1" ]; then
  # First remaining arg is an existing path — treat all remaining as files
  # and infer the subject from the rebase range.
  #
  # Note: a typo'd path (file that doesn't exist) falls through to legacy-
  # subject handling and will fail later at `git add`. Pass `--subject` or
  # `--infer` explicitly to disambiguate.
  infer_subject=1
else
  # Legacy positional: 2nd arg is the subject, remainder are files.
  subject="$1"
  shift
fi

if [ $# -lt 1 ]; then
  echo "ERROR: no files specified" >&2
  usage
  exit 1
fi

files=("$@")

# Bail BEFORE mutating anything if we're in detached HEAD. `git rev-parse
# --abbrev-ref HEAD` returns the literal string "HEAD" when detached; we'd
# otherwise try to fetch/push a ref named HEAD downstream.
branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" = "HEAD" ]; then
  echo "ERROR: cannot run fixup-and-push from a detached HEAD state. Check out the feature branch first (\`git checkout <branch>\`)." >&2
  exit 1
fi

# Fetch the base ref first — we need it for inference AND the rebase, and a
# stale origin ref would silently widen/narrow the range.
git fetch origin "$base"

if [ "$infer_subject" -eq 1 ] || [ -z "$subject" ]; then
  # Skip `fixup!` lines so a prior fixup commit on this branch (a retry
  # scenario) doesn't get re-targeted, which would produce `fixup! fixup! …`
  # that autosquash won't fold. See harness-kit#45 follow-up.
  # `|| true` keeps the pipeline succeeding under `set -euo pipefail` when
  # grep filters out everything (empty input → grep exits 1, pipefail trips)
  # — without this, the script would die silently before the `[ -z ]` branch
  # below ever runs.
  subject=$(git log "origin/${base}..HEAD" --no-merges --format=%s \
    | { grep -v '^fixup!' || true; } \
    | head -1)
  if [ -z "$subject" ]; then
    echo "ERROR: could not infer a fixup target subject — no non-merge, non-fixup commits in origin/${base}..HEAD" >&2
    echo "Pass --subject explicitly or commit something on this branch first." >&2
    exit 1
  fi
  echo "Inferred fixup target subject: ${subject}" >&2
fi

# Stage specific files (never git add -A)
git add "${files[@]}"

# Create fixup commit
git commit -m "$(
  cat <<EOF
fixup! ${subject}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Autosquash rebase onto the latest base. The base was already fetched above
# (before subject inference), so we don't re-fetch it here.
git rebase --autosquash "origin/${base}"

# Post-rebase safety check. Note: only reachable when the autosquash rebase
# succeeded — if `git rebase` aborts (conflict, network failure, etc.),
# `set -e` exits before this point, leaving the repo mid-rebase. Callers
# must `git rebase --abort` manually in that case.
#
# Autosquash silently no-ops when the fixup target subject matches a commit
# outside the rebase range (e.g. already on the base branch). Detect that
# here and surface an actionable recovery path. See harness-kit#40.
remaining_fixups=$(git log "origin/${base}..HEAD" --format=%s | grep -c '^fixup!' || true)
if [ "$remaining_fixups" -gt 0 ]; then
  cat >&2 <<EOF
ERROR: ${remaining_fixups} fixup! commit(s) did not get squashed by autosquash.

This typically means the fixup commit's target subject matched a commit
that was already on the base branch (outside the rebase range), so autosquash
found no in-range target to fold into.

Manual recovery (see also harness-kit#42):
  cat > /tmp/squash-fixup.sh <<'SH'
#!/bin/bash
sed -i.bak '/fixup!/s/^pick /fixup /' "\$1"
SH
  chmod +x /tmp/squash-fixup.sh
  env GIT_SEQUENCE_EDITOR=/tmp/squash-fixup.sh git rebase -i origin/${base}
EOF
  exit 1
fi

# Push, hardened against a moved remote branch.
#
# A bare ``git push --force-with-lease`` leases against the locally-tracked
# ``origin/<branch>`` ref. But we only fetched "$base" above, so that ref is
# STALE whenever the remote branch moved since our last push — most commonly a
# GitHub "Update branch" merge commit. The stale lease then rejects the push
# with "stale info", and ``set -e`` aborts the script here, leaving the rebase
# above UNPUSHED — so the PR keeps showing as behind base and the next round
# hits the same wall (a self-perpetuating loop fed by clicking "Update branch").
#
# Fix: re-fetch THIS branch and lease against its FRESH remote tip. That still
# blocks a genuine concurrent push (the lease fails if the remote moves again
# between this fetch and the push), while letting our rebase supersede a
# redundant Update-branch merge — whose content (base's commits) our rebase
# already incorporated.
#
# We must also distinguish "branch is not on the remote yet" (the legitimate
# first-push case, handled by the plain tracking push below) from "fetch itself
# failed" (network, auth, permission — a real problem we should NOT silently
# swallow, because the stale local ``refs/remotes/origin/${branch}`` would
# otherwise feed a misleading lease).
if git fetch origin "$branch" 2>/dev/null; then
  remote_tip="$(git rev-parse --verify "refs/remotes/origin/${branch}")"
  git push --force-with-lease="${branch}:${remote_tip}" origin "$branch"
elif git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  echo "ERROR: failed to fetch origin/${branch} but the branch exists on the remote. Check network/auth and retry." >&2
  exit 1
else
  # Branch genuinely doesn't exist on the remote yet — first push.
  git push -u origin "$branch"
fi
