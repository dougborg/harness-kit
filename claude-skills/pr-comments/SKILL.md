---
name: pr-comments
description: Reply in thread to every unresolved PR review comment, once the fixes are pushed.
allowed-tools: Bash(gh api *), Bash(gh pr *), Bash(git *), Bash(${CLAUDE_SKILL_DIR}/reply-to-comment.sh*), Bash(${CLAUDE_SKILL_DIR}/resolve-github-context.sh*), Bash(${CLAUDE_SKILL_DIR}/fetch-pr-context.sh*), Read
disable-model-invocation: true
---

# PR Comments

Answer every unresolved review comment on a PR, in its own thread. This is
the reply pass: the fixes are already made and pushed. To fix and reply in
one go, use `/review-pr` instead.

Reply only after the push has landed, since each reply tells the reviewer the
fix is live. Reply only through `reply-to-comment.sh`: it checks the comment
belongs to this PR and uses the right endpoint. `gh pr comment` posts outside
the thread and loses its context, and the
`gh api .../pulls/comments/{id}/replies` endpoint does not exist (404).

## 1. Fetch the unresolved comments

```bash
ctx=$(${CLAUDE_SKILL_DIR}/resolve-github-context.sh {number})
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_SKILL_DIR}/fetch-pr-context.sh "$owner_repo" {number}
```

The script returns comments with their resolved status. Done when you have
the unresolved ones listed.

## 2. Triage each comment

Give each one an answer:

- **Fixed:** "Fixed — [what changed]"
- **Already fixed** in an earlier commit: "Addressed in [commit] — [brief
  explanation]"
- **Acknowledged** but deferred: "Noted — [reasoning]. Tracked in #NNN",
  with the issue link

Several small, related comments from one reviewer can share one numbered
reply; several comments in one thread get one reply. Agree conflicting
feedback before replying. [reply-patterns.md](reply-patterns.md) has worked
examples, batching rules, and how to handle disagreement, multiple reviewers,
and declined suggestions.

Done when every unresolved comment has a drafted answer.

## 3. Reply in thread

```bash
${CLAUDE_SKILL_DIR}/reply-to-comment.sh {owner}/{repo} {number} {comment_id} 'Fixed — [explanation]'
```

Reply to every comment in the same push cycle. Done when every unresolved
comment from step 1 has a reply.

## 4. Summary

Report the counts fixed, already fixed, and acknowledged, plus anything left
unaddressed. Done when the report is printed.

## Related

- `/review-pr` — review a PR, or fix and reply to its feedback
- `/commit` — create the commits being replied to
- [GitHub REST API: Pull Request Comments](https://docs.github.com/en/rest/pulls/comments)
