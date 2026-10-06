#!/usr/bin/env bash
# Poll for review activity on a PR with timeout.
#
# Usage: poll-review.sh <owner/repo> <pr-number> [timeout-seconds]
#
# Prints exactly one state and exits:
#   approved           exit 0  a reviewer's latest review is APPROVED
#   changes-requested  exit 0  a reviewer's latest review is CHANGES_REQUESTED
#                              (with actionable threads, or body-only)
#   comments           exit 0  new actionable inline threads exist
#   summary-only       exit 0  a reviewer's latest review is COMMENTED with
#                              zero inline comments (overall body only —
#                              read it, no fixup loop needed)
#   timeout            exit 2  an expected reviewer (requested, or automatic
#                              Copilot) did not arrive in time
#   none               exit 3  nothing from outside reviewers needs action:
#                              nobody is expected (returned at once), or only
#                              Copilot was expected and it has already reviewed
#                              with nothing actionable left
#   error              exit 4  the GitHub API failed 3 polls in a row (auth,
#                              rate limit, wrong repo or PR); details on stderr
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
# Testing: POLL_REVIEW_FIXTURE=<file> reads the GraphQL response from a file
# instead of calling the API (see scripts/test-poll-review.sh).

set -euo pipefail

repo="${1:?Usage: poll-review.sh <owner/repo> <pr-number> [timeout-seconds]}"
pr_number="${2:?Missing PR number}"
timeout="${3:-900}"                             # default 15 minutes
copilot_wait="${POLL_REVIEW_COPILOT_WAIT:-300}" # default 5 min from PR creation
expect_override="${POLL_REVIEW_EXPECT:-auto}"
fixture="${POLL_REVIEW_FIXTURE:-}"
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
     ] | length) as $actionable
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

errfile=$(mktemp)
trap 'rm -f "$errfile"' EXIT

fetch() {
  if [ -n "$fixture" ]; then
    jq -r "$decide" "$fixture"
  else
    gh api graphql -f query="$query" \
      -F "owner=$owner" -F "repo=$repo_name" -F "number=$pr_number" \
      --jq "$decide"
  fi
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
      echo "error"
      exit 4
    fi
  fi
  if [ "$expect_override" != auto ]; then
    expect="$expect_override"
  fi

  case "$state" in
  approved | changes-requested | comments | summary-only)
    echo "$state"
    exit 0
    ;;
  esac

  case "$expect" in
  none)
    echo "none"
    exit 3
    ;;
  copilot)
    # Only Copilot is expected. Once it has reviewed, anything actionable
    # was reported above, so nothing is left to act on. If its window has
    # passed without a review, it is not coming.
    if [ "$copilot_reviewed" = "yes" ]; then
      echo "none"
      exit 3
    fi
    if [ -n "$pr_age" ] && [ "$pr_age" -ge "$copilot_wait" ]; then
      echo "timeout"
      exit 2
    fi
    ;;
  esac

  if [ "$elapsed" -ge "$timeout" ]; then
    echo "timeout"
    exit 2
  fi

  sleep "$interval"
  elapsed=$((elapsed + interval))
done
