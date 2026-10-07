# Git guardrail hooks

harness-kit does not ship a hook that blocks dangerous git commands, such as
mattpocock/skills' `git-guardrails-claude-code`.

## Why this is out of scope

Claude Code permission deny rules already block commands like
`git push --force` without a hook, and a shell-parsing hook misses spellings
such as `git -C <dir> push`. Upstream froze the skill for the same reasons.

## Prior requests

- #111: considered while porting mattpocock/skills
