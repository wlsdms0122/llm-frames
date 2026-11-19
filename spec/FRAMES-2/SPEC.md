# FRAMES-2: Areas and points

Status: accepted

## Summary

How a place is named in a clip's coordinate space: an area, as a rectangle, as the box of another clip at the same instant, or, where there is a media picture to search, as text found by OCR; and a point, as coordinates or a named point of an area. Shapes, masks, crops, positions and tracking all take these same values.

## Motivation

Shape geometry, a mask, a crop, a title's position and a tracker's target all name a place in a picture, and an editor that gave each its own way of naming it would make the same place be written four times. One area and one point form, in the clip's own coordinate space, lets a mask, a shape outline and a title beside it take the same value and stay together when the picture under them moves. Where the picture holds text (a sign in camera footage, a slide, a scoreboard, an app on screen), a place can also be named by that text, so a document survives a new take or a new export without measuring again, and stopping on an ambiguous or missing match keeps a mask from landing on the wrong word unnoticed. A place can also be named by another clip, as After Effects' `sourceRectAtTime` names a layer's box: a lower third's bar written as the box of its name, with padding, fits any name a template is given, and a note placed at the name's right edge moves with it. A template runs no program and must draw rightly for every value its parameters take ([FRAMES-17](../FRAMES-17/SPEC.md)), and a bar measured once around one name is wrong for the next, so the box of another clip is a tool of frames and not an extension's work ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Rules

### Areas

An area is given in one of these forms, in the coordinate space of the clip that writes it ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md)).

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle: its top left corner at `(x, y)`, `w` wide and `h` tall. `w` and `h` are above 0, and 0 or more in a keyframe ([FRAMES-4](../FRAMES-4/SPEC.md)) |
| `{"text": "...", "nth": n, "padding": p}` | the recognised line that contains the text. With `nth`, the nth line (from 0) among the lines that contain it, counted top to bottom by row and left to right within a row, where lines whose vertical centres lie within half the shorter one's height of each other are one row |
| `{"clip": "<id>", "padding": p}` | the box of the clip with that `id` at the same instant, grown by `padding` ([Clip areas](#clip-areas)) |
| `{"from": "...", "to": "...", "fromNth": a, "toNth": b, "padding": p}` | the rectangle around the `from` line and the `to` line, each found as the `text` form finds its line (`fromNth` and `toNth` acting as its `nth`), and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |

- `nth`, `fromNth` and `toNth` are optional whole numbers, 0 or more. `padding` is optional, a number 0 or more, and defaults to 0. An area object holds the keys of one form, and one that mixes `clip` with a text form's keys stops.
- Text is compared with whitespace removed. A line matches when it contains the text.
- A text form without `nth` that matches more than one line stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that matches no line, or an `nth` past the last match, stops, naming the media, the text and the nth.
- A text form's area grows outward on every side by its `padding`, in pixels of the picture searched, once the area is found. A tracker follows the area as found, before padding ([FRAMES-12](../FRAMES-12/SPEC.md)).
- An area keeps what is written or found, also where it reaches past the picture's edges. A shape, a mask and a point drawn from it are where it says, and the part of a crop beyond the picture is transparent ([FRAMES-9](../FRAMES-9/SPEC.md)). OCR and the tracker read only the picture's pixels.

### Clip areas

A clip area `{"clip": "<id>", "padding": p}` is the box of another clip, as the clip draws it at the instant being evaluated, in the coordinate space of the clip that writes the area.

- `clip` names, by its `id` ([FRAMES-7](../FRAMES-7/SPEC.md)), a connected or sequence media clip, title or shape in the same document, the clips a track matte may name ([FRAMES-11](../FRAMES-11/SPEC.md)). Any other clip named (a storyline clip, an adjustment clip, an audio clip, a clip in another document), or an id that names no clip, stops.
- **The named clip's box is taken in one coordinate space, never across two**: the clip that writes the area and the named clip have the same `parent`, or neither has one, or the named clip is the `parent` of the clip that writes the area. Any other pair stops, naming both: two clips with different parents, or a clip with a parent and one without that is not its parent.
- With the same parent or none, the named clip's box is its box ([FRAMES-1](../FRAMES-1/SPEC.md)) before its own transform: for a clip with a box of its own (a title's text box with its style's background, a media clip's box, a rect or ellipse placed by `width` and `height`), that box with its anchor point at the clip's keyframed `position`, without its `scale`, `rotation`, tracked motion and animation; for a shape placed by its geometry, its `area` or the bounding box of its `points`, without its `outset`. A clip with a box of its own keeps its size in output pixels under a parent ([FRAMES-10](../FRAMES-10/SPEC.md)), so under one its box is carried into the parent's space by the inverse of the parent's map at that instant, and where that map turns or skews it, the area is the axis-aligned rectangle that bounds its four carried corners.
- When the named clip is the parent, its box is taken in the space it gives its children ([FRAMES-10](../FRAMES-10/SPEC.md)), which is the space the clip that writes the area is drawn in: a title's box and the box of a rect or ellipse placed by `width` and `height` lie in that space with the text box's or the box's top left corner at its origin (a title's background padding reaching past it), a media clip's box is carried back into its media pixels by the map of its crop to its box, and a shape placed by its geometry gives its `area` or the bounding box of its `points` as written. The parent's transform then carries the area with the rest of the child, so a bar parented to its title with `area: {"clip": "<title>"}` fits the title and follows its transform, its animation's motion included.
- `padding` is in the unit of the coordinate space the area is written in, as every area's padding is ([FRAMES-1](../FRAMES-1/SPEC.md)): the box grows by it on every side, once it is in that space. It is the number an `[x, y, w, h]` written there would grow by, output pixels for an unparented clip and the parent's units under a parent, so a bar parented to its title takes padding that scales with the title.
- The box is taken at the instant being evaluated, on the sequence clock, whether or not the named clip is visible then. Outside the named clip's window it holds the box it has at the window's edge, as a parent's transform does ([FRAMES-10](../FRAMES-10/SPEC.md)). A clip area in a keyframe is the named clip's box at each instant of the spans on its sides ([FRAMES-4](../FRAMES-4/SPEC.md)).
- A clip area may stand wherever an area or a point is in the clip's coordinate space: the `area`, `points` and `position` of a connected or sequence clip, and the mask of a shape placed by `area` or `points` or of an adjustment clip. A clip area in a `crop`, a `track` target, or the mask of a media clip, a title, a storyline clip or a shape placed by `width` and `height` stops, since those are in the clip's own media or box.
- A clip whose box depends on itself through clip areas, its own included, stops and names the clips in the cycle: a rect whose area is a title's box, and a title whose `position` is a point of that rect's area.

