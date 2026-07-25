---
paths:
  - "skills/**"
---

# Skill Size and Reference Files

Keep each `SKILL.md` under 500 lines. Split deeper material into reference `.md` files that sit **next to** the SKILL.md and are linked directly from it — exactly one level deep. A reference file must never link to another reference file; Claude previews unfamiliar files with `head -100` and would act on incomplete content. Any reference file over 100 lines needs a table of contents at the top.
