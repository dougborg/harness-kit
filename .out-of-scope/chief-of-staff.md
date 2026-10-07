# A chief-of-staff skill

harness-kit does not ship mattpocock/skills' `chief-of-staff` skill or another
cross-agent coordinator alongside `agent-standup`.

## Why this is out of scope

`agent-standup` already reconciles ownership, handoffs, and merge order across
agents and operators. A second coordinator would split that job across two
skills that drift apart.

## Prior requests

- #111: considered while porting mattpocock/skills
