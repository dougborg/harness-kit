# Credits

## mattpocock/skills

Parts of harness-kit's authoring guidance and skills are adapted from
[mattpocock/skills](https://github.com/mattpocock/skills), used under the MIT
License. Adapted material so far:

- The `skill-writer` skill's body-writing guidance (context pointers,
  completion criteria, leading words, positive framing, no-op and sediment
  pruning, splitting by branch) and its
  invocation rules (user-invoked vs model-invoked skills, composition by
  calling the Skill tool), from `writing-for-agents` and `.agents/invocation.md`.
- The `thinking` area: `grilling` (adapted to ask through `AskUserQuestion` on
  Claude Code), `domain-modeling` with its glossary and ADR formats, `grill-me`,
  `grill-with-docs`, `wait-what`, and `to-questionnaire`.
- The engineering discipline skills: `tdd` with its test and mocking
  references, `codebase-design` with `DEEPENING.md` and `DESIGN-IT-TWICE.md`,
  and `diagnosing-bugs` with its human-in-the-loop script template.
- The two-axis review in `review-pr` and `code-reviewer` (a standards pass
  and a separate spec pass, reported side by side) and the Fowler smell
  baseline, from `code-review`.
- The environment categories in `/harness retro` (navigation, automated
  checks, mechanical vs judgement standards, steering files, tool economy,
  information access), from `retro`.
- `to-spec` and `to-tickets` (tracer-bullet slices with blocking edges, and
  expand-contract for wide refactors), replacing harness-kit's
  `feature-spec`.
- `wayfinder` (a map of decision tickets with fog of war, resolved one per
  session) and `research`.
- `handoff`, and the `ask-harness` router with its phase-boundaries guide,
  from `handoff` and `ask-matt`.
- `implement` and `implement-spec` (a spec's tickets as a task graph worked
  across its frontier onto one integration branch).
- `triage`, with its agent-brief format and the `.out-of-scope/` record of
  rejected ideas.
- `teach`, with its mission, resources, and learning-record formats.
- `loop-me` (experimental), from the in-progress upstream skill.
- The optional engineering skills `prototype` (logic and UI branches),
  `improve-codebase-architecture` with its HTML report format, and `wizard`
  with its bash wizard template.
- The `pr-body` skill, from `pr`. Its menu of summary visuals is credited
  there to Dex Horthy's `show-me` skill
  ([humanlayer/skills](https://github.com/humanlayer/skills)).

Tracking issue: [#111](https://github.com/dougborg/harness-kit/issues/111).

```text
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## ponytail

Adapted from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail),
used under the MIT License:

- The root-cause rule in `diagnosing-bugs` (find every caller of the function
  you're about to change, and fix the defect where they all route through).
- The `minimal-change` skill: the ladder and the list of things to always
  keep. Its `shortcut:` markers adapt ponytail's `ponytail:` comments.
- The complexity lens in `code-reviewer` (the `delete`, `reuse`, `stdlib`,
  `native`, `yagni`, and `shrink` tags).
- The `shortcut-ledger` skill, from `ponytail-debt`.

```text
MIT License

Copyright (c) 2026 DietrichGebert

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
