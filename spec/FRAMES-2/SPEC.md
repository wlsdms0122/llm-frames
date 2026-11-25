# FRAMES-2: Areas and points

Status: accepted

## Summary

How a place is named in a clip's coordinate space: an area, as a rectangle or as the box of another clip at the same instant; and a point, as coordinates or a named point of an area. Shapes, masks, crops and positions all take these same values.

## Motivation

Shape geometry, a mask, a crop, a title's position and the area `track` follows all name a place in a picture, and an editor that gave each its own way of naming it would make the same place be written four times. One area and one point form, in the clip's own coordinate space, lets a mask, a shape outline and a title beside it take the same value and stay together when the picture under them moves. A place found in a picture, by eye or by its text on screen with `ocr`, is written as the rectangle it was found at, one value for one fact. A place can also be named by another clip, as After Effects' `sourceRectAtTime` names a layer's box: a lower third's bar written as the box of its name, with padding, fits any name a template is given, and a note placed at the name's right edge moves with it. A template runs no program, and a template draws its design for every parameter value it accepts on the fonts it is resolved with, and stops for a value it cannot draw ([FRAMES-17](../FRAMES-17/SPEC.md)). A bar measured once around one name does not fit the next and does not draw the design, so the box of another clip is a tool of frames ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Rules

### Areas

