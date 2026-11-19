# FRAMES-11: Titles, shapes, media and adjustment clips

Status: accepted

## Summary

The clip kinds that draw on a sequence: titles with styled runs, the three shapes (rect, ellipse and path) with fill, stroke, arrowheads and trim, media clips (picture in picture and graphics made elsewhere), adjustment clips, the masks and track mattes any picture takes, and blend modes.

## Motivation

Titles and shapes are the basics of any NLE. A lower third is a name and a role in two styles over a bar, an end card is a title in a box, a diagram is lines and arrows drawn on one by one, a spotlight darkens everything but a region. Each of these is made from a few general tools: text in runs, a rect, an ellipse and a path with a stroke model, and a mask. Their geometry belongs to frames, how they move is a preset, and how they look is a theme style. Masks and track mattes cut any picture to a shape or to another clip, as they do in After Effects and Premiere Pro, which is how a logo is cut to a circle, a filter is kept to one region, or text is filled with video.

## Rules

### Titles

- `title` is a string or a list of runs `{text, style}`. A string is one run in the clip's style. A run's `style` names a theme text style whose character attributes (size, weight, colour, stroke) apply to that run, and the paragraph attributes (placement, offset, align, line height, lines, background) come from the clip's `style`. Runs are laid out as [FRAMES-5](../FRAMES-5/SPEC.md) says.
- `style` names a theme text style ([FRAMES-22](../FRAMES-22/SPEC.md)) and is required, since which kind of text a title is belongs to the document.
- `width`, in output pixels, is the width of the title's text box, and the text wraps at it. Each line is placed inside that width by the style's `align`, and the style's background fills it. A title without `width` does not wrap: its lines break only at `\n`, and its text box is as wide as its widest line ([FRAMES-5](../FRAMES-5/SPEC.md)).
- A title's box is its text box, grown by its style's background padding ([FRAMES-5](../FRAMES-5/SPEC.md)). It is placed by `placement` or `position` about its anchor point ([FRAMES-1](../FRAMES-1/SPEC.md)).

### Shapes

`shape` is `rect`, `ellipse` or `path`.

| shape | Geometry | Keys of its own |
| --- | --- | --- |
| `rect` | a box: `area`, or `width` and `height` placed as a box | `radius`, `outset` |
| `ellipse` | a box, as for `rect`: the ellipse inscribed in it | `outset` |
| `path` | `points`, a list of at least two points ([FRAMES-2](../FRAMES-2/SPEC.md)), joined by straight segments in order | `closed` (default `false`), which joins the last point to the first |

- A rect or ellipse takes exactly one of `area` (an area in its coordinate space, [FRAMES-2](../FRAMES-2/SPEC.md)) and the pair `width` and `height` (output pixels, both needed). Given `width` and `height`, the box is placed by `placement` or `position` about its `anchor`, as a media clip's box is ([FRAMES-1](../FRAMES-1/SPEC.md)). A shape given by `area` or `points` is placed by its geometry ([FRAMES-1](../FRAMES-1/SPEC.md)).
- `radius` rounds a rect's corners with circular arcs, cut to half the box's shorter side. `outset` grows the outline a rect or an ellipse draws on every side, before the corners are rounded, and takes no part in placing it. Both are theme lengths ([FRAMES-1](../FRAMES-1/SPEC.md)), so they keep their size under a parent's zoom.
- A key a shape kind does not take stops: `radius` on an ellipse or a path, `outset`, `area`, `width` or `height` on a path, `points` or `closed` on a rect or an ellipse.
- A shape's box ([FRAMES-1](../FRAMES-1/SPEC.md)) is its box as written for a rect or an ellipse, `width` by `height` or its `area`, and the bounding box of its points for a path. `placement`, `position`, `anchor`, the space its children see ([FRAMES-10](../FRAMES-10/SPEC.md)) and an animation's `x` and `y` ([FRAMES-14](../FRAMES-14/SPEC.md)) all take that box. `outset` grows only the outline it draws, and so what it draws: its receiver box and its content-fit extent measure the grown outline.

**Appearance.**

