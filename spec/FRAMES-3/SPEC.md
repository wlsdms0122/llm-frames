# FRAMES-3: Media references

Status: accepted

## Summary

The forms a document names media in (files, pack media, image sequences, nested sequences as compound clips, and template instances), and how frames picks a frame of each at a media time.

## Motivation

Every role and provider must read the same frame for the same time, or a mask tracked on one frame, the text recognised on another and the picture drawn from a third would not line up. One rule for media time and frame picking, pinned in the resolved document, makes them agree. A rendered result is also media for the next edit, and a sequence can stand where a file does as a compound clip, as a nested sequence does in an NLE, so a piece is built once and used in many places.

## Rules

| Form | Meaning |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` sequence document, which stands as if written there |
| `"<pack>/<name.ext>"` | a file in a pack's `media/` ([FRAMES-17](../FRAMES-17/SPEC.md)), a `.json` sequence document there included |
| `{"imageSequence": "/abs/dir", "fps": 30}` | a numbered image sequence (the directory may be `<pack>/<dir>`, a folder in a pack's `media/`): every PNG in the directory, in natural order (runs of digits compare as numbers), at that rate. It plays like a video: its media seconds are frame index / fps, and it takes `in`, `out`, `speed` and `timeRemap` |
| a sequence document object ([FRAMES-6](../FRAMES-6/SPEC.md)) | a compound clip: the nested sequence plays as a video with sound, and its sequence time is its media time |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance ([FRAMES-17](../FRAMES-17/SPEC.md)). The template is `<pack>/<name>` or an absolute path |

- A `.json` file or a document object whose `kind` is not `"sequence"` stops ([FRAMES-6](../FRAMES-6/SPEC.md)).
- A document with `params` is a template and is used only as a template instance. Anywhere else it stops.
- A document or template that holds itself, directly or through the documents and templates it names, stops, since it would never end.
- An image sequence's `fps` is above 0, and 0 or less stops.
- Paths are absolute. Inside a pack, its own files are named by `<pack>/<name>` like any other pack's ([FRAMES-17](../FRAMES-17/SPEC.md)).
- A compound clip is evaluated at the media times the outer frames ask for, not at its own frame rate. Its `format` `size`, `background`, `conform` and `compositing` apply, so its picture is its own frame, at its own size, with its own background, its clips composited in its own form. Its `fps`, `colorSpace`, `peak` and `motionBlur` apply only when it is rendered alone ([FRAMES-26](../FRAMES-26/SPEC.md), [FRAMES-29](../FRAMES-29/SPEC.md)). It is part of the document that wrote it, so its theme is merged over the one in effect there. A template instance is not ([FRAMES-17](../FRAMES-17/SPEC.md)).
- A compound clip is evaluated at one media time for each output frame, the one the frame's instant maps to, so its picture is held over the frame's exposure. Its clips with motion blur take the outermost sequence's exposure mapped into its media time through its clip's time map ([FRAMES-29](../FRAMES-29/SPEC.md)).
- A compound clip's duration is the length of its nested sequence ([FRAMES-8](../FRAMES-8/SPEC.md)).
- Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha) and compound clips. This is how graphics made elsewhere come in, and how a compound clip whose background is transparent sits over what is below it.
- At media time s, a video or an image sequence shows the frame whose presentation interval holds s: its timestamp is at or before s, and the next one is after s. OCR, tracking, extraction and drawing all pick frames by this rule, and the resolved document pins each such file's frame timestamps, so evaluation picks the frame once and names it by index. Times are measured to the microsecond: a media time and a timestamp are compared rounded to the nearest microsecond, so floating point noise in a computed media time picks no earlier frame.
- A compound clip has no frames of its own. It is evaluated at whatever time is asked, clamped into `[0, duration)`.

## Interactions

A sequence document is [FRAMES-6](../FRAMES-6/SPEC.md), and its format is [FRAMES-9](../FRAMES-9/SPEC.md). Media time through a clip's time map, `timeRemap` included, is [FRAMES-8](../FRAMES-8/SPEC.md). Templates are [FRAMES-17](../FRAMES-17/SPEC.md). Pinning is [FRAMES-19](../FRAMES-19/SPEC.md). The decoder that reads every file is in [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered

Showing the frame nearest to s: it shows a frame before its time half the time, and the frame on screen at a time in an NLE is the one whose interval holds it.

Evaluating a compound clip at its own frame rate: under an outer sequence at another rate its frames would repeat or skip, and its motion would not match a clip beside it. Evaluating it at the outer times keeps motion smooth, as an NLE renders a nested sequence at the rate of the sequence it plays in.

A picture document kind (an op list on an image, a grid of images) usable as media: it would be a second model for what a sequence already does. A still is a sequence rendered as one frame ([FRAMES-6](../FRAMES-6/SPEC.md)), and as media it is a compound clip.

## Notes
