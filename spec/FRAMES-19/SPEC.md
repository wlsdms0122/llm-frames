# FRAMES-19: The resolved document

Status: accepted

## Summary

The resolved document, frames' own lockfile: what resolve has already done, its shape, and the rules for reading it.

## Motivation

An edit opened on another machine, or on the same machine a month later, should come out the same. In an NLE it often does not: a font is missing or a different version and titles reflow, a pack or a LUT has changed, a tracker run again lands a little elsewhere, a template's defaults moved. What can differ between machines and over time (installed fonts and packs, what a provider recognised or followed, theme and preset values, template arguments) must be fixed once, or a result cannot be made again. Writing every such decision out as values, with every file the roles still open pinned by hash, makes the resolved document enough to make the result again, and gives evaluation one input with nothing left to look up.

## Rules

The resolved document is frames' own lockfile: what `resolve` writes, and what evaluation and `render` read. It is not an exchange format, and frames reads only what resolve wrote. It is JSON with `"kind": "sequence"`, the one document kind ([FRAMES-6](../FRAMES-6/SPEC.md)), and `"resolved"` set to the version of the frames that wrote it ([FRAMES-18](../FRAMES-18/SPEC.md)).

What resolve has already done:

- **Keys are checked.** A resolved document carries only the keys below.
- **No text areas.** Every area is `[x, y, w, h]` and every point `[x, y]`, the padding of a text form already added ([FRAMES-2](../FRAMES-2/SPEC.md)). Each stays in the coordinate space of the clip that wrote it ([FRAMES-10](../FRAMES-10/SPEC.md)): a crop in the media pixels of its media, a parented clip's `position`, geometry and masks in the space its parent gives, and an unparented clip's in output pixels.
- **Files are pinned.** Every file a role opens (media, mattes, LUTs, fonts) is written as its absolute path and its SHA-256. An image sequence is pinned as its ordered list of files, each with its SHA-256, so a frame added, removed or changed is refused. `render` checks every hash before any role starts and refuses a file whose hash differs.
- **Decisions are written down.** Conformed crops, the measured size of a content-fit frame ([FRAMES-6](../FRAMES-6/SPEC.md)), parents, track mattes and tracks are values, not rules to apply again. A track is the target's quadrilateral on each frame followed and the similarity motion fitted to it ([FRAMES-12](../FRAMES-12/SPEC.md)).
- **Parents are named.** A clip's `parent` is the `id` of its parent clip in the same document, or `null`. Resolve has checked it: it names a clip with a picture in the same document, and no parent chain holds a cycle ([FRAMES-10](../FRAMES-10/SPEC.md)).
- **Anchor points are applied.** A clip with a box of its own (a title, a media clip, a storyline picture, a rect or ellipse placed by `width` and `height`) writes `size`, its box in output pixels, `anchor`, the point its scale and rotation act around in the box's own pixels (origin at the box's top left), and `position`, where that point goes in the clip's coordinate space. A clip placed by `placement` is written with the `position` its placement gives. A storyline picture's box is the one [FRAMES-9](../FRAMES-9/SPEC.md) gives (the frame, or under content fit its crop's pixel size), which its conformed crop fills. A shape placed by `area` or `points` and an adjustment have no box: their `size` and `anchor` are `null`, their scale and rotation act around the centre of their geometry's box at each time ([FRAMES-1](../FRAMES-1/SPEC.md)), and `position` is `null` unless the clip writes one, and then it is where that centre goes.
- **Clips are named.** Every clip keeps its place in the document and its `id`, so `evaluate` and `locate` can name what made each thing drawn.
- **No names.** Theme colours, text styles, shape styles, presets and template arguments are written out as values, and so are the theme colours a preset names (a cover or a bloom `color`) in the theme where the preset is chosen. A preset is written with its arguments applied ([FRAMES-14](../FRAMES-14/SPEC.md)): it holds plain values, and no `params` and no `{"param"}` remain. Theme lengths are already multiplied by their length scale ([FRAMES-1](../FRAMES-1/SPEC.md)). Colours are `#RRGGBBAA`.
- **Text is shaped.** Every title carries its box size, its background and its runs in order. A run carries its font file, face, hash, size, colour, stroke (`{width, color}` or `null`) and its glyph ids and positions in the title's box. A title written as a string is one run in the clip's style, and a run's character attributes come from its own style ([FRAMES-11](../FRAMES-11/SPEC.md)).
- **Masks and mattes are geometry and ids.** A clip's `mask` is `null` or a keyframe list whose values are lists of masks in order, each `{geometry, feather, invert, mode}`: `geometry` in one of the forms of the display list ([FRAMES-20](../FRAMES-20/SPEC.md)) in the clip's own coordinate space (the media pixels of its media for a picture, the space its geometry is in for any other clip), a path mask a closed `polyline`, and `feather` in output pixels. A mask given by `width`, `height` and `position` is written as its `rect`. A clip's `trackMatte` is `null` or `{clip, mode, invert}`, `clip` the `id` of the matte clip. The matte clip keeps its own entry, and evaluation draws it only as a matte.
- **One clock.** Every instant on a sequence is sequence time, and keyframes keep their eases, a spring as `{"spring": {"bounce": b}}` with `b` a number ([FRAMES-4](../FRAMES-4/SPEC.md)). A clip's `in` and `out` stay on its clip time and its `speed` as written ([FRAMES-8](../FRAMES-8/SPEC.md)). A clip with `timeRemap` carries it as a keyframe list in sequence time whose values are media seconds, and its `speed` is 1. A clip without one has `timeRemap` `null`, and its clip time is its media time.
- **Lanes kept.** Clips keep document order and carry their signed `lane`, so evaluation stacks them by [FRAMES-9](../FRAMES-9/SPEC.md). A storyline transition keeps its `over`, which evaluation applies at each time.

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
  "format": { "size": [1920, 1080], "fps": 25, "duration": 9, "background": "#000000FF", "conform": "fill" },
  "storyline": [
    { "id": "interview", "media": { "file": "/abs/interview.mov", "sha256": "9f2c41d07b3e", "frames": [0, 0.04, 0.08] },
      "in": 12, "out": 18, "speed": 1, "timeRemap": null, "start": 0, "end": 6,
      "size": [1920, 1080], "anchor": [960, 540],
      "position": [ { "at": 0, "value": [960, 540], "ease": "linear" } ],
      "scale": [ { "at": 0, "value": 1, "ease": "ease-in-out" }, { "at": 6, "value": 1.08, "ease": "linear" } ],
      "crop": [ { "at": 0, "value": [0, 0, 3840, 2160], "ease": "linear" } ],
      "filter": [ { "op": "saturation", "amount": 1.1 } ],
      "mask": null, "trackMatte": null, "track": null, "transition": null },
    { "id": "surf", "media": { "file": "/abs/broll-surf.mov", "sha256": "2b7e05aa31c9", "frames": [0, 0.02, 0.04] },
      "in": 0, "out": 3, "speed": 1, "start": 6, "end": 9,
      "timeRemap": [ { "at": 6, "value": 4, "ease": "linear" }, { "at": 7, "value": 4, "ease": "ease-in" }, { "at": 9, "value": 6.5, "ease": "linear" } ],
      "transition": { "start": 5.75, "end": 6.25, "over": "incoming", "audio": "constant-power",
                      "incoming": { "ease": "ease-in-out", "keys": [ { "t": 0, "opacity": 0 }, { "t": 1, "opacity": 1 } ] },
                      "outgoing": null, "cover": null, "matte": null } }
  ],
  "clips": [
    { "id": "bar", "shape": "rect", "start": 1, "end": 5, "lane": 1, "storyline": 0, "parent": null,
      "area": [ { "at": 1, "value": [96, 840, 720, 120], "ease": "linear" } ], "width": null, "height": null, "points": null, "closed": null,
      "radius": [ { "at": 1, "value": 12, "ease": "linear" } ],
      "fill": "#1B3A6BE6", "stroke": null, "shadow": null,
      "trim": [ { "at": 1, "value": [0, 1], "ease": "linear" } ],
      "size": null, "anchor": null, "position": null, "blend": "normal", "mask": null, "trackMatte": null,
      "animation": { "entrance": { "seconds": 0.4, "ease": { "spring": { "bounce": 0.2 } }, "revealFrom": "left",
                                   "keys": [ { "t": 0, "reveal": 0 }, { "t": 1, "reveal": 1 } ] } } },
    { "id": "name", "start": 1.2, "end": 5, "lane": 2, "storyline": 0, "parent": "bar",
      "title": { "size": [512.4, 62.5], "background": null,
                 "runs": [
                   { "font": "/System/Library/Fonts/HelveticaNeue.ttc", "sha256": "41aa0c9e5d17", "face": "HelveticaNeue-Bold", "size": 48, "color": "#FFFFFFFF", "stroke": null,
                     "glyphs": [ [43, 0, 46.1], [72, 31.2, 46.1] ] },
                   { "font": "/System/Library/Fonts/HelveticaNeue.ttc", "sha256": "41aa0c9e5d17", "face": "HelveticaNeue", "size": 36, "color": "#C9D6EAFF", "stroke": null,
                     "glyphs": [ [3, 268.5, 46.1] ] } ] },
      "size": [512.4, 62.5], "anchor": [0, 31.25],
      "position": [ { "at": 1.2, "value": [128, 900], "ease": "linear" } ], "blend": "normal", "mask": null, "trackMatte": null },
    { "id": "logo", "media": { "file": "/abs/logo.png", "sha256": "77d01c3e9ab4" }, "start": 0, "end": 9, "lane": 3, "storyline": null, "parent": null,
      "size": [160, 160], "anchor": [80, 80], "position": [ { "at": 0, "value": [1744, 176], "ease": "linear" } ],
      "crop": [ { "at": 0, "value": [0, 0, 512, 512], "ease": "linear" } ], "conform": "fit",
      "mask": [ { "at": 0,
                  "value": [ { "geometry": { "ellipse": { "rect": [16, 16, 480, 480] } }, "feather": 6, "invert": false, "mode": "add" } ],
                  "ease": "linear" } ],
      "trackMatte": null, "blend": "normal", "radius": 0, "border": null, "shadow": null }
  ],
  "audio": [
    { "media": { "file": "/abs/score.m4a", "sha256": "c07d9a1e44f2" }, "in": 0, "out": 184.2, "speed": 1, "start": 0, "origin": 0, "end": 9, "loop": false,
      "volume": [ { "at": 0, "value": 0.4, "ease": "linear" }, { "at": 8, "value": 0.4, "ease": "linear" }, { "at": 9, "value": 0, "ease": "linear" } ],
      "pan": [ { "at": 0, "value": -0.2, "ease": "linear" } ] }
  ]
}
```

- The example is laid out to be read and keeps only the keys it explains. Hashes in the example are cut short. A glyph is `[glyph id, x, y]`, its origin in the title's box, and the example's glyph lists are cut short too.
- `format.size` is the frame size, the measured one for a content-fit frame ([FRAMES-6](../FRAMES-6/SPEC.md)). `format.duration` is the sequence end.
- A video or image sequence keeps its frame timestamps in `frames` (cut short in the example).
- A storyline entry has `id`, `media`, `in`, `out`, `speed`, `timeRemap`, `start`, `end`, its box (`size`, `anchor`, `position`), its keyframable properties (`crop` as conformed crops, `position`, `scale`, `rotation`, `opacity`) as keyframe lists in sequence time, its `blend`, `mask`, `trackMatte` and `track`, its filter as an op list, and `transition` as `null` or `{start, end, over, audio, incoming, outgoing, cover, matte}` with spans and files inline. A cover or matte that shows media carries it pinned, a video with its `frames`, and its `duration` in media seconds (0 for a still), so evaluation shows media time p × `duration` at progress p ([FRAMES-14](../FRAMES-14/SPEC.md)) without opening the file.
- A solid storyline entry carries its colour as `solid`, and `media` is `null`.
- A clips entry is a title, a shape, an adjustment or a media clip with its visible window `start` and `end` already narrowed by [FRAMES-8](../FRAMES-8/SPEC.md) and [FRAMES-12](../FRAMES-12/SPEC.md), its keyframable properties as keyframe lists in sequence time, its animation spans inline, its `blend`, `lane`, `storyline` (the index of the storyline entry it is connected to, or `null` for a sequence clip), `parent`, `mask`, `trackMatte` and `track`.
- A media clip also carries `conform`, `radius`, `border` (`{width, color}` or `null`), `shadow` (`{radius, offset, color}` or `null`), its filter as an op list, and its `crop` as every crop conformed to its box by `conform`, the whole picture when none is written. A timed media clip also carries `in`, `origin`, `out`, `speed`, `loop` and `timeRemap`: it plays from clip time `in` at sequence time `origin`, the start of its window, which lies before `start` where tracking narrowed it. A connected or sequence media clip with `timeRemap` writes `in`, `out` and `loop` as `null`, since its keys give the media time at every instant of its window ([FRAMES-8](../FRAMES-8/SPEC.md)), and its `timeRemap` keys are in sequence time like its other keyframes.
- A shape entry carries `shape` (`rect`, `ellipse` or `path`) and its geometry, each a keyframe list or `null`: `area` for a rect or ellipse placed by its area, `width` and `height` for one placed by its box, `points` and `closed` for a path. Its geometry is already grown by `outset`. It carries `radius` and `trim` as keyframe lists, `fill` as a colour or `null`, `stroke` as `{color, width, join, cap, start, end}` or `null` and `shadow` as `{radius, offset, color}` or `null`, its shape style applied and its lengths in output pixels ([FRAMES-11](../FRAMES-11/SPEC.md)).
- An adjustment entry carries `adjust`, its filter as an op list, and its `mask`, which is where it applies.
- A clip's or a storyline entry's `track` is `null` or `{media, time, target, frames}`: the pinned media it follows (its own, or its parent's), the target's quadrilateral as found on the frame at media time `time`, before padding, and every frame followed as `{time, quad, motion}` in media time. A quadrilateral is four points `[[x, y], [x, y], [x, y], [x, y]]` in media pixels, top left, top right, bottom right and bottom left as the target faces on the frame it was found. `motion` is the similarity fitted from the target to that frame's quadrilateral ([FRAMES-12](../FRAMES-12/SPEC.md)), as an affine matrix `[a, b, c, d, tx, ty]` in media pixels, in the form of the display list's `transform` ([FRAMES-20](../FRAMES-20/SPEC.md)).
- An audio entry is a source of sound, storyline clips included, with its `volume` and `pan` keyframes in sequence time, its fades and its transitions. Evaluation multiplies them into the mix plan. It plays from clip time `in` at sequence time `origin`. A clip with `timeRemap` plays no sound, so it has no audio entry ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A compound clip or a sequence template instance carries its nested resolved sequence in place of a media file. Its `size`, `background` and `conform` apply ([FRAMES-3](../FRAMES-3/SPEC.md)).

### Reading a resolved document

- Resolve is deterministic for the same document, arguments, media, theme, presets, packs, fonts, recognised text and tracks.
- Evaluating and rendering a resolved document needs its pinned files and nothing else. It names no role: the command that renders it picks them ([FRAMES-21](../FRAMES-21/SPEC.md)), and the same result is promised for the same ones.
- A frames reads a resolved document written by a frames of its own major version at its minor version or an earlier one, and refuses any other, naming both versions. Made again by the version that wrote it, a resolved document gives the same result. A later version gives the same result too, except where a patch brought evaluation or a role back to this specification.
- Display lists and the mix plan have a JSON form too, with `"displayList"` and `"mixPlan"` set to the version of the frames that wrote them, so what evaluation gives a role can be checked, recorded and replayed apart from it. They are read by the same rule as a resolved document.
- Evaluation and `render` trust a resolved document as they trust resolve. They check its version, and `render` its hashes, not its rules again. Evaluation opens no file.

## Interactions

Its version is [FRAMES-18](../FRAMES-18/SPEC.md). Evaluation reads it ([FRAMES-20](../FRAMES-20/SPEC.md)). Every document-taking command takes it ([FRAMES-23](../FRAMES-23/SPEC.md)). The values it fixes come from [FRAMES-2](../FRAMES-2/SPEC.md) (areas and points), [FRAMES-6](../FRAMES-6/SPEC.md) (content fit), [FRAMES-8](../FRAMES-8/SPEC.md) (time and `timeRemap`), [FRAMES-10](../FRAMES-10/SPEC.md) (parents), [FRAMES-11](../FRAMES-11/SPEC.md) (shapes, runs, masks and track mattes), [FRAMES-12](../FRAMES-12/SPEC.md) (tracks) and [FRAMES-14](../FRAMES-14/SPEC.md) (preset arguments).

## Alternatives considered

An exchange format (FCPXML, OpenTimelineIO, an EDL): those carry an edit between tools and leave out what frames must fix to make a result again, such as shaped glyphs, recognised text, fitted tracks and pinned hashes. frames reads only what resolve wrote, so its form can follow frames.

A project file that keeps names and is resolved again on every render, as an NLE project relinks media and lays out titles with the fonts it finds: the result would change with the machine's fonts, packs, providers and theme, and the principle of a result reproducible from one file would not hold.

Writing only the tracker's quadrilaterals and fitting the motion in evaluation: the fit is a decision like any other, and writing it leaves evaluation with arithmetic only.

## Notes
