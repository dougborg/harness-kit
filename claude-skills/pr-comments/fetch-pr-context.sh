#!/usr/bin/env bash
# Fetch PR metadata, comments, and review-thread resolution status.
#
# Usage: fetch-pr-context.sh <owner/repo> <pr-number>
# Output: JSON to stdout with title, body, comments (each with is_resolved)
#         and a top-level unresolved_count.
#
# Combines REST API (for comment details) and GraphQL (for resolved status)
# into a single output so skills don't need to make multiple API calls.
#
# Requires: gh CLI; jq (preferred) or python3 (fallback) for JSON merge.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <owner/repo> <pr-number>" >&2
  echo "Example: $0 owner/repo 19" >&2
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# Fetch PR metadata
pr_json=$(gh pr view "$PR_NUMBER" --repo "$REPO" \
  --json title,body,state,baseRefName,headRefName,author)

# Fetch review comments (REST API — has path, line, body, id)
comments_json=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
  --paginate --jq '[.[] | {id: .id, path: .path, line: .line, body: .body, author: .user.login, created_at: .created_at}]')

# Fetch review thread resolved status (GraphQL), cursor-paginated.
# Pull every comment in each thread so reply-comment IDs also inherit the
# thread's is_resolved status, not just the first comment.
#
# Both connections use pageInfo { hasNextPage, endCursor } so PRs with >100
# review threads, or threads with >100 comments, are fully reported instead
# of silently truncated (issue #20). All per-page parsing goes through gh's
# built-in --jq (gojq), so pagination adds no dependency beyond gh itself;
# jq/python3 are still only needed for the final merge below.
read -r -d '' threads_query <<'GRAPHQL' || true
  query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            comments(first: 100) {
              pageInfo { hasNextPage endCursor }
              nodes { databaseId }
            }
          }
        }
      }
    }
  }
GRAPHQL

# Follow-up query for the rare thread with >100 comments: resume that
# thread's comments connection from the cursor where the main query stopped
# (no refetch, so no duplicate rows reach the merge).
read -r -d '' thread_comments_query <<'GRAPHQL' || true
  query($threadId: ID!, $cursor: String!) {
    node(id: $threadId) {
      ... on PullRequestReviewThread {
        comments(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes { databaseId }
        }
      }
    }
  }
GRAPHQL