```json
{ "id": "name", "at": [2, 8], "lane": 2, "title": "Mina Park", "style": "name" },
{ "at": [2, 8], "lane": 1, "shape": "rect", "area": { "clip": "name", "padding": 24 }, "fill": "#101418E6", "radius": 8 },
{ "at": [2.4, 8], "lane": 2, "title": "Head baker", "style": "role",
  "position": { "area": { "clip": "name", "padding": 24 }, "point": "right" }, "anchor": "left" }
```

The bar is the name's box grown by 24 points on every side, so it fits whatever name a template is given, and the role sits at the bar's right edge, growing to the right from it.

### Where text forms are allowed

A text form needs a picture to search. It is allowed only where its coordinate space is the media pixels of a video, an image or an image sequence:

- the `area`, `points` and `position` of a clip, and the `mask` of a shape placed by `area` or `points` or of an adjustment clip (whose mask is in its parent's space, [FRAMES-11](../FRAMES-11/SPEC.md)), when the clip is parented to a storyline clip or media clip whose media is one of those, searched in the parent's media, or to a shape or adjustment clip whose space is that media's pixels (its own parent is such a clip, [FRAMES-10](../FRAMES-10/SPEC.md)), searched in that media;
- the `crop`, `mask` and `track` target of a storyline clip or media clip whose media is one of those, searched in its own media.

A text form in the mask of a title or of a shape placed by `width` and `height` stops, since that mask is in the clip's own box and not in media pixels. A text form anywhere else stops: on an unparented clip, whose coordinates are output pixels; on a clip parented to a title, or to a shape or adjustment clip whose space is output pixels; and on or under a compound clip or a template instance, whose picture is drawn, not read. Text inside a compound clip is named from inside its nested document. Text is recognised only in media files, through the OCR provider ([FRAMES-21](../FRAMES-21/SPEC.md)).

### The search instant

On video and image sequences, the text is searched in the frame at the instant where the area takes effect:

| Area | Instant |
| --- | --- |
| a keyframe's area or point | that keyframe's `at` |
| a static area, point, `crop`, `mask` or `track` area of a connected or sequence clip | the clip's start (a connected clip without `at` starts at its storyline clip's `in`, a sequence clip without `at` at 0) |
| a static `crop`, `mask` or `track` area of a storyline clip | that clip's `in` |

