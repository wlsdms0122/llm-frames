# FRAMES-1: Units, placement and anchor points

Status: accepted

## Summary

The units every value is measured in, the length scale that sizes theme lengths, how a clip with a box of its own is placed on the frame (by `placement` or `position`, about its anchor point), and how `scale` acts on each axis and on the lengths a clip draws with.

## Motivation

A value means one thing only when its unit and origin are fixed. A document is written once and rendered at more than one size (a 1920 wide master, a 1080 wide vertical cut, a still for a poster), and a clip may sit on the frame or inside another clip's picture, so media pixels, output pixels and theme lengths are told apart once, here. One anchor point serves position, keyframes and animation, as in an NLE, so a lower third placed at the bottom left grows from its corner and a logo that spins in turns about its centre.

## Rules

### Units

| Value | Unit |
| --- | --- |
| Time | seconds, as a number. Which clock a time is on is [FRAMES-8](../FRAMES-8/SPEC.md) |
| Media pixels | pixels of a media picture as it is displayed, origin at the top left, rotation metadata applied, pixels made square |
| Output pixels | pixels of the frame, origin at its top left. The frame is the output frame of the sequence, or of the compound clip the clip plays in |
| A clip's coordinates (`position`, `area`, path points, mask geometry) | the clip's coordinate space: output pixels for an unparented clip, the space its parent gives for a parented one ([FRAMES-10](../FRAMES-10/SPEC.md)). A clip's own `crop` is in media pixels of its media |
| Theme lengths | points at the theme `baseWidth`, multiplied by the length scale (below), which gives output pixels. They are the lengths of a text style (size, line height, stroke width, offset, background padding and radius), of a shape style (stroke width, dash lengths and dash offset, radius, outset, shadow radius and offset), of the `border` and `shadow` groups, the theme `placement.padding`, and a filter's `blur`, `sharpen` and `bloom` `radius` and `pixelate` and `grain` `size` (a `vignette` radius is a fraction, not a length). The same key written on a clip over its style is in the same unit as the style's |
| Area padding | pixels of the picture searched, not a theme length ([FRAMES-2](../FRAMES-2/SPEC.md)) |
| Animation offsets `x`, `y` | multiples of the animated thing's own size, its box before any scale. In a transition, multiples of the frame |
| Angles | degrees, clockwise positive |
| Colours | `#RRGGBB`, `#RRGGBBAA`, or the name of a theme colour |

A clip's own size is that of its box: a title's box (its text box, `width` wide or fitted to its text, with its background, [FRAMES-11](../FRAMES-11/SPEC.md)), a media clip's box, a storyline picture's box (the frame, which its conformed crop fills, [FRAMES-9](../FRAMES-9/SPEC.md)), a rect or ellipse shape's box, and the bounding box of a path's points. Scale and rotation act around the clip's anchor point ([Placement](#placement)).

Media time, in media seconds, is a media file's presentation timeline after its edit list, with 0 at the first presented frame. The decoder converts pictures to sRGB and tone maps HDR sources. Everything that reads media reads it by these definitions.

The length scale is `width / baseWidth`, where width is the width of the frame the clip is drawn on: the sequence's output frame, or the compound clip's own frame for a clip inside a compound clip. A sequence whose size is measured from its content ([FRAMES-6](../FRAMES-6/SPEC.md)) has no width yet when its lengths are needed, so its length scale is the width of its first storyline picture's box over `baseWidth`, and a content-fit sequence with no storyline clip that has a picture of its own (every storyline clip a solid) stops.

### Placement

A clip with a box of its own (a title, a media clip, a rect or ellipse shape given by `width` and `height`) is placed by `placement` or by `position`, never both. A clip with both stops. A storyline clip is placed by `position` only. A shape given by `area` or `points` is placed by its geometry, and its `position`, when written, moves its anchor point there.

- `placement` is a name: `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right`. The clip's box sits at that place inside the frame, kept in from every edge by the theme `placement.padding`, the title safe margin. A text style's `offset` replaces that margin on the top or bottom edge, when the name has one (a subtitle sits `offset` above the bottom of the frame).
- `position` is a point ([FRAMES-2](../FRAMES-2/SPEC.md)) in the clip's coordinate space: where the clip's anchor point goes. It is `[x, y]`, or `{"area": <area>, "point": <placement name>}` where an area is allowed. It is keyframable.
- `anchor` names the clip's anchor point, as in an NLE: one of the placement names, a point of the clip's box (`top-left` is its top left corner, `bottom` the middle of its bottom edge). The default is `center`, or for a clip placed by `placement` the point that placement names (a `bottom` subtitle grows from its bottom edge). On a shape placed by its geometry the anchor is a point of that geometry's box. A shape's box is its box as written for every shape: `outset` grows the outline it draws and takes no part in placing it ([FRAMES-11](../FRAMES-11/SPEC.md)). Keyframed and animated scale and rotation both act around it, as in an NLE.
- Under a parent, the anchor point moves with the parent's space and the clip keeps the lengths it draws with ([FRAMES-10](../FRAMES-10/SPEC.md)).