| Key | Form | Meaning |
| --- | --- | --- |
| `fill` | a colour, or `false` | the inside of the outline filled with that colour. A path is filled as if it were closed, by the nonzero rule, as SVG fills it. `false` turns off a style's fill |
| `stroke` | `{color, width, join, cap, start, end}`, or `false` | the outline drawn centred on itself. `false` turns off a style's stroke |
| `trim` | `[a, b]`, each from 0 to 1, default `[0, 1]` | the part of the outline the stroke draws, as After Effects' Trim Paths |
| `shadow` | `true` (the theme `shadow`), `false`, or `{radius, offset, color}` whose missing keys come from the theme `shadow` | a drop shadow of the shape's drawn picture ([FRAMES-22](../FRAMES-22/SPEC.md)) |
| `style` | a shape style's name | defaults for `fill`, `stroke`, `radius`, `outset` and `shadow` ([FRAMES-22](../FRAMES-22/SPEC.md)) |

| Stroke key | Form | Default |
| --- | --- | --- |
| `color` | a colour | the theme `accent` colour |
| `width` | a theme length above 0 ([FRAMES-1](../FRAMES-1/SPEC.md)) | required |
| `join` | `miter`, `round` or `bevel`, as SVG `stroke-linejoin`, with a miter limit of 4 as SVG's | `round` |
| `cap` | `butt`, `round` or `square`, as SVG `stroke-linecap` | `butt` |
| `start`, `end` | `none` or `arrow` | `none` |

