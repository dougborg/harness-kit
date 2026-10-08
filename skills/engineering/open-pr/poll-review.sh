#!/usr/bin/env bash
# Poll for review activity on a PR with timeout.
#
# Usage: poll-review.sh <pr-number|pr-url> [timeout-seconds]
#
# Output contract (shared with poll-ci.sh): while waiting it prints a
# "REVIEW POLL:" heartbeat each interval; every terminal outcome ends with
# one "REVIEW RESULT: <state> for PR #N …" line. Output that ends on a
# heartbeat means the poll was killed mid-wait: the state is unknown, re-poll.
#
#   state              exit
#   approved           0  a reviewer's latest review is APPROVED
#   changes-requested  0  a reviewer's latest review is CHANGES_REQUESTED
#                         (with actionable threads, or body-only)
#   comments           0  new actionable inline threads exist
#   summary-only       0  a reviewer's latest review is COMMENTED with zero
#                         inline comments (overall body only: read it, no
#                         fixup loop needed)
#   none               0  nothing from outside reviewers needs action:
#                         nobody is expected (returned at once), or only
#                         Copilot was expected and it has already reviewed
#                         with nothing actionable left
#   timeout            2  an expected reviewer (requested, or automatic
#                         Copilot) did not arrive in time
#   error              3  the PR couldn't be read, or the GitHub API failed 3
#                         polls in a row; details on stderr
#   (usage)            64 a bad argument or POLL_REVIEW_EXPECT value; no
#                         RESULT line
#
# "Actionable" thread = unresolved AND its last comment is NOT by the PR
# author. Threads the author already replied to don't re-trigger `comments`,
# so the script can be used to watch for the NEXT round of review activity
# without a timestamp baseline. Reviews authored by the PR author (e.g. the
# COMMENTED reviews created by posting in_reply_to replies) are ignored.
#
# Who is expected (POLL_REVIEW_EXPECT=auto|requested|copilot|none overrides):
#   requested  someone (a person, team, or the Copilot bot) is in the PR's
#              pending review requests: wait up to the full timeout.
#   copilot    nobody is requested, but the Copilot review bot (login contains
#              "copilot-pull-request-reviewer") reviewed at least 3 of the
#              repo's 5 most recent other PRs, i.e. automatic review is on.
#              (One or two manual requests on past PRs don't count: a manual
#              request on this PR shows up as `requested`.) Wait only while
#              Copilot has not reviewed and the PR is younger than
#              POLL_REVIEW_COPILOT_WAIT seconds (default 300), measured from
#              PR creation: Copilot usually lands 2-5 minutes after the PR
#              opens, so by the time open-pr finishes CI and its agent review
#              it has normally arrived or is not coming.
#   none       neither: report `none` immediately instead of idling. Our own
#              agent review is the gate; outside reviews are optional input.
#
# Early states (approved, summary-only) come from each reviewer's latest
# review, which may predate your newest push; check the review time when it
# matters.
#
# Testing: scripts/test-poll-review.sh puts a stub gh first on PATH;
# POLL_REVIEW_INTERVAL overrides the 60s interval.

set -euo pipefail

pr_arg="${1:?Usage: poll-review.sh <pr-number|pr-url> [timeout-seconds]}"
timeout="${2:-900}"                             # default 15 minutes
copilot_wait="${POLL_REVIEW_COPILOT_WAIT:-300}" # default 5 min from PR creation
expect_override="${POLL_REVIEW_EXPECT:-auto}"
interval="${POLL_REVIEW_INTERVAL:-60}"
max_failures=3
failures=0

case "$expect_override" in
auto | requested | copilot | none) ;;
*)
  echo "poll-review.sh: POLL_REVIEW_EXPECT must be auto, requested, copilot, or none (got '$expect_override')" >&2
  exit 64
  ;;
esac
elapsed=0

# result <state> <exit> [detail]: the terminal line, then exit.
result() {
  echo "REVIEW RESULT: $1 for PR #${pr_number:-?} after ${elapsed}s${3:+ — $3}"
  exit "$2"
}

