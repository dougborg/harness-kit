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
# The repo (and, for GitHub Enterprise, the host) comes from a PR URL when
# given one, so a URL for another repo or a fork works; a bare number uses the
# `origin` remote. Every thread query is cursor-paginated, so PRs with more
# than 100 threads are complete (#20, #155).
#
# Exit 0 on success; 1 on a bad argument, any failed GitHub call (never a
# quiet empty result), or (resolve-all) a thread that failed to resolve.
# Requires gh and jq.

set -euo pipefail

usage() {
  sed -n '3,/^$/{/^#/p;}' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

die() {
  echo "pr-threads: $*" >&2
  exit 1
}

[ $# -ge 2 ] || usage
pr_arg=$1
command=$2
shift 2

# owner/repo from a git remote URL that names a host, in any of its shapes:
# git@host:o/r.git, ssh://git@host/o/r, https://host/o/r(.git). A local path
# or file:// remote names no GitHub repo, so it prints nothing.
repo_from_remote() {
  case "$1" in
  file://* | /* | ./* | ../*) return 0 ;;
  *://*/* | *:*) sed -E 's#\.git/?$##; s#/$##; s#^.*[:/]([^/:]+/[^/:]+)$#\1#' <<<"$1" ;;
  esac
}

if [[ "$pr_arg" =~ ^https?://([^/]+)/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  host="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]}"
  pr="${BASH_REMATCH[4]}"
  if [ "$host" != github.com ]; then export GH_HOST="$host"; fi
elif [[ "$pr_arg" =~ ^[0-9]+$ ]]; then
  pr=$pr_arg
  url=$(git remote get-url origin 2>/dev/null) || die "no 'origin' remote; pass the PR URL instead of a number"
  repo=$(repo_from_remote "$url")
else
  die "not a PR number or URL: $pr_arg"
fi
[[ "$repo" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || die "can't read owner/repo from '$repo'; pass the PR URL"
owner=${repo%%/*}
name=${repo##*/}

# paginate <jq> <start-cursor> <gh api graphql args...>: run a paginated
# GraphQL query page by page, adding -f cursor=<cursor> after the first page
# (or from the start, when a start cursor is given). The jq program prints
# hasNextPage, then endCursor, then this page's output lines. Prints every
# page's output lines; returns 1 on any failed call, so a caller never mistakes
# a failure for an empty result.
paginate() {
  local program=$1 cursor=$2 page has_next rest
  shift 2
  while :; do
    local args=("$@")
    if [ -n "$cursor" ]; then args+=(-f "cursor=$cursor"); fi
    page=$(gh api graphql "${args[@]}" --jq "$program") || return 1
    {
      read -r has_next || return 1
      read -r cursor || true
      rest=$(cat)
    } <<<"$page"
    if [ -n "$rest" ]; then printf '%s\n' "$rest"; fi
    case "$has_next" in
    true) [ -n "$cursor" ] || return 1 ;; # a next page with no cursor would loop
    false) break ;;
    *) return 1 ;;
    esac
  done
}

# paginate_threads <query> <jq-body>: paginate over the PR's reviewThreads.
paginate_threads() {
  paginate "$threads_jq_head $2" "" -f query="$1" \
    -f "owner=$owner" -f "repo=$name" -F "number=$pr"
}

# jq programs live in quoted heredocs, like the GraphQL, so their $variables
# stay jq's. Every page program starts with hasNextPage, then endCursor.
read -r -d '' threads_jq_head <<'JQ' || true
.data.repository.pullRequest.reviewThreads as $rt
| ($rt.pageInfo.hasNextPage | tostring), ($rt.pageInfo.endCursor // ""),
JQ

unresolved() {
  local query program rows
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
  rows=$(paginate_threads "$query" "$program") || die "fetching review threads failed"
  jq -s . <<<"$rows"
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
  ids=$(paginate_threads "$query" "$program") || die "fetching review threads failed"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    # Counted only when GitHub confirms the thread is now resolved.
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

# Scratch files for context's payloads: argv caps one argument at ~128KB.
scratch=""
trap 'if [ -n "$scratch" ]; then rm -rf "$scratch"; fi' EXIT

context() {
  local query program rows overflow thread_query comments_program merge
  local entry thread resolved cursor ids
  scratch=$(mktemp -d)
  gh pr view "$pr" --repo "$repo" --json title,body,state,baseRefName,headRefName,author \
    >"$scratch/pr.json" || die "reading PR #$pr in $repo failed"
  gh api "repos/$repo/pulls/$pr/comments" --paginate \
    --jq '.[] | {id, path, line, body, author: .user.login, created_at}' \
    >"$scratch/comments.jsonl" || die "reading review comments failed"
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
  rows=$(paginate_threads "$query" "$program") || die "fetching review threads failed"
  overflow=$(jq -c 'select(.overflow) | .overflow' <<<"$rows")
  jq -c 'select(.comment_id)' <<<"$rows" >"$scratch/rows.jsonl"
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
  read -r -d '' comments_program <<'JQ' || true
.data.node.comments as $c
| ($c.pageInfo.hasNextPage | tostring), ($c.pageInfo.endCursor // ""), ($c.nodes[].databaseId)
JQ
  # Drain the rest of any thread whose comments overflowed the first 100.
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    thread=$(jq -r '.[0]' <<<"$entry")
    resolved=$(jq -r '.[1]' <<<"$entry")
    cursor=$(jq -r '.[2]' <<<"$entry")
    ids=$(paginate "$comments_program" "$cursor" -f query="$thread_query" \
      -f "threadId=$thread") || die "fetching comments of thread $thread failed"
    if [ -n "$ids" ]; then
      jq -c --argjson r "$resolved" "{comment_id: ., is_resolved: \$r}" <<<"$ids" >>"$scratch/rows.jsonl"
    fi
  done <<<"$overflow"
  read -r -d '' merge <<'JQ' || true
($resolved | map({key: (.comment_id | tostring), value: .is_resolved}) | from_entries) as $by_id
| [$comments[] | . + {is_resolved: ($by_id[.id | tostring] // false)}] as $merged
| . + {comments: $merged, unresolved_count: ([$merged[] | select(.is_resolved | not)] | length)}
JQ
  jq --slurpfile comments "$scratch/comments.jsonl" --slurpfile resolved "$scratch/rows.jsonl" \
    "$merge" "$scratch/pr.json"
}

reply() {
  [ $# -eq 2 ] || usage
  local comment_id=$1 body=$2 comment_pr
  # The comment must belong to this PR, or the reply lands on the wrong one.
  comment_pr=$(gh api "repos/$repo/pulls/comments/$comment_id" --jq '.pull_request_url') ||
    die "looking up comment $comment_id in $repo failed (see gh's error above)"
  if [ "${comment_pr##*/}" != "$pr" ]; then
    die "comment $comment_id belongs to PR #${comment_pr##*/}, not #$pr"
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
