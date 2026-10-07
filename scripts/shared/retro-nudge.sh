#!/usr/bin/env bash
# Stop hook: when the repo has more than three changed files (unstaged,
# staged, or committed in the last four hours), suggest a harness retro.
# A Stop hook's plain stdout only reaches the debug log, so the nudge goes out
# as a JSON systemMessage, which is shown to the user without making the
# agent carry on. Stop fires after every turn, so the nudge shows once per
# session, keyed on the session_id in the hook's JSON input. Exits 0 always
# (hook safety); without jq it can't tell sessions apart, so it stays quiet.
command -v jq >/dev/null 2>&1 || exit 0
session=$(jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9-')
marker=""
if [ -n "$session" ]; then
  marker="${TMPDIR:-/tmp}/harness-kit-retro-nudge-${session}"
  if [ -e "$marker" ]; then exit 0; fi
fi

changed=$({
  git diff --name-only 2>/dev/null
  git diff --name-only --cached 2>/dev/null
  git log --diff-filter=ACMR --name-only --pretty=format: --since='4 hours ago' 2>/dev/null
} | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
if [ "${changed:-0}" -gt 3 ]; then
  printf '{"systemMessage": "Session touched %s files: consider running the harness skill in retro mode to capture learnings."}\n' "$changed"
  if [ -n "$marker" ]; then touch "$marker" 2>/dev/null || true; fi
fi
exit 0
