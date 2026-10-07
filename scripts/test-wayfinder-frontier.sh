#!/usr/bin/env bash
# Regression test for skills/project-management/wayfinder/frontier.sh, using a
# canned GraphQL response (WAYFINDER_FIXTURE) instead of the live API.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/skills/project-management/wayfinder/frontier.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Open and unblocked (#2), blocked by an open ticket (#3), claimed (#4),
# closed (#5), and unblocked because its only blocker is closed (#6).
cat >"$scratch/map.json" <<'JSON'
{"data":{"repository":{"issue":{"subIssues":{"nodes":[
{"number":2,"title":"Pick the store","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[]}},
{"number":3,"title":"Schema shape","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[{"number":2,"state":"OPEN"}]}},
{"number":4,"title":"Auth model","state":"OPEN","assignees":{"totalCount":1},"blockedBy":{"nodes":[]}},
{"number":5,"title":"Done one","state":"CLOSED","assignees":{"totalCount":0},"blockedBy":{"nodes":[]}},
{"number":6,"title":"Unblocked now","state":"OPEN","assignees":{"totalCount":0},"blockedBy":{"nodes":[{"number":5,"state":"CLOSED"}]}}
]}}}}}
JSON

want='FRONTIER
  #2 Pick the store
  #6 Unblocked now
CLAIMED
  #4 Auth model
BLOCKED
  #3 Schema shape  (blocked by #2)'
got=$(WAYFINDER_FIXTURE="$scratch/map.json" "$script" 1)
if [ "$got" = "$want" ]; then
  echo "PASS: frontier, claimed, and blocked groups"
else
  echo "FAIL: frontier grouping"
  diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") || true
  exit 1
fi
