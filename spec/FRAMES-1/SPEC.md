# FRAMES-1: Units, placement and anchor points

Status: accepted

## Summary

The units every value is measured in, the length scale that sizes theme lengths, and how a clip with a box of its own is placed on the frame: by `placement` or `position`, about its anchor point.

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
| Theme lengths | points at the theme `baseWidth`, multiplied by the length scale (below), which gives output pixels. They are the lengths of a text style (size, line height, stroke width, offset, background padding and radius), of a shape style (stroke width, radius, outset, shadow radius and offset), of the `border` and `shadow` groups, the theme `placement.padding`, and a filter's `blur`, `sharpen` and `bloom` `radius` and `pixelate` and `grain` `size` (a `vignette` radius is a fraction, not a length). The same key written on a clip over its style is in the same unit as the style's |
| Area padding | pixels of the picture searched, not a theme length ([FRAMES-2](../FRAMES-2/SPEC.md)) |
| Animation offsets `x`, `y` | multiples of the animated thing's own size, its box before any scale. In a transition, multiples of the frame |
| Angles | degrees, clockwise positive |
| Colours | `#RRGGBB`, `#RRGGBBAA`, or the name of a theme colour |

A clip's own size is that of its box: a title's text box, a media clip's box, a storyline picture's box (the frame, which its conformed crop fills, [FRAMES-9](../FRAMES-9/SPEC.md)), a rect or ellipse shape's box, and the bounding box of a path's points. Scale and rotation act around the clip's anchor point ([Placement](#placement)).

Media time, in media seconds, is a media file's presentation timeline after its edit list, with 0 at the first presented frame. The decoder converts pictures to sRGB and tone maps HDR sources. Everything that reads media reads it by these definitions.

The length scale is `width / baseWidth`, where width is the width of the frame the clip is drawn on: the sequence's output frame, or the compound clip's own frame for a clip inside a compound clip. A sequence whose size is measured from its content ([FRAMES-6](../FRAMES-6/SPEC.md)) has no width yet when its lengths are needed, so its length scale is the width of its first storyline picture's box over `baseWidth`, and a content-fit sequence with no storyline clip that has a picture of its own (every storyline clip a solid) stops.

### Placement

A clip with a box of its own (a title, a media clip, a rect or ellipse shape given by `width` and `height`) is placed by `placement` or by `position`, never both. A clip with both stops. A storyline clip is placed by `position` only. A shape given by `area` or `points` is placed by its geometry, and its `position`, when written, moves its anchor point there.

- `placement` is a name: `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right`. The clip's box sits at that place inside the frame, kept in from every edge by the theme `placement.padding`, the title safe margin. A text style's `offset` replaces that margin on the top or bottom edge, when the name has one (a subtitle sits `offset` above the bottom of the frame).
- `position` is a point ([FRAMES-2](../FRAMES-2/SPEC.md)) in the clip's coordinate space: where the clip's anchor point goes. It is `[x, y]`, or `{"area": <area>, "point": <placement name>}` where an area is allowed. It is keyframable.
- `anchor` names the clip's anchor point, as in an NLE: one of the placement names, a point of the clip's box (`top-left` is its top left corner, `bottom` the middle of its bottom edge). The default is `center`, or for a clip placed by `placement` the point that placement names (a `bottom` subtitle grows from its bottom edge). On a shape placed by its geometry the anchor is a point of that geometry's box as written, before `outset`: `outset` changes what the shape draws, not the point it turns and scales about. Keyframed and animated scale and rotation both act around it, as in an NLE.
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

## Interactions

Areas and points are [FRAMES-2](../FRAMES-2/SPEC.md). Parented coordinates are [FRAMES-10](../FRAMES-10/SPEC.md). A storyline picture's box and conform are [FRAMES-9](../FRAMES-9/SPEC.md). The theme lengths come from [FRAMES-22](../FRAMES-22/SPEC.md). A content-fit frame and what it does to placement are [FRAMES-6](../FRAMES-6/SPEC.md). Transition offsets are applied as [FRAMES-14](../FRAMES-14/SPEC.md) says.

## Alternatives considered

A separate anchor for animation: one point for position, keyframes and animation keeps a preset's look the same about any anchor.

Theme lengths in output pixels: a theme written for a 1920 wide master would draw its text at half the relative size on a 3840 wide one. Points at `baseWidth`, scaled by the frame, keep a look the same at every size, as a resolution-independent title template does in an NLE.

Placement measured on an action safe area other than `placement.padding`: one margin, set by the theme, is enough for the nine names, and anything else is written as a `position`.

## Notes