- An `arrow` at an end is an arrowhead: a filled triangle in the stroke's colour, `4 × width` long and `4 × width` wide at its base, its tip at that end of the drawn stroke and its axis along the stroke's direction there. The stroke stops at the head's base. Where the drawn stroke is shorter than its heads, each head shrinks, length and width together, so the heads together take the stroke's length. Arrowheads sit on the ends of the stroke as drawn: an open path's stroke always has two, and a rect's, an ellipse's or a closed path's has them only when its `trim` leaves part of the outline undrawn. A whole closed outline has no ends and draws no arrowhead.
- `trim` measures the outline as a fraction of its length: a rect from its top left corner (for a rounded rect, where the top edge leaves the corner's arc), clockwise; an ellipse from its top, clockwise; a path from its first point along its points, the closing segment last when it is closed. These directions are in the shape's own coordinates, so a mirrored shape draws on mirrored. The stroke is drawn from the smaller of `a` and `b` to the larger, and `a` equal to `b` draws no stroke. A trimmed outline has ends, which take `cap` and its arrowheads. `trim` acts on the stroke only, and the fill is drawn whole. It is keyframable, which draws a stroke on or off.
- Keys written on the clip win over its style's, each whole: a clip's `stroke` replaces the style's `stroke`. A shape without `style` takes nothing from the theme but colour names. A shape that, after its style, has neither a fill nor a stroke stops, since it would draw nothing.
- `scale` and `rotation` act about the shape's anchor point ([FRAMES-1](../FRAMES-1/SPEC.md)). The stroke width, `radius`, `outset` and the shadow scale with the shape's own and its animation's scale, by its scale factor and the same in every direction ([FRAMES-1](../FRAMES-1/SPEC.md)), and not with a parent's ([FRAMES-10](../FRAMES-10/SPEC.md)).
- A shape's `points`, `area`, `width`, `height`, `radius`, `outset`, `fill`, `stroke` and `shadow` keyframe as [FRAMES-4](../FRAMES-4/SPEC.md) says, each keyframe's value read as a static one, so a stroke's colour and width move while its `join` and `cap` stay. A `points` keyframe interpolates point by point, so every `points` value of one shape has the same number of points, and keyframes that differ in it stop.

**Note.** To darken everything but a region, draw a rect over the frame filled with a dark colour, with an inverted mask of the region ([Masks and track mattes](#masks-and-track-mattes)). To point at a region, draw a path with `"end": "arrow"` whose last point is a point of that region ([FRAMES-2](../FRAMES-2/SPEC.md)). A label is a title parented to its shape ([FRAMES-10](../FRAMES-10/SPEC.md)).

### Media clips

- `width` and `height` size the clip's box in output pixels. Given one, the other follows the aspect ratio of the clip's first crop, or of the media when there is no crop, and every crop conforms to that box, so the box holds still while the crop moves. Given both, the crop conforms to the box by the clip's `conform` (`fit` or `fill`, default `fit`), as a storyline crop conforms to the frame ([FRAMES-9](../FRAMES-9/SPEC.md)). Given neither, the box is the first crop, or the media, fitted to the frame, as an NLE conforms a picture to its sequence. Under content fit the box given neither is measured as [FRAMES-6](../FRAMES-6/SPEC.md) says.
- `crop` and `filter` work as on a storyline clip, with the clip's own box in place of the frame. `crop` is in media pixels of the clip's own media.
- `radius` rounds the box's corners with circular arcs, a theme length cut to half the box's shorter side. `border` is `true` (the theme `border`, `{width, color}`) or a colour, which replaces the theme border's colour, and draws a border of the theme border's width inside the box, its outer edge following the rounded corners. `shadow` is `true` (the theme `shadow`), `false`, or `{radius, offset, color}` whose missing keys come from the theme `shadow`, and draws a drop shadow of the box's picture below it. Each length is a theme length ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-22](../FRAMES-22/SPEC.md)). `radius`, `border` and `shadow` are keyframable ([FRAMES-4](../FRAMES-4/SPEC.md)): a border's colour moves, and `true` in a keyframe stands for the theme value. A storyline clip with media takes the three keys the same way on its frame-sized box ([FRAMES-9](../FRAMES-9/SPEC.md)).
- A media clip of video, image sequence or compound media takes `timeRemap` ([FRAMES-8](../FRAMES-8/SPEC.md)), and every media clip takes `mask` and `trackMatte` ([below](#masks-and-track-mattes)) and `blend` ([Blend modes](#blend-modes)).
- A video media clip is picture in picture, an image sequence or a video with alpha is how a motion graphic made elsewhere comes in, and a compound clip is a window with an edit of its own inside it ([FRAMES-9](../FRAMES-9/SPEC.md)).

### Adjustment clips

An adjustment clip applies a filter choice (`adjust`, [FRAMES-15](../FRAMES-15/SPEC.md)) to everything drawn below it in its frame, as an NLE's adjustment layer: over the whole frame, or inside its `mask` when it has one. Its `opacity` blends the filtered result with what is below, and its `blend` composites the filtered result onto the unfiltered one. Inside a compound clip it reaches only the clips of that compound clip. It takes no keyframed transform: its mask is in the space its parent gives, or in output pixels without one ([FRAMES-10](../FRAMES-10/SPEC.md)), and it moves with its tracked motion and its animation.

### Masks and track mattes

`mask` is taken by every clip with a picture: a storyline clip with media, a media clip, a title, a shape and an adjustment clip. Its value is a mask or a list of masks, combined in list order.

| Mask key | Form | Default |
| --- | --- | --- |
| `shape` | `rect`, `ellipse` or `path` | required |
| `area` | an area ([FRAMES-2](../FRAMES-2/SPEC.md)), for a rect or an ellipse | |
| `width`, `height`, `position` | a box for a rect or an ellipse: `width` by `height`, its centre at the point `position` | |
| `points` | a list of at least three points, for a path. The path is always closed | |
| `radius` | the corner radius of a rect, in the mask's coordinate space, cut to half the box's shorter side | 0 |
| `feather` | a theme length, 0 or more: the standard deviation of a Gaussian blur of the mask's edge | 0 |
| `invert` | `true` or `false`: the mask covers everything outside its geometry | `false` |
| `mode` | `add`, `subtract` or `intersect`: how the mask combines with the masks before it | `add` |

- A rect or ellipse mask takes exactly one of `area` and the box `width`, `height` and `position`, which are all needed together. A path mask takes `points`. Any other geometry key on a mask stops.
- A mask's geometry is in the clip's own coordinate space: for a storyline clip or a media clip, the media pixels of its media; for a title, its text box; for a rect or ellipse placed by `width` and `height`, its box; for a shape placed by `area` or `points`, the space its geometry is written in; for an adjustment clip, its parent's space or output pixels. It is carried with the clip by its own transform, its parent's ([FRAMES-10](../FRAMES-10/SPEC.md)), and its tracked motion ([FRAMES-12](../FRAMES-12/SPEC.md)), so a mask stays on what it cuts. On a storyline clip it cuts the picture before the transition motion moves it ([FRAMES-9](../FRAMES-9/SPEC.md)), and that motion then carries the cut picture. Its feather is a theme length and does not grow with a parent's scale.
- A mask's value at a point is the coverage of its geometry (1 inside, 0 outside), blurred by its feather, and 1 minus that when inverted. The masks of a clip combine in order, as After Effects combines a layer's masks: the result starts at 0 when the first mask's mode is `add` and at 1 when it is `subtract` or `intersect`, and each mask m then changes the result r to `r + m - r × m` (`add`), `r × (1 - m)` (`subtract`) or `r × m` (`intersect`). The clip's alpha is multiplied by the result.
- `mask` is keyframable as a whole list: a keyframe's `mask` is the clip's every mask at that instant. Between keyframes each mask interpolates its geometry per component (an area per component, a box's `width`, `height` and `position`, a path point by point) and its `radius` and `feather` as numbers. Keyframes whose mask lists differ in length, or whose masks at one place differ in `shape`, in how their geometry is given, in the number of points, in `invert` or in `mode`, stop.

`trackMatte` is taken by every clip with a picture: `{clip: "<id>", mode: "alpha" | "luma", invert: false}`. `mode` is required and `invert` defaults to `false`.

- `clip` names, by its `id` ([FRAMES-7](../FRAMES-7/SPEC.md)), a connected or sequence media clip, title or shape in the same document. Any other clip named (a storyline clip, an adjustment clip, an audio clip, a clip in another document), or an id that names no clip, stops.
- The named clip is the matte and is not drawn itself. Its picture at t is what it would draw at t (with its transform, parent, animation, opacity, mask and its own track matte, and without its blend), on a transparent frame, and nothing outside its visible window.
- `alpha` multiplies the clip's alpha by the matte's alpha. `luma` multiplies it by the matte's luma: the Rec. 709 luma of its unpremultiplied sRGB-encoded values times its alpha, so a transparent matte counts as black. `invert` uses 1 minus that value.
- The matte cuts the clip where its mask does: on a storyline clip, before the transition motion ([FRAMES-9](../FRAMES-9/SPEC.md)).
- A clip used as a matte by two clips is fine. A matte that has a track matte of its own is followed, and a chain of track mattes that comes back to a clip already in it stops.

### Blend modes

`blend` composites a clip with a picture with what is below it: a storyline clip with media, a media clip, a title, a shape, or an adjustment clip's filtered result. The modes and their formulas are those of W3C Compositing and Blending Level 1: `normal` (default), `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`. Light leaks and film burns come in this way, as media with `screen` or `plus-lighter`.

## Interactions

Placement, anchor points and theme lengths are [FRAMES-1](../FRAMES-1/SPEC.md). Areas and points are [FRAMES-2](../FRAMES-2/SPEC.md). Text layout and runs are [FRAMES-5](../FRAMES-5/SPEC.md). Keys are [FRAMES-7](../FRAMES-7/SPEC.md), `timeRemap` is [FRAMES-8](../FRAMES-8/SPEC.md), the storyline and stacking are [FRAMES-9](../FRAMES-9/SPEC.md), and parents are [FRAMES-10](../FRAMES-10/SPEC.md). Tracked masks are [FRAMES-12](../FRAMES-12/SPEC.md). Animations, reveal and transitions are [FRAMES-14](../FRAMES-14/SPEC.md), filters [FRAMES-15](../FRAMES-15/SPEC.md). Text styles, shape styles, the border and the shadow are [FRAMES-22](../FRAMES-22/SPEC.md). Display list items, the mask and track matte fields among them, are [FRAMES-20](../FRAMES-20/SPEC.md).

## Alternatives considered

A fixed set of annotation shapes (a box, a fill, a dim, an arrow) with labels: each is a rect, a path or a mask with a style, and a fixed set names purposes where frames gives tools. A label side chosen by the engine: a label is a title parented to its shape, placed where the document puts it.

Emphasis markup inside a title's text: a run names its style, so any style can be mixed into a line and no character has to be escaped.

Curved paths (Bézier segments): left out (README). Straight segments draw rules, frames, pointers and outlines, and curves arrive as media.

Masks as clips of their own: a mask belongs to the clip it cuts and moves with it, as in After Effects. A clip that shapes another clip's picture is a track matte, which names its matte by id.

Trimming the fill with the stroke, as After Effects trims a whole shape: drawing on is a stroke's, and a fill that changes shape as it is trimmed is rarely wanted.

## Notes
