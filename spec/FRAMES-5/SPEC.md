# FRAMES-5: Text layout

Status: draft

## Summary

Text is laid out by resolve with real fonts: the font chosen, lines broken and wrapped, runs shaped by the shaping provider, emphasis, and one-line styles.

## Motivation

If renderers laid out text, the same title would wrap differently on each, and a label side measured at resolve would not match what is drawn. Resolve writes glyph runs, so every renderer draws the same lines.

## Rules

Text is laid out by resolve, with real fonts, so line breaks, sizes and label sides are part of the resolved document and are the same on every renderer.

- A style's font is the first family in the theme `font` list that its pack carries ([FRAMES-17](../FRAMES-17/SPEC.md)) or the machine has installed, in the style's weight. Characters that face lacks fall back to a face the shaping provider finds on the machine, and the resolved document keeps the face it found, as it keeps recognised text ([FRAMES-21](../FRAMES-21/SPEC.md)). A list with no family on the machine stops, naming the families.
- Lines break by Unicode line breaking (UAX #14) at the wrapping width, and at `\n`.
- Resolve shapes each run of text with the shaping provider, which gives glyph ids and advances. frames breaks, wraps and places the lines. The resolved document carries glyph runs (font file, face, size, colour, glyph ids and positions) and the box they fill. A renderer draws the glyphs where they are written and shapes nothing.
- `**text**` takes the style's `emphasis` colour.
- A style with `lines: 1` never wraps. Text wider than its room stops, since a cut label would say something else.

## Interactions

Styles are [FRAMES-22](../FRAMES-22/SPEC.md). The shaping provider is [FRAMES-21](../FRAMES-21/SPEC.md). Pack fonts are found as [FRAMES-17](../FRAMES-17/SPEC.md) says.

## Alternatives considered

Right-to-left and mixed-direction text is left out (README).

## Notes