# The repo comes from a PR URL, or from gh for a bare number (the current
# repo). This script is skill-local, so it resolves the repo itself rather
# than calling the shared pr-threads.sh; keep the URL handling in step with
# that script's.
if [[ "$pr_arg" =~ ^https?://([^/]+)/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
  if [ "${BASH_REMATCH[1]}" != github.com ]; then export GH_HOST="${BASH_REMATCH[1]}"; fi
  repo="${BASH_REMATCH[2]}"
  pr_number="${BASH_REMATCH[3]}"
elif [[ "$pr_arg" =~ ^[0-9]+$ ]]; then
  pr_number=$pr_arg
  if ! url=$(gh pr view "$pr_number" --json url --jq .url) ||
    [[ ! "$url" =~ ^https?://[^/]+/([^/]+/[^/]+)/pull/ ]]; then
    echo "poll-review.sh: couldn't read PR #$pr_number from GitHub (check the number and gh auth)" >&2
    result error 3
  fi
  repo="${BASH_REMATCH[1]}"
else
  echo "poll-review.sh: not a PR number or URL: $pr_arg" >&2
  exit 64
fi
owner="${repo%%/*}"
repo_name="${repo##*/}"

read -r -d '' query <<'GRAPHQL' || true
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequests(last: 6, states: [OPEN, MERGED, CLOSED]) {
        nodes {
          number
          reviews(first: 50) { nodes { author { login } } }
        }
      }
      pullRequest(number: $number) {
        number
        createdAt
        author { login }
        reviewRequests(first: 1) { totalCount }
        reviews(last: 100) {
          nodes {
            state
            submittedAt
            author { login }
            comments { totalCount }
          }
        }
        reviewThreads(first: 100) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            comments(last: 1) {
              nodes { author { login } }
            }
          }
        }
      }
    }
  }
GRAPHQL

