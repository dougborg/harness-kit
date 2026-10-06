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
#   timeout            exit 2  an outside review was expected but none arrived
#                              within the timeout
#   none               exit 3  no outside review is expected: nobody is
#                              requested and Copilot does not review this
#                              repo's PRs automatically. Returned at once.
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
#              Wait only while Copilot has not reviewed and the PR is younger
#              than POLL_REVIEW_COPILOT_WAIT seconds (default 300); Copilot
#              usually lands 2-5 minutes after the PR opens.
#   none       neither: report `none` immediately instead of idling. Our own
#              agent review (open-pr Phase 7) is the gate; outside reviews
#              are optional input.

set -euo pipefail

repo="${1:?Usage: poll-review.sh <owner/repo> <pr-number> [timeout-seconds]}"
pr_number="${2:?Missing PR number}"
timeout="${3:-900}"                             # default 15 minutes
copilot_wait="${POLL_REVIEW_COPILOT_WAIT:-300}" # default 5 min from PR creation
expect_override="${POLL_REVIEW_EXPECT:-auto}"
interval=60
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
  | ([ .data.repository.pullRequests.nodes[]
       | select(.number != $pr.number)
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

while :; do
  state="pending"
  pr_age=""
  copilot_reviewed="no"
  expect="requested" # if the API call fails, fall back to a plain timed wait
  if snapshot=$(gh api graphql -f query="$query" \
    -F "owner=$owner" -F "repo=$repo_name" -F "number=$pr_number" \
    --jq "$decide" 2>/dev/null); then
    read -r state pr_age copilot_reviewed expect <<<"$snapshot"
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
    # Only Copilot is expected: stop once it has reviewed (any actionable
    # state was reported above) or its window has passed.
    if [ "$copilot_reviewed" = "yes" ] ||
      { [ -n "$pr_age" ] && [ "$pr_age" -ge "$copilot_wait" ]; }; then
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
