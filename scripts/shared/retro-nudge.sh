#!/usr/bin/env bash
# Stop hook: after a session that touched more than three files (unstaged,
# staged, or committed in the last four hours), suggest a harness retro.
# A Stop hook's plain stdout only reaches the debug log, so the nudge goes out
# as a JSON systemMessage, which is shown to the user without making the
# agent carry on. Exits 0 always (hook safety).

changed=$({
  git diff --name-only 2>/dev/null
  git diff --name-only --cached 2>/dev/null
  git log --diff-filter=ACMR --name-only --pretty=format: --since='4 hours ago' 2>/dev/null
} | sed '/^$/d' | sort -u | wc -l | tr -d ' ')

if [ "${changed:-0}" -gt 3 ]; then
  printf '{"systemMessage": "Session touched %s files: consider running the harness skill in retro mode to capture learnings."}\n' "$changed"
fi
exit 0
