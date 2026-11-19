# FRAMES-11: Titles, shapes, media and adjustment clips

Status: accepted

## Summary

The clip kinds that draw on a sequence: titles with styled runs, the three shapes (rect, ellipse and path) with fill, stroke, gradients, dashes, arrowheads and trim, media clips (picture in picture and graphics made elsewhere), adjustment clips, the masks and track mattes any picture takes, and blend modes.

## Motivation

Titles and shapes are the basics of any NLE. A lower third is a name and a role in two styles over a bar, an end card is a title in a box, a diagram is lines and arrows drawn on one by one, a spotlight darkens everything but a region. Each of these is made from a few general tools: text in runs, a rect, an ellipse and a path with a stroke model, and a mask. Their geometry belongs to frames, how they move is a preset, and how they look is a theme style. Masks and track mattes cut any picture to a shape or to another clip, as they do in After Effects and Premiere Pro, which is how a logo is cut to a circle, a filter is kept to one region, or text is filled with video.

## Rules

### Titles

- `title` is a string or a list of runs `{text, style}`. A string is one run in the clip's style. A run's `style` names a theme text style whose character attributes (font, size, weight, italic, tracking, kerning, features, baseline shift, colour, stroke, highlight and underline) apply to that run, with the clip's `character` merged over them, and the paragraph attributes (placement, offset, align, line height, lines, background) come from the clip's `style`, with the clip's `paragraph` merged over them. Runs are laid out as [FRAMES-5](../FRAMES-5/SPEC.md) says.
- `style` names a theme text style ([FRAMES-22](../FRAMES-22/SPEC.md)) and is required, since which kind of text a title is belongs to the document.
- `character` is an object of character attributes, the character keys of a text style (`font`, `size`, `weight`, `italic`, `tracking`, `kerning`, `features`, `baselineShift`, `color`, `stroke`, `highlight`, `underline`, [FRAMES-22](../FRAMES-22/SPEC.md)), as After Effects' Character panel sets them on a text layer. It merges over every run's style leaf by leaf, as every layer of a look merges ([FRAMES-22](../FRAMES-22/SPEC.md)), so `character: {"color": "accent"}` colours every run and keeps each run's size and weight. Its lengths are theme lengths, as a style's are ([FRAMES-1](../FRAMES-1/SPEC.md)), and the clip's line height, when its style and its `paragraph` leave it to its default, follows the size of the clip's style with `character` merged over it.
- The attributes that decide the text's faces, shaping and line breaks (`font`, `size`, `weight`, `italic`, `kerning`, `features`) are static, since resolve makes those decisions once ([FRAMES-5](../FRAMES-5/SPEC.md)), and a keyframe's `character` that holds one stops. The others take keyframes ([FRAMES-4](../FRAMES-4/SPEC.md)): `color`, `stroke`, `baselineShift`, which raises only its own run's glyphs, and `highlight` and `underline`, which take no part in layout, so a title's colour, a highlight's padding or an underline's offset changes as one value on one clip. `tracking` takes keyframes too, with its lines broken once at its largest value and its glyphs placed along them at each instant ([FRAMES-5](../FRAMES-5/SPEC.md)). A title's size changes through its `scale` ([FRAMES-1](../FRAMES-1/SPEC.md)).
- `paragraph` is an object of paragraph attributes, `align`, `lineHeight` and `background` as a text style takes them ([FRAMES-22](../FRAMES-22/SPEC.md)), as After Effects' Paragraph panel sets them on a text layer. It merges over the paragraph attributes of the clip's style leaf by leaf, as `character` merges over the runs' styles, and its lengths are theme lengths. `align` is a name and static. `lineHeight` and the background's `color`, `padding` and `radius` take keyframes ([FRAMES-4](../FRAMES-4/SPEC.md)), since no line break depends on them: evaluation places the lines at the line height of each instant and draws the background with its values then ([FRAMES-5](../FRAMES-5/SPEC.md)), so leading that opens as a title enters, or a box whose padding grows around a name, is one value on one clip. `placement`, `offset` and `lines` stay the style's: a title is placed by its own `placement` or `position`, and `lines` is the limit its style sets.
- `width`, in output pixels, is the width of the title's text box, and the text wraps at it. Each line is placed inside that width by its `align`, and its background fills it. A title without `width` does not wrap: its lines break only at `\n`, and its text box is as wide as its widest line ([FRAMES-5](../FRAMES-5/SPEC.md)).
- A title's box is its text box, grown by its background padding ([FRAMES-5](../FRAMES-5/SPEC.md)), each at the instant it is read. It is placed by `placement` or `position` about its anchor point ([FRAMES-1](../FRAMES-1/SPEC.md)).

