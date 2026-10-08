#!/usr/bin/env bash
# Regression tests for scripts/shared/pr-threads.sh against a stub `gh` that
# serves 250 review threads in pages of 100 (odd-numbered threads unresolved;
# thread 7 has 150 comments, so its comments overflow too). No network, and
# the stub records every write instead of making it.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/shared/pr-threads.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"

cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env python3
"""Stub gh: answers the calls pr-threads.sh makes; logs to $STUB_LOG."""
import json, os, subprocess, sys

args = sys.argv[1:]
log = open(os.environ["STUB_LOG"], "a")
THREADS, PAGE, BIG = 250, 100, 7

def opt(flag_names, key):
    for i, a in enumerate(args):
        if a in flag_names and i + 1 < len(args) and args[i + 1].startswith(key + "="):
            return args[i + 1].split("=", 1)[1]
    return None

def jq_out(data):
    prog = args[args.index("--jq") + 1]
    out = subprocess.run(["jq", "-r", prog], input=json.dumps(data), text=True,
                         capture_output=True, check=True).stdout
    sys.stdout.write(out)

def comment(n):
    return {"databaseId": n, "body": f"body {n}", "path": "f.sh", "line": 1,
            "author": {"login": "reviewer"}}

def thread(t):
    total = 150 if t == BIG else 1
    nodes = [comment(t * 1000 + c) for c in range(min(total, 100))]
    return {"id": f"T{t}", "isResolved": t % 2 == 0,
            "comments": {"pageInfo": {"hasNextPage": total > 100,
                                      "endCursor": "C100" if total > 100 else None},
                         "nodes": nodes}}

if args[:2] == ["api", "graphql"]:
    query = opt(["-f"], "query") or ""
    if "resolveReviewThread" in query:
        log.write("resolve %s\n" % opt(["-f"], "threadId"))
        jq_out({"data": {"resolveReviewThread": {"thread": {"isResolved": True}}}})
    elif "node(id:" in query:
        start = int(opt(["-f"], "cursor")[1:])
        ids = [BIG * 1000 + c for c in range(start, 150)]
        jq_out({"data": {"node": {"comments": {
            "pageInfo": {"hasNextPage": False, "endCursor": None},
            "nodes": [{"databaseId": i} for i in ids]}}}})
    else:
        log.write("repo %s/%s\n" % (opt(["-F"], "owner"), opt(["-F"], "repo")))
        start = int((opt(["-f"], "cursor") or "P0")[1:])
        end = min(start + PAGE, THREADS)
        jq_out({"data": {"repository": {"pullRequest": {"reviewThreads": {
            "pageInfo": {"hasNextPage": end < THREADS, "endCursor": f"P{end}"},
            "nodes": [thread(t) for t in range(start + 1, end + 1)]}}}}})
elif args[:2] == ["pr", "view"]:
    log.write("prview %s\n" % args[args.index("--repo") + 1])
    print(json.dumps({"title": "t", "body": "b", "state": "OPEN", "baseRefName": "main",
                      "headRefName": "f", "author": {"login": "me"}}))
elif args[0] == "api" and args[1].endswith("/comments") and "-X" not in args:
    rest = [{"id": n, "path": "f.sh", "line": 1, "body": "b", "user": {"login": "r"},
             "created_at": "2026-01-01"} for n in (1000, 2000, 7000, 7149)]
    jq_out(rest)
elif args[0] == "api" and "/pulls/comments/" in args[1]:
    jq_out({"pull_request_url": "https://api.github.com/repos/o/r/pulls/%s"
            % os.environ.get("STUB_COMMENT_PR", "5")})
elif args[0] == "api" and "-X" in args:
    log.write("reply %s\n" % args[1])
    jq_out({"id": 99, "html_url": "https://github.com/o/r/pull/5#c99"})
else:
    sys.exit("stub gh: unexpected call: %s" % " ".join(args))
STUB
chmod +x "$scratch/bin/gh"

# A git repo whose origin is some/origin-repo, for the bare-number path.
git -C "$scratch" init -q work
git -C "$scratch/work" remote add origin git@github.com:some/origin-repo.git

fail=0
check() { # check <name> <command...>
  local name=$1
  shift
  if "$@"; then echo "PASS: $name"; else
    echo "FAIL: $name"
    fail=1
  fi
}
run() { # run <log> <args...>: pr-threads in the work repo with the stub gh
  local log=$1
  shift
  (cd "$scratch/work" && PATH="$scratch/bin:$PATH" STUB_LOG="$log" "$script" "$@")
}

: >"$scratch/l1"
check number-uses-origin [ "$(run "$scratch/l1" 5 repo)" = some/origin-repo ]
check url-uses-its-repo [ "$(run "$scratch/l1" https://github.com/other/fork/pull/9 repo)" = other/fork ]

: >"$scratch/l2"
out=$(run "$scratch/l2" https://github.com/other/fork/pull/9 unresolved)
check unresolved-all-pages [ "$(jq length <<<"$out")" = 125 ]
check unresolved-latest-comment [ "$(jq -r '.[0] | "\(.id) \(.author)"' <<<"$out")" = "1000 reviewer" ]
check queries-hit-url-repo [ "$(sort -u "$scratch/l2")" = "repo other/fork" ]

: >"$scratch/l3"
check resolve-all-count [ "$(run "$scratch/l3" 5 resolve-all)" = 125 ]
check resolve-all-every-page grep -qx "resolve T249" "$scratch/l3"
check resolve-all-only-unresolved [ "$(grep -c '^resolve T[0-9]*[02468]$' "$scratch/l3")" = 0 ]

: >"$scratch/l4"
out=$(run "$scratch/l4" 5 context)
check context-merges [ "$(jq -c '[.comments[] | {id, is_resolved}]' <<<"$out")" = \
  '[{"id":1000,"is_resolved":false},{"id":2000,"is_resolved":true},{"id":7000,"is_resolved":false},{"id":7149,"is_resolved":false}]' ]
check context-unresolved-count [ "$(jq .unresolved_count <<<"$out")" = 3 ]
check context-pr-view-repo grep -qx "prview some/origin-repo" "$scratch/l4"

: >"$scratch/l5"
check reply-posts [ "$(run "$scratch/l5" 5 reply 1000 'Fixed' | jq -r .id)" = 99 ]
check reply-right-pr grep -qx "reply repos/some/origin-repo/pulls/5/comments" "$scratch/l5"
: >"$scratch/l6"
set +e
STUB_COMMENT_PR=6 run "$scratch/l6" 5 reply 1000 'Fixed' 2>"$scratch/err"
rc=$?
set -e
check reply-wrong-pr-refused [ "$rc" = 1 ]
check reply-wrong-pr-no-post [ ! -s "$scratch/l6" ]
check reply-wrong-pr-says-why grep -q "belongs to PR #6, not #5" "$scratch/err"

set +e
run "$scratch/l1" not-a-pr repo 2>/dev/null
rc=$?
set -e
check bad-pr-arg [ "$rc" = 1 ]

exit "$fail"
