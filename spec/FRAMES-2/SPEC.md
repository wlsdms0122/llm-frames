# FRAMES-2: Areas and points

Status: accepted

## Summary

How a place is named in a clip's coordinate space: an area, as a rectangle or, where there is a media picture to search, as text found by OCR; and a point, as coordinates or a named point of an area. Shapes, masks, crops, positions and tracking all take these same values.

## Motivation

Shape geometry, a mask, a crop, a title's position and a tracker's target all name a place in a picture, and an editor that gave each its own way of naming it would make the same place be written four times. One area and one point form, in the clip's own coordinate space, lets a mask, a shape outline and a title beside it take the same value and stay together when the picture under them moves. Where the picture holds text (a sign in camera footage, a slide, a scoreboard, an app on screen), a place can also be named by that text, so a document survives a new take or a new export without measuring again, and stopping on an ambiguous or missing match keeps a mask from landing on the wrong word unnoticed.

## Rules

### Areas

An area is given in one of these forms, in the coordinate space of the clip that writes it ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md)).

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle: its top left corner at `(x, y)`, `w` wide and `h` tall. `w` and `h` are above 0 |
| `{"text": "...", "nth": n, "padding": p}` | the recognised line that contains the text. With `nth`, the nth line (from 0) among the lines that contain it, counted top to bottom by row and left to right within a row, where lines whose vertical centres lie within half the shorter one's height of each other are one row |
| `{"from": "...", "to": "...", "fromNth": a, "toNth": b, "padding": p}` | the rectangle around the `from` line and the `to` line, each found as the `text` form finds its line (`fromNth` and `toNth` acting as its `nth`), and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |

- `nth`, `fromNth` and `toNth` are optional whole numbers, 0 or more. `padding` is optional, a number 0 or more, and defaults to 0.
- Text is compared with whitespace removed. A line matches when it contains the text.
- A text form without `nth` that matches more than one line stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that matches no line, or an `nth` past the last match, stops, naming the media, the text and the nth.
- A text form's area grows outward on every side by its `padding`, in pixels of the picture searched, once the area is found. A tracker follows the area as found, before padding ([FRAMES-12](../FRAMES-12/SPEC.md)).

### Where text forms are allowed

A text form needs a picture to search. It is allowed only where its coordinate space is the media pixels of a video, an image or an image sequence:

- the `area`, `points`, `position` and `mask` of a clip parented to a storyline clip or media clip whose media is one of those, searched in the parent's media, or to a shape or adjustment clip whose space is that media's pixels (its own parent is such a clip, [FRAMES-10](../FRAMES-10/SPEC.md)), searched in that media;
- the `crop`, `mask` and `track` target of a storyline clip or media clip whose media is one of those, searched in its own media.

A text form anywhere else stops: on an unparented clip, whose coordinates are output pixels; on a clip parented to a title, or to a shape or adjustment clip whose space is output pixels; and on or under a compound clip or a template instance, whose picture is drawn, not read. Text inside a compound clip is named from inside its nested document. Text is recognised only in media files, through the OCR provider ([FRAMES-21](../FRAMES-21/SPEC.md)).

### The search instant

On video and image sequences, the text is searched in the frame at the instant where the area takes effect:

| Area | Instant |
| --- | --- |
| a keyframe's area or point | that keyframe's `at` |
| a static area, point, `crop`, `mask` or `track` area of a connected or sequence clip | the clip's start (a connected clip without `at` starts at its storyline clip's `in`, a sequence clip without `at` at 0) |
| a static `crop`, `mask` or `track` area of a storyline clip | that clip's `in` |

The instant is on the clock of the clip that writes the area ([FRAMES-8](../FRAMES-8/SPEC.md)). It is carried to the clip time of the clip whose media is searched, and turned into that media's media time through that clip's time map: its `timeRemap` when it has one, otherwise clip time is media time ([FRAMES-8](../FRAMES-8/SPEC.md)). So a text area on a picture-in-picture clip's crop searches that clip's own frame, and a title parented to a time-remapped clip searches the frame shown at its start. A clip's `track` finds its target at that instant too ([FRAMES-12](../FRAMES-12/SPEC.md)). An image has one frame, and the instant does not matter.

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

Padding from the theme: how far an area reaches past its text is a choice about that place in that picture, not part of a look, so it is written on the area, in the pixels of the picture searched.

Text forms on any coordinate space, found by recognising drawn pixels: a resolved value would then depend on a renderer, and providers read media files, never drawn pixels (README). A text form is allowed only where there is a media picture.

A band form, the full width of a picture between two lines: it served one layout. A rectangle written with the picture's full width names the same place, and a pack can write it.

## Notes
