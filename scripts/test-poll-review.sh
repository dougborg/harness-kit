#!/usr/bin/env bash
# Regression tests for skills/engineering/open-pr/poll-review.sh decision
# logic, using canned GraphQL responses (POLL_REVIEW_FIXTURE) instead of the
# live API.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/skills/engineering/open-pr/poll-review.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# fixture <name> <json-args...>: build a GraphQL response for PR #10.
#   created=old|new  requests=N  copilot_history=list of booleans (oldest first)
#   reviews=JSON array  threads=JSON array
fixture() {
  python3 - "$scratch/$1.json" "${@:2}" <<'PY'
import json, sys, datetime
out, *args = sys.argv[1:]
opts = dict(a.split("=", 1) for a in args)
now = datetime.datetime.now(datetime.timezone.utc)
created = now if opts.get("created") == "new" else now - datetime.timedelta(days=1)
history = [h == "1" for h in opts.get("copilot_history", "").split(",") if h]
others = [
    {"number": i + 1, "reviews": {"nodes": (
        [{"author": {"login": "copilot-pull-request-reviewer"}}] if h else [])}}
    for i, h in enumerate(history)
]
pr = {
    "number": 10,
    "createdAt": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "author": {"login": "me"},
    "reviewRequests": {"totalCount": int(opts.get("requests", "0"))},
    "reviews": {"nodes": json.loads(opts.get("reviews", "[]"))},
    "reviewThreads": {"nodes": json.loads(opts.get("threads", "[]")),
                      "pageInfo": {"hasNextPage": "next" in opts,
                                   "endCursor": opts.get("next")}},
}
nodes = others + [{"number": 10, "reviews": {"nodes": []}}]
json.dump({"data": {"repository": {"pullRequests": {"nodes": nodes[-6:]},
                                   "pullRequest": pr}}}, open(out, "w"))
PY
}

fail=0
expect() { # expect <name> <state> <exit> [env...]
  local name=$1 want_state=$2 want_exit=$3 got_state got_exit
  shift 3
  set +e
  got_state=$(env POLL_REVIEW_FIXTURE="$scratch/$name.json" POLL_REVIEW_INTERVAL=0 \
    "$@" "$script" owner/repo 10 0 2>/dev/null)
  got_exit=$?
  set -e
  if [ "$got_state" = "$want_state" ] && [ "$got_exit" = "$want_exit" ]; then
    echo "PASS: $name ($got_state, exit $got_exit)"
  else
    echo "FAIL: $name: want $want_state/exit $want_exit, got '$got_state'/exit $got_exit"
    fail=1
  fi
}

copilot_review='[{"state":"COMMENTED","submittedAt":"2026-01-01T00:00:00Z","author":{"login":"copilot-pull-request-reviewer"},"comments":{"totalCount":0}}]'
copilot_review_inline='[{"state":"COMMENTED","submittedAt":"2026-01-01T00:00:00Z","author":{"login":"copilot-pull-request-reviewer"},"comments":{"totalCount":2}}]'
open_thread='[{"isResolved":false,"comments":{"nodes":[{"author":{"login":"reviewer"}}]}}]'
replied_thread='[{"isResolved":false,"comments":{"nodes":[{"author":{"login":"me"}}]}}]'
body_only_cr='[{"state":"CHANGES_REQUESTED","submittedAt":"2026-01-01T00:00:00Z","author":{"login":"reviewer"},"comments":{"totalCount":0}}]'

fixture nobody
expect nobody none 3

fixture requested requests=1
expect requested timeout 2

fixture comments requests=1 threads="$open_thread"
expect comments comments 0

fixture replied requests=1 threads="$replied_thread"
expect replied timeout 2

fixture body-only-cr reviews="$body_only_cr"
expect body-only-cr changes-requested 0

# Copilot reviewed 2 of the last 5 other PRs: manual requests, not automatic.
fixture copilot-manual copilot_history=0,0,1,0,1
expect copilot-manual none 3

# Copilot on the 3 oldest of 6 other PRs: only 2 fall inside the last 5.
fixture copilot-old-history copilot_history=1,1,1,0,0,0
expect copilot-old-history none 3

fixture copilot-auto-missed copilot_history=1,1,1,0,1
expect copilot-auto-missed timeout 2

fixture copilot-auto-done copilot_history=1,1,1,1,1 reviews="$copilot_review_inline" threads="$replied_thread"
expect copilot-auto-done none 3

fixture copilot-summary copilot_history=1,1,1,1,1 reviews="$copilot_review"
expect copilot-summary summary-only 0

fixture override copilot_history=0,0,0,0,0
expect override timeout 2 POLL_REVIEW_EXPECT=requested
expect override "" 64 POLL_REVIEW_EXPECT=bogus

: >"$scratch/broken.json"
printf 'not json' >"$scratch/broken.json"
expect broken error 4

# More than 100 threads: the only actionable thread is on the second page,
# which the fixture serves as "<fixture>.<cursor>" (#155).
page2() { # page2 <file> <threads-json>
  printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":%s}}}}}' "$2" >"$1"
}
fixture paged requests=1 threads="$replied_thread" next=c2
page2 "$scratch/paged.json.c2" "$open_thread"
expect paged comments 0
fixture paged-replied requests=1 threads="$replied_thread" next=c2
page2 "$scratch/paged-replied.json.c2" "$replied_thread"
expect paged-replied timeout 2

# A live gh that fails reports error, never a quiet pending.
mkdir -p "$scratch/bin"
printf '#!/usr/bin/env bash\necho "gh: HTTP 502" >&2\nexit 1\n' >"$scratch/bin/gh"
chmod +x "$scratch/bin/gh"
set +e
got=$(env PATH="$scratch/bin:$PATH" POLL_REVIEW_INTERVAL=0 POLL_REVIEW_EXPECT=requested \
  "$script" owner/repo 10 0 2>/dev/null)
rc=$?
set -e
if [ "$got" = error ] && [ "$rc" = 4 ]; then
  echo "PASS: gh-failure (error, exit 4)"
else
  echo "FAIL: gh-failure: want error/exit 4, got '$got'/exit $rc"
  fail=1
fi

exit "$fail"
