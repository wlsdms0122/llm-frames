# FRAMES-2: Areas

Status: draft

## Summary

How a place in a picture is named: a rectangle, or text found by OCR in one of the finding forms, grown by the theme's padding, at the instant it takes effect.

## Motivation

Places measured by hand break whenever the recording changes. Naming them by the text on screen lets a document survive a new take, and stopping on an ambiguous or missing match keeps a box from landing on the wrong line without a word.

## Rules

A place in a picture is given in one of these forms. Coordinates are media pixels.

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `"text"` | the whole recognised line that contains the text. A text area names a line by part of its text, and the area is the line |
| `{"text": "...", "nth": 1}` | the nth line (from 0) among the lines that contain the text, counted top to bottom by row and left to right within a row, where lines whose vertical centres lie within half the shorter one's height of each other are one row |
| `{"from": "...", "to": "...", "fromNth": 0, "toNth": 0}` | the rectangle around both lines and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |
| `{"band": <area>}` | the full width of the picture, between the top and bottom of the inner area, which is one of the forms above |

- Text is compared with whitespace removed. A line matches when it contains the text.
- A text form without `nth` that matches more than one line stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that matches no line stops, naming the media, the text and the nth.
- An area found by text grows outward by the theme `area.padding`, or by `area.cropPadding` when it is a crop. Padding is added once the area is found and before a band widens it. A tracker follows the area before padding ([FRAMES-12](../FRAMES-12/SPEC.md)). Both paddings are lengths in the picture the area is in: their points are multiplied by that picture's width over `baseWidth`, giving media pixels, so padding is fixed in the picture and grows with it under a zoom like the text it surrounds.
- On video, the text is searched in the frame at the instant where the area takes effect: a connected clip's start (its storyline clip's `in` when it has no `at`), a keyframe's time, or a storyline clip's `in` for a static crop. A clip's `track` finds its target at that instant too ([FRAMES-12](../FRAMES-12/SPEC.md)). The instant is turned into the media time of the clip that owns the area through that clip's time map (its `in` and `speed`), so a text area on a picture-in-picture clip's crop searches that clip's own frame. An image document's `time` picks its frame.
- Text is only recognised in media files. On an image document used as a source, a text area finds the text in that document's `source` and follows its operations to where that text ended up. A compound clip takes no text area from outside, since its picture is drawn, not read. Text inside it is pointed at from the nested document.

## Interactions

Text is found through the OCR provider of [FRAMES-21](../FRAMES-21/SPEC.md). On a tracked clip the area found is the target of [FRAMES-12](../FRAMES-12/SPEC.md). The instant comes from [FRAMES-8](../FRAMES-8/SPEC.md).

## Alternatives considered

Silently taking the first match: two lines with the same text are common on a screen, and the wrong one looks right.

## Notes
