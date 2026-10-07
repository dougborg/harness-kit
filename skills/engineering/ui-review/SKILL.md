---
name: ui-review
description: >-
  Audits web UI components for accessibility and UX against WCAG 2.1 AA,
  reporting each violation as `[CRITICAL|IMPORTANT|MINOR] file:line` with a
  specific fix. Use when the user asks about accessibility, a11y, WCAG, screen
  readers, keyboard navigation, or color contrast, or wants a UX pass over
  components.
allowed-tools: Read, Grep, Glob
---

# UI Review

Audit web components (HTML, CSS, or framework code) against WCAG 2.1 AA and
report each violation with its severity, location, and fix.

Three rules carry the most weight:

- **Every interactive element is keyboard-accessible**: anything clickable is
  reachable with Tab and activates with Enter or Space.
- **Focus rings stay visible**: keep a `:focus-visible` outline such as
  `outline: 2px solid`; `outline: none` hides focus from keyboard users.
- **Color is never the only signal**: status, errors, and links also carry
  text or an icon.

## 1. Check the components

Read the components in scope and check each against
[checklist.md](checklist.md), which covers:

- Forms: labels, validation, autocomplete
- Keyboard navigation: tab order, visible focus
- Color and contrast: WCAG AA ratios
- Semantic HTML: headings, lists, navigation
- Images and icons: alt text, `aria-hidden`
- Loading states: no layout shift, announcements
- Motion: `prefers-reduced-motion`, transitions

Done when every component in scope has been checked against every checklist
category.

## 2. Report

Give each violation a severity: **CRITICAL** blocks release, **IMPORTANT** is
needed before the PR, **MINOR** is nice to have.

```text
[SEVERITY] — file:line
Rule: [rule name]
Issue: [what is wrong]
Fix: [specific code change]

Summary: N critical, M important, P minor. Ready: [YES|NO]
```

Done when every violation has a `file:line` and a specific fix, and the
summary gives the counts by severity and a Ready-for-PR verdict.
