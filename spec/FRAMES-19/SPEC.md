# FRAMES-19: The resolved document

Status: accepted

## Summary

The resolved document, frames' own lockfile: what resolve has already done, its shape for sequences, images and layouts, and the rules for reading it.

## Motivation

What can differ between machines (recognised text, tracks, text layout, installed packs) must be fixed once, or a result cannot be made again. Writing it out as values, with every file pinned by hash, makes the resolved document enough.

## Rules

The resolved document is frames' own lockfile: what `resolve` writes, and what evaluation and `render` read. It is not an exchange format, and frames reads only what resolve wrote. It is JSON of the same kind as its document, with `"resolved"` set to the version of the frames that wrote it ([FRAMES-18](../FRAMES-18/SPEC.md)).

What resolve has already done:

- **Keys are checked.** A resolved document carries only the keys below.
- **No text areas.** Every area is `[x, y, w, h]`. A storyline crop and a parented area or position stay in the media pixels of their picture. Every other area on a sequence is in output pixels.
- **Files are pinned.** Every file a role opens (media, mattes, LUTs, fonts) is written as its absolute path and its SHA-256. An image sequence is pinned as its ordered list of files, each with its SHA-256, so a frame added, removed or changed is refused. `render` checks every hash before any role starts and refuses a file whose hash differs.
- **Decisions are written down.** Label sides, conformed crops and tracks (the target's rectangle on each frame followed) are values, not rules to apply again.
- **Anchor points are applied.** A `position` is written as the top left of the clip's box, and the anchor point that scale and rotation act around as `anchor`, a point in the box's own pixels. A title or media clip carries its box's `size` in output pixels, and a clip placed by `placement` is written with the `position` its placement gives. A parented clip's `position` stays in the media pixels of its picture as its anchor point less `anchor`, so its anchor point there is `position + anchor`, and its box keeps its size in output pixels around that point. A shape or adjustment is placed by its area and has no box of its own, so its `size`, `position` and `anchor` are `null`.
- **Clips are named.** Every clip keeps its place in the document and its `id`, so `evaluate` and `locate` can name what made each thing drawn.
- **No names.** Theme colours, styles, presets and template arguments are written out as values, and so are the theme colours a preset names (a cover or a bloom `color`) in the theme where the preset is chosen. Theme lengths are already multiplied by their length scale. Colours are `#RRGGBBAA`.
- **Text is shaped.** Every title and label carries its glyph runs (font file, face, hash, size, colour, glyph ids and positions in its own box), its box size, stroke and background.
- **One clock.** Every instant on a sequence is sequence time, and keyframes keep their eases. Media keeps `in`, `out` and `speed` in media time.
- **Lanes kept.** Clips keep document order and carry their signed `lane`, so evaluation stacks them by [FRAMES-9](../FRAMES-9/SPEC.md). The order of units during a transition (`over`) is applied at each time.

How it is written, so the same plan gives the same bytes:

- **One layout.** It is UTF-8 JSON indented by two spaces, one member or element to a line, except that a list of numbers, strings, booleans or `null` stays on one line, and it ends with a line break. Keys come in one fixed order for each kind of object, `kind` and `"resolved"` first, never sorted.
- **One number form.** A number is the shortest decimal that reads back to the same 64-bit floating point value, with no exponent, no fraction when it is whole (`1080`, not `1080.0`), and `0` for negative zero. A string escapes `"`, `\` and control characters only, and writes every other character as itself.
- **Hashes.** A SHA-256 is 64 lower case hexadecimal digits under `sha256`, next to the absolute `file` it pins. An image sequence is `imageSequence`, its frame files in order, each `{file, sha256}`.
- **Keyframe lists.** A keyframable property is a list of `{at, value, ease}` in time order, where `ease` shapes the span that starts at its keyframe. A property written without keyframes is one keyframe at the instant its areas take effect, and one not written is its plain value there.
- **Every key written.** An entry carries every key of its kind, `null` where it has none. Only the outermost document carries `"resolved"`, and a nested one is the same shape without it. Track frames are frames of media, so they keep media time, as `frames` does. An audio clip is drawn by nothing, so it is an audio entry only.

### Resolved sequence

```json
{
  "kind": "sequence", "resolved": "1.0.0",
  "format": { "size": [1080, 1920], "fps": 30, "duration": 13.95, "background": "#000000FF",
              "content": [40, 420, 1000, 1380], "conform": "fit" },
  "storyline": [
    { "media": { "file": "/abs/run.mp4", "sha256": "9f2c41d07b3e", "frames": [0, 0.0333, 0.0667] }, "in": 2, "out": 8, "speed": 2, "start": 0, "end": 3,
      "crop": [ { "at": 0, "value": [0, 0, 1206, 2622], "ease": "linear" }, { "at": 3, "value": [45, 97, 1116, 2428], "ease": "linear" } ],
      "filter": [ { "op": "saturation", "amount": 1.25 } ],
      "transition": null }
  ],
  "clips": [
    { "title": { "size": [929.1, 68.2], "background": { "color": "#000000B8", "radius": 14.2 }, "stroke": null,
                 "runs": [
                   { "font": "/System/Library/Fonts/AppleSDGothicNeo.ttc", "sha256": "41aa0c9e5d17", "face": "AppleSDGothicNeo-Bold", "size": 51.4, "color": "#FFD43BFF",
                     "glyphs": [ [1043, 21.4, 52.0], [2210, 70.9, 52.0] ] },
                   { "font": "/System/Library/Fonts/AppleSDGothicNeo.ttc", "sha256": "41aa0c9e5d17", "face": "AppleSDGothicNeo-Bold", "size": 51.4, "color": "#FFFFFFFF",
                     "glyphs": [ [3, 288.1, 52.0] ] } ] },
      "start": 0, "end": 3, "position": [75.4, 1709.8], "blend": "normal",
      "animation": { "entrance": { "seconds": 0.35, "ease": "back-out", "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1, "opacity": 1 } ] } },
      "storyline": null, "parented": false }
  ],
  "audio": [
    { "media": { "file": "/abs/bgm.m4a", "sha256": "c07d9a1e44f2" }, "in": 0, "out": 92.1, "speed": 1, "start": 0, "end": 13.95, "loop": true,
      "volume": [ { "at": 0, "value": 0.3 }, { "at": 12.95, "value": 0.3 }, { "at": 13.95, "value": 0 } ] }
  ]
}
```

- `format.content` is the content rect. `format.duration` is the sequence end.
- A storyline entry has `start`, `end`, its keyframable properties as sequence-time keyframe lists, its filter as an op list, and `transition` as `null` or `{start, end, over, incoming, outgoing, cover, matte}` with spans and files inline. A cover or matte that shows media carries it pinned, a video with its `frames`, and its `duration` in media seconds (0 for a still), so evaluation shows media time p × `duration` at progress p ([FRAMES-14](../FRAMES-14/SPEC.md)) without opening the file.
- The example is laid out to be read and keeps only the keys it explains. Hashes in the example are cut short. A glyph is `[glyph id, x, y]`, its origin in the title's box, and the example's glyph lists are cut short too.
- A video or image sequence keeps its frame timestamps in `frames` (cut short in the example).
- A clips entry is a title, a shape, an adjustment or a media clip with its visible window `start` and `end` already narrowed by [FRAMES-8](../FRAMES-8/SPEC.md), its properties as keyframe lists in sequence time, its animation spans inline, its `blend`, its `lane`, `storyline` (the index of the storyline entry it is connected to, or `null` for a sequence clip) and `parented` (whether it is composited with that entry's picture). A media clip also carries `conform`, `radius`, `border` (`{width, color}` or `null`) and `shadow` (`{radius, offset, color}` or `null`), and its `crop` as every crop conformed to its box by `conform`, the whole picture when none is written. A timed media clip also carries `in`, `origin`, `out`, `speed` and `loop`: it plays from media time `in` at sequence time `origin`, the start of its window, which lies before `start` where tracking narrowed it. A shape's `label` is `null` or `{side, at, text, animation}`: the side it goes on, the sequence time that side was chosen at, its shaped text, and its own animation spans in the same shape as a clip's `animation`, combined on top of the shape's over the shape's visible window. A clip's or a storyline entry's `track` is `null` or `{target, time, band, frames}`: the target's rectangle before padding on the frame at media time `time`, whether the tracked area is a band, which keeps the full width of its picture and takes only the vertical part of the motion ([FRAMES-12](../FRAMES-12/SPEC.md)), and the target's rectangle on every frame followed as `{time, value}` in media time.
- A shape entry carries `shape` and how it is drawn on its `area`, its theme lengths scaled into output pixels, which stay so under a zoom: a box its stroke `width`, corner `radius` and `color`, a fill or a dim its `color`, and an arrow its `side`, `length`, line `width`, `head` and `color`. An arrow's tip is the middle of that side of its area at each time, and its tail lies `length` beyond it, so the arrow follows the area's keyframes and track as the area does.
- A solid storyline entry carries its colour as `solid`, and `media` is `null`.
- An audio entry is a source of sound, storyline clips included, with its volume keyframes in sequence time, its fades and its transitions. Evaluation multiplies them into the mix plan. It plays from media time `in` at sequence time `origin`.
- A compound clip or a sequence template instance carries its nested resolved sequence in place of a media file.

### Resolved image and layout

An image document and a layout resolve to their final size and one list of drawing steps: the source picture with its crop and scale, pads as fills, shapes, adjustments over what is below them inside their areas, shaped text and borders, each clipped to its canvas, in operation order and in output pixels. Evaluating them at any time gives the same display list.

### Reading a resolved document

- Resolve is deterministic for the same document, arguments, media, theme, presets, packs, fonts, recognised text and tracks.
- Evaluating and rendering a resolved document needs its pinned files and nothing else. It names no role: the command that renders it picks them ([FRAMES-21](../FRAMES-21/SPEC.md)), and the same result is promised for the same ones.
- A frames reads a resolved document written by a frames of its own major version at its minor version or an earlier one, and refuses any other, naming both versions. Made again by the version that wrote it, a resolved document gives the same result. A later version gives the same result too, except where a patch brought evaluation or a role back to this specification.
- Display lists and the mix plan have a JSON form too, with `"displayList"` and `"mixPlan"` set to the version of the frames that wrote them, so what evaluation gives a role can be checked, recorded and replayed apart from it. They are read by the same rule as a resolved document.
- Evaluation and `render` trust a resolved document as they trust resolve. They check its version, and `render` its hashes, not its rules again. Evaluation opens no file.

## Interactions

Its version is [FRAMES-18](../FRAMES-18/SPEC.md). Evaluation reads it ([FRAMES-20](../FRAMES-20/SPEC.md)). Every document-taking command takes it ([FRAMES-23](../FRAMES-23/SPEC.md)).

## Alternatives considered

An exchange format: frames reads only what resolve wrote, so its form can follow frames.

## Notes
