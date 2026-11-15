# FRAMES-1: Units, placement and anchor points

Status: accepted

## Summary

The units every value is measured in, the length scale that sizes theme lengths, and how a clip that is not placed by an area is placed: by `placement` or `position`, about its anchor point.

## Motivation

A value means one thing only when its unit and origin are fixed. An agent writes positions from OCR rectangles and frames draws them at any output size, so media pixels, output pixels and theme lengths are told apart once, here. One anchor point serves position, keyframes and animation, as in an NLE, so a subtitle placed at the bottom grows from its bottom edge.

## Rules

### Units

| Value | Unit |
| --- | --- |
| Time | seconds, as a number. Which clock a time is on is [FRAMES-8](../FRAMES-8/SPEC.md) |
| Area in media | media pixels: pixels of the media picture as it is displayed, origin at the top left, rotation metadata applied, pixels made square |
| Position and size on a sequence | pixels of the output, origin at the top left |
| Theme lengths (text size, stroke, the theme's paddings, line width, filter radius) | points at the theme `baseWidth`, multiplied by the length scale of the place they are drawn (below). Area padding is the exception and is measured in its picture ([FRAMES-2](../FRAMES-2/SPEC.md)) |
| Animation offsets `x`, `y` | multiples of the animated thing's own size, its box before any scale (a label's own box for a label animation). In a transition, multiples of the content rect |

| Angles | degrees, clockwise positive |
| Colours | `#RRGGBB`, `#RRGGBBAA`, or the name of a theme colour |

A clip's own size is that of its box: a title's text box, a media clip's box, a shape's area (an arrow's from tail to head). A label is not part of it. Scale and rotation act around the clip's anchor point ([Placement](#placement)), and around the centre of the box for a clip placed by an area.

Media time, in media seconds, is a media file's presentation timeline after its edit list, with 0 at the first presented frame. The decoder converts pictures to sRGB and tone maps HDR sources. Everything that reads media reads it by these definitions.

The length scale is `width / baseWidth`, where width is the output width for a sequence, the width of the canvas at that operation for an image document, and the widest item for a layout.

### Placement

A clip on a sequence that is not placed by an area is placed by `placement` or by `position`, never both. A clip with both stops.

- `placement` is a name: `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right`. The clip sits inside the output frame, inset by the theme `placement.padding` on every side. A text style's `offset` replaces that inset on the top or bottom edge, when the name has one (a subtitle sits `offset` above the bottom of the output).
- `position` is `[x, y]`, where the clip's anchor point goes, in output pixels, or in the media pixels of its picture for a parented clip ([FRAMES-10](../FRAMES-10/SPEC.md)). On a parented clip it may also be `{area, point}`: the point (a placement name) of an area found as [FRAMES-2](../FRAMES-2/SPEC.md) says, padding included, so a title sits beside a button by its text: `{"area": "Send", "point": "left"}` with `anchor: "right"`. It is keyframable.
- `anchor` names the clip's anchor point, as in an NLE: one of the placement names, a point of the clip's box (`top-left` is its top left corner). The default is `center`, or the point the placement names for a clip placed by `placement` (a `bottom` subtitle grows from its bottom edge). Keyframed and animated scale and rotation both act around it, as in an NLE. Under a parent's zoom or a track's scale the anchor point stays on its place in the picture and the clip keeps its size, so a clip next to something stays on it when it is anchored on the side that faces it: a title left of a button is anchored `right`.

Placement is measured on the output frame, not the content rect, so a title can sit in the band an inset leaves. The default is the text style's placement for titles and `center` for media. A parented title or media clip has no default and needs `position`.

## Interactions

Areas are measured as [FRAMES-2](../FRAMES-2/SPEC.md) says. Parented positions are in the media pixels of the picture, [FRAMES-10](../FRAMES-10/SPEC.md). The theme lengths come from [FRAMES-22](../FRAMES-22/SPEC.md).

## Alternatives considered

A separate anchor for animation: one point for position, keyframes and animation keeps a preset's look the same about any anchor.

## Notes
