---
name: svg-logo-designer
description: Generate SVG logos with multiple concepts, layouts, and color variations.
allowed-tools: Read, Write, Glob
---

# SVG Logo Designer

Design a logo as scalable vector graphics: several concepts first, then the
chosen ones in every layout and color treatment. When the user wants a single
design rather than a family of variations, skip steps 3 and 4.

## 1. Gather the brief

Ask about the brand name, industry, target audience, color preferences, style
(modern, classic, playful), and logo type (wordmark, icon, or combination).
Done when each is answered or the user has left it to you.

## 2. Sketch concepts

Create 3 to 5 distinct directions that explore different visual metaphors and
compositions. The full set is 20 files per concept (five layouts times four
color treatments), so confirm the scope with the user: which concepts, and
which layouts and treatments each needs. Done when the user has picked the
concepts and agreed the set of files to produce.

## 3. Lay out each concept

For each chosen concept: horizontal, vertical (stacked), square, icon-only,
and text-only. Done when every chosen concept has each agreed layout.

## 4. Color each layout

Each layout in full color, monochrome dark, monochrome light, and reversed.
Done when every layout has each agreed treatment.

## 5. Build the SVG

Every file follows this structure:

```svg
<svg viewBox="0 0 [width] [height]" xmlns="http://www.w3.org/2000/svg">
  <title>Logo Name</title>
  <desc>Brief description for accessibility</desc>
  <defs><!-- Gradients, patterns, masks --></defs>
  <!-- Logo elements -->
</svg>
```

- Size the root `<svg>` with `viewBox` alone, without fixed `width` or
  `height`, so the logo scales to any container.
- Give it a `<title>` and `<desc>`, which screen readers use to describe the
  logo.
- Define gradients, patterns, and masks once in `<defs>` and reference them,
  rather than repeating them inline.

Done when every file meets all three.

## 6. Deliver

Hand over one SVG file per variation, the color specs (HEX and RGB), and
usage guidelines. Done when the user has all three.
