# FRAMES-20: Evaluation, display lists and the mix plan

Status: accepted

## Summary

`evaluate(resolved, t)`: the display list at a time, its items, and the mix plan of a sequence's sound.

## Motivation

Roles must not know clips, keyframes or presets, or each new renderer implements the editing model again. Evaluation does everything above pixels once and hands a role only what to draw.

## Rules

`evaluate(resolved, t)` gives the display list at sequence time t: the frame size, its background, and drawing items bottom first, every value already sampled at t. Frame k of a sequence is `evaluate(resolved, k / fps)`, and an image or layout has one display list.

Every item has `transform` (an affine matrix `[a, b, c, d, tx, ty]` in output pixels), `opacity`, `blend` ([FRAMES-11](../FRAMES-11/SPEC.md)), `mask` (a rectangle in output pixels, or `null`) and `reveal` (a rectangle in the item's own coordinates before its transform, or `null`). `reveal` turns with the item, so a wipe on a rotated title follows the title. Inside a nested display list, output pixels are the pixels of that list's own frame.

| Item | Fields | Draws |
| --- | --- | --- |
| `picture` | `source` (a frame of a media file or image sequence, by index, or a nested display list), `rect` (the media region), `dest` (the output rectangle it fills), `filter` (op list, applied at `dest` size), `matte` (`{source, frame, progress, softness, invert}` or `null`), `radius`, `border` `{width, color}`, `shadow` `{radius, offset, color}` | a region of a media picture scaled into a rectangle, filtered, then masked by its matte |
| `fill` | `rect`, `radius`, `color`, `hole` (`{rect, radius}` or `null`) | a filled rounded rectangle, with an optional rounded hole |
| `stroke` | `rect`, `radius`, `width`, `color`, `trim` (0 to 1, from the top left clockwise) | the outline of a rounded rectangle, centred on its edge, drawn as far as `trim` |
| `arrow` | `tail`, `head` (points), `width`, `headSize`, `color` | a straight arrow |
| `glyphs` | `runs` (font file, face, size, colour, glyph ids and positions), `stroke` `{width, color}`, `background` `{rect, radius, color}` | glyphs, with their outline and background |
| `adjust` | `rect` (or `null` for the whole frame), `filter` | the filter applied to everything drawn below it, inside the rect |

- Corners given by `radius` are circular arcs. A `shadow` radius is the standard deviation of its Gaussian blur, as for `blur`.
- A `stroke`'s `trim` is measured along its outline from the start of the top edge, just after the top left corner's arc, clockwise, and a trimmed stroke ends square.
- An `arrow` is a shaft `width` wide from `tail`, ending square there, to the base of a filled triangular head `headSize` long and `headSize` wide at its base, its tip at `head`. On an arrow shorter than `headSize` the head shrinks to the arrow's length.
- A picture's `border` lies inside `dest`, its outer edge following the rounded corners. Its `shadow` is the picture's shape (its alpha after the matte, the corners and the border) blurred, moved by `offset` in the item's own coordinates and drawn below it.
- A `glyphs` item draws its background, then the outline of every glyph as one stroke, centred on the outline with round joins and caps, then every glyph's fill, so no stroke covers a fill.
- Evaluation picks a media source's frame by [FRAMES-3](../FRAMES-3/SPEC.md) from the pinned timestamps, and the renderer draws that frame.
- Evaluation writes `seed` into every `grain` op: the number of the output frame being drawn, k for frame k of the outermost sequence (evaluated at k / fps), the frame whose interval holds t for `still` and `evaluate`, and 0 for a picture. Nested lists take the outer frame's seed, so grain belongs to the output frame and two units in a transition share it.
- A nested display list stands for an image or layout document, a compound clip at its mapped time, or a storyline unit. It is drawn at its own size, and the picture's `rect`, `dest`, `filter`, `radius`, `border` and `shadow` apply to it as to any source.
- A matte is stretched over `dest`. The picture shows where the matte's luminance in `frame` (picked from its media time, [FRAMES-14](../FRAMES-14/SPEC.md)) is below `progress`, with an edge `softness` wide, inverted when `invert` is true. With L the Rec. 709 luma of the matte's unpremultiplied sRGB-encoded values (1 - L when inverted), p the `progress` and s the `softness`, the picture's alpha is multiplied by clamp((p × (1 + s) - L) / s, 0, 1), and when s is 0 by its limit (1 where L < p, p where L = p, 0 where L > p), so progress 0 shows none of the picture and progress 1 all of it.
- A storyline unit ([FRAMES-9](../FRAMES-9/SPEC.md)) is one `picture` whose source is the unit's nested display list, the size of the content rect: its parented clips and its media picture (the conformed crop as `rect`, with its filter), in unit order and in content rect coordinates. The outer picture takes the transition's transform, opacity, reveal and matte, with the content rect as its mask, so they act on the unit as one picture, and a blend or an adjustment inside the unit reaches only the unit.
- Evaluation has done everything above pixels: keyframes and eases, animation spans and how they combine, transition motion, cover and matte progress, reveal (as the item's `reveal` rectangle, a `trim`, a shorter arrow or a moving hole), compositing units, parent transforms and masks, tracked motion, label sides, and the visible windows.
- In the JSON form ([FRAMES-19](../FRAMES-19/SPEC.md)) an item names what it draws under `item`, and carries `origin`, the clip or op that drew it as `{place, id, kind}` as `evaluate` reports it ([FRAMES-23](../FRAMES-23/SPEC.md)), or `null` for the background outside the content rect and a transition cover. A `glyphs` item also carries `size`, its text box. A `picture`'s `source` is `{media, frame}`, the pinned media and the frame's index, or `{list}`, a nested list without the version, its `rect` is `null` where it shows the whole source, and a matte's `source` is the pinned media. Colours are `#RRGGBBAA`.
- The model keeps one seed per list, its nested lists included, so a list read back takes the seed of the first `grain` written, stops on a `grain` with another, and takes 0 when it has no `grain`. A frame index outside its media's frames stops.

The mix plan is the sound of a whole sequence: a list of segments, each with a media file, its media start and speed, the sequence times it starts and ends, and a gain envelope of points `[t, gain]` joined in straight lines. The mixer mixes each segment's channels into the output's as its role decides ([FRAMES-21](../FRAMES-21/SPEC.md)). The envelope already holds volume keyframes and their eases (sampled at the frame rate), fades and crossfades. A loop is one segment per repeat, and a compound clip's sounds are segments of their own. In the JSON form a segment is `{media, mediaStart, speed, start, end, envelope}`, `media` the pinned media and each envelope point `[t, gain]`.

## Interactions

It reads [FRAMES-19](../FRAMES-19/SPEC.md) and feeds the roles of [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered


## Notes
