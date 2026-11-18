# FRAMES-5: Text layout

Status: accepted

## Summary

Text is laid out by resolve with real fonts: the font chosen, a title's runs styled, lines broken and wrapped, runs shaped by the shaping provider, and line limits.

## Motivation

If renderers laid out text, the same title would wrap differently on each, a lower third would end at a different place on each, and a frame measured from its content would not match what is drawn. Resolve writes glyph runs, so every renderer draws the same lines. A title often mixes looks inside one paragraph (a name in bold and a role in regular weight, one word in another colour), and runs give that as data, each in a named style, without a markup syntax to escape.

## Rules

Text is laid out by resolve, with real fonts, so line breaks, sizes and every title's box are part of the resolved document and are the same on every renderer.

### Runs

A title's text ([FRAMES-11](../FRAMES-11/SPEC.md)) is a string or a list of runs:

```json
"title": [ { "text": "Ana Ruiz", "style": "name" }, { "text": "\nDirector of photography", "style": "role" } ]
```

- A string is one run in the clip's `style`.
- A run is `{text, style}`. `text` is a string. `style` names a theme text style ([FRAMES-22](../FRAMES-22/SPEC.md)) and is optional: without it the run is in the clip's `style`. A style a run names that the theme in effect does not hold stops.
- A run's style gives that run its character attributes: `size`, `weight`, `color` and `stroke`. Every other attribute is a paragraph attribute and comes from the clip's `style` alone: `placement`, `offset`, `align`, `lineHeight`, `lines` and `background`. A run style's paragraph attributes are not read.
- The runs are laid out as one text, in order. A run's text may hold `\n`, and a line may hold parts of several runs.
- An empty list of runs stops, since it is a title with nothing to show.

### Lines

- A style's font is the first family in the theme `font` list that its pack carries ([FRAMES-17](../FRAMES-17/SPEC.md)) or the machine has installed, in the style's weight. Characters that face lacks fall back to a face the shaping provider finds on the machine, and the resolved document keeps the face it found, as it keeps recognised text ([FRAMES-21](../FRAMES-21/SPEC.md)). A list with no family on the machine stops, naming the families.
- Lines break by Unicode line breaking (UAX #14) over the text of all runs together, at the wrapping width and at `\n`. A run boundary is not a break opportunity of its own. Words are kept whole as CSS `word-break: keep-all` keeps them: no line breaks between two letters, digits, ideographs or Hangul syllables, so Korean breaks at spaces and `iPhone에서` stays whole, and Chinese and Japanese also break only at spaces, punctuation and the other places UAX #14 gives outside those pairs. A word wider than the wrapping width starts a line of its own and breaks inside where UAX #14 allows, unless its style keeps it on one line.
- Lines are `lineHeight` of the clip's style apart, baseline to baseline. The glyphs of every run on a line share its baseline. The first baseline lies the largest ascent among that line's runs below the top of the text box, and the box ends the largest descent among the last line's runs below the last baseline. A line with no text, which only a `\n` makes, takes the ascent and descent of the run it begins in.
- Each line is placed in the wrapping width by the clip style's `align`, measured on the advances of all its runs.
- Resolve shapes each run of text with the shaping provider, which gives glyph ids and advances, and a run boundary ends a shaping run. frames breaks, wraps and places the lines. The resolved document carries glyph runs (font file, face, size, colour, stroke, glyph ids and positions) and the box they fill. A renderer draws the glyphs where they are written and shapes nothing.
- A style's `lines` is the most lines its text may take, a whole number of 1 or more. Text that needs more lines than that, after wrapping and after every `\n`, stops, since cutting it or shrinking it to fit would show something other than what was written. So a line of a `lines: 1` style that is wider than its wrapping width stops, since it would need a second line. Without `lines` a title takes as many lines as it needs.

## Interactions

Styles are [FRAMES-22](../FRAMES-22/SPEC.md). A title's keys, `width` among them, are [FRAMES-11](../FRAMES-11/SPEC.md). The shaping provider is [FRAMES-21](../FRAMES-21/SPEC.md). Pack fonts are found as [FRAMES-17](../FRAMES-17/SPEC.md) says. A title's box is measured into a content-fit frame as [FRAMES-6](../FRAMES-6/SPEC.md) says.

## Alternatives considered

Inline markup (Markdown's `**...**`, a subset of HTML): it needs an escape for its own characters, it reaches only the looks its syntax names, and an agent writing text from a transcript or a script would have to quote it. Runs name any theme style and hold text as it is.

Paragraph attributes per run (a run with its own alignment or line height): one paragraph has one alignment and one line spacing in every NLE title tool, and a second paragraph that needs another look is a second title.

Right-to-left and mixed-direction text is left out (README).

## Notes
