# FRAMES-5: Text layout

Status: accepted

## Summary

Text is laid out by resolve with real fonts: the face chosen by family, weight and style, a title's runs styled, tracking, kerning, OpenType features and baseline shift, lines broken and wrapped, runs shaped by the shaping provider, and line limits.

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
- A run's style gives that run its character attributes: `font`, `size`, `weight`, `italic`, `tracking`, `kerning`, `features`, `baselineShift`, `color` and `stroke` ([FRAMES-22](../FRAMES-22/SPEC.md)). Every other attribute is a paragraph attribute and comes from the clip's `style` alone: `placement`, `offset`, `align`, `lineHeight`, `lines` and `background`. A run style's paragraph attributes are not read.
- The runs are laid out as one text, in order. A run's text may hold `\n`, and a line may hold parts of several runs.
- An empty list of runs stops, since it is a title with nothing to show.

### Faces

- A style's family is the first family in its `font` list, or in the theme `font` when it has none, that its pack carries ([FRAMES-17](../FRAMES-17/SPEC.md)) or the machine has installed. A list with no family on the machine stops, naming the families.
- Its face is chosen among that family's faces by the font matching of CSS Fonts 4, with `font-stretch: normal`, the style's `italic` as `font-style` and its `weight` as `font-weight`. Width is narrowed first: the faces of normal width, else the narrower ones from the widest down, else the wider ones from the narrowest up. Then style: for `italic`, italic faces, else oblique ones, else upright ones; otherwise upright faces, else oblique, else italic. Then weight: a weight from 400 to 500 takes the nearest face from it up to 500, else the nearest below it, else the nearest above 500; a lighter weight takes the nearest at or below it, else the nearest above; a heavier one the nearest at or above it, else the nearest below. A face's width, style and weight are those its font file declares in its OS/2 table, as CSS reads them. So a family without a 300 face sets `light` text in its regular face, as a browser does.
- `italic: true` in a family with neither an italic nor an oblique face stops, naming the family and the style, since upright text is not what the style asks for. frames synthesises no weight and no slant, as CSS `font-synthesis: none`.
- Characters the face lacks fall back to a face the shaping provider finds on the machine for the style's weight and italic, and the resolved document keeps the face it found, as it keeps recognised text ([FRAMES-21](../FRAMES-21/SPEC.md)). A fallback face is the nearest the provider finds, and may be upright in italic text.

### Spacing

- Resolve shapes each run with its style's `features`, and with the OpenType `kern` feature on for `kerning: metrics` and off for `kerning: none`. A feature the style does not set is as the font's script turns it on or off, as CSS leaves it. A feature tag the face does not have does nothing, as in CSS.
- In a run whose `tracking` is not 0 the optional ligatures (`liga`, `clig`, `dlig`) are off, unless its `features` turns them on, as CSS turns them off under `letter-spacing`, since a ligature would join characters the tracking spaces apart.
- `tracking` adds `tracking / 1000 ×` the run's size after every grapheme cluster (an extended grapheme cluster of UAX #29) of the run, except the last cluster on each line. So the width of a line, which wrapping and `align` measure, holds the tracking between its characters and none after the last one, and tracking does not move a centred or right-aligned line off its place.
- `baselineShift` raises the run's glyphs by its length above the line's baseline, and lowers them when it is negative. Lines keep their spacing and the text box its size: a line's ascent and descent are those of its runs as if unshifted, so a raised run may reach outside the text box.

### Lines

- Lines break by Unicode line breaking (UAX #14) over the text of all runs together, at the title's `width` when it has one and at every `\n`. A title without `width` breaks only at `\n`, so each of its lines is as long as its text. A run boundary is not a break opportunity of its own. Words are kept whole as CSS `word-break: keep-all` keeps them: no line breaks between two letters, digits, ideographs or Hangul syllables, so Korean breaks at spaces and `iPhone에서` stays whole, and Chinese and Japanese also break only at spaces, punctuation and the other places UAX #14 gives outside those pairs. A word wider than `width` starts a line of its own and breaks inside where UAX #14 allows, unless its style keeps it on one line. A piece of it that still has no break opportunity stays whole on its line and widens the text box to hold it.
- Lines are `lineHeight` of the clip's style apart, baseline to baseline. The glyphs of every run on a line share its baseline. The first baseline lies the largest ascent among that line's runs below the top of the text box, and the box ends the largest descent among the last line's runs below the last baseline. A line with no text, which only a `\n` makes, takes the ascent and descent of the run it begins in.
- The text box is as tall as its lines. A title with `width` has a text box `width` wide, and a title without one has a text box as wide as its widest line, which fits the text exactly. A style's background lies behind the text box and grows it by its padding on each side.
- Each line is placed inside the text box by the clip style's `align`, measured on the advances of all its runs: inside `width` when the title has one, and inside the widest line when it has none.
- Resolve shapes each run of text with the shaping provider, which gives glyph ids and advances, and a run boundary ends a shaping run. frames breaks, wraps and places the lines. The resolved document carries glyph runs (font file, face, size, colour, stroke, glyph ids and positions) and the box they fill. A renderer draws the glyphs where they are written and shapes nothing.
- A style's `lines` is the most lines its text may take, a whole number of 1 or more. It limits a title with `width` or without one. Text that needs more lines than that, after wrapping at `width` and after every `\n`, stops, since cutting it or shrinking it to fit would show something other than what was written; a title without `width` counts the lines its `\n` make. So a line of a `lines: 1` style that is wider than the title's `width` stops, since it would need a second line. Without `lines` a title takes as many lines as it needs.

## Interactions

Styles are [FRAMES-22](../FRAMES-22/SPEC.md). A title's keys, `width` among them, are [FRAMES-11](../FRAMES-11/SPEC.md). The shaping provider is [FRAMES-21](../FRAMES-21/SPEC.md). Pack fonts are found as [FRAMES-17](../FRAMES-17/SPEC.md) says. A title's box is measured into a content-fit frame as [FRAMES-6](../FRAMES-6/SPEC.md) says.

## Alternatives considered

Inline markup (Markdown's `**...**`, a subset of HTML): it needs an escape for its own characters, it reaches only the looks its syntax names, and an agent writing text from a transcript or a script would have to quote it. Runs name any theme style and hold text as it is.

A default `width` taken from the frame: a title's box would change with the frame it is drawn on, a background could not hug a short title without its own `width`, and a content-fit frame has no width yet to take it from. A title without `width` is point text and a title with it is paragraph text, as After Effects makes them.

Paragraph attributes per run (a run with its own alignment or line height): one paragraph has one alignment and one line spacing in every NLE title tool, and a second paragraph that needs another look is a second title.

Synthesised bold and slanted italic, as CSS `font-synthesis` and After Effects' Faux Bold and Faux Italic make them: a renderer would have to embolden or shear outlines its font does not hold, and two renderers would draw them differently. A family's own faces are what a type designer drew, and a style that asks for a slant its family cannot give stops.

Optical kerning, as After Effects and InDesign offer it: it is each tool's own algorithm, with no formula two implementations could share. `metrics` is the font's own kerning, which every shaper reads the same.

Tracking after the last character of a line, as CSS `letter-spacing` adds it: a centred line would sit half a tracking step to the left of its centre, and a right-aligned one would end short of its edge.

Right-to-left and mixed-direction text is left out (README).

## Notes
