# HTML Report Format

The architecture review is one self-contained HTML file in the OS temp
directory. Tailwind and Mermaid come from CDNs. Mermaid draws graph-shaped
diagrams reliably; hand-built divs and inline SVG draw the editorial ones
(mass diagrams, cross-sections). Mix the two, or every diagram starts to look
the same.

## Contents

- [Scaffold](#scaffold)
- [Header](#header)
- [Candidate card](#candidate-card)
- [Diagram patterns](#diagram-patterns)
- [Style](#style)
- [Top recommendation](#top-recommendation)
- [Tone](#tone)

## Scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Architecture review for {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral" });
    </script>
    <style>
      /* What Tailwind doesn't cover cleanly: dashed seams, leak edges. */
      .seam { stroke-dasharray: 4 4; }
      .leak { stroke: #dc2626; }
      .deep { background: linear-gradient(135deg, #0f172a, #1e293b); }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-5xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="candidates" class="space-y-10">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## Header

Repo name, date, and a compact legend: solid box for a module, dashed line
for a seam, red arrow for leakage, thick dark box for a deep module. No
introduction; go straight to the candidates.

## Candidate card

The diagrams carry the weight. Prose is sparse and plain, and uses the
`codebase-design` terms without ceremony. Each candidate is one `<article>`:

- **Title**: short, naming the deepening ("Collapse the Order intake
  pipeline").
- **Badges**: strength (`Strong` emerald, `Worth exploring` amber,
  `Speculative` slate) and the dependency category from `codebase-design`
  (`in-process`, `local-substitutable`, `remote but owned`, `true external`).
- **Files**: a monospaced list (`font-mono text-sm`).
- **Before / after diagram**: the centrepiece, two columns side by side.
- **Problem**: one sentence on what hurts.
- **Solution**: one sentence on what changes.
- **Wins**: bullets of six words or fewer ("Tests hit one interface",
  "Pricing logic stops leaking", "Delete 4 shallow wrappers").
- **ADR callout**, when one applies: one line in an amber box.

If a diagram needs a paragraph to be understood, redraw the diagram.

## Diagram patterns

Pick the pattern that fits each candidate, and vary them.

**Mermaid graph**, the workhorse for dependencies and call flow: "X calls Y
calls Z, and look at the mess". Wrap it in a styled card, colour leak edges
red, and draw the deep module dark. A sequence diagram suits "before: six
round trips; after: one".

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    flowchart LR
      A[OrderHandler] --> B[OrderValidator]
      B --> C[OrderRepo]
      C -.leak.-> D[PricingClient]
      classDef leak stroke:#dc2626,stroke-width:2px;
      class C,D leak
  </pre>
</div>
```

**Hand-built boxes and arrows**, when Mermaid's layout fights you: modules as
bordered `<div>`s, arrows as inline SVG positioned over a relative container.
Use it when the "after" should read as one thick-bordered deep module with
greyed-out internals.

**Cross-section**, for layered shallowness: stacked horizontal bands
(`h-12 border-l-4`) for the layers a call passes through. Before: six thin
layers doing nothing. After: one thick band named for the merged
responsibility.

**Mass diagram**, for an interface as wide as its implementation: two
rectangles per module, interface and implementation. Shallow: they're nearly
the same height. Deep: a short interface over a tall implementation.

**Call-graph collapse**: before, a tree of calls as nested boxes; after, the
same tree collapsed into one box with the now-internal calls faded inside.

## Style

- Editorial, not a corporate dashboard. Generous whitespace; `font-serif`
  headings work well with stone and slate.
- One accent colour (emerald or indigo), plus red for leakage and amber for
  warnings.
- Diagrams about 320px tall, so before and after sit side by side without
  scrolling.
- Module labels in `text-xs uppercase tracking-wider`, so they read as
  schematic, not UI.
- The only scripts are the Tailwind CDN and the Mermaid import. Otherwise
  the report is static.

## Top recommendation

One larger card: the candidate's name, one sentence on why, and a link to
its card.

## Tone

Plain and concise, with the architecture nouns and verbs taken from
`codebase-design`.

Use exactly: module, interface, implementation, depth, deep, shallow, seam,
adapter, leverage, locality. Never substitute component, service, or unit for
module; API or signature for interface; boundary for seam; or layer or
wrapper for module.

Phrasings that fit:

- "Order intake module is shallow: interface nearly matches the
  implementation."
- "Pricing leaks across the seam."
- "Deepen: one interface, one place to test."
- "Two adapters justify the seam: HTTP in prod, in-memory in tests."

Wins name the gain in those terms ("locality: bugs concentrate in one
module", "leverage: one interface, N call sites"), never "easier to
maintain" or "cleaner code". If a sentence could be a bullet, make it one;
if a bullet could go, cut it.
