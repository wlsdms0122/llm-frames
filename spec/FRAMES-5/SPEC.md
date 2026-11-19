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
- A run's style gives that run its character attributes: `font`, `size`, `weight`, `italic`, `tracking`, `kerning`, `features`, `baselineShift`, `color`, `stroke`, `highlight` and `underline` ([FRAMES-22](../FRAMES-22/SPEC.md), [below](#highlights-and-underlines)). Every other attribute is a paragraph attribute and comes from the clip's `style` alone: `placement`, `offset`, `align`, `lineHeight`, `lines` and `background`. A run style's paragraph attributes are not read.
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
- The text box is as tall as its lines. A title with `width` has a text box `width` wide, and a title without one has a text box as wide as its widest line, which fits the text exactly. The clip style's background, the paragraph background, lies behind the text box and grows it by its padding on each side.
- Each line is placed inside the text box by the clip style's `align`, measured on the advances of all its runs: inside `width` when the title has one, and inside the widest line when it has none.
- Resolve shapes each run of text with the shaping provider, which gives glyph ids and advances, and a run boundary ends a shaping run. frames breaks, wraps and places the lines. The resolved document carries glyph runs (font file, face, size, colour, stroke, highlight and underline pieces, glyph ids and positions) and the box they fill. A renderer draws the glyphs where they are written and shapes nothing.
- A style's `lines` is the most lines its text may take, a whole number of 1 or more. It limits a title with `width` or without one. Text that needs more lines than that, after wrapping at `width` and after every `\n`, stops, since cutting it or shrinking it to fit would show something other than what was written; a title without `width` counts the lines its `\n` make. So a line of a `lines: 1` style that is wider than the title's `width` stops, since it would need a second line. Without `lines` a title takes as many lines as it needs.

### Highlights and underlines

A run's highlight and its underline mark the run where it lies, as a highlighter and an underline do on a page. They are drawn on each line the run occupies, as one piece per line, each piece with its own padding and rounded corners, as CSS `box-decoration-break: clone` draws an inline box broken over lines.

- A piece spans the run's glyphs on that line, from the origin of the first to the end of the advance of the last, the glyphs a fallback face set included and the spaces that end a line excluded. Spaces inside the run are in it.
- A highlight piece runs from the run's ascent above the baseline to its descent below it, the ascent and descent of its face at its size, as CSS paints an inline box's content area. It grows by its `padding`, vertically above and below and horizontally at both ends, and its corners are rounded by its `radius` ([FRAMES-20](../FRAMES-20/SPEC.md)).
- An underline piece is a band across the piece, without padding, `width` thick, its top edge `offset` below the baseline, in its `color`. A `true` underline, and an object that leaves out a key, take the thickness and the position of the top edge from the face's `post` table at the run's size, and the run's colour. It is drawn through descenders, as CSS `text-decoration-skip-ink: none` draws it.
- Both move with the run's `baselineShift`.
- Neither takes part in layout: they move no glyph, add no space and do not grow the text box, so a padded highlight may reach over the space beside its run and out of the text box. A title's drawn extent holds them ([FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-14](../FRAMES-14/SPEC.md)).
- They are drawn over the paragraph background and under every glyph: the highlights in text order, then the underlines, then the glyphs' strokes and fills ([FRAMES-20](../FRAMES-20/SPEC.md)).

### Units

A title whose animation plays by character, word or line ([FRAMES-14](../FRAMES-14/SPEC.md)) is split by its layout into units, in reading order, which is the order of its text.

| `by` | A unit is |
| --- | --- |
| `character` | an extended grapheme cluster of UAX #29 |
| `word` | a word between UAX #29 word boundaries, with the punctuation it touches |
| `line` | a laid out line |

- Spaces are not units and belong to none. A line that holds nothing but spaces, such as an empty line a `\n` makes, is no `line` unit.
- Under `word`, a piece of text between two UAX #29 word boundaries that holds a letter, a digit or an ideograph is a word. A piece of punctuation or symbols joins the word it touches with no space between them, the word before it when it touches two, so `Hello,` and `"Quote"` are one unit each, and a dash between two spaces is a unit of its own. The boundaries are those of UAX #29's default rules, with no dictionary, so each Chinese or Japanese ideograph is a word, a Korean word runs from space to space, and `iPhone에서` is one word.
- Characters the shaping provider sets as one glyph are in one unit: units that would share a glyph are one unit. Under `character` the optional ligatures (`liga`, `clig`, `dlig`) are off, unless the style's `features` turns them on, so that each character can move alone.
- A unit's box runs across its glyphs, from the origin of the first to the end of the advance of the last, and down its line, from the line's baseline less the largest ascent among the line's runs to the baseline plus their largest descent. It grows on every side by half the widest stroke among its glyphs. It is in the title's box, and does not move with `baselineShift`, so every unit on a line shares the line's height and its centre.
- The paragraph background, the highlights and the underlines are not part of any unit.

## Interactions

Styles are [FRAMES-22](../FRAMES-22/SPEC.md). A title's keys, `width` among them, are [FRAMES-11](../FRAMES-11/SPEC.md). The shaping provider is [FRAMES-21](../FRAMES-21/SPEC.md). Pack fonts are found as [FRAMES-17](../FRAMES-17/SPEC.md) says. A title's box is measured into a content-fit frame as [FRAMES-6](../FRAMES-6/SPEC.md) says.

## Alternatives considered

Inline markup (Markdown's `**...**`, a subset of HTML): it needs an escape for its own characters, it reaches only the looks its syntax names, and an agent writing text from a transcript or a script would have to quote it. Runs name any theme style and hold text as it is.

A default `width` taken from the frame: a title's box would change with the frame it is drawn on, a background could not hug a short title without its own `width`, and a content-fit frame has no width yet to take it from. A title without `width` is point text and a title with it is paragraph text, as After Effects makes them.

Highlights and underlines that take space, as CSS padding on an inline box widens its line: a highlight added to one word would rewrap the paragraph and move every word after it, where an editor adds a highlight to a caption that is already timed and placed.

Paragraph attributes per run (a run with its own alignment or line height): one paragraph has one alignment and one line spacing in every NLE title tool, and a second paragraph that needs another look is a second title.

Synthesised bold and slanted italic, as CSS `font-synthesis` and After Effects' Faux Bold and Faux Italic make them: a renderer would have to embolden or shear outlines its font does not hold, and two renderers would draw them differently. A family's own faces are what a type designer drew, and a style that asks for a slant its family cannot give stops.

Optical kerning, as After Effects and InDesign offer it: it is each tool's own algorithm, with no formula two implementations could share. `metrics` is the font's own kerning, which every shaper reads the same.

Tracking after the last character of a line, as CSS `letter-spacing` adds it: a centred line would sit half a tracking step to the left of its centre, and a right-aligned one would end short of its edge.

Right-to-left and mixed-direction text is left out (README).

## Notes