# Per page the --jq program emits line-oriented output (gh prints jq string
# results raw, and @json renders compact single-line JSON):
#   line 1:  reviewThreads hasNextPage ("true"/"false")
#   line 2:  reviewThreads endCursor (empty when null)
#   line 3:  rows for this page — compact JSON array, one row per
#            (thread_id, comment_id) so the join works for replies too
#   line 4+: threads whose comments overflowed first:100 —
#            TSV of thread_id, isResolved, comments endCursor
row_pages=()
overflow=""
cursor=""
while :; do
  page_args=(-F "owner=$OWNER" -F "repo=$REPO_NAME" -F "number=$PR_NUMBER")
  if [ -n "$cursor" ]; then
    page_args+=(-f "cursor=$cursor")
  fi
  # shellcheck disable=SC2016  # $rt/$t are jq variables, not shell — single-quote intentional.
  page=$(gh api graphql -f query="$threads_query" "${page_args[@]}" \
    --jq '.data.repository.pullRequest.reviewThreads as $rt
      | ($rt.pageInfo.hasNextPage | tostring),
        ($rt.pageInfo.endCursor // ""),
        ([$rt.nodes[] as $t | $t.comments.nodes[] | {
          comment_id: .databaseId,
          thread_id: $t.id,
          is_resolved: $t.isResolved
        }] | @json),
        ($rt.nodes[]
          | select(.comments.pageInfo.hasNextPage)
          | [.id, (.isResolved | tostring), .comments.pageInfo.endCursor]
          | @tsv)')
  {
    read -r has_next
    read -r cursor
    read -r page_rows
    page_overflow=$(cat)
  } <<<"$page"
  row_pages+=("$page_rows")
  if [ -n "$page_overflow" ]; then
    overflow+="$page_overflow"$'\n'
  fi
  [ "$has_next" = "true" ] || break
done

# Drain comments for any thread that overflowed first:100.
if [ -n "$overflow" ]; then
  while IFS=$'\t' read -r thread_id thread_resolved comments_cursor; do
    [ -n "$thread_id" ] || continue
    extra_rows=""
    while :; do
      # shellcheck disable=SC2016  # $c is a jq variable, not shell — single-quote intentional.
      page=$(gh api graphql -f query="$thread_comments_query" \
        -f "threadId=$thread_id" -f "cursor=$comments_cursor" \
        --jq '.data.node.comments as $c
          | ($c.pageInfo.hasNextPage | tostring),
            ($c.pageInfo.endCursor // ""),
            ($c.nodes[].databaseId)')
      {
        read -r has_next
        read -r comments_cursor
        ids=$(cat)
      } <<<"$page"
      while read -r comment_id; do
        [ -n "$comment_id" ] || continue
        if [ -n "$extra_rows" ]; then
          extra_rows+=","
        fi
        extra_rows+="{\"comment_id\":${comment_id},\"thread_id\":\"${thread_id}\",\"is_resolved\":${thread_resolved}}"
      done <<<"$ids"
      [ "$has_next" = "true" ] || break
    done
    row_pages+=("[$extra_rows]")
  done <<<"$overflow"
fi

# Flatten the per-page compact arrays into one array (plain string surgery
# on compact JSON — only the outermost brackets are touched).
resolved_rows=""
for page_rows in "${row_pages[@]}"; do
  inner="${page_rows#\[}"
  inner="${inner%\]}"
  [ -n "$inner" ] || continue
  if [ -n "$resolved_rows" ]; then
    resolved_rows+=","
  fi
  resolved_rows+="$inner"
done
resolved_json="[$resolved_rows]"

# Merge resolved status into comments
if command -v jq >/dev/null; then
  echo "$pr_json" | jq --argjson comments "$comments_json" \
    --argjson resolved "$resolved_json" '
    . + {
      comments: [
        $comments[] | . as $c |
        . + {
          is_resolved: (
            ($resolved[] | select(.comment_id == $c.id) | .is_resolved) // false
          )
        }
      ],
      unresolved_count: ([
        $comments[] | . as $c |
        select(
          ($resolved[] | select(.comment_id == $c.id) | .is_resolved) // false
          | not
        )
      ] | length)
    }
  '
else
  # Fallback: merge JSON via python3 (jq is not available).
  # The previous string-concat approach used `${pr_json%\}}`, which fails
  # because `\}` is a literal pattern, not an escape — leaving invalid JSON.
  if ! command -v python3 >/dev/null; then
    echo "fetch-pr-context.sh: needs jq or python3 to merge JSON" >&2
    exit 1
  fi
  PR_JSON="$pr_json" COMMENTS_JSON="$comments_json" RESOLVED_JSON="$resolved_json" \
    python3 - <<'PY'
import json, os, sys

pr = json.loads(os.environ["PR_JSON"])
comments = json.loads(os.environ["COMMENTS_JSON"])
resolved = json.loads(os.environ["RESOLVED_JSON"])

# Build comment_id -> is_resolved index so each comment (including replies)
# inherits its thread's flag. Mirror the jq path's output schema exactly so
# downstream consumers don't need to branch on which merger ran.
resolved_by_comment = {row["comment_id"]: row["is_resolved"] for row in resolved}
for c in comments:
    c["is_resolved"] = resolved_by_comment.get(c["id"], False)

pr["comments"] = comments
pr["unresolved_count"] = sum(1 for c in comments if not c["is_resolved"])

json.dump(pr, sys.stdout)
sys.stdout.write("\n")
PY
fi
