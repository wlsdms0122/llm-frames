# FRAMES-20: Evaluation, display lists and the mix plan

Status: accepted

## Summary

`evaluate(resolved, t)`: the display list at a time, its four item kinds (`picture`, `path`, `glyphs`, `adjust`) with the fields every item shares (transform, opacity, blend, mask, track matte, reveal), and the mix plan of a sequence's sound.

## Motivation

One frame of an edit is many rules at once: keyframes and their eases, a parent's transform, a tracked motion, an animation, a transition moving two pictures, a feathered mask, a track matte, a retimed frame. If a renderer had to know those rules, each new renderer would implement the editing model again, and two renderers would disagree on where a title is in the middle of a dissolve. Evaluation does everything above pixels once and hands a role only what to draw, as a compositor's render graph hands a GPU only draw calls. The items are the primitives every 2D renderer already has (an image drawn into a rectangle, a path filled and stroked, glyphs, a filter over a backdrop), so Core Graphics, Skia or an SVG renderer can each draw them.

## Rules

`evaluate(resolved, t)` gives the display list at sequence time t: the frame size, its background, and drawing items bottom first, every value already sampled at t. Frame k of a sequence is `evaluate(resolved, k / fps)`, and a PNG is the display list at the time it is rendered at ([FRAMES-23](../FRAMES-23/SPEC.md)).

### Fields every item has

| Field | Value | Meaning |
| --- | --- | --- |
| `transform` | `[a, b, c, d, tx, ty]` | the affine map from the item's own coordinates to output pixels: a point (x, y) goes to (a x + c y + tx, b x + d y + ty), as Core Graphics and SVG write a matrix |
| `opacity` | 0 to 1 | multiplies the item's alpha |
| `blend` | a mode name | how the item composites with what is below it ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| `mask` | a list of masks, or `null` | each `{geometry, transform, feather, invert, mode}` (below) |
| `trackMatte` | `{source, mode, invert}` or `null` | `source` a nested display list, `mode` `alpha` or `luma` (below) |
| `reveal` | `[x, y, w, h]` or `null` | the part of the item that shows, a rectangle in its own coordinates before its transform |