An area is given in one of these forms, in the coordinate space of the clip that writes it ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md)).

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle: its top left corner at `(x, y)`, `w` wide and `h` tall. `w` and `h` are above 0, and 0 or more where two keyframes or more write it ([FRAMES-4](../FRAMES-4/SPEC.md)) |
| `{"clip": "<id>", "padding": p}` | the box of the clip with that `id` at the same instant, grown by `padding` ([Clip areas](#clip-areas)) |

- A clip area's `padding` is optional, a number 0 or more, and defaults to 0. An area object holds `clip` and may hold `padding`, and any other key in it stops, as an unknown key does.
- An area keeps what is written, also where it reaches past the picture's edges. A shape, a mask and a point drawn from it are where it says, and the part of a crop beyond the picture is transparent ([FRAMES-9](../FRAMES-9/SPEC.md)).

### Clip areas

A clip area `{"clip": "<id>", "padding": p}` is the box of another clip, as the clip draws it at the instant being evaluated, in the coordinate space of the clip that writes the area.

- `clip` names, by its `id` ([FRAMES-7](../FRAMES-7/SPEC.md)), a storyline clip with media, or a connected or sequence media clip, title, shape or null, in the same document ([FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md)): a clip with a box, where a null's box is read as a shape's though it draws nothing. Any other clip named (a solid, an adjustment clip, an audio clip, a clip in another document), or an id that names no clip, stops.
- **The named clip's box is taken in one coordinate space, never across two**: the clip that writes the area and the named clip have the same `parent`, or neither has one, or the named clip is the `parent` of the clip that writes the area. A storyline clip has no parent, so an unparented clip and a child of it may name it. Any other pair stops, naming both: two clips with different parents, or a clip with a parent and one without that is not its parent.
- With the same parent or none, the named clip's box is its box ([FRAMES-1](../FRAMES-1/SPEC.md)) before its own transform: for a clip with a corner pin, its corner pin bounds at that instant, the rectangle that bounds its corner pin as written there, before its tracked motion ([FRAMES-27](../FRAMES-27/SPEC.md#the-key)), which lie in the space of the clip that writes the area already; for any other clip with a box of its own (a title's text box with its background, a storyline clip's or a media clip's box ([FRAMES-6](../FRAMES-6/SPEC.md)), a rect, an ellipse or a null placed by `width` and `height`), that box with its anchor point at the clip's keyframed `position`, without its `scale`, `rotation`, tracked motion and animation, and for a storyline clip without its transition motion; for a shape placed by its geometry, its `area` or the bounding box of its path's outline ([FRAMES-11](../FRAMES-11/SPEC.md#shapes)), without its `outset`, and for a null placed by `area`, its `area`. A clip with a box of its own and no corner pin keeps its size in output pixels under a parent ([FRAMES-10](../FRAMES-10/SPEC.md)), so under one its box is carried into the parent's space by the inverse of the parent's map at that instant, and where that map turns or skews it, the area is the axis-aligned rectangle that bounds its four carried corners.
- When the named clip is the parent, its box is taken in the space it gives its children ([FRAMES-10](../FRAMES-10/SPEC.md)), which is the space the clip that writes the area is drawn in: a title's text box with its background at that instant and the box of a rect, an ellipse or a null placed by `width` and `height` lie in that space with that box's top left corner at its origin, a storyline clip's or a media clip's box is carried back into its media pixels by the map of its crop to its box, a shape or a null placed by its geometry gives its `area` or the bounding box of its path's outline as written, and a clip with a corner pin gives its corner pin bounds at that instant, the rectangle a sibling takes ([FRAMES-27](../FRAMES-27/SPEC.md#the-key)), which its transform, its tracked motion, then carries. A storyline clip's crop is the `rect` of its `box` that `timeline --at` reports ([FRAMES-23](../FRAMES-23/SPEC.md#a-clips-times-and-spaces)). The parent's transform then carries the area with the rest of the child, so a bar parented to its title with `area: {"clip": "<title>"}` fits the title and follows its transform, its animation's motion included.
- `padding` is a theme length ([FRAMES-1](../FRAMES-1/SPEC.md)), as a title background's padding is, so a lower third keeps its proportions on every frame size: the box grows by it on every side, once it is in the space of the clip that writes the area. With the same parent or none, the padding keeps its size against the named clip's box, which keeps its size in output pixels: under a parent it is divided by the length factor of the parent's map at that instant ([FRAMES-20](../FRAMES-20/SPEC.md)). A named clip with a corner pin gives its corner pin bounds in the parent's space, where they scale with the parent, so the padding against them is not divided. When the named clip is the parent, the padding is in the space the parent gives its children, as the parent's box is, so it scales with the parent as a title's background padding scales with its title.
- The box is taken at the instant being evaluated, on the sequence clock, whether or not the named clip is visible then. Outside the named clip's window it holds the box it has at the window's edge, as a parent's transform does ([FRAMES-10](../FRAMES-10/SPEC.md)). A storyline clip's window is the range it is drawn over, the transitions at its two ends included, the range `timeline` reports as its `drawn` ([FRAMES-23](../FRAMES-23/SPEC.md#machine-output)), so a clip area naming it holds its box before that range and after it. A clip area in a keyframe is the named clip's box at each instant of the spans on its sides ([FRAMES-4](../FRAMES-4/SPEC.md)).
- A clip area may stand wherever an area or a point is in the clip's coordinate space: the `area`, `points`, `position` and `cornerPin` of a connected or sequence clip, and the mask of a shape placed by `area` or `points` or of an adjustment clip. A clip area in a `crop` or the mask of a media clip, a title, a storyline clip or a shape placed by `width` and `height` stops, since those are in the clip's own media or box.
- A clip whose box depends on itself through clip areas, its own included, stops and names the clips in the cycle: a rect whose area is a title's box, and a title whose `position` is a point of that rect's area.

```json
{ "id": "name", "at": [2, 8], "lane": 2, "kind": "title", "text": "Mina Park", "style": "name" },
{ "at": [2, 8], "lane": 1, "kind": "rect", "area": { "clip": "name", "padding": 24 }, "fill": "#101418E6", "radius": 8 },
{ "at": [2.4, 8], "lane": 2, "kind": "title", "text": "Head baker", "style": "role",
  "position": { "area": { "clip": "name", "padding": 24 }, "point": "right" }, "anchor": "left" }
```

The bar is the name's box grown by 24 points on every side, a theme length, so it keeps its share of the frame at every size, so it fits whatever name a template is given, and the role sits at the bar's right edge, growing to the right from it.

### Points

A point is one of these forms, in the same coordinate space as an area.

| Form | Meaning |
| --- | --- |
| `[x, y]` | that point |
| `{"area": <area>, "point": <placement name>}` | that point of the area, padding included: `top-left` its top left corner, `top` the middle of its top edge, `center` its centre, and so on for the nine names of [FRAMES-1](../FRAMES-1/SPEC.md) |

An area inside a point is either form, where that form is allowed.

### What takes areas and points

| Key | Takes |
| --- | --- |
| a rect or ellipse shape's `area` ([FRAMES-11](../FRAMES-11/SPEC.md)) | an area |
| a path shape's `points` ([FRAMES-11](../FRAMES-11/SPEC.md)) | a list of vertices, each `[x, y]` or a vertex object whose `vertex` is a point and which may carry tangents ([FRAMES-11](../FRAMES-11/SPEC.md#shapes)) |
| a mask's `area`, `points` and `position` ([FRAMES-11](../FRAMES-11/SPEC.md)) | an area, a list of vertices as a path shape's, a point |
| `crop` ([FRAMES-9](../FRAMES-9/SPEC.md)) | an area, or `{scale}` |
| `position` ([FRAMES-1](../FRAMES-1/SPEC.md)) | a point |
| `cornerPin` ([FRAMES-27](../FRAMES-27/SPEC.md)) | a list of four points |

## Interactions

The sequence clock a clip area is taken on is [FRAMES-8](../FRAMES-8/SPEC.md). A coordinate space is given by parenting, [FRAMES-10](../FRAMES-10/SPEC.md). Keyframed areas and points interpolate as [FRAMES-4](../FRAMES-4/SPEC.md) says.

## Alternatives considered

A place named by text in the document, an area found by OCR as the line that holds some text or the lines between two texts: a program reads `ocr --json`, which gives each recognised line with its rectangle at a media time ([FRAMES-23](../FRAMES-23/SPEC.md)), and writes the rectangle, one value for one fact ([FRAMES-25](../FRAMES-25/SPEC.md)). In resolve it would carry rules kept for that one feature: the frame a text is searched on, the coordinate spaces where a search may stand, and the carrying of a found value back through a parent's transform and a track's motion. So a document whose areas name text is turned into a frames document by a tool before resolve.

A storyline clip left out of what a clip area names, since the storyline places it: a template whose storyline clip is a media parameter under a `fit` conform shows a picture whose box depends on the media's aspect, so a caption at the picture's edge or an outline around it fits no written value for every argument, and a template draws its design for every value it accepts ([FRAMES-17](../FRAMES-17/SPEC.md)). A storyline clip's box is defined as any media clip's is ([FRAMES-6](../FRAMES-6/SPEC.md)), and an unparented clip shares its space. A storyline clip still writes no clip area, since the storyline places it in output pixels.

A clip area naming a storyline clip that takes the clip's transition motion, so that an unparented caption slides out with a pushed picture: the storyline draws a clip's picture in two layers, its own transform inside and the transition's motion outside, which moves the whole frame about its centre, so that motion applied to the box before the clip's own `scale` and `rotation` lands where no picture is drawn whenever those are not 1 and 0, and taking the inner layer too is the clip area with the named clip's transform rejected below. The form taken is not circular either way, since a transition's motion depends on the storyline alone. What is seen is followed by parenting: a child of the storyline clip is carried by both layers as one map ([FRAMES-10](../FRAMES-10/SPEC.md)), and its clip area naming its parent is the crop in media pixels, so an outline parented to the picture fits it through a scale, a turn and a push.

A clip area that takes the named clip's transform, its scale, rotation and animation included: a bar would turn and bounce with its title's entrance and not with its own, and the area would not be a rectangle. The box before its transform is what `sourceRectAtTime` gives, and a bar that should move with its title is parented to it, which a clip area naming the parent allows.

A clip area between two clips with two different parents, carried through each parent: it would mix two parents' motion into one value, and two clips that should share a space share a parent or are parent and child. A parent's box in its own space mixes nothing, since it is the space its child is drawn in.

Text that shrinks to fit a box, as a responsive title template does: a template sets a title's `width` and `lines`, and a name longer than they allow is a value the template cannot draw, so it stops ([FRAMES-5](../FRAMES-5/SPEC.md), [FRAMES-17](../FRAMES-17/SPEC.md)), and the template draws its design for every value it accepts on the fonts it is resolved with. A program that must fit text measures it with `evaluate` ([FRAMES-23](../FRAMES-23/SPEC.md)) and writes the size, one value for the fact, which builds it outside frames ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Notes
