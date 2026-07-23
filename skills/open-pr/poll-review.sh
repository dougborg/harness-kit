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
#   timeout            exit 2  no new review activity within the timeout
#
# "Actionable" thread = unresolved AND its last comment is NOT by the PR
# author. Threads the author already replied to don't re-trigger `comments`,
# so the script can be used to watch for the NEXT round of review activity
# without a timestamp baseline. Reviews authored by the PR author (e.g. the
# COMMENTED reviews created by posting in_reply_to replies) are ignored.
#
# Copilot-aware wait: the script will not report `timeout` while the Copilot
# review bot (login contains "copilot-pull-request-reviewer"; REST appends
# "[bot]", GraphQL does not) has not yet reviewed AND the PR is younger than
# POLL_REVIEW_COPILOT_WAIT seconds (default 300, measured from PR creation).
# There is no way to know a priori whether a repo has Copilot review
# configured, so this window is also the graceful fallback for repos
# without it: the hold expires once the PR is older than the window.

set -euo pipefail

repo="${1:?Usage: poll-review.sh <owner/repo> <pr-number> [timeout-seconds]}"
pr_number="${2:?Missing PR number}"
timeout="${3:-900}"                             # default 15 minutes
copilot_wait="${POLL_REVIEW_COPILOT_WAIT:-300}" # default 5 min from PR creation
interval=60
elapsed=0

owner="${repo%%/*}"
repo_name="${repo##*/}"

read -r -d '' query <<'GRAPHQL' || true
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        createdAt
        author { login }
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

# One line of output: "<state> <pr-age-seconds> <copilot-reviewed:yes|no>".
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
  | (if $cr and ($actionable > 0) then "changes-requested"
     elif $cr_body_only then "changes-requested"
     elif $actionable > 0 then "comments"
     elif $approved and ($cr | not) then "approved"
     elif $summary then "summary-only"
     else "pending" end)
    + " " + ((now - ($pr.createdAt | fromdateiso8601)) | floor | tostring)
    + " " + (if $copilot then "yes" else "no" end)
JQ

while :; do
  state="pending"
  pr_age=""
  copilot_reviewed="no"
  if snapshot=$(gh api graphql -f query="$query" \
    -F "owner=$owner" -F "repo=$repo_name" -F "number=$pr_number" \
    --jq "$decide" 2>/dev/null); then
    read -r state pr_age copilot_reviewed <<<"$snapshot"
  fi

  case "$state" in
  approved | changes-requested | comments | summary-only)
    echo "$state"
    exit 0
    ;;
  esac

  if [ "$elapsed" -ge "$timeout" ]; then
    # Copilot-aware hold: keep polling past the timeout while Copilot has
    # not reviewed and the PR is still inside the copilot wait window.
    # If the API call failed (pr_age empty), time out normally.
    if [ "$copilot_reviewed" = "no" ] && [ -n "$pr_age" ] &&
      [ "$pr_age" -lt "$copilot_wait" ]; then
      : # keep waiting for Copilot
    else
      echo "timeout"
      exit 2
    fi
  fi

  sleep "$interval"
  elapsed=$((elapsed + interval))
done