# One line of output:
#   "<state> <pr-age-seconds> <copilot-reviewed:yes|no> <expect>".
# State precedence: changes-requested > comments > approved > summary-only.
# A CHANGES_REQUESTED review only fires while it still has actionable
# threads — or has no inline comments at all (body-only request) — so an
# already-replied-to round doesn't re-trigger on the next poll.
read -r -d '' decide <<'JQ' || true
  .data.repository.pullRequest as $pr
  | ($pr.author.login // "") as $pr_author
  | ([ $pr.reviewThreads.nodes[]
       | select(.isResolved | not)
       | select((.comments.nodes[0].author.login // "") != $pr_author)
     ] | length + $more_actionable) as $actionable
  | ([ $pr.reviews.nodes[]
       | select(.state != "PENDING")
       | select((.author.login // "") != $pr_author)
     ] | group_by(.author.login) | map(max_by(.submittedAt))
    ) as $latest
  | ([ $latest[] | select(.state == "CHANGES_REQUESTED") ] | length > 0) as $cr
  | ([ $latest[] | select(.state == "CHANGES_REQUESTED"
                          and .comments.totalCount == 0) ] | length > 0
    ) as $cr_body_only
  | ([ $latest[] | select(.state == "APPROVED") ] | length > 0) as $approved
  | ([ $latest[] | select(.state == "COMMENTED"
                          and .comments.totalCount == 0) ] | length > 0
    ) as $summary
  | ([ $pr.reviews.nodes[]
       | select((.author.login // "") | ascii_downcase
                | contains("copilot-pull-request-reviewer"))
     ] | length > 0) as $copilot
  | ([ [ .data.repository.pullRequests.nodes[]
         | select(.number != $pr.number) ]
       | .[-5:][]
     | select([ .reviews.nodes[]
                  | (.author.login // "") | ascii_downcase
                  | select(contains("copilot-pull-request-reviewer")) ]
                | length > 0)
     ] | length) as $copilot_recent
  | (if $pr.reviewRequests.totalCount > 0 then "requested"
     elif $copilot_recent >= 3 then "copilot"
     else "none" end) as $expect
  | (if $cr and ($actionable > 0) then "changes-requested"
     elif $cr_body_only then "changes-requested"
     elif $actionable > 0 then "comments"
     elif $approved and ($cr | not) then "approved"
     elif $summary then "summary-only"
     else "pending" end)
    + " " + ((now - ($pr.createdAt | fromdateiso8601)) | floor | tostring)
    + " " + (if $copilot then "yes" else "no" end)
    + " " + $expect
JQ

# Threads past the first 100: same "actionable" rule, one page at a time.
read -r -d '' threads_query <<'GRAPHQL' || true
  query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            comments(last: 1) { nodes { author { login } } }
          }
        }
      }
    }
  }
GRAPHQL
read -r -d '' page_info <<'JQ' || true
  .data.repository.pullRequest.reviewThreads.pageInfo
  | "\(.hasNextPage // false) \(.endCursor // "")"
JQ
read -r -d '' page_actionable <<'JQ' || true
  [ .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved | not)
    | select((.comments.nodes[0].author.login // "") != $pr_author)
  ] | length
JQ

errfile=$(mktemp)
trap 'rm -f "$errfile"' EXIT

# graphql <query> [cursor]: one response.
graphql() {
  gh api graphql -f query="$1" -f "owner=$owner" -f "repo=$repo_name" \
    -F "number=$pr_number" ${2:+-f "cursor=$2"}
}

# fetch runs inside `if snapshot=$(fetch)`, where set -e is off, so every
# step returns its own failure: a failed call must count as a failed poll.
fetch() {
  local first page n more=0 has_next cursor author info
  first=$(graphql "$query") || return 1
  author=$(jq -r '.data.repository.pullRequest.author.login // ""' <<<"$first") || return 1
  info=$(jq -r "$page_info" <<<"$first") || return 1
  read -r has_next cursor <<<"$info"
  while [ "$has_next" = true ]; do
    [ -n "$cursor" ] || return 1 # a next page with no cursor would loop
    page=$(graphql "$threads_query" "$cursor") || return 1
    n=$(jq --arg pr_author "$author" "$page_actionable" <<<"$page") || return 1
    more=$((more + n))
    info=$(jq -r "$page_info" <<<"$page") || return 1
    read -r has_next cursor <<<"$info"
  done
  jq -r --argjson more_actionable "$more" "$decide" <<<"$first"
}

while :; do
  state="pending"
  pr_age=""
  copilot_reviewed="no"
  expect="requested" # after a transient failure, fall back to a timed wait
  if snapshot=$(fetch 2>"$errfile"); then
    failures=0
    read -r state pr_age copilot_reviewed expect <<<"$snapshot"
  else
    failures=$((failures + 1))
    # Give up after repeated failures, or at the timeout if the last poll
    # failed: either way no review state is known, so `timeout` would lie.
    if [ "$failures" -ge "$max_failures" ] || [ "$elapsed" -ge "$timeout" ]; then
      echo "poll-review.sh: GitHub API failed ($failures in a row):" >&2
      cat "$errfile" >&2
      result error 3 "the GitHub API failed $failures polls in a row"
    fi
  fi
  if [ "$expect_override" != auto ]; then
    expect="$expect_override"
  fi

  case "$state" in
  approved | changes-requested | comments | summary-only)
    result "$state" 0
    ;;
  esac

  case "$expect" in
  none)
    result none 0 "no outside reviewer is expected"
    ;;
  copilot)
    # Only Copilot is expected. Once it has reviewed, anything actionable
    # was reported above, so nothing is left to act on. If its window has
    # passed without a review, it is not coming.
    if [ "$copilot_reviewed" = "yes" ]; then
      result none 0 "Copilot has reviewed and nothing is left to act on"
    fi
    if [ -n "$pr_age" ] && [ "$pr_age" -ge "$copilot_wait" ]; then
      result timeout 2 "Copilot's window passed without a review"
    fi
    ;;
  esac

  if [ "$elapsed" -ge "$timeout" ]; then
    result timeout 2 "an expected reviewer has not arrived"
  fi

  echo "REVIEW POLL: ${elapsed}s elapsed for PR #${pr_number} — no actionable review yet (expecting: ${expect}), waiting..."
  sleep "$interval"
  elapsed=$((elapsed + interval))
done
