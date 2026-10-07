#!/usr/bin/env bash
# Regression test for skills/project-management/wayfinder/frontier.sh, using a
# canned GraphQL response (WAYFINDER_FIXTURE) instead of the live API.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/skills/project-management/wayfinder/frontier.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Open and unblocked (#2), blocked by an open ticket (#3), claimed (#4),
# closed (#5), unblocked because its only blocker is closed (#6), and
# blocked by two open tickets alongside a closed one (#7).
cat >"$scratch/map.json" <<'JSON'
{"data":{"repository":{"issue":{"subIssues":{"nodes":[
{"number":2,"title":"Pick the store","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[]}},
{"number":3,"title":"Schema shape","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[{"number":2,"state":"OPEN"}]}},
{"number":4,"title":"Auth model","state":"OPEN","assignees":{"totalCount":1},"blockedBy":{"nodes":[]}},
{"number":5,"title":"Done one","state":"CLOSED","assignees":{"totalCount":0},"blockedBy":{"nodes":[]}},
{"number":6,"title":"Unblocked now","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[{"number":5,"state":"CLOSED"}]}},
{"number":7,"title":"Rollout plan","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[{"number":2,"state":"OPEN"},{"number":3,"state":"OPEN"},{"number":5,"state":"CLOSED"}]}}
]}}}}}
JSON

want='FRONTIER
  #2 Pick the store
  #6 Unblocked now
CLAIMED
  #4 Auth model
BLOCKED
  #3 Schema shape  (blocked by #2)
  #7 Rollout plan  (blocked by #2, #3)'
fail=0
expect() { # expect <name> <fixture-json> <want>
  local got
  printf '%s' "$2" >"$scratch/case.json"
  got=$(WAYFINDER_FIXTURE="$scratch/case.json" "$script" 1)
  if [ "$got" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    diff <(printf '%s\n' "$3") <(printf '%s\n' "$got") || true
    fail=1
  fi
}

expect "frontier, claimed, and blocked groups" "$(cat "$scratch/map.json")" "$want"
expect "map with no sub-issues" \
  '{"data":{"repository":{"issue":{"subIssues":{"nodes":[]}}}}}' \
  'No sub-issues: this map has no tickets yet (or it is not a map).'
expect "empty groups print (none)" \
  '{"data":{"repository":{"issue":{"subIssues":{"nodes":[{"number":9,"title":"Last one","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[]}}]}}}}}' \
  'FRONTIER
  #9 Last one
CLAIMED
  (none)
BLOCKED
  (none)'
exit "$fail"