The instant is on the clock of the clip that writes the area ([FRAMES-8](../FRAMES-8/SPEC.md)). It is carried to the clip time of the clip whose media is searched, and turned into that media's media time through that clip's time map: its `timeRemap` when it has one, otherwise clip time is media time ([FRAMES-8](../FRAMES-8/SPEC.md)). So a text area on a picture-in-picture clip's crop searches that clip's own frame, and a title parented to a time-remapped clip searches the frame shown at its start. A clip's `track` finds its target at that instant too ([FRAMES-12](../FRAMES-12/SPEC.md)). An image has one frame, and the instant does not matter.

Text found for a clip parented to a shape or adjustment clip is where it lies in the media at its instant, and the clip's coordinates are in the parent's space, which the parent's transform carries to the media ([FRAMES-10](../FRAMES-10/SPEC.md)). So the found value is brought into the parent's space through the inverse of the parent's transform at that instant, without its animation, as `geometry(clip, t)` gives it: a title placed beside text next to a tracked or keyframed box stays beside it. An area carried back through a rotation or a skew is the axis-aligned rectangle that bounds its four carried corners. A parent whose transform has no inverse at that instant, a scale factor of 0 on an axis, stops, naming the clip and the instant. A value written as numbers is in the parent's space already and is not changed.

### Points

A point is one of these forms, in the same coordinate space as an area.

| Form | Meaning |
| --- | --- |
| `[x, y]` | that point |
| `{"area": <area>, "point": <placement name>}` | that point of the area, padding included: `top-left` its top left corner, `top` the middle of its top edge, `center` its centre, and so on for the nine names of [FRAMES-1](../FRAMES-1/SPEC.md) |

An area inside a point is any area form, with text forms only where they are allowed, and its search instant is that of the point.

### What takes areas and points

| Key | Takes |
| --- | --- |
| a rect or ellipse shape's `area` ([FRAMES-11](../FRAMES-11/SPEC.md)) | an area |
| a path shape's `points` ([FRAMES-11](../FRAMES-11/SPEC.md)) | a list of points |
| a mask's `area`, `points` and `position` ([FRAMES-11](../FRAMES-11/SPEC.md)) | an area, a list of points, a point |
| `crop` ([FRAMES-9](../FRAMES-9/SPEC.md)) | an area, or `{scale}` |
| `position` ([FRAMES-1](../FRAMES-1/SPEC.md)) | a point |
| `track` ([FRAMES-12](../FRAMES-12/SPEC.md)) | an area, or `true` |

## Interactions

Text is found through the OCR provider of [FRAMES-21](../FRAMES-21/SPEC.md), and the resolved document pins what was recognised ([FRAMES-19](../FRAMES-19/SPEC.md)). On a tracked clip the area found is the target of [FRAMES-12](../FRAMES-12/SPEC.md). The clocks and time maps come from [FRAMES-8](../FRAMES-8/SPEC.md). A coordinate space is given by parenting, [FRAMES-10](../FRAMES-10/SPEC.md). Keyframed areas and points interpolate as [FRAMES-4](../FRAMES-4/SPEC.md) says.

## Alternatives considered

Silently taking the first match: two lines with the same text are common in a picture (a word repeated on a sign, a menu item and a heading), and the wrong one looks right. Ambiguity stops.

A bare string as a shorthand text form: one form per meaning keeps a string from reading as a colour, a path or text, and the object form has room for `nth` and `padding`.

Padding from the theme: how far an area reaches past its text or its clip is a choice about that place, not part of a look, so it is written on the area, in the unit of the coordinates the area is written in, as the rest of the area is. A clip area's padding as a theme length would give one key of an area two units.

Text forms on any coordinate space, found by recognising drawn pixels: a resolved value would then depend on a renderer, and providers read media files, never drawn pixels (README). A text form is allowed only where there is a media picture.

A band form, the full width of a picture between two lines: it served one layout. A rectangle written with the picture's full width names the same place, and a pack can write it.

A clip area that takes the named clip's transform, its scale, rotation and animation included: a bar would turn and bounce with its title's entrance and not with its own, and the area would not be a rectangle. The box before its transform is what `sourceRectAtTime` gives, and a bar that should move with its title is parented to it, which a clip area naming the parent allows.

A clip area between two clips with two different parents, carried through each parent: it would mix two parents' motion into one value, and two clips that should share a space share a parent or are parent and child. A parent's box in its own space mixes nothing, since it is the space its child is drawn in.

Text that shrinks to fit a box, as a responsive title template does: a template sets a title's `width` and `lines`, and text that does not fit stops, as any value its place does not take stops in an instance ([FRAMES-17](../FRAMES-17/SPEC.md)), so a template never draws it wrong. A program that must fit text measures it with `evaluate` ([FRAMES-23](../FRAMES-23/SPEC.md)) and writes the size, which builds it outside frames ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Notes