Placement names are measured on the frame. The defaults:

| Clip | Default |
| --- | --- |
| storyline clip | `position` the centre of the frame, `anchor` `center` |
| media clip | `placement` `center` |
| title | the placement of its text style. A title whose style gives none has no default, and without `placement` or `position` it stops |
| rect or ellipse shape by `width` and `height` | `placement` `center` |
| shape by `area` or `points` | its geometry where it is written, `anchor` the centre of its geometry's box |
| parented clip | none: a parented clip with a box of its own needs `position` (or `area` or `points` for a shape), and one with a `placement` stops, since a placement names the frame and not the parent's space |

On a sequence whose size is measured from its content, the defaults that name the frame do not apply and a `placement` stops, as [FRAMES-6](../FRAMES-6/SPEC.md) says.

### Scale

`scale` is a number, one factor on both axes, or `[sx, sy]`, a factor along each of the clip's own axes, as After Effects' Scale. It acts about the anchor point, before the clip's rotation. A negative factor mirrors the clip about its anchor point along that axis: `[-1, 1]` flips it horizontally and `[1, -1]` vertically. A number s is the pair `[s, s]` wherever it stands, a keyframe included. An animation's scale is a number, and it multiplies both factors ([FRAMES-14](../FRAMES-14/SPEC.md)).

A scale stretches the clip's picture and geometry along each axis. **The lengths a clip draws with do not stretch: each length that follows the clip's own scale is multiplied by its scale factor, the geometric mean √(|sx| × |sy|), and drawn the same in every direction.** Those lengths are a stroke's width and dashes, a corner `radius`, an `outset`, a border's width, a shadow's radius, and a run's stroke width and background radius ([FRAMES-10](../FRAMES-10/SPEC.md), [FRAMES-20](../FRAMES-20/SPEC.md)). A shadow's offset is multiplied by the scale factor too, and is a direction in the clip's picture, so it turns, stretches and mirrors with it. For a number s the scale factor is |s|, and a clip's animation multiplies it by the animation's scale.

Skew is not a key. Every linear map of the plane is a rotation, a scale per axis and a second rotation, so a compound clip whose picture is rotated inside it, scaled per axis and rotated again by the clip that shows it gives any affine map of that picture ([FRAMES-9](../FRAMES-9/SPEC.md)). A shape placed by its geometry under a parent rotated and scaled per axis follows its parent's map whole ([FRAMES-10](../FRAMES-10/SPEC.md)), and is skewed with it.

## Interactions

Areas and points are [FRAMES-2](../FRAMES-2/SPEC.md). Parented coordinates are [FRAMES-10](../FRAMES-10/SPEC.md). A storyline picture's box and conform are [FRAMES-9](../FRAMES-9/SPEC.md). The theme lengths come from [FRAMES-22](../FRAMES-22/SPEC.md). A content-fit frame and what it does to placement are [FRAMES-6](../FRAMES-6/SPEC.md). Transition offsets are applied as [FRAMES-14](../FRAMES-14/SPEC.md) says.

## Alternatives considered

A separate anchor for animation: one point for position, keyframes and animation keeps a preset's look the same about any anchor.

Lengths that stretch with a per-axis scale, as an After Effects layer's transform stretches its strokes: a bar scaled wider would draw thicker sides than top and bottom, and a rounded box would get oval corners. Drawing the lengths at the geometric mean keeps a stroke one width and a corner round, and keeps the drawn area of a length the same as the stretched one.

A skew key, as After Effects' Skew and CSS `skew()`: a rotation inside a per-axis scale already gives every affine map, and a skewed picture is rare enough in an edit that a compound clip carries it.

Theme lengths in output pixels: a theme written for a 1920 wide master would draw its text at half the relative size on a 3840 wide one. Points at `baseWidth`, scaled by the frame, keep a look the same at every size, as a resolution-independent title template does in an NLE.

Placement measured on an action safe area other than `placement.padding`: one margin, set by the theme, is enough for the nine names, and anything else is written as a `position`.

## Notes