### Shapes

`shape` is `rect`, `ellipse` or `path`.

| shape | Geometry | Keys of its own |
| --- | --- | --- |
| `rect` | a box: `area`, or `width` and `height` placed as a box | `radius`, `outset` |
| `ellipse` | a box, as for `rect`: the ellipse inscribed in it | `outset` |
| `path` | `points`, a list of at least two points ([FRAMES-2](../FRAMES-2/SPEC.md)), joined by straight segments in order | `closed` (default `false`), which joins the last point to the first |

- A rect or ellipse takes exactly one of `area` (an area in its coordinate space, [FRAMES-2](../FRAMES-2/SPEC.md)) and the pair `width` and `height` (output pixels, both needed). Given `width` and `height`, the box is placed by `placement` or `position` about its `anchor`, as a media clip's box is ([FRAMES-1](../FRAMES-1/SPEC.md)). A shape given by `area` or `points` is placed by its geometry ([FRAMES-1](../FRAMES-1/SPEC.md)).
- `radius` rounds a rect's corners with arcs, circular in the shape's own coordinates and carried with the outline, so a per-axis scale draws them elliptical ([FRAMES-1](../FRAMES-1/SPEC.md)), cut to half the box's shorter side. `outset` grows the outline a rect or an ellipse draws on every side, before the corners are rounded, and takes no part in placing it. Both are theme lengths ([FRAMES-1](../FRAMES-1/SPEC.md)), so they keep their size under a parent's zoom.
- A key a shape kind does not take stops: `radius` on an ellipse or a path, `outset`, `area`, `width` or `height` on a path, `points` or `closed` on a rect or an ellipse.
- A shape's box ([FRAMES-1](../FRAMES-1/SPEC.md)) is its box as written for a rect or an ellipse, `width` by `height` or its `area`, and the bounding box of its points for a path. `placement`, `position`, `anchor`, the space its children see ([FRAMES-10](../FRAMES-10/SPEC.md)) and an animation's `x` and `y` ([FRAMES-14](../FRAMES-14/SPEC.md)) all take that box. `outset` grows only the outline it draws, and so what it draws: its receiver box and its content-fit extent measure the grown outline.

**Appearance.**

