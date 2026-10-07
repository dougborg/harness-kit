# Git guardrail hooks

harness-kit does not ship a hook that blocks dangerous git commands, such as
mattpocock/skills' `git-guardrails-claude-code`.

## Why this is out of scope

Each host already gates commands without a hook: Claude Code through
permission deny rules, Codex through its sandbox and approval policy. A hook
that parses shell text adds little on top, and it misses spellings such as
`git -C <dir> push`.

## Prior requests

- #111: "epic: integrate mattpocock/skills" (its "Not adopting" list)
