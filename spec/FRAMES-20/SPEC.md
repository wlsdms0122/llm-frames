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
- Evaluation picks a media source's frame by [FRAMES-3](../FRAMES-3/SPEC.md) from the pinned timestamps, and the renderer draws that frame.
- Evaluation writes `seed` into every `grain` op: the number of the output frame being drawn, k for frame k of the outermost sequence (evaluated at k / fps), the frame whose interval holds t for `still` and `evaluate`, and 0 for a picture. Nested lists take the outer frame's seed, so grain belongs to the output frame and two units in a transition share it.
- A nested display list stands for an image or layout document, a compound clip at its mapped time, or a storyline unit. It is drawn at its own size, and the picture's `rect`, `dest`, `filter`, `radius`, `border` and `shadow` apply to it as to any source.
- A matte is stretched over `dest`. The picture shows where the matte's luminance in `frame` (picked from its media time, [FRAMES-14](../FRAMES-14/SPEC.md)) is below `progress`, with an edge `softness` wide, inverted when `invert` is true.
- A storyline unit ([FRAMES-9](../FRAMES-9/SPEC.md)) is one `picture` whose source is the unit's nested display list, the size of the content rect: its parented clips and its media picture (the conformed crop as `rect`, with its filter), in unit order and in content rect coordinates. The outer picture takes the transition's transform, opacity, reveal and matte, with the content rect as its mask, so they act on the unit as one picture, and a blend or an adjustment inside the unit reaches only the unit.
- Evaluation has done everything above pixels: keyframes and eases, animation spans and how they combine, transition motion, cover and matte progress, reveal (as the item's `reveal` rectangle, a `trim`, a shorter arrow or a moving hole), compositing units, parent transforms and masks, tracked motion, label sides, and the visible windows.

The mix plan is the sound of a whole sequence: a list of segments, each with a media file, its channels, its media start and speed, the sequence times it starts and ends, and a gain envelope of points `[t, gain]` joined in straight lines. The envelope already holds volume keyframes and their eases (sampled at the frame rate), fades and crossfades. A loop is one segment per repeat, and a compound clip's sounds are segments of their own.

## Interactions

It reads [FRAMES-19](../FRAMES-19/SPEC.md) and feeds the roles of [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered


## Notes