- An item is drawn in this order: its content in its own coordinates, with its alpha cut to its `reveal` rectangle (a hard straight edge) and, for a `picture`, multiplied by its `matte`; then carried by `transform` to output pixels; then its alpha multiplied by its mask, its track matte and its `opacity`; then composited onto what is below by its `blend`, with the formulas of W3C Compositing and Blending Level 1 (source-over with the mode's blend function). `reveal` turns with the item, so a wipe on a rotated title follows the title.
- A length in an item's own fields (a stroke width, a corner radius, a shadow radius and offset, a filter length) is in its own coordinates and is carried by its transform. Evaluation writes them so that, after the transform, a clip's lengths are those of [FRAMES-1](../FRAMES-1/SPEC.md) multiplied by the clip's own and its animation's scale, and not by its parent's ([FRAMES-10](../FRAMES-10/SPEC.md)). A mask's `feather` is in output pixels.
- Inside a nested display list, output pixels are the pixels of that list's own frame.
- Corners given by `radius` are circular arcs. A radius larger than half the shorter side of its rectangle is taken as half of it, as CSS and Core Graphics take it.
- A `shadow` is `{radius, offset, color}`: the item's alpha after its reveal, matte, mask and track matte, blurred by a Gaussian whose standard deviation is `radius`, moved by `offset` in the item's own coordinates, filled with `color` and drawn below the item. The item and its shadow take `opacity` and `blend` together.

### Items

| Item | Fields | Draws |
| --- | --- | --- |
| `picture` | `source` (a frame of a media file or image sequence, by index, or a nested display list), `rect` (the source region), `dest` (the rectangle it fills, in its own coordinates), `filter` (op list, applied at `dest` size), `matte` (`{source, frame, progress, softness, invert}` or `null`), `radius`, `border` `{width, color}` or `null`, `shadow` or `null` | a region of a picture scaled into a rectangle, filtered, then cut by its transition matte |
| `path` | `geometry`, `fill` (a colour or `null`), `stroke` (`{width, color, join, cap, start, end}` or `null`), `trim` `[a, b]`, `shadow` or `null` | a rectangle, an ellipse or a polyline, filled and stroked |
| `glyphs` | `runs` (each: font file, face, size, colour, `stroke` `{width, color}` or `null`, glyph ids and positions), `background` `{rect, radius, color}` or `null`, `size` | glyphs, with their outlines and background |
| `adjust` | `filter` | the filter applied to everything drawn below it in the same list |

### Pictures

- Evaluation picks a media source's frame by [FRAMES-3](../FRAMES-3/SPEC.md) from the pinned timestamps at the media time the clip's time map gives, its `timeRemap` included ([FRAMES-8](../FRAMES-8/SPEC.md)), and the renderer draws that frame. Part of `rect` that lies outside the source is transparent.
- A picture's `border` lies inside `dest`, its outer edge following the rounded corners.
- A nested display list stands for a compound clip or a template instance at its mapped time, or for a storyline picture inside its transition motion (above). It is drawn at its own size, and the picture's `rect`, `dest`, `filter`, `radius`, `border` and `shadow` apply to it as to any source.
- A `matte` is a transition matte ([FRAMES-14](../FRAMES-14/SPEC.md)), stretched over `dest`. The picture shows where the matte's luminance in `frame` (picked from its media time) is below `progress`, with an edge `softness` wide, inverted when `invert` is true. With L the Rec. 709 luma of the matte's unpremultiplied sRGB-encoded values (1 - L when inverted), p the `progress` and s the `softness`, the picture's alpha is multiplied by clamp((p × (1 + s) - L) / s, 0, 1), and when s is 0 by its limit (1 where L < p, p where L = p, 0 where L > p), so progress 0 shows none of the picture and progress 1 all of it. `matte` and `trackMatte` are different things on purpose: the first is a wipe between two storyline pictures, the second a clip that cuts another.

### Paths

`geometry` is one of:

| Form | Outline |
| --- | --- |
| `{"rect": {"rect": [x, y, w, h], "radius": r}}` | a rectangle with circular corners of radius `r` (0 for square corners) |
| `{"ellipse": {"rect": [x, y, w, h]}}` | the ellipse inscribed in the rectangle |
| `{"polyline": {"points": [[x, y], ...], "closed": false}}` | straight segments through the points in order, at least two, and from the last back to the first when `closed` |

- **Direction.** Every outline runs clockwise as seen on the output, y down, from a fixed start: a rect from the top left corner (the start of its top edge, just after the top left corner's arc), an ellipse from its top, a polyline from its first point.
- **Fill.** `fill` paints the inside of the geometry by the nonzero winding rule, an open polyline closed by a straight segment from its last point to its first, as SVG fills it. `trim` does not cut the fill.
- **Stroke.** The stroke is `width` wide, centred on the outline. `join` (`miter`, `round` or `bevel`) shapes each corner of a polyline, and a miter longer than 4 × `width` is drawn as a bevel, the SVG default miter limit. `cap` (`butt`, `round` or `square`) shapes the ends of an open outline and of a trimmed piece. A whole closed outline has no ends.
- **Trim.** `trim` is `[a, b]`, each from 0 to 1. With L the length of the outline, the stroke is drawn along it from min(a, b) × L to max(a, b) × L, measured from its start in its direction. `[0, 1]` draws all of it, and `a = b` draws no stroke. A trimmed piece of a closed outline is open, with its caps at both ends.
- **Arrowheads.** `start` and `end` are `none` or `arrow`. An `arrow` is drawn at the start or the end of the stroke as drawn (after `trim`): a filled isosceles triangle in the stroke's colour, its tip at that end point, 4 × `width` long along the outline's direction there and 4 × `width` wide at its base. The line stops at the middle of the base, with its cap there, so nothing of the line shows past the tip. Where the stroke as drawn is shorter than its heads, each head is scaled down about its tip, keeping its shape, so that their lengths add up to the stroke's length. A whole closed outline has no ends and draws no arrowhead.
- The stroke and its arrowheads are one shape: where they overlap, nothing is drawn twice. The fill is drawn first and the stroke over it.

```json
{ "item": "path", "origin": { "place": "clips[2]", "id": "pointer", "kind": "shape" },
  "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal", "mask": null, "trackMatte": null, "reveal": null,
  "geometry": { "polyline": { "points": [[420, 300], [760, 520]], "closed": false } },
  "fill": null, "stroke": { "width": 8, "color": "#FFFFFFFF", "join": "round", "cap": "round", "start": "none", "end": "arrow" },
  "trim": [0, 0.6], "shadow": null }
```

### Glyphs and adjustments

- A `glyphs` item draws its background, then the outline of every glyph of every run with a stroke, each run's glyphs as one stroke in its width and colour, centred on the outline with round joins and caps, then every glyph's fill, so no stroke covers a fill. Glyph positions are in the item's own coordinates, its text box `size` with its origin at the top left.
- An `adjust` item covers the whole frame of its list: the filter is applied to everything drawn below it in that list, and the filtered picture is composited onto the unfiltered one with the item's `blend`, its alpha multiplied by the item's reveal, mask, track matte and `opacity`. Its `transform` carries its `reveal` only.

### Masks

A mask is `{geometry, transform, feather, invert, mode}`: `geometry` in one of the path forms, `transform` the affine map from its coordinates to output pixels, `feather` a length in output pixels, `invert` a boolean and `mode` `add`, `subtract` or `intersect`.

- A mask's value m at a point of the output is the coverage of its geometry carried by its transform (1 inside, 0 outside, a polyline always closed, by the nonzero rule), blurred by a Gaussian whose standard deviation is `feather` (none at 0), and 1 - m when `invert` is true.
- The masks of an item combine in list order, as After Effects combines a layer's masks. The result starts at 0 when the first mask's mode is `add` and at 1 when it is `subtract` or `intersect`, and each mask then changes it: `add` gives r + m - r × m, `subtract` gives r × (1 - m), `intersect` gives r × m. The item's alpha is multiplied by the result.
- A mask's transform carries it with the clip that owns it: through the clip's coordinate space, its own transform, its parent's, and for a storyline picture its transition motion, so a mask stays on what it cuts.

### Track mattes

- A `trackMatte`'s `source` is a nested display list the size of the list that holds the item, drawn in that list's output pixels with no background: the items the matte clip draws at t ([FRAMES-11](../FRAMES-11/SPEC.md)). A clip used as a matte draws no item of its own. Outside the matte clip's visible window its source holds no item.
- At each point of the output the matte's value v is the source's alpha for `alpha`, and for `luma` the Rec. 709 luma of the source's unpremultiplied sRGB-encoded values multiplied by its alpha, so a transparent part of a luma matte counts as black. With `invert` it is 1 - v. The item's alpha is multiplied by v.

### Storyline pictures and transitions

- A storyline clip's picture is two `picture` items, one inside the other, so its own transform and the transition motion each act in their own coordinates, in the order [FRAMES-9](../FRAMES-9/SPEC.md) gives. The inner item is its media: its conformed crop as `rect`, its box ([FRAMES-9](../FRAMES-9/SPEC.md)) as `dest`, its filter, `radius`, `border` and `shadow`, and its own transform, opacity, mask and track matte, with `blend` `normal`. It is the one item of a nested display list the size of the frame. The outer item is a `picture` whose `source` is that list and whose `dest` is the frame, carrying the clip's `blend` and, during a transition, the transition's motion for its side ([FRAMES-14](../FRAMES-14/SPEC.md)): the motion's scale, rotation and `x`, `y` (multiples of the frame) as its transform about the centre of the frame, the motion's opacity as its opacity, the motion's reveal as its reveal rectangle, and on the incoming picture the transition's `matte`. Out of a transition the outer item's transform is the identity and its opacity 1. The two storyline pictures stack as `over` says. A solid is a `path` item, a rect the size of the frame filled with its colour, carried the same way by the transition's motion.
- A transition cover is an item above both storyline pictures and below the clips on positive lanes: a colour cover a `path` item, a rect the size of the frame filled with the cover's colour, and a media cover a `picture` item whose `dest` is the frame, each with the cover's opacity at t.
- Items come bottom first in the stacking order of [FRAMES-9](../FRAMES-9/SPEC.md). The background is the list's own `background`, not an item.
- An item's transform is its clip's own (position, anchor, scale, rotation, the tracked motion of a clip that follows its parent's media, and its animation's transform part; a clip that follows its own media moves its crop and mask instead, [FRAMES-12](../FRAMES-12/SPEC.md)) composed with its parent's as [FRAMES-10](../FRAMES-10/SPEC.md) gives it. A parent's transition motion moves its children; its opacity, reveal, mask and matte do not.

### What evaluation has done

Evaluation has done everything above pixels: keyframes and eases (springs included), animation spans and how they combine, transition motion, cover and matte progress, reveal, parent transforms, masks, track mattes, tracked motion, time remapping, and the visible windows. A role is left with the items as written.

- Evaluation writes `seed` into every `grain` op: the number of the output frame being drawn, k for frame k of the outermost sequence (evaluated at k / fps), and the frame whose interval holds t for `still`, `evaluate` and a PNG. Nested lists take the outer frame's seed, so grain belongs to the output frame and two pictures in a transition share it.

### JSON form

- In the JSON form ([FRAMES-19](../FRAMES-19/SPEC.md)) an item names what it draws under `item` (`picture`, `path`, `glyphs` or `adjust`), and carries `origin`, the clip or op that drew it as `{place, id, kind}` as `evaluate` reports it ([FRAMES-23](../FRAMES-23/SPEC.md)), or `null` for a transition cover. Every item carries every field of its kind and the common fields, `null` where it has none.
- A `picture`'s `source` is `{media, frame}`, the pinned media and the frame's index, or `{list}`, a nested list without the version, and its `rect` is `null` where it shows the whole source. A transition matte's `source` is the pinned media. A track matte's `source` is `{list}`. A run's font is pinned as `{file, sha256}`. Colours are `#RRGGBBAA`.
- The model keeps one seed per list, its nested lists included, so a list read back takes the seed of the first `grain` written, stops on a `grain` with another, and takes 0 when it has no `grain`. A frame index outside its media's frames stops.

### The mix plan

The mix plan is the sound of a whole sequence: a list of segments, each with a media file, its media start and speed, the sequence times it starts and ends, a gain envelope and a pan envelope.

- The gain envelope is a list of points `[t, gain]` joined in straight lines. It already holds volume keyframes and their eases, fades, and transition crossfades on the transition's `audio` curve ([FRAMES-13](../FRAMES-13/SPEC.md)): with u the progress through the transition, `constant-power` gives the outgoing sound cos(uπ/2) and the incoming sin(uπ/2), and `constant-gain` gives them 1 - u and u. Eased keyframes and the crossfade curve are sampled at the frame rate.
- The pan envelope is a list of points `[t, pan]` joined in straight lines, from -1 (left) to 1 (right), the pan keyframes and their eases sampled at the frame rate. The mixer pans by the pan law of [FRAMES-13](../FRAMES-13/SPEC.md).
- The mixer mixes each segment's channels into the output's as its role decides ([FRAMES-21](../FRAMES-21/SPEC.md)). A loop is one segment per repeat, and a compound clip's sounds are segments of their own. A clip with `timeRemap` has no segment.
- In the JSON form a segment is `{media, mediaStart, speed, start, end, envelope, pan}`, `media` the pinned media, each envelope point `[t, gain]` and each pan point `[t, pan]`.

## Interactions

It reads [FRAMES-19](../FRAMES-19/SPEC.md) and feeds the roles of [FRAMES-21](../FRAMES-21/SPEC.md). Stacking is [FRAMES-9](../FRAMES-9/SPEC.md), parent transforms [FRAMES-10](../FRAMES-10/SPEC.md), shapes, masks, track mattes and blend modes [FRAMES-11](../FRAMES-11/SPEC.md), tracked motion [FRAMES-12](../FRAMES-12/SPEC.md), the pan law and crossfade curves [FRAMES-13](../FRAMES-13/SPEC.md), transitions and reveal [FRAMES-14](../FRAMES-14/SPEC.md), filter ops [FRAMES-15](../FRAMES-15/SPEC.md).

## Alternatives considered

Roles that read the resolved document, as an NLE's playback engine reads its project: every role would implement keyframes, parenting and transitions again, and two of them would disagree.

One item kind per shape (a box, a fill, an arrow): every new shape would need a new item in every renderer. One `path` item with three geometry forms and one stroke model is what Core Graphics, Skia and SVG all draw, so a renderer maps it to its own path.

Masks as hard clip paths, as SVG `clipPath` is: an editor's mask is feathered and combined by mode, and a clip path is only the case of feather 0 and one mask.

Feather in the mask's own coordinates: a feather would then soften with a zoom on its parent, where an editor sets it to look the same on the output.

A storyline picture and the clips grouped with it drawn as one nested list, moved together by a transition: a parent's transform already carries a clip with its picture, and a compound clip gives a group that must leave as one picture. The storyline picture alone is nested, inside its transition motion, because its own transform and the motion are two coordinate stages that one item's transform cannot hold. A transition field on the picture item: the order of the common fields would then differ for one kind of item. Both items keep the clip as their origin, as a compound clip's do, so `evaluate` and `locate` still see one place.

## Notes
