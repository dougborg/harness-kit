#!/usr/bin/env bash
# Pull request review threads and comments, behind one interface.
#
# Usage: pr-threads.sh <pr-number|pr-url> <command> [args]
#
# Commands:
#   repo                      print owner/repo
#   context                   PR metadata plus every review comment, each with
#                             is_resolved, and a top-level unresolved_count
#   unresolved                JSON array: the latest comment of each unresolved
#                             thread (id, path, line, body, author)
#   reply <comment-id> <body> reply in the comment's thread, after checking the
#                             comment belongs to this PR; prints {id, url}
#   resolve-all               resolve every unresolved thread; prints the count
#
# The repo comes from a PR URL when given one (so a URL for another repo or a
# fork works), and from the `origin` remote for a bare number. Every thread
# query is cursor-paginated, so PRs with more than 100 threads are complete
# (#20, #155).
#
# Exit 0 on success; 1 on a bad argument, an API error, or (resolve-all) a
# thread that failed to resolve. Requires gh and jq.

set -euo pipefail

usage() {
  sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

[ $# -ge 2 ] || usage
pr_arg=$1
command=$2
shift 2

if [[ "$pr_arg" =~ ^https?://[^/]+/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  pr="${BASH_REMATCH[3]}"
elif [[ "$pr_arg" =~ ^[0-9]+$ ]]; then
  pr=$pr_arg
  url=$(git remote get-url origin 2>/dev/null || true)
  if [ -z "$url" ]; then
    echo "pr-threads: no 'origin' remote; pass the PR URL instead of a number" >&2
    exit 1
  fi
  repo=$(sed -E 's#^.*github\.com[:/]##; s#\.git$##' <<<"$url")
else
  echo "pr-threads: not a PR number or URL: $pr_arg" >&2
  exit 1
fi
owner=${repo%%/*}
name=${repo##*/}

# paginate <query> <jq>: run a reviewThreads query page by page. The query
# takes $owner, $repo, $number, and $cursor; the jq program prints
# hasNextPage, then endCursor, then this page's output lines. Prints every
# page's output lines.
paginate() {
  local query=$1 program=$2 cursor="" page has_next rest
  while :; do
    local args=(-F "owner=$owner" -F "repo=$name" -F "number=$pr")
    if [ -n "$cursor" ]; then args+=(-f "cursor=$cursor"); fi
    page=$(gh api graphql -f query="$query" "${args[@]}" --jq "$program")
    {
      read -r has_next
      read -r cursor
      rest=$(cat)
    } <<<"$page"
    if [ -n "$rest" ]; then printf '%s\n' "$rest"; fi
    [ "$has_next" = "true" ] || break
  done
}

# jq programs live in quoted heredocs, like the GraphQL, so their $variables
# stay jq's. Every page program starts with this head: hasNextPage, endCursor.
read -r -d '' threads_jq_head <<'JQ' || true
.data.repository.pullRequest.reviewThreads as $rt
| ($rt.pageInfo.hasNextPage | tostring), ($rt.pageInfo.endCursor // ""),
JQ

unresolved() {
  local query program
  # The latest comment is the current ask; comments(last: 1) also avoids the
  # nested 100-comment cap. A thread whose only comment was deleted is skipped.
  read -r -d '' query <<'GRAPHQL' || true
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          comments(last: 1) {
            nodes { databaseId body path line author { login } }
          }
        }
      }
    }
  }
}
GRAPHQL
  read -r -d '' program <<'JQ' || true
($rt.nodes[] | select(.isResolved | not) | .comments.nodes[0] | select(. != null)
  | {id: .databaseId, path, line, body, author: .author.login} | @json)
JQ
  paginate "$query" "$threads_jq_head $program" | jq -s .
}

resolve_all() {
  local query mutation program ids id resolved=0 failed=0
  read -r -d '' query <<'GRAPHQL' || true
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { id isResolved }
      }
    }
  }
}
GRAPHQL
  read -r -d '' mutation <<'GRAPHQL' || true
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) { thread { isResolved } }
}
GRAPHQL
  read -r -d '' program <<'JQ' || true
