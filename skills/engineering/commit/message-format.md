# Commit message format

Conventional commit types, scope, description, body, and worked examples.

## Types

| Type | Use case | Example |
| --- | --- | --- |
| `feat` | New feature or capability | `feat(auth): add two-factor authentication` |
| `fix` | Bug fix | `fix(api): handle null responses from upstream` |
| `refactor` | Code restructuring (no behavior change) | `refactor: extract validation into utility` |
| `docs` | Documentation updates | `docs: clarify API rate limits in README` |
| `chore` | Maintenance, dependencies, build | `chore: upgrade prettier to latest` |
| `test` | Test additions or fixes | `test: add edge case coverage for date parsing` |
| `style` | Formatting, missing semicolons (rarely used) | N/A |
| `perf` | Performance improvements (rarely used) | `perf: use memoization for expensive calculation` |

## Scope

Optional; names the area of change.

- Use the project's own names: `auth`, `api`, `ui`, `database`.
- Omit it for project-wide changes.
- Examples: `feat(keyboard): add macro support`, `fix: resolve memory leak`.

## Description

- Imperative mood: "add feature", not "added feature" or "adds feature".
- No period at the end.
- 50 characters at most; aim for about 30.
- Specific: "add password reset flow", not "fix auth stuff".

## Body

Optional.

- Explain why; the code shows what.
- Wrap at 72 characters.
- Separate it from the subject with a blank line.
- Link issues: `Closes #NNN`, `Fixes #NNN`, `Relates to #MMM`.

## A good commit

```text
feat(keyboard): add macro recording and playback

Users can now record key sequences and replay them with a hotkey.
This addresses frequent requests for repetitive key patterns.

Macro storage uses ~/.config/daskeyboard/macros.json for
persistence across sessions.

Testing: Added 12 test cases covering:
- Basic record/playback
- Edge cases (empty macros, special keys)
- Storage persistence

Closes #234
```

## Bad commits

```text
fix stuff                           ← Too vague
feat: add oauth                     ← Missing scope, too brief
docs: update                        ← What did you update?
refactor(everything): big cleanup   ← Scope "everything" is suspicious
```