| Key | Form | Meaning |
| --- | --- | --- |
| `fill` | a colour, a gradient ([Gradients](#gradients)), or `false` | the inside of the outline painted with that colour or gradient, as SVG's `fill` takes a paint. A path is filled as if it were closed, by the nonzero rule, as SVG fills it. `false` turns off a style's fill |
| `stroke` | `{color, gradient, width, join, cap, start, end, dash, dashOffset}`, or `false` | the outline drawn centred on itself. `false` turns off a style's stroke |
| `trim` | `[a, b]`, each from 0 to 1, default `[0, 1]` | the part of the outline the stroke draws, as After Effects' Trim Paths |
| `shadow` | `true` (the theme `shadow`), `false`, or `{radius, offset, color}` whose missing keys come from the theme `shadow` | a drop shadow of the shape's drawn picture ([FRAMES-22](../FRAMES-22/SPEC.md)) |
| `style` | a shape style's name | defaults for `fill`, `stroke`, `radius`, `outset` and `shadow` ([FRAMES-22](../FRAMES-22/SPEC.md)) |

| Stroke key | Form | Default |
| --- | --- | --- |
| `color` | a colour | the theme `accent` colour, when the stroke has no `gradient` |
| `gradient` | a gradient ([Gradients](#gradients)), which paints the stroke in place of `color` | none |
| `width` | a theme length above 0 ([FRAMES-1](../FRAMES-1/SPEC.md)), 0 or more where two keyframes or more write it ([FRAMES-4](../FRAMES-4/SPEC.md)), where a width of 0 draws no stroke and no arrowhead | required |
| `join` | `miter`, `round` or `bevel`, as SVG `stroke-linejoin`, with a miter limit of 4 as SVG's | `round` |
| `cap` | `butt`, `round` or `square`, as SVG `stroke-linecap` | `butt` |
| `start`, `end` | `none` or `arrow` | `none` |
| `dash` | a list of theme lengths, 0 or more and not all 0: the lengths of the dashes and the gaps between them in turn, as SVG `stroke-dasharray` | none: the stroke is drawn whole |
| `dashOffset` | a theme length: how far into the pattern the stroke starts, as SVG `stroke-dashoffset` | 0 |

- A stroke takes at most one of `color` and `gradient`, and one with both stops. Without either it is drawn in the theme `accent` colour.
- An `arrow` at an end is an arrowhead: a filled triangle in the stroke's colour or gradient, `4 × width` long and `4 × width` wide at its base, its tip at that end of the drawn stroke and its axis along the stroke's direction there. The stroke stops at the head's base. Where the drawn stroke is shorter than its heads, each head shrinks, length and width together, so the heads together take the stroke's length. Arrowheads sit on the ends of the stroke as drawn: an open path's stroke always has two, and a rect's, an ellipse's or a closed path's has them only when its `trim` leaves part of the outline undrawn. A whole closed outline has no ends and draws no arrowhead.
- `dash` lays dashes along the stroke as drawn, from its start after `trim`: a dash of the first length, a gap of the second, and so on, the list taken twice over when its length is odd, as SVG does, and the pattern repeated to the stroke's end. `dashOffset` moves the pattern back along the stroke by its length, so keyframing it moves the dashes along the outline. Each dash takes `cap` at both its ends and `join` at the corners inside it. Arrowheads are drawn whole over a dashed stroke, and the line stops at their bases as an undashed one does. A `dash` that is empty, holds a negative length or holds only zeros stops, in a keyframe as in a static value: a pattern of zeros draws the stroke whole, as SVG draws one, while the patterns beside it draw fine dots, so it is not where a dashed stroke changes continuously into a whole one. A gap of 0 is: `[d, 0]` draws the stroke whole for any `d`, and a dashed stroke eases into a whole one by keyframing its gaps to 0. A sampled pattern an ease carries to all zeros draws the stroke whole.
- `trim` measures the outline as a fraction of its length: a rect from its top left corner (for a rounded rect, where the top edge leaves the corner's arc), clockwise; an ellipse from its top, clockwise; a path from its first point along its points, the closing segment last when it is closed. These directions are in the shape's own coordinates, so a mirrored shape draws on mirrored. The stroke is drawn from the smaller of `a` and `b` to the larger, and `a` equal to `b` draws no stroke. A trimmed outline has ends, which take `cap` and its arrowheads. `trim` acts on the stroke only, and the fill is drawn whole. It is keyframable, which draws a stroke on or off.
- A key written on the clip, its static value with the structure its keyframes give ([FRAMES-4](../FRAMES-4/SPEC.md)), merges over its style's value leaf by leaf, as every layer of a look merges ([FRAMES-22](../FRAMES-22/SPEC.md)): the style gives defaults and the clip changes only what it writes. So a clip's `stroke: {"color": "#FF0000"}` takes its style's `width`, `join` and `cap`, and a theme that thickens the style's stroke thickens this one too; a colour `fill`, written statically or only in keyframes, replaces a style's gradient; a clip's stroke `color` drops its style's stroke `gradient`, and the reverse; and `false` turns a style's value off. A stroke whose clip and style together give no `width` stops. A shape without `style` takes nothing from the theme but colour names and the theme `shadow` for `true`. A shape that, after its style, has neither a fill nor a stroke stops, since it would draw nothing.
- `scale` and `rotation` act about the shape's anchor point ([FRAMES-1](../FRAMES-1/SPEC.md)). The stroke width and the shadow scale with the shape's own and its animation's scale by its scale factor, the same in every direction, and `radius`, `outset` and the dash lengths are part of the outline and follow its scale along each axis ([FRAMES-1](../FRAMES-1/SPEC.md)). None of them grows with a parent's scale ([FRAMES-10](../FRAMES-10/SPEC.md)).
- A shape's `points`, `area`, `width`, `height`, `radius`, `outset`, `fill`, `stroke` and `shadow` keyframe leaf by leaf as [FRAMES-4](../FRAMES-4/SPEC.md) says, each timed leaf sampled over the clip's static value merged over its style's, so keyframes that write only a stroke's colour move the colour of the style's stroke while its width, `join` and `cap` stay, and a gradient's kind and number of stops are static while its points, offsets and colours move. A `points` keyframe interpolates point by point, so every `points` value of one shape has the same number of points, and a keyframe with another number stops.

**Gradients.** A gradient is a paint that changes colour across the shape, as CSS's and SVG's linear and radial gradients do:

| Form | Keys |
| --- | --- |
| `{"linear": {"from": p, "to": p, "stops": [...]}}` | `from` and `to`, points in fractions of the shape's box |
| `{"radial": {"center": p, "radius": r, "stops": [...]}}` | `center`, a point in fractions of the shape's box, and `radius`, a number above 0 (0 or more where two keyframes or more write it, [FRAMES-4](../FRAMES-4/SPEC.md)), default 1: a fraction of the distance from the centre to the farthest corner of the box, as CSS's `farthest-corner` |

- A point `[u, v]` of a gradient is `[x + u × w, y + v × h]` of the shape's box `[x, y, w, h]` ([FRAMES-1](../FRAMES-1/SPEC.md)): `[0, 0]` is its top left corner and `[1, 1]` its bottom right. Fractions outside 0 to 1 lie outside the box. So the gradient follows the box as it is placed, keyframed and parented, and is carried by the shape's transform with its geometry: a radial gradient is a circle in the shape's own coordinates, `radius × D` in radius, where D is the distance from its centre to the box's farthest corner, and is drawn as an ellipse where the shape is scaled per axis. So at `radius` 1 the last stop's colour reaches every corner of the box, on a wide frame and on a tall one alike.
- `stops` is a list of at least two `[offset, colour]`, with offsets from 0 to 1 in order, each at least the one before it. A colour may be a theme colour's name. Fewer than two stops, an offset outside 0 to 1, or an offset below the one before it stops.
- At a point q of the shape's own coordinates the gradient's position is g = ((q - from) · (to - from)) / |to - from|² for a linear gradient, the projection onto the line from `from` to `to`, and g = |q - center| / (radius × D) for a radial one. Its colour at g is the first stop's colour where g is at or below the first offset, the last stop's at or past the last offset, and between two neighbouring stops their colours interpolated at g's place between their offsets with premultiplied alpha, as CSS interpolates a gradient: on the working space's sRGB-encoded values ([FRAMES-21](../FRAMES-21/SPEC.md)), each colour's red, green and blue multiplied by its alpha, all four channels interpolated linearly, and red, green and blue divided by the alpha that results (0 where it is 0). A gradient lays colour over space, where alpha is coverage, so a transparent stop adds no colour of its own: a vignette from `#00000000` or from `#FFFFFF00` to black darkens alike, with no grey band. Two stops at one offset make a hard edge there.
- A linear gradient whose `from` and `to` are the same point, or a radial one of radius 0, paints its last stop's colour, as SVG does.
- A stroke's gradient is laid over the same box as a fill's and paints the stroke and its arrowheads wherever they lie, the colours past its ends held as above.
- A gradient is a value with leaves, so it is keyframable ([FRAMES-4](../FRAMES-4/SPEC.md)): its points, radius, offsets and colours move, and its kind and its number of stops stay. Where an ease carries the offsets out of order, each sampled offset is clamped to 0 to 1 and then raised to the one before it, as CSS fixes the positions of its colour stops.
- A shape's `fill` and its stroke's `gradient`, and a shape style's, are the only gradients. Every colour a clip draws with, a stroke's `color` included, is one colour.

**Note.** A rect over the frame with a gradient fill is an NLE's gradient generator, and a frame-sized rect with a radial gradient from a clear centre to a dark edge, blended with `multiply`, is a vignette that a template can place and keyframe. frames has no generator clip.

**Note.** To darken everything but a region, draw a rect over the frame filled with a dark colour, with an inverted mask of the region ([Masks and track mattes](#masks-and-track-mattes)). To point at a region, draw a path with `"end": "arrow"` whose last point is a point of that region ([FRAMES-2](../FRAMES-2/SPEC.md)). A label is a title parented to its shape ([FRAMES-10](../FRAMES-10/SPEC.md)). A bar that fits its title and moves with it is a rect parented to the title whose `area` is the title's box with padding ([FRAMES-2](../FRAMES-2/SPEC.md)).

### Media clips

- `width` and `height` size the clip's box in output pixels. Given one, the other follows the aspect ratio of the clip's first crop, or of the media when there is no crop, and every crop conforms to that box, so the box holds still while the crop moves. Given both, the crop conforms to the box by the clip's `conform` (`fit` or `fill`, default `fit`), as a storyline crop conforms to the frame ([FRAMES-9](../FRAMES-9/SPEC.md)). Given neither, the box is the first crop, or the media, fitted to the frame, as an NLE conforms a picture to its sequence. Under content fit the box given neither is measured as [FRAMES-6](../FRAMES-6/SPEC.md) says.
- `crop` and `filter` work as on a storyline clip, with the clip's own box in place of the frame. `crop` is in media pixels of the clip's own media.
- `radius` rounds the box's corners as a rect's are rounded, a theme length cut to half the box's shorter side. `border` is `true` (the theme `border`, `{width, color}`) or a colour, which replaces the theme border's colour, and draws a border of the theme border's width inside the box, its outer edge following the rounded corners. `shadow` is `true` (the theme `shadow`), `false`, or `{radius, offset, color}` whose missing keys come from the theme `shadow`, and draws a drop shadow of the box's picture below it. Each length is a theme length ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-22](../FRAMES-22/SPEC.md)). `radius`, `border` and `shadow` are keyframable ([FRAMES-4](../FRAMES-4/SPEC.md)): a border's colour moves, and `true` in a keyframe stands for the theme value. A storyline clip with media takes the three keys the same way on its frame-sized box ([FRAMES-9](../FRAMES-9/SPEC.md)).
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
- `mask` is keyframable leaf by leaf ([FRAMES-4](../FRAMES-4/SPEC.md)). The clip's `mask` gives its masks in order, each with its `shape`, how its geometry is given, its number of points, `invert` and `mode`, which are static, and a keyframe's `mask` is a list of the same length whose masks write the geometry, `radius` and `feather` they move, merged over the static masks. Between keyframes each mask interpolates its geometry per component (an area per component, a box's `width`, `height` and `position`, a path point by point) and its `radius` and `feather` as numbers. A keyframe whose list has another length, or that writes a static leaf of a mask, stops.

`trackMatte` is taken by every clip with a picture: `{clip: "<id>", mode: "alpha" | "luma", invert: false}`. `mode` is required and `invert` defaults to `false`.

- `clip` names, by its `id` ([FRAMES-7](../FRAMES-7/SPEC.md)), a connected or sequence media clip, title or shape in the same document. Any other clip named (a storyline clip, an adjustment clip, an audio clip, a clip in another document), or an id that names no clip, stops.
- The named clip is the matte and is not drawn itself. Its picture at t is what it would draw at t (with its transform, parent, animation, opacity, mask and its own track matte, and without its blend), on a transparent frame, and nothing outside its visible window.
- `alpha` multiplies the clip's alpha by the matte's alpha. `luma` multiplies it by the matte's luma: the Rec. 709 luma of its unpremultiplied sRGB-encoded values times its alpha, so a transparent matte counts as black. `invert` uses 1 minus that value.
- The matte cuts the clip where its mask does: on a storyline clip, before the transition motion ([FRAMES-9](../FRAMES-9/SPEC.md)).
- A clip used as a matte by two clips is fine. A matte that has a track matte of its own is followed, and a chain of track mattes that comes back to a clip already in it stops.

### Blend modes

`blend` composites a clip with a picture with what is below it: a storyline clip with media, a media clip, a title, a shape, or an adjustment clip's filtered result. The modes and their formulas are those of W3C Compositing and Blending Level 1: `normal` (default), `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`, and the non-separable modes `hue`, `saturation`, `color` and `luminosity`. A non-separable mode mixes the three channels of a colour together: it is computed with W3C's `Lum` (the weights 0.3, 0.59 and 0.11), `Sat`, `SetLum`, `SetSat` and `ClipColor` on the working space's sRGB-encoded values ([FRAMES-21](../FRAMES-21/SPEC.md)), as every other mode is. Light leaks and film burns come in this way, as media with `screen` or `plus-lighter`, and a colour wash as a rect over the frame filled with one colour and blended with `color`, which keeps the luminosity of what is below.

## Interactions

Placement, anchor points and theme lengths are [FRAMES-1](../FRAMES-1/SPEC.md). Areas and points are [FRAMES-2](../FRAMES-2/SPEC.md). Text layout and runs are [FRAMES-5](../FRAMES-5/SPEC.md). Keys are [FRAMES-7](../FRAMES-7/SPEC.md), `timeRemap` is [FRAMES-8](../FRAMES-8/SPEC.md), the storyline and stacking are [FRAMES-9](../FRAMES-9/SPEC.md), and parents are [FRAMES-10](../FRAMES-10/SPEC.md). Tracked masks are [FRAMES-12](../FRAMES-12/SPEC.md). Animations, reveal and transitions are [FRAMES-14](../FRAMES-14/SPEC.md), filters [FRAMES-15](../FRAMES-15/SPEC.md). Text styles, shape styles, the border and the shadow are [FRAMES-22](../FRAMES-22/SPEC.md). Display list items, the mask and track matte fields among them, are [FRAMES-20](../FRAMES-20/SPEC.md).

## Alternatives considered

A fixed set of annotation shapes (a box, a fill, a dim, an arrow) with labels: each is a rect, a path or a mask with a style, and a fixed set names purposes where frames gives tools. A label side chosen by the engine: a label is a title parented to its shape, placed where the document puts it.

Emphasis markup inside a title's text: a run names its style, so any style can be mixed into a line and no character has to be escaped.

Curved paths (Bézier segments): left out (README). Straight segments draw rules, frames, pointers and outlines, and curves arrive as media.

Masks as clips of their own: a mask belongs to the clip it cuts and moves with it, as in After Effects. A clip that shapes another clip's picture is a track matte, which names its matte by id.

Trimming the fill with the stroke, as After Effects trims a whole shape: drawing on is a stroke's, and a fill that changes shape as it is trimmed is rarely wanted.

Gradient points in the shape's coordinate space, as SVG's `userSpaceOnUse`: a gradient would stay where it was written while its shape moves or grows, and a template's bar would need its gradient written again for every size. Fractions of the box, as SVG's `objectBoundingBox` and CSS's gradients on an element, follow the shape. A radial radius as a fraction of the distance to the farthest corner keeps the gradient round, where `objectBoundingBox` stretches it over a box that is not square, and reaches the whole box at 1 whatever its shape. A fraction of the box's width would leave the top and bottom of a tall box outside a vignette written for a wide one.

Gradients left to extensions, as bands of flat colour stacked or an image made outside and laid in: one ramp would be spread over many clips or baked into media, and its colours, its direction and the box it follows would no longer be values of one shape ([FRAMES-25](../FRAMES-25/SPEC.md)).

Dashes laid from the outline's start and uncovered by `trim`: a dashed line drawn on would show the same, but a trim whose start moves would cut a dash anywhere along its length. Laid along the stroke as drawn, as After Effects lays dashes on a trimmed path, the stroke always starts with a whole dash, and `dashOffset` moves the pattern where that is wanted.

## Notes
