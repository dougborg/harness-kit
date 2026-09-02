#!/usr/bin/env bash
# Fetch unresolved review comments for a PR.
#
# Usage: fetch-unresolved-comments.sh <owner/repo> <pr-number>
# Output: JSON array of unresolved comments with id, path, line, body, author
#
# Uses GraphQL to get resolved status, then filters to unresolved only.
#
# Note: `line` may be null for file-level review comments (those not anchored
# to a specific line in the diff). This is expected and matches GitHub's schema.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <owner/repo> <pr-number>" >&2
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# reviewThreads is cursor-paginated via pageInfo { hasNextPage, endCursor }
# so PRs with >100 review threads are fully reported instead of silently
# truncated (issue #20). Nested comments need no pagination here: see the
# `comments(last: 1)` note below.
read -r -d '' query <<'GRAPHQL' || true
  query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            comments(last: 1) {
              nodes {
                id
                databaseId
                body
                path
                line
                author { login }
              }
            }
          }
        }
      }
    }
  }
GRAPHQL
# For each unresolved thread, surface the LATEST comment. A thread can
# accumulate multiple comments (reviewer's original + author's reply +
# reviewer's follow-up); the "reply to every comment" workflow needs the
# most recent ask, not the original request. Using `comments(last: 1)`
# at the API layer fetches only that latest comment directly — this
# avoids the 100-comment pagination cap that would silently truncate
# very long threads, and reduces payload size. The `select(. != null)`
# guard drops threads whose only comment was deleted (empty `nodes`).
# The reply itself attaches to the thread regardless of which comment
# ID is used as the anchor.
#
# Per page the --jq program emits three lines (gh prints jq string results
# raw, and @json renders compact single-line JSON):
#   line 1: hasNextPage ("true"/"false")
#   line 2: endCursor (empty when null)
#   line 3: this page's unresolved comments — compact JSON array
rows=""
cursor=""
while :; do
  page_args=(-F "owner=$OWNER" -F "repo=$REPO_NAME" -F "number=$PR_NUMBER")
  if [ -n "$cursor" ]; then
    page_args+=(-f "cursor=$cursor")
  fi
  # shellcheck disable=SC2016  # $rt is a jq variable, not shell — single-quote intentional.
  page=$(gh api graphql -f query="$query" "${page_args[@]}" \
    --jq '.data.repository.pullRequest.reviewThreads as $rt
      | ($rt.pageInfo.hasNextPage | tostring),
        ($rt.pageInfo.endCursor // ""),
        ([$rt.nodes[]
          | select(.isResolved | not)
          | .comments.nodes[0]
          | select(. != null)
          | {id: .databaseId, path: .path, line: .line, body: .body, author: .author.login}
        ] | @json)')
  {
    read -r has_next
    read -r cursor
    read -r page_rows
  } <<<"$page"
  # Splice this page's rows into the accumulator (compact JSON — only the
  # outermost brackets are touched).
  inner="${page_rows#\[}"
  inner="${inner%\]}"
  if [ -n "$inner" ]; then
    if [ -n "$rows" ]; then
      rows+=","
    fi
    rows+="$inner"
  fi
  [ "$has_next" = "true" ] || break
done

printf '[%s]\n' "$rows"
