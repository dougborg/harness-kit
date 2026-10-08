#!/usr/bin/env bash
# Regression tests for skills/engineering/open-pr/poll-review.sh, through a
# stub gh on PATH that serves canned GraphQL responses: the fixture file for
# the first page, and "<fixture>.<cursor>" for a later page of threads.
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

mkdir -p "$scratch/bin"
cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh: the PR's URL, or the canned GraphQL response for STUB_FIXTURE.
# STUB_FAIL_PR / STUB_FAIL_GRAPHQL fail just that call; STUB_LOG records the
# GH_HOST each GraphQL call sees.
case "$1 $2" in
"pr view")
  [ -z "${STUB_FAIL_PR:-}" ] || { echo "gh: HTTP 502" >&2; exit 1; }
  echo "https://github.com/owner/repo/pull/10"
  ;;
"api graphql")
  [ -z "${STUB_FAIL_GRAPHQL:-}" ] || { echo "gh: HTTP 502" >&2; exit 1; }
  if [ -n "${STUB_LOG:-}" ]; then echo "host=${GH_HOST:--}" >>"$STUB_LOG"; fi
  cursor=""
  for arg in "$@"; do case "$arg" in cursor=*) cursor=${arg#cursor=} ;; esac; done
  cat "$STUB_FIXTURE${cursor:+.$cursor}"
  ;;
*) exit 1 ;;
esac
STUB
chmod +x "$scratch/bin/gh"

fail=0
# expect <name> <state> <exit> [env...]: the last line is the RESULT line for
# that state (or, with an empty state, there is none) and the exit matches.
expect() {
  local name=$1 want_state=$2 want_exit=$3 out got_state got_exit
  shift 3
  set +e
  out=$(env PATH="$scratch/bin:$PATH" STUB_FIXTURE="$scratch/$name.json" \
    POLL_REVIEW_INTERVAL=0 "$@" "$script" 10 0 2>/dev/null)
  got_exit=$?
  set -e
  got_state=$(tail -n 1 <<<"$out" | sed -n 's/^REVIEW RESULT: \([a-z-]*\) for PR #10.*/\1/p')
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
expect nobody none 0

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
expect copilot-manual none 0

# Copilot on the 3 oldest of 6 other PRs: only 2 fall inside the last 5.
fixture copilot-old-history copilot_history=1,1,1,0,0,0
expect copilot-old-history none 0

fixture copilot-auto-missed copilot_history=1,1,1,0,1
expect copilot-auto-missed timeout 2

fixture copilot-auto-done copilot_history=1,1,1,1,1 reviews="$copilot_review_inline" threads="$replied_thread"
expect copilot-auto-done none 0

fixture copilot-summary copilot_history=1,1,1,1,1 reviews="$copilot_review"
expect copilot-summary summary-only 0

fixture override copilot_history=0,0,0,0,0
expect override timeout 2 POLL_REVIEW_EXPECT=requested
expect override "" 64 POLL_REVIEW_EXPECT=bogus

: >"$scratch/broken.json"
printf 'not json' >"$scratch/broken.json"
expect broken error 3

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

# A gh that fails reports error, never a quiet pending.
fixture pr-unreadable
expect pr-unreadable error 3 STUB_FAIL_PR=1
fixture api-failing
expect api-failing error 3 STUB_FAIL_GRAPHQL=1 POLL_REVIEW_EXPECT=requested
out=$(env PATH="$scratch/bin:$PATH" STUB_FIXTURE="$scratch/api-failing.json" STUB_FAIL_GRAPHQL=1 \
  POLL_REVIEW_INTERVAL=0 POLL_REVIEW_EXPECT=requested "$script" 10 0 2>/dev/null || true)
if [[ "$(tail -n 1 <<<"$out")" == *"the GitHub API failed"* ]]; then
  echo "PASS: api-failing-says-why"
else
  echo "FAIL: api-failing-says-why: $out"
  fail=1
fi

# While waiting it prints a heartbeat, so a killed poll is distinguishable.
fixture heartbeat requests=1
out=$(env PATH="$scratch/bin:$PATH" STUB_FIXTURE="$scratch/heartbeat.json" \
  POLL_REVIEW_INTERVAL=1 "$script" 10 1 2>/dev/null || true)
if grep -q '^REVIEW POLL: 0s elapsed for PR #10' <<<"$out"; then
  echo "PASS: heartbeat"
else
  echo "FAIL: heartbeat: $out"
  fail=1
fi

# A PR URL names its own repo: no `gh pr view` lookup (it would fail here),
# and a GitHub Enterprise host reaches gh as GH_HOST.
fixture url-arg
out=$(env PATH="$scratch/bin:$PATH" STUB_FIXTURE="$scratch/url-arg.json" STUB_FAIL_PR=1 \
  POLL_REVIEW_INTERVAL=0 "$script" https://github.com/owner/repo/pull/10 0 2>/dev/null || true)
if [[ "$(tail -n 1 <<<"$out")" == "REVIEW RESULT: none for PR #10"* ]]; then
  echo "PASS: url-arg"
else
  echo "FAIL: url-arg: $out"
  fail=1
fi
env PATH="$scratch/bin:$PATH" STUB_FIXTURE="$scratch/url-arg.json" STUB_FAIL_PR=1 \
  STUB_LOG="$scratch/hosts" POLL_REVIEW_INTERVAL=0 \
  "$script" https://ghe.example.com/owner/repo/pull/10 0 >/dev/null 2>&1 || true
if [ "$(sort -u "$scratch/hosts")" = host=ghe.example.com ]; then
  echo "PASS: ghe-url-sets-host"
else
  echo "FAIL: ghe-url-sets-host: $(cat "$scratch/hosts" 2>/dev/null)"
  fail=1
fi

exit "$fail"