($rt.nodes[] | select(.isResolved | not) | .id)
JQ
  ids=$(paginate "$query" "$threads_jq_head $program")
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ "$(gh api graphql -f query="$mutation" -f threadId="$id" \
      --jq '.data.resolveReviewThread.thread.isResolved')" = true ]; then
      resolved=$((resolved + 1))
    else
      echo "pr-threads: failed to resolve thread $id" >&2
      failed=$((failed + 1))
    fi
  done <<<"$ids"
  echo "$resolved"
  [ "$failed" -eq 0 ]
}

context() {
  local pr_json comments_json query program rows overflow thread_query
  pr_json=$(gh pr view "$pr" --repo "$repo" --json title,body,state,baseRefName,headRefName,author)
  comments_json=$(gh api "repos/$repo/pulls/$pr/comments" --paginate \
    --jq '.[] | {id, path, line, body, author: .user.login, created_at}' | jq -s .)
  # Every comment of every thread, so replies inherit their thread's status.
  read -r -d '' query <<'GRAPHQL' || true
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
  # Each output line is a row ({comment_id, is_resolved}) or, for a thread
  # whose comments overflowed, an {overflow: [thread, resolved, cursor]} line.
  read -r -d '' program <<'JQ' || true
($rt.nodes[] as $t
  | ($t.comments.nodes[] | {comment_id: .databaseId, is_resolved: $t.isResolved} | @json),
    (select($t.comments.pageInfo.hasNextPage)
      | {overflow: [$t.id, $t.isResolved, $t.comments.pageInfo.endCursor]} | @json))
JQ
  rows=$(paginate "$query" "$threads_jq_head $program")
  overflow=$(jq -c 'select(.overflow) | .overflow' <<<"$rows")
  rows=$(jq -c 'select(.comment_id)' <<<"$rows")
  read -r -d '' thread_query <<'GRAPHQL' || true
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
  local entry thread resolved cursor page has_next ids comments_program merge
  read -r -d '' comments_program <<'JQ' || true
.data.node.comments as $c
| ($c.pageInfo.hasNextPage | tostring), ($c.pageInfo.endCursor // ""), ($c.nodes[].databaseId)
JQ
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    thread=$(jq -r '.[0]' <<<"$entry")
    resolved=$(jq -r '.[1]' <<<"$entry")
    cursor=$(jq -r '.[2]' <<<"$entry")
    while :; do
      page=$(gh api graphql -f query="$thread_query" -f "threadId=$thread" -f "cursor=$cursor" \
        --jq "$comments_program")
      {
        read -r has_next
        read -r cursor
        ids=$(cat)
      } <<<"$page"
      rows+=$'\n'$(jq -c --argjson r "$resolved" "{comment_id: ., is_resolved: \$r}" <<<"$ids")
      [ "$has_next" = "true" ] || break
    done
  done <<<"$overflow"
  read -r -d '' merge <<'JQ' || true
($resolved | map({key: (.comment_id | tostring), value: .is_resolved}) | from_entries) as $by_id
| [$comments[] | . + {is_resolved: ($by_id[.id | tostring] // false)}] as $merged
| . + {comments: $merged, unresolved_count: ([$merged[] | select(.is_resolved | not)] | length)}
JQ
  jq --argjson comments "$comments_json" --argjson resolved "$(jq -s . <<<"$rows")" \
    "$merge" <<<"$pr_json"
}

reply() {
  [ $# -eq 2 ] || usage
  local comment_id=$1 body=$2 comment_pr
  # The comment must belong to this PR, or the reply lands on the wrong one.
  comment_pr=$(gh api "repos/$repo/pulls/comments/$comment_id" --jq '.pull_request_url' 2>/dev/null || true)
  if [ -z "$comment_pr" ]; then
    echo "pr-threads: comment $comment_id not found in $repo" >&2
    exit 1
  fi
  if [ "${comment_pr##*/}" != "$pr" ]; then
    echo "pr-threads: comment $comment_id belongs to PR #${comment_pr##*/}, not #$pr" >&2
    exit 1
  fi
  # POST .../pulls/<n>/comments with in_reply_to; .../comments/<id>/replies
  # does not exist.
  gh api "repos/$repo/pulls/$pr/comments" -X POST -F in_reply_to="$comment_id" \
    -f body="$body" --jq '{id, url: .html_url}'
}

case "$command" in
repo) echo "$repo" ;;
context) context ;;
unresolved) unresolved ;;
reply) reply "$@" ;;
resolve-all) resolve_all ;;
*) usage ;;
esac
