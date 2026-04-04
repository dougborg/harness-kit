---
name: svg-logo-designer
description: Generate scalable vector graphics (SVG) logos with multiple concepts, layouts, and color variations
model: sonnet
allowed-tools: Read, Write, Glob
---

# /svg-logo-designer — SVG Logo Designer

Generate scalable vector graphics (SVG) logos with multiple concepts, layouts, and color variations.

## PURPOSE

Create professional SVG logos with multiple design directions, layouts, and color schemes.

## CRITICAL

- **Always use `viewBox` for scalability** — never set fixed `width`/`height` on the root `<svg>` element.
- **Include `<title>` and `<desc>` for accessibility** — screen readers need these to describe the logo.
- **Define reusable elements in `<defs>`** — gradients, patterns, and masks go here, not inline.

## ASSUMES

- You have Write access to create SVG files
- Design requires multiple variations (if single design, consider simpler alternatives)
- SVG expertise available to refine output

## STANDARD PATH

### 1. Gather Requirements

Ask about: brand name, industry, target audience, color preferences, style (modern, classic, playful), logo type (wordmark, icon, combination).

### 2. Generate Concepts

Create 3-5 distinct design directions exploring different visual metaphors and composition styles.

### 3. Generate Layouts

For each selected concept: horizontal, vertical/stacked, square, icon-only, text-only.

### 4. Generate Color Variations

Each layout in: full color, monochrome dark, monochrome light, reversed.

### 5. SVG Structure

```svg
<svg viewBox="0 0 [width] [height]" xmlns="http://www.w3.org/2000/svg">
  <title>Logo Name</title>
  <desc>Brief description for accessibility</desc>
  <defs><!-- Gradients, patterns --></defs>
  <!-- Logo elements -->
</svg>
```text

### 6. Deliverables

SVG files for each variation, color specs (HEX/RGB), usage guidelines.
