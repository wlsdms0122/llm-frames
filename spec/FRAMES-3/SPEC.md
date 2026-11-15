# FRAMES-3: Media references

Status: accepted

## Summary

The forms a document names media in (files, pack media, image sequences, nested documents and template instances), and how frames picks a frame of each at a media time.

## Motivation

Every role and provider must read the same frame for the same time, or the text OCR found and the pixels drawn come from different pictures. One rule for media time and frame picking, pinned in the resolved document, makes them agree.

## Rules

| Form | Meaning |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` document, which stands as if written there |
| `"<pack>/<name.ext>"` | a file in a pack's `media/` ([FRAMES-17](../FRAMES-17/SPEC.md)), a `.json` document there included |
| `{"imageSequence": "/abs/dir", "fps": 30}` | a numbered image sequence (the directory may be `<pack>/<dir>`, a folder in a pack's `media/`): every PNG in the directory, in natural order (runs of digits compare as numbers), at that rate. It plays like a video: its media seconds are frame index / fps, and it takes `in`, `out` and `speed` |
| an image or layout document object | the picture that document draws ([FRAMES-6](../FRAMES-6/SPEC.md)) |
| a sequence document object | a compound clip: the nested sequence plays as a video with sound, and its sequence time is its media time |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance ([FRAMES-17](../FRAMES-17/SPEC.md)). The template is `<pack>/<name>` or an absolute path |

- A document with `params` is a template and is used only as a template instance. Anywhere else it stops.
- An image sequence's `fps` is above 0, and 0 or less stops.
- Paths are absolute. Inside a pack, its own files are named by `<pack>/<name>` like any other pack's ([FRAMES-17](../FRAMES-17/SPEC.md)).
- A compound clip is evaluated at the media times the outer frames ask for, not at its own frame rate. Its `size`, `background`, `inset` and `conform` apply. Its `fps` applies only when it is rendered alone. It is part of the document that wrote it, so its theme is merged over the one in effect there. A template instance is not ([FRAMES-17](../FRAMES-17/SPEC.md)).
- Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha) and compound clips. This is how graphics made elsewhere come in.
- At media time s, a video or an image sequence shows the frame whose presentation interval holds s: its timestamp is at or before s, and the next one is after s. OCR, extraction and drawing all pick frames by this rule, and the resolved document pins each such file's frame timestamps, so evaluation picks the frame once and names it by index.
- A compound clip has no frames of its own. It is evaluated at whatever time is asked, clamped into `[0, duration)`.

## Interactions

Templates are [FRAMES-17](../FRAMES-17/SPEC.md). Pinning is [FRAMES-19](../FRAMES-19/SPEC.md). The decoder that reads every file is in [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered


## Notes
