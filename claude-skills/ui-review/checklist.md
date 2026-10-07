# Accessibility and UX checklist

The full WCAG 2.1 AA checklist, by category, with the default severity for a
violation in each.

## Forms (CRITICAL)

- [ ] Every input has an associated `<label>` via `htmlFor`/`id`
- [ ] Error messages use `role="alert"` and `aria-describedby`
- [ ] Required fields have the `required` attribute and a visual indicator
- [ ] `aria-invalid="true"` on inputs with errors
- [ ] Submit button disabled while pending
- [ ] `autocomplete` on email, name, and tel fields

## Keyboard navigation (CRITICAL)

- [ ] All interactive elements reachable via Tab
- [ ] Focus order is logical (top to bottom, left to right)
- [ ] Modals trap focus while open
- [ ] `:focus-visible` ring visible, never suppressed

## Color and contrast (CRITICAL)

- [ ] Body text contrast meets WCAG AA (4.5:1 normal, 3:1 large)
- [ ] Links are not color-alone: they have an underline or icon
- [ ] Error states use red plus an icon or text, not color alone

## Semantic HTML (IMPORTANT)

- [ ] One `<h1>` per page, with a logical heading hierarchy
- [ ] Lists use `<ul>`/`<ol>`, not styled divs
- [ ] Navigation uses `<nav aria-label="...">`
- [ ] Data tables use `<table>`, `<th scope="col">`, and `<caption>`

## Images and icons (IMPORTANT)

- [ ] Decorative SVGs have `aria-hidden="true"`
- [ ] Functional SVGs have `aria-label`
- [ ] Every `<img>` has an `alt` attribute

## Loading states (IMPORTANT)

- [ ] Loading skeletons match the shape of the content they replace
- [ ] No layout shift when content loads
- [ ] Async operations announce via `aria-live="polite"` or a toast

## Motion (IMPORTANT)

- [ ] `prefers-reduced-motion` respected
- [ ] Hover transitions use `transition-colors`, not `transition-all`
- [ ] Modal entrance is 300ms at most
