# FRAMES-7: The sequence document and its keys

Status: accepted

## Summary

The shape of a sequence document and the closed key table of every object in it, with the keyframable properties and what `id` and `metadata` are for.

## Motivation

Editing is iterative: a document is changed, checked with `still`, `sheet` and `timeline`, and changed again many times before it is rendered. A misspelt key that renders as no effect is the costliest mistake in that loop, since a check shows a picture that looks plausible and nothing says a key was ignored. Fixing every object's keys lets frames stop at the place of the typo. `id` gives a clip a name that does not move when clips are added, which `parent` and `trackMatte` refer to and the programs outside frames keep, and `metadata` gives those programs a place for what frames does not read.

## Rules

### Shape

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080], "fps": 25, "conform": "fill" },
  "theme": {
    "styles": { "name": { "size": 54, "weight": "bold", "placement": "bottom-left" }, "role": { "size": 34, "color": "#F2B33D" } },
    "defaults": { "transition": { "preset": "frames/fade", "seconds": 0.5 } }
  },
  "storyline": [
    { "id": "interview", "kind": "media", "media": "/abs/cam-a/interview.mov", "in": 12, "out": 21.5,
      "filter": { "kind": "preset", "preset": "studio/grade", "args": { "strength": 0.6 } },
      "keyframes": [ { "at": 12, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 21.5, "crop": { "scale": 1.1 } } ],
      "connected": [
        { "id": "name", "at": [13, 18], "kind": "title", "text": [ { "text": "Mina Park\n" }, { "text": "Head baker", "style": "role" } ], "style": "name",
          "animation": { "entrance": { "preset": "studio/slide", "args": { "distance": 0.4 } }, "exit": "frames/fade" } },
        { "at": [13, 18], "parent": "name", "kind": "path", "points": [ [0, -18], [420, -18] ],
          "stroke": { "paint": "#F2B33D", "width": 6, "cap": "round" },
          "keyframes": [ { "at": 13, "trim": [0, 0], "ease": "ease-out" }, { "at": 13.6, "trim": [0, 1] } ] } ] },
    { "id": "pour", "kind": "media", "media": "/abs/broll/pour.mov", "in": 0, "out": 6,
      "keyframes": [ { "at": 0, "timeRemap": 4 }, { "at": 2, "timeRemap": 6 },
                     { "at": 3.5, "timeRemap": 6, "ease": "ease-in" }, { "at": 6, "timeRemap": 9 } ] },
    { "kind": "media", "media": "/abs/cam-a/interview.mov", "in": 64, "out": 75, "scale": 1.15, "position": [1010, 560],
      "transition": { "preset": "frames/push-left", "seconds": 0.6 },
      "connected": [
        { "id": "hands", "at": [66, 71], "position": [1440, 540],
          "kind": "media",
          "media": { "kind": "sequence", "format": { "size": [960, 1080], "conform": "fill" },
                     "storyline": [ { "kind": "media", "media": "/abs/cam-b/hands.mov", "in": 40, "out": 45 } ] } } ] }
  ],
  "clips": [
    { "id": "logo", "kind": "media", "media": "/abs/brand/logo.png", "width": 180, "placement": "top-right", "opacity": 0.9, "lane": 3,
      "mask": { "kind": "ellipse", "area": [0, 0, 512, 512], "feather": 2 } },
    { "kind": "audio", "media": "/abs/music/morning.m4a", "fadeIn": 1, "fadeOut": 2,
      "keyframes": [ { "at": 9.3, "volume": 0.15, "ease": "ease-in-out" }, { "at": 9.8, "volume": 0.6 },
                     { "at": 15.2, "volume": 0.6, "ease": "ease-in-out" }, { "at": 15.7, "volume": 0.15 } ] },
    { "at": 15.3, "kind": "audio", "media": "/abs/sfx/whoosh.wav", "pan": -0.5 }
  ]
}
```

The interview opens with a slow push in and a lower third, a name and a role in two styles, under a rule that draws on beside it as a child of the title. The B-roll plays from media second 4 to 6, holds that frame for a second and a half, and ramps on to second 9. The second interview shot is punched in and reframed, and pushes in over the B-roll. A second camera plays in a 960 by 1080 window on its right half, a compound clip placed by its centre. A logo cut to a circle by its mask sits above everything, the music ducks under the interview, and a whoosh plays on the left with the push. `studio/grade` and `studio/slide` stand for presets of a pack that publish those parameters.

- `storyline` is the primary storyline. Its clips play one after another, and a transition plays across the edit point between two of them.
- `connected` clips belong to one storyline clip and live on its clip time ([FRAMES-8](../FRAMES-8/SPEC.md)). They move when that clip moves.
- `clips` are the sequence's clips on the sequence clock.
- A clip says what it is with `kind`, which every clip writes: `media` (a media clip), `audio` (an audio clip), `title`, `rect`, `ellipse` or `path` (a shape), `adjustment` (an adjustment clip), `solid` or `null`. A storyline clip is a `media` or a `solid`, and a connected or a sequence clip is any kind but a `solid`. A clip without `kind` stops, and so does a kind its place does not take, with the kinds it takes. Each kind's content has a key of its own: a media clip's and an audio clip's media is `media`, a title's text `text`, an adjustment clip's filter `adjust` and a solid's colour `color`, and a shape and a null are made of the keys of their geometry. A **media clip** shows its media's picture, and plays its sound where its media has one. An **audio clip** takes its media's sound alone and draws nothing: the sound of a sound file, or of a video, a compound clip or a sequence template instance, as Final Cut Pro detaches a clip's audio ([FRAMES-13](../FRAMES-13/SPEC.md)). Media with no picture as a media clip's media stops, saying that the media has no picture and that a clip of its sound alone is written with kind `audio`, and media with no sound as an audio clip's media stops, as any media of the wrong sort for its place does ([FRAMES-13](../FRAMES-13/SPEC.md#audio-clips)). A **null** draws nothing and only carries a box and a transform for other clips to follow ([FRAMES-11](../FRAMES-11/SPEC.md#null-clips)), and a **clip with a picture** is every clip but an audio clip and a null.

### Keys

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips, audioFilter, keyframes`. `kind` is required and is `"sequence"`. Its `keyframes` time its `audioFilter` on sequence time ([FRAMES-4](../FRAMES-4/SPEC.md), [FRAMES-28](../FRAMES-28/SPEC.md#buses)) |
| format | `size, fps, background, conform, colorSpace, peak, compositing, motionBlur` |
| motion blur (`format.motionBlur`) | `shutterAngle, shutterPhase, samplesPerFrame` ([FRAMES-29](../FRAMES-29/SPEC.md)) |
| content fit (a `size` written as an object, [FRAMES-6](../FRAMES-6/SPEC.md)) | `fit, margin` |
| storyline clip, timed media (video, image sequence, compound) | `id, metadata, kind, media, colorSpace, toneMap, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, split, keyframes, connected`, and `audioFilter` on a video or a compound clip ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| storyline clip, still (an image or a page of a PDF, [FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages), which takes no `toneMap`, [FRAMES-26](../FRAMES-26/SPEC.md#media)) | `id, metadata, kind, media, colorSpace, toneMap, duration, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, radius, border, shadow, keyframes, connected` |
| storyline clip, solid | `id, metadata, kind, color, duration, transition, motionBlur, keyframes, connected` |
| every clip with a picture (connected and sequence) | `id, metadata, kind, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip with a picture's, `audioFilter` on a video or a compound clip and `split` ([FRAMES-13](../FRAMES-13/SPEC.md)), `media, colorSpace, toneMap, in, out, speed, loop, volume, pan, fadeIn, fadeOut, placement, position, anchor, scale, rotation, cornerPin, crop, conform, filter, width, height, radius, border, shadow` |
| still media clip (an image or a page of a PDF, which takes no `toneMap`) | every clip with a picture's, `media, colorSpace, toneMap, placement, position, anchor, scale, rotation, cornerPin, crop, conform, filter, width, height, radius, border, shadow` |
| audio clip (`audio`), of any media with sound ([FRAMES-13](../FRAMES-13/SPEC.md#audio-clips)) | `id, metadata, kind, at, media, in, out, speed, loop, volume, pan, fadeIn, fadeOut, audioFilter, keyframes` |
| title clip | every clip with a picture's, `text, style, character, paragraph, width, placement, position, anchor, scale, rotation, cornerPin` |
| run (an item of a title's `text` list) | `text, style` |
| character (a title's `character`) | `font, size, weight, italic, tracking, kerning, features, baselineShift, color, stroke, highlight, underline, textOrientation, textCombineUpright`, each as a text style takes it ([FRAMES-22](../FRAMES-22/SPEC.md)) |
| paragraph (a title's `paragraph`) | `writingMode, direction, align, lineHeight, background`, each as a text style takes it ([FRAMES-22](../FRAMES-22/SPEC.md)) |
| shape clip (`rect`, `ellipse`, `path`) | every clip with a picture's, `style, area, width, height, placement, position, anchor, points, closed, radius, outset, fill, stroke, trim, shadow, scale, rotation`, and `cornerPin` on a rect or ellipse given by `width` and `height` ([FRAMES-27](../FRAMES-27/SPEC.md)) |
| null clip | `id, metadata, kind, at, parent, motionBlur, track, animation, keyframes, area, width, height, placement, position, anchor, scale, rotation` ([FRAMES-11](../FRAMES-11/SPEC.md#null-clips)) |
| split (on a storyline clip or a visual media clip) | `before, after` ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| stroke | `paint, width, align, join, cap, start, end, dash, dashOffset` |
| linear gradient (`linear`, [FRAMES-11](../FRAMES-11/SPEC.md)) | `kind, from, to, stops` |
| radial gradient (`radial`) | `kind, center, radius, stops` |
| adjustment clip (`adjustment`) | every clip with a picture's, `adjust` |
| mask | `kind, area, points, width, height, position, radius, feather, invert, mode` |
| path vertex (every object in the `points` of a path shape or a path mask, [FRAMES-11](../FRAMES-11/SPEC.md#shapes)) | `vertex, inTangent, outTangent`, `vertex` required outside a keyframe |
| track matte | `clip, mode, invert` |
| `track`, track data ([FRAMES-12](../FRAMES-12/SPEC.md#track-data)) | `time, frames`, both required |
| track data frame | `time, quad` |
| keyframe | `at, ease`, and the keyframable properties of its clip |
| transition choice | a preset as `<pack>/<name>` or an absolute path, `"cut"`, or `{preset, seconds, args}` with at least one of `seconds` and `args`, `preset` left out to merge over the theme's default ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-22](../FRAMES-22/SPEC.md)) |
| animation choice | a preset as `<pack>/<name>` or an absolute path, `"none"`, or `{preset, args, entrance, exit}`, each key optional, where each side is a preset, `"none"` or `{preset, args}`. `preset` may be left out of an object to merge over the theme's default ([FRAMES-22](../FRAMES-22/SPEC.md)). On a title the object also takes `by`, `stagger` and `order` ([FRAMES-14](../FRAMES-14/SPEC.md)) |
| filter choice | a preset as `<pack>/<name>` or an absolute path, a preset entry `{kind, preset, args, mix}` with `kind` `preset` and at least one of `args` and `mix`, `preset` left out to merge over the theme's default ([FRAMES-22](../FRAMES-22/SPEC.md)), a filter op, a list of those, or `"none"` ([FRAMES-15](../FRAMES-15/SPEC.md)) |
| filter op | `kind`, the op's name, the parameters the op table of [FRAMES-15](../FRAMES-15/SPEC.md) gives that op, and `mix` where a choice writes it (not in a preset's `ops`) |
| audio filter choice (`audioFilter`) | an audio preset as `<pack>/<name>` or an absolute path, a preset entry `{kind, preset, args, mix}` with `kind` `preset` and at least one of `args` and `mix`, an audio op, or a list of those ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| audio op | `kind`, the op's name, `mix` where a choice writes it (not in a preset's `ops`), and its parameters: `bands` for `eq`; `threshold, ratio, knee, attack, release, makeup` for `compressor`; `threshold, range, attack, hold, release` for `gate`; `gain, ceiling, lookahead, release` for `limiter`; `file, gain` for `convolve` |
| EQ band | `kind, frequency, gain, q`, `gain` for `lowShelf`, `highShelf` and `peak` only |
| arguments (`args` of a preset choice or a template instance) | the names of the parameters the preset or template publishes ([FRAMES-17](../FRAMES-17/SPEC.md)) |
| media object ([FRAMES-3](../FRAMES-3/SPEC.md)) | `kind`, required: `page`, `imageSequence`, `sequence` (a sequence document, the `sequence` row) or `template` |
| template instance (`template`) | `kind, template, args`, `template` required |
| page of a PDF as media (`page`, [FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages)) | `kind, file, page`, `file` and `page` required, `page` static and stood for by no parameter alone ([FRAMES-17](../FRAMES-17/SPEC.md)) |
| image sequence (`imageSequence`, [FRAMES-3](../FRAMES-3/SPEC.md)) | `kind, directory, fps`, `directory` and `fps` required |
| parameter | `type, default, description`, and `options` for a choice |

Which keys each shape kind takes, the forms of masks and track mattes, and `radius`, `border` and `shadow`, which act on a media clip's box and on a storyline picture's box alike, are [FRAMES-11](../FRAMES-11/SPEC.md). Every length a clip draws with (a stroke `width`, the `radius` of a shape or a box, `outset`, a mask's `feather`, a border's width, a shadow's sizes and the lengths of a title's `character` and `paragraph`) is a theme length, the unit of the style it overrides ([FRAMES-1](../FRAMES-1/SPEC.md)), and positions, areas and points are in the clip's coordinate space. A media clip's `colorSpace` names the colour space its media are in, over what the file says, wherever that clip's media is read, providers included, as a transition cover's or matte's `colorSpace` does for its media ([FRAMES-14](../FRAMES-14/SPEC.md)), and two places of one file that name two colour spaces stop ([FRAMES-26](../FRAMES-26/SPEC.md#media)); its `toneMap` (a boolean, `true` by default) whether an HDR picture of it is tone mapped to the sequence's peak where its own peak is higher; a clip whose media is a compound clip or a template instance takes neither; the format's `colorSpace`, `peak` and `compositing` are the sequence's colour space, the mastering peak of a `rec2100-pq` sequence and the form it composites in ([FRAMES-26](../FRAMES-26/SPEC.md)). The sequence's `audioFilter` is its bus's chain, an audio filter choice run over the sum of its sounds wherever it plays, inside another sequence included ([FRAMES-28](../FRAMES-28/SPEC.md#buses)). How a preset choice passes its arguments is [FRAMES-14](../FRAMES-14/SPEC.md): an unknown argument name stops, an argument of the wrong type stops, and a missing one takes its parameter's default.

A clip's `motionBlur` (a boolean, `false` by default) is whether the values it owns move over each frame's exposure, wherever they are read: in its own picture, in its children as a parent, in a track matte, in a clip area or point that names it, and in a transition it brings in, which moves both pictures. The outgoing clip's switch does not blur a transition another clip brings in. And `format.motionBlur` is the shutter of that exposure, the same for every clip the sequence shows ([FRAMES-29](../FRAMES-29/SPEC.md)). Every clip with a picture takes it, an adjustment clip included, and so does a null, whose values its children and the clip areas that name it read. An audio clip takes none.

`id` names a clip for whatever reads or changes the document, inside it and outside it ([FRAMES-25](../FRAMES-25/SPEC.md)), since a place like `storyline[1].connected[0]` moves when clips are added. It is a string, unique within its document (a nested document has its own), and a duplicate stops. `parent` ([FRAMES-10](../FRAMES-10/SPEC.md)) and a track matte's `clip` ([FRAMES-11](../FRAMES-11/SPEC.md)) name a clip by its `id`. Messages and machine output give it with the place.

`metadata` is an object that frames does not read: what the programs that read and change a document keep on a clip ([FRAMES-25](../FRAMES-25/SPEC.md)), such as which tool added it and why, as an NLE keeps keywords and notes. Its contents are not checked, and resolve does not carry it into the resolved document.

A clip's `kind` picks its row, and every key outside that row stops as an unknown key of the kind, the content key of another kind included, so `text` on a `rect` stops as `fill` on a title does. Within `media`, which media row applies depends on what the media holds, so those keys are checked once the media has been probed. An `audio` clip takes the audio clip's row whatever its media is, so its keys are known from its `kind`, and its media is probed only to know that it has sound. Where the media is a template parameter, the parameter's type picks the row, and a page given to an `image` parameter takes the keys of a page when the template is instantiated with it ([FRAMES-17](../FRAMES-17/SPEC.md)). An `audio` parameter as a media clip's media stops, since a sound file has no picture, and so does an `image` parameter as an audio clip's media, since a still has no sound.

`kind` decides which keys a clip takes, so a parameter stands for it only as a choice between shapes: a template's `choice` whose options are each `rect`, `ellipse` or `path`, which checks the clip's keys with each option ([FRAMES-17](../FRAMES-17/SPEC.md)). A parameter of another type at `kind` stops, and so does a choice with an option that is not a shape.

Keyframable properties, as the principle of [FRAMES-4](../FRAMES-4/SPEC.md) gives them (a key whose value is built from numbers and colours and whose change alters no decision resolve makes once). The table is written for reference, and where it and the principle differ the principle decides:

| Clip | Properties |
| --- | --- |
| sequence, by its own `keyframes` | `audioFilter` |
| storyline clip with media | `crop, position, scale, rotation, cornerPin, opacity, mask, filter, radius, border, shadow`, and `volume`, `pan` and `timeRemap` on timed media, and `audioFilter` on video and compound clips with sound |
| storyline clip, solid | `color` |
| media clip | `position, scale, rotation, cornerPin, opacity, crop, mask, filter, radius, border, shadow`, and `volume`, `pan` and `timeRemap` on timed media, and `audioFilter` on video and compound clips with sound |
| audio clip | `volume, pan`, and `audioFilter` where it takes one |
| title clip | `position, scale, rotation, cornerPin, opacity, mask`, and in `character` its `color`, `stroke`, `tracking` ([FRAMES-5](../FRAMES-5/SPEC.md)), `baselineShift`, `highlight` and `underline`, and in `paragraph` its `lineHeight` and `background` |
| shape clip | `area, width, height, points, position, scale, rotation, cornerPin, opacity, trim, radius, outset, fill, stroke, shadow, mask` |
| adjustment clip | `opacity, mask, adjust` |
| null clip | `area, width, height, position, scale, rotation` |

`timeRemap` is written only in keyframes ([FRAMES-8](../FRAMES-8/SPEC.md)), so a static `timeRemap` on a clip stops. A keyframe sets the leaves it writes and no others, and each leaf is timed on its own ([FRAMES-4](../FRAMES-4/SPEC.md)): `mask`, `filter`, `adjust`, `fill`, `stroke`, `shadow`, `border`, `character`, `paragraph` and `audioFilter` in a keyframe write the numbers and colours they change, timed over the merged value (the clip's static value, with the structure its keyframes give, merged over its style's), whose names and structure are static, and a leaf written `null` is the merged value at that instant.

Keys are checked over the whole JSON tree before any value is read, except the media rows, which follow the probe. A value of the wrong type also stops, with its place, and so does a key written twice in one object. An object whose `kind` says which of a fixed set of kinds it is (the document, a clip, a media object, a mask, a gradient, an ease, a filter or audio filter entry, an op and an EQ band) and that writes no `kind` stops as a missing key, and its message lists the kinds its place takes, as the message for a kind it does not take lists them: `storyline[0] (storyline clip): missing key "kind". Allowed: media, solid`. A leaf written statically and given a value in every keyframe that writes it stops, since the static value would never show ([FRAMES-4](../FRAMES-4/SPEC.md)), a solid's `color` included.

An object with a `tool` key is a request, a hole a tool fills ([FRAMES-25](../FRAMES-25/SPEC.md#requests)), and the engine takes none. Wherever the check meets one, where any value stands, in a clip, a keyframe, a point of a list of points or an argument, it stops at the place the object stands, before any key of the object is checked: `<place> (request): this is a request for the tool "<tool>", and a tool fills its requests before the document is given to frames`, with the name its `tool` gives. `tool` is text, and any other value of it stops as a value of the wrong type. `metadata` is not checked, so an object with a `tool` key inside it is no request.

## Interactions

A sequence is the one document kind ([FRAMES-6](../FRAMES-6/SPEC.md)). Time is [FRAMES-8](../FRAMES-8/SPEC.md). Each clip kind's keys are explained in [FRAMES-9](../FRAMES-9/SPEC.md) (format and storyline clips), [FRAMES-10](../FRAMES-10/SPEC.md) (`parent`), [FRAMES-11](../FRAMES-11/SPEC.md) (titles, shapes, media and adjustment clips, nulls, masks and track mattes), [FRAMES-12](../FRAMES-12/SPEC.md) (`track` and track data), [FRAMES-13](../FRAMES-13/SPEC.md) (sound) and [FRAMES-27](../FRAMES-27/SPEC.md) (`cornerPin`). Placement and anchor points are [FRAMES-1](../FRAMES-1/SPEC.md), areas and points [FRAMES-2](../FRAMES-2/SPEC.md), media forms [FRAMES-3](../FRAMES-3/SPEC.md), keyframes and eases [FRAMES-4](../FRAMES-4/SPEC.md), colour spaces and compositing [FRAMES-26](../FRAMES-26/SPEC.md), templates and their parameters [FRAMES-17](../FRAMES-17/SPEC.md), and buses and the `limiter` op [FRAMES-28](../FRAMES-28/SPEC.md).

Motion blur and the shutter are [FRAMES-29](../FRAMES-29/SPEC.md).

## Alternatives considered

Objects that ignore unknown keys, as CSS ignores an unknown property: a misspelt key would render as no effect, and nothing in the edit loop would say so. Meaning carried in `id` strings: `metadata` is the place for what frames does not read. Naming a parent or a matte by its place in the document: a place moves when a clip is added before it, and an `id` does not.

A clip's kind as the one key of its content it holds, `"title": "Mina Park"`, `"shape": "rect"` or `"solid": "#000"`: one key carries two facts, the kind and the content, so a kind made of nothing but its box needs a flag such as `"null": true`, a shape writes its kind beside its geometry under a key named for every shape, a solid's colour is required as the mark of its kind even where its keyframes give every value of it, and a reader learns what a clip is by trying every kind key in turn. `kind` says what a clip is with one value, as it says what a document is, and each content key says only what it holds.

An audio clip as a media clip that takes no picture, because its media holds only sound or because it writes `"picture": false`: a flag switches the clip's kind and the keys it takes, and a clip of a sound file is an audio clip by what the file holds, which the document does not say. `audio` is the kind of a clip that takes sound alone, whatever its media, so its keys are known from its `kind` before its media is read, and a sound file as a `media` clip's media stops as media of the wrong sort for its place.

## Notes
