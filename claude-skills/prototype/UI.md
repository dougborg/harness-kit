# UI Prototype

Several **radically different UI variants** on one route, switched from a
floating bottom bar. The user flips between them in the browser, picks one
(or takes parts of each), and the rest are thrown away.

If the question is about logic or state rather than looks, this is the wrong
branch: go back to the skill and take the logic branch.

## Contents

- [When this is the right shape](#when-this-is-the-right-shape)
- [Where the variants live](#where-the-variants-live)
- [1. State the question and pick N](#1-state-the-question-and-pick-n)
- [2. Draft structurally different variants](#2-draft-structurally-different-variants)
- [3. Wire them together](#3-wire-them-together)
- [4. Build the floating switcher](#4-build-the-floating-switcher)
- [5. Hand it over](#5-hand-it-over)
- [6. Capture the answer and clean up](#6-capture-the-answer-and-clean-up)
- [Anti-patterns](#anti-patterns)

## When this is the right shape

- "What should this page look like?"
- "Show me a few options for this dashboard before we commit."
- "Try a different layout for the settings screen."
- Any time the user would otherwise spend a day choosing between vague
  mockups in their head.

## Where the variants live

A UI variant is far easier to judge against the rest of the app: the real
header, sidebar, data, and density. On an empty route every variant looks
fine.

**On an existing page (the default).** Render the variants on the page's own
route, chosen by a `?variant=` search param. Data fetching, params, and auth
stay as they are; only the rendering swaps. Something that doesn't have a
page yet but would naturally sit inside one (a new dashboard section, a new
settings card, a new step in a flow) also goes here, mounted inside the host
page.

**On a new throwaway route (last resort).** Only when nothing existing could
host it, such as a new top-level surface. Follow the project's routing
convention, put `prototype` in the path or filename, and use the same
`?variant=` param. Before choosing this, check again that no existing page
could host it: an empty route hides problems a populated one exposes.

The floating bar is the same either way.

## 1. State the question and pick N

Default to three variants, and never more than five: past that they stop
being radically different. Write the plan in one line at the prototype's
location or in a top-of-file comment, for example: "Three variants of the
settings page, switched by `?variant=`, on the existing `/settings` route."
Done when the plan line is written.

## 2. Draft structurally different variants

Each variant respects the page's purpose and data, uses the project's
component library and styling system, and exports a clear component name
(`VariantA`, `VariantB`, `VariantC`).

Variants differ in **structure**: layout, information hierarchy, primary
affordance. Three tweaked card grids are wallpaper, not a prototype. If two
drafts come out alike, redo one with an explicit constraint ("no card
grid"). Done when no two variants share a layout.

## 3. Wire them together

One switcher on the route:

```tsx
// pseudo-code; adapt to the project's framework
const variant = searchParams.get('variant') ?? 'A';
return (
  <>
    {variant === 'A' && <VariantA {...data} />}
    {variant === 'B' && <VariantB {...data} />}
    {variant === 'C' && <VariantC {...data} />}
    <PrototypeSwitcher variants={['A', 'B', 'C']} current={variant} />
  </>
);
```

On an existing page, keep the data fetching above the switcher so only the
rendered subtree changes. A throwaway route mounts the same switcher. Done
when each `?variant=` value renders its variant.

## 4. Build the floating switcher

A small fixed bar at the bottom centre, in one shared component placed
wherever the project keeps shared UI:

- **Left arrow**: the previous variant, wrapping around.
- **Label**: the current key and, if the variant exports one, its name, such
  as `B (Sidebar layout)`.
- **Right arrow**: the next variant, wrapping around.

It updates the URL search param through the framework's router
(`router.replace` on Next.js, `navigate` on React Router), so a variant is
shareable and survives a reload. The `←` and `→` keys also cycle, except
while an `<input>`, `<textarea>`, or `[contenteditable]` has focus. It looks
clearly separate from the design under review (a high-contrast pill, a soft
shadow). It is hidden in production builds, gated on
`process.env.NODE_ENV !== 'production'` or the project's equivalent, so a
stray merge can't ship it.

Done when the arrows and keys cycle through every variant and a production
build doesn't render the bar.

## 5. Hand it over

Give the user the URL and the `?variant=` keys. The best feedback is usually
"the header from B with the sidebar from C", which is the design they
actually want. Done when the user has the URL.

## 6. Capture the answer and clean up

Once a variant wins, record which one and why, then capture the prototype as
the skill's rules describe:

- **On an existing page:** fold the winner into the page and drop the other
  variants and the switcher from main.
- **On a throwaway route:** promote the winner to a real route and drop the
  throwaway route and the switcher from main.

The full set of variants goes to the throwaway branch: variant components
left on main rot fast and confuse the next reader. Done when main holds only
the winner and the throwaway branch holds every variant.

## Anti-patterns

- **Variants that differ only in colour or copy.** That's a tweak. Real
  variants disagree about structure.
- **Sharing too much between variants.** A shared header is fine; a shared
  layout defeats the point.
- **Wiring variants to real mutations.** Read-only is fine; a variant that
  must mutate calls a stub. The question is how it looks, not whether the
  backend works.
- **Promoting prototype code straight to production.** It was written with
  no tests and minimal error handling. Rewrite the winner properly as you
  fold it in.
