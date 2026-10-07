#!/usr/bin/env bash
# List a parent issue's sub-issues by state, in order: a wayfinder map's
# decision tickets, or a spec's implementation tickets.
#
# Usage: sub-issue-frontier.sh <parent-issue-number>
# Prints three groups: FRONTIER (open, unblocked, unclaimed: takeable now),
# CLAIMED (open and assigned), and BLOCKED (open, with an open blocker). An
# empty group prints "(none)"; a map with no sub-issues says so instead, so
# it can't be mistaken for a finished map.
# GitHub caps sub-issues at 100 per parent, so one page covers a map; a
# ticket with more than 50 blockers would need pagination.
# Testing: WAYFINDER_FIXTURE=<file> reads the GraphQL response from a file.
set -euo pipefail

map="${1:?Usage: sub-issue-frontier.sh <parent-issue-number>}"

if [ -n "${WAYFINDER_FIXTURE:-}" ]; then
  data=$(cat "$WAYFINDER_FIXTURE")
else
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
  # gh fills in {owner} and {repo} from the current repository.
  data=$(gh api graphql -F o='{owner}' -F r='{repo}' -F n="$map" -f query="$query")
fi

jq -r '
  if (.data.repository.issue.subIssues.nodes | length) == 0 then
    "No sub-issues: this issue has no tickets yet."
  else
  [.data.repository.issue.subIssues.nodes[] | select(.state == "OPEN")
   | . + {open_blockers: [.blockedBy.nodes[] | select(.state == "OPEN") | .number]}]
  | (map(select(.open_blockers == [] and .assignees.totalCount == 0))) as $frontier
  | (map(select(.assignees.totalCount > 0))) as $claimed
  | (map(select(.open_blockers != [] and .assignees.totalCount == 0))) as $blocked
  | def group($name; $items; f):
      $name, (if ($items | length) == 0 then "  (none)" else ($items[] | f) end);
    group("FRONTIER"; $frontier; "  #\(.number) \(.title)"),
    group("CLAIMED"; $claimed; "  #\(.number) \(.title)"),
    group("BLOCKED"; $blocked;
      "  #\(.number) \(.title)  (blocked by \(.open_blockers | map("#\(.)") | join(", ")))")
  end
' <<<"$data"
