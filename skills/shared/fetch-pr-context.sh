#!/usr/bin/env bash
# Fetch PR metadata, diff, comments, and review thread resolution status.
#
# Usage: fetch-pr-context.sh <owner/repo> <pr-number>
# Output: JSON to stdout with title, body, comments (with resolved status)
#
# Combines REST API (for comment details) and GraphQL (for resolved status)
# into a single output so skills don't need to make multiple API calls.

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

# Fetch review thread resolved status (GraphQL)
read -r -d '' query <<'GRAPHQL' || true
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { databaseId }
            }
          }
        }
      }
    }
  }
GRAPHQL
resolved_json=$(gh api graphql -f query="$query" \
  -F "owner=$OWNER" -F "repo=$REPO_NAME" -F "number=$PR_NUMBER" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | {
    comment_id: .comments.nodes[0].databaseId,
    thread_id: .id,
    is_resolved: .isResolved
  }]')

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
  # Fallback: return without merged resolution (jq not available)
  echo "${pr_json%\}}, \"comments\": $comments_json, \"resolved_threads\": $resolved_json}"
fi
