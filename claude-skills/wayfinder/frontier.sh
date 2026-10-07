#!/usr/bin/env bash
# List a wayfinder map's child tickets by state, in map order.
#
# Usage: frontier.sh <map-issue-number>
# Prints three groups: FRONTIER (open, unblocked, unclaimed: takeable now),
# CLAIMED (open and assigned), and BLOCKED (open, with an open blocker).
# Testing: WAYFINDER_FIXTURE=<file> reads the GraphQL response from a file.
set -euo pipefail

map="${1:?Usage: frontier.sh <map-issue-number>}"

if [ -n "${WAYFINDER_FIXTURE:-}" ]; then
  data=$(cat "$WAYFINDER_FIXTURE")
else
  read -r owner repo < <(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
  read -r -d '' query <<'GRAPHQL' || true
query($o: String!, $r: String!, $n: Int!) {
  repository(owner: $o, name: $r) {
    issue(number: $n) {
      subIssues(first: 100) {
        nodes {
          number title state
          assignees(first: 1) { totalCount }
          blockedBy(first: 50) { nodes { number state } }
        }
      }
    }
  }
}
GRAPHQL
  data=$(gh api graphql -F o="$owner" -F r="$repo" -F n="$map" -f query="$query")
fi

jq -r '
  [.data.repository.issue.subIssues.nodes[] | select(.state == "OPEN")
   | . + {open_blockers: [.blockedBy.nodes[] | select(.state == "OPEN") | .number]}]
  | (map(select(.open_blockers == [] and .assignees.totalCount == 0))) as $frontier
  | (map(select(.assignees.totalCount > 0))) as $claimed
  | (map(select(.open_blockers != [] and .assignees.totalCount == 0))) as $blocked
  | "FRONTIER", ($frontier[] | "  #\(.number) \(.title)"),
    "CLAIMED", ($claimed[] | "  #\(.number) \(.title)"),
    "BLOCKED", ($blocked[] | "  #\(.number) \(.title)  (blocked by \(.open_blockers | map("#\(.)") | join(", ")))")
' <<<"$data"
