---
name: ui-review
description: Accessibility and UX audit based on WCAG 2.1 AA guidelines
allowed-tools: Read, Grep, Glob
---

# /ui-review — Accessibility & UX Audit

Accessibility and UX audit for web components. Reports violations as `[CRITICAL|IMPORTANT|MINOR] file:line` based on WCAG 2.1 AA.

## PURPOSE

Audit UI components for accessibility and UX compliance. Report violations with severity and fix guidance.

## CRITICAL

- **Every interactive element must be keyboard-accessible** — if it can be clicked, it must be reachable via Tab and activatable via Enter/Space.
- **Never suppress focus rings** — `:focus-visible` outline must always be visible. Use `outline: 2px solid`, never `outline: none`.
- **Color must never be the sole indicator** — status, errors, and links need text/icon in addition to color.

## ASSUMES

- Reviewing web/UI components with HTML, CSS, or framework-based code
- Violations are reported with file:line references
- Severity levels matter: CRITICAL blocks release, IMPORTANT needed before PR, MINOR nice-to-have

## STANDARD PATH

### 1. Run Accessibility Checklist

Review against checklist (DETAIL: Full Checklist). Check:

- Forms: labels, validation, autocomplete
- Keyboard navigation: tab order, focus visible
- Color & contrast: WCAG AA ratios
- Semantic HTML: headings, lists, navigation
- Images/icons: alt text, aria-hidden
- Loading states: no layout shift, announcements
- Motion: prefers-reduced-motion, transitions

### 2. Report Findings

For each violation:

```text
[SEVERITY] — file:line
Rule: [rule name]
Issue: [what is wrong]
Fix: [specific code change]
```text

### 3. Summary

Count by severity. Verdict: Ready for PR (yes/no).

## EDGE CASES

- [Full checklist] — read DETAIL: Full Checklist for complete list
- [Specific violation] — read DETAIL sections for each category

---

## DETAIL: Full Checklist

### Forms (CRITICAL)

- [ ] Every input has associated `<label>` via `htmlFor`/`id`
- [ ] Error messages use `role="alert"` and `aria-describedby`
- [ ] Required fields have `required` attribute AND visual indicator
- [ ] `aria-invalid="true"` on inputs with errors
- [ ] Submit button disabled during pending state
- [ ] `autocomplete` on email, name, tel fields

### Keyboard Navigation (CRITICAL)

- [ ] All interactive elements reachable via Tab
- [ ] Focus order is logical (top to bottom, left to right)
- [ ] Modals trap focus while open
- [ ] `:focus-visible` ring visible — never suppressed

### Color & Contrast (CRITICAL)

- [ ] Body text contrast ratio meets WCAG AA (4.5:1 normal, 3:1 large)
- [ ] Links not color-alone — must have underline or icon
- [ ] Error states use red + icon/text, not color alone

### Semantic HTML (IMPORTANT)

- [ ] One `<h1>` per page, logical heading hierarchy
- [ ] Lists use `<ul>`/`<ol>`, not styled divs
- [ ] Navigation uses `<nav aria-label="...">`
- [ ] Data tables use `<table>`, `<th scope="col">`, `<caption>`

### Images & Icons (IMPORTANT)

- [ ] Decorative SVGs have `aria-hidden="true"`
- [ ] Functional SVGs have `aria-label`
- [ ] No `<img>` without `alt` attribute

### Loading States (IMPORTANT)

- [ ] Loading skeletons match replaced content shape
- [ ] No layout shift when content loads
- [ ] Async operations announce via `aria-live="polite"` or toast

### Motion (IMPORTANT)

- [ ] `prefers-reduced-motion` respected
- [ ] Hover transitions use `transition-colors` (not `transition-all`)
- [ ] Modal entrance max 300ms

---

## Output Format

```text
[SEVERITY] — file:line
Rule: [rule name]
Issue: [what is wrong]
Fix: [specific code change]

Summary: N critical, M important, P minor. Ready: [YES|NO]
```text
