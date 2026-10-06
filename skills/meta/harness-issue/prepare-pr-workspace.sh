#!/usr/bin/env bash
# Prepare a clean working copy of the upstream harness repository so the
# caller can apply changes and open a PR against it.
#
# Behaviour:
#   - Workspace path: $HARNESS_UPSTREAM_WORKSPACE (override) or
#     ${XDG_CACHE_HOME:-$HOME/.cache}/harness-issue/<owner>/<repo>
#   - If the path doesn't exist, clones owner/repo via gh.
#   - If it exists but isn't the right git repo, refuses (avoids clobbering
#     a user's working copy).
#   - Fetches origin, checks out the default branch, fast-forwards.
#   - Refuses to proceed if the existing checkout has uncommitted changes
#     (tracked or untracked) or unpushed commits on the default branch.
#   - Creates the requested branch (must not exist locally or as origin/<branch>).
#   - Prints the resolved absolute workspace path on stdout.
#
# Usage: prepare-pr-workspace.sh <owner/repo> <new-branch-name>

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <owner/repo> <new-branch-name>" >&2
  exit 2
fi

upstream="$1"
branch="$2"

if [[ ! "$upstream" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "ERROR: invalid upstream: $upstream (expected owner/repo)" >&2
  exit 1
fi

if [[ ! "$branch" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$branch" == */ ]] || [[ "$branch" == /* ]]; then
  echo "ERROR: invalid branch name: $branch" >&2
  exit 1
fi

cache_root="${HARNESS_UPSTREAM_WORKSPACE:-${XDG_CACHE_HOME:-$HOME/.cache}/harness-issue}"
workspace="$cache_root/$upstream"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI is required" >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 1
fi

if [ ! -d "$workspace/.git" ]; then
  if [ -e "$workspace" ]; then
    echo "ERROR: $workspace exists but is not a git repository — refusing to clobber it." >&2
    echo "       Move or remove it, or set \$HARNESS_UPSTREAM_WORKSPACE to an alternate path." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$workspace")"
  echo "Cloning $upstream into $workspace ..." >&2
  gh repo clone "$upstream" "$workspace" -- --quiet >&2
fi

cd "$workspace"

# Sanity-check: workspace remote must match the requested upstream.
# Parse owner/repo out of the URL with string ops (not regex) so that owner
# names containing regex metacharacters (e.g. dots) can't cause false matches.
remote_url=$(git config --get remote.origin.url || echo "")
remote_owner_repo=$(
  url="${remote_url%.git}"
  url="${url//:/\/}"
  repo="${url##*/}"
  rest="${url%/"$repo"}"
  owner="${rest##*/}"
  printf '%s/%s' "$owner" "$repo"
)
if [ "$remote_owner_repo" != "$upstream" ]; then
  echo "ERROR: $workspace remote.origin.url ($remote_url) does not match $upstream — refusing to use it." >&2
  exit 1
fi

# Determine default branch (main, master, etc.).
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
if [ -z "$default_branch" ]; then
  default_branch=$(gh repo view "$upstream" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo main)
fi

git fetch origin --quiet >&2

if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: $workspace has uncommitted or untracked changes — refusing to proceed." >&2
  echo "       Commit, stash, or clean them, then retry." >&2
  exit 1
fi

git checkout --quiet "$default_branch" >&2
# Refuse if local default branch has unpushed commits — that's the user's WIP.
ahead=$(git rev-list --count "origin/${default_branch}..${default_branch}" 2>/dev/null || echo 0)
if [ "$ahead" -gt 0 ]; then
  echo "ERROR: $workspace has $ahead unpushed commit(s) on $default_branch — refusing to proceed." >&2
  exit 1
fi
git merge --ff-only --quiet "origin/${default_branch}" >&2

if git show-ref --verify --quiet "refs/heads/${branch}" \
  || git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
  echo "ERROR: branch '$branch' already exists in $workspace (local or origin)." >&2
  exit 1
fi
git checkout -b "$branch" --quiet >&2

# Print the resolved absolute path so callers get an unambiguous workspace
# location regardless of how $HARNESS_UPSTREAM_WORKSPACE was specified.
pwd -P
