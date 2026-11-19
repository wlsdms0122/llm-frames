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
    { "id": "interview", "media": "/abs/cam-a/interview.mov", "in": 12, "out": 21.5,
      "filter": { "preset": "studio/grade", "args": { "strength": 0.6 } },
      "keyframes": [ { "at": 12, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 21.5, "crop": { "scale": 1.1 } } ],
      "connected": [
        { "id": "name", "at": [13, 18], "title": [ { "text": "Mina Park\n" }, { "text": "Head baker", "style": "role" } ], "style": "name",
          "animation": { "entrance": { "preset": "studio/slide", "args": { "distance": 0.4 } }, "exit": "frames/fade" } },
        { "at": [13, 18], "parent": "name", "shape": "path", "points": [ [0, -18], [420, -18] ],
          "stroke": { "color": "#F2B33D", "width": 6, "cap": "round" },
          "keyframes": [ { "at": 13, "trim": [0, 0], "ease": "ease-out" }, { "at": 13.6, "trim": [0, 1] } ] } ] },
    { "id": "pour", "media": "/abs/broll/pour.mov", "in": 0, "out": 6,
      "keyframes": [ { "at": 0, "timeRemap": 4 }, { "at": 2, "timeRemap": 6 },
                     { "at": 3.5, "timeRemap": 6, "ease": "ease-in" }, { "at": 6, "timeRemap": 9 } ] },
    { "media": "/abs/cam-a/interview.mov", "in": 64, "out": 75, "scale": 1.15, "position": [1010, 560],
      "transition": { "preset": "frames/push-left", "seconds": 0.6 },
      "connected": [
        { "id": "hands", "at": [66, 71], "position": [1440, 540],
          "media": { "kind": "sequence", "format": { "size": [960, 1080], "conform": "fill" },
                     "storyline": [ { "media": "/abs/cam-b/hands.mov", "in": 40, "out": 45 } ] } } ] }
  ],
  "clips": [
    { "id": "logo", "media": "/abs/brand/logo.png", "width": 180, "placement": "top-right", "opacity": 0.9, "lane": 3,
      "mask": { "shape": "ellipse", "area": [0, 0, 512, 512], "feather": 2 } },
    { "media": "/abs/music/morning.m4a", "fadeIn": 1, "fadeOut": 2,
      "keyframes": [ { "at": 9.3, "volume": 0.15, "ease": "ease-in-out" }, { "at": 9.8, "volume": 0.6 },
                     { "at": 15.2, "volume": 0.6, "ease": "ease-in-out" }, { "at": 15.7, "volume": 0.15 } ] },
    { "at": 15.3, "media": "/abs/sfx/whoosh.wav", "pan": -0.5 }
  ]
}
```

The interview opens with a slow push in and a lower third, a name and a role in two styles, under a rule that draws on beside it as a child of the title. The B-roll plays from media second 4 to 6, holds that frame for a second and a half, and ramps on to second 9. The second interview shot is punched in and reframed, and pushes in over the B-roll. A second camera plays in a 960 by 1080 window on its right half, a compound clip placed by its centre. A logo cut to a circle by its mask sits above everything, the music ducks under the interview, and a whoosh plays on the left with the push. `studio/grade` and `studio/slide` stand for presets of a pack that publish those parameters.

- `storyline` is the primary storyline. Its clips play one after another, and a transition plays across the edit point between two of them.
- `connected` clips belong to one storyline clip and live on its clip time ([FRAMES-8](../FRAMES-8/SPEC.md)). They move when that clip moves.
- `clips` are the sequence's clips on the sequence clock.
- A clip is a media clip (`media`), a title (`title`), a shape (`shape`), an adjustment clip (`adjust`) or a solid (`solid`, storyline only). Exactly one of these keys is present. `"picture": false` on a media clip whose media has a picture and sound (a video, a compound clip, a sequence template instance) takes only the sound, as Final Cut Pro detaches a clip's audio, and the clip is then an audio clip ([FRAMES-13](../FRAMES-13/SPEC.md)). An **audio clip** is a media clip that takes no picture, because its media holds only sound or because it is written with `"picture": false`, and a **clip with a picture** is every other clip.

### Keys

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips`. `kind` is required and is `"sequence"` |
| format | `size, fps, background, conform` |
| content fit (a `size` written as an object, [FRAMES-6](../FRAMES-6/SPEC.md)) | `fit, margin` |
| storyline clip, timed media (video, image sequence, compound) | `id, metadata, media, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, split, keyframes, connected`, and `audioFilter` on a video ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| storyline clip, still (image) | `id, metadata, media, duration, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, radius, border, shadow, keyframes, connected` |
| storyline clip, solid | `id, metadata, solid, duration, transition, keyframes, connected` |
| every clip with a picture (connected and sequence) | `id, metadata, at, lane, parent, opacity, blend, mask, trackMatte, track, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip with a picture's, `audioFilter` on a video and `split` ([FRAMES-13](../FRAMES-13/SPEC.md)), `media, picture, in, out, speed, loop, volume, pan, fadeIn, fadeOut, placement, position, anchor, scale, rotation, crop, conform, filter, width, height, radius, border, shadow` |
| still media clip (image) | every clip with a picture's, `media, placement, position, anchor, scale, rotation, crop, conform, filter, width, height, radius, border, shadow` |
| audio clip | `id, metadata, at, media, in, out, speed, loop, volume, pan, fadeIn, fadeOut, audioFilter, keyframes` |
| audio clip of a video's sound (`"picture": false`) | every audio clip's, `picture` |
| audio clip of a compound clip's or a template instance's sound (`"picture": false`) | every audio clip's but `audioFilter`, and `picture` ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| title clip | every clip with a picture's, `title, style, character, paragraph, width, placement, position, anchor, scale, rotation` |
| run (an item of a `title` list) | `text, style` |
| character (a title's `character`) | `font, size, weight, italic, tracking, kerning, features, baselineShift, color, stroke, highlight, underline`, each as a text style takes it ([FRAMES-22](../FRAMES-22/SPEC.md)) |
| paragraph (a title's `paragraph`) | `align, lineHeight, background`, each as a text style takes it ([FRAMES-22](../FRAMES-22/SPEC.md)) |
| shape clip | every clip with a picture's, `shape, style, area, width, height, placement, position, anchor, points, closed, radius, outset, fill, stroke, trim, shadow, scale, rotation` |
| split (on a storyline clip or a visual media clip) | `before, after` ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| stroke | `color, gradient, width, join, cap, start, end, dash, dashOffset` |
| gradient | exactly one of `linear` and `radial` ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| linear gradient | `from, to, stops` |
| radial gradient | `center, radius, stops` |
| adjustment clip | every clip with a picture's, `adjust` |
| mask | `shape, area, points, width, height, position, radius, feather, invert, mode` |
| track matte | `clip, mode, invert` |
| keyframe | `at, ease`, and the keyframable properties of its clip |
| transition choice | a preset as `<pack>/<name>` or an absolute path, `"cut"`, or `{preset, seconds, args}` with at least one of `seconds` and `args`, `preset` left out to merge over the theme's default ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-22](../FRAMES-22/SPEC.md)) |
| animation choice | a preset as `<pack>/<name>` or an absolute path, `"none"`, `{preset, args}`, or `{entrance, exit}`, where each side is a preset, `"none"` or `{preset, args}`. `preset` may be left out of an object to merge over the theme's default ([FRAMES-22](../FRAMES-22/SPEC.md)). On a title the two object forms also take `by` and `stagger` ([FRAMES-14](../FRAMES-14/SPEC.md)) |
| filter choice | a preset as `<pack>/<name>` or an absolute path, `{preset, args, mix}` with at least one of `args` and `mix`, `preset` left out to merge over the theme's default ([FRAMES-22](../FRAMES-22/SPEC.md)), a filter op, a list of those, or `"none"` ([FRAMES-15](../FRAMES-15/SPEC.md)) |
| filter op | `op`, the parameters the op table of [FRAMES-15](../FRAMES-15/SPEC.md) gives that op, and `mix` where a choice writes it (not in a preset's `ops`) |
| audio filter choice (`audioFilter`) | an audio preset as `<pack>/<name>` or an absolute path, `{preset, args, mix}` with at least one of `args` and `mix`, an audio op, or a list of those ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| audio op | `op`, `mix` where a choice writes it (not in a preset's `ops`), and its parameters: `bands` for `eq`; `threshold, ratio, knee, attack, release, makeup` for `compressor`; `threshold, range, attack, hold, release` for `gate` |
| EQ band | `type, frequency, gain, q`, `gain` for `lowShelf`, `highShelf` and `peak` only |
| arguments (`args` of a preset choice or a template instance) | the names of the parameters the preset or template publishes ([FRAMES-17](../FRAMES-17/SPEC.md)) |
| template instance | `template, args` |
| parameter | `type, default, description`, and `options` for a choice |

Which keys each shape kind takes, the forms of masks and track mattes, and `radius`, `border` and `shadow`, which act on a media clip's box and on a storyline picture's box alike, are [FRAMES-11](../FRAMES-11/SPEC.md). Every length a clip draws with (a stroke `width`, the `radius` of a shape or a box, `outset`, a mask's `feather`, a border's width, a shadow's sizes and the lengths of a title's `character` and `paragraph`) is a theme length, the unit of the style it overrides ([FRAMES-1](../FRAMES-1/SPEC.md)), and positions, areas and points are in the clip's coordinate space. How a preset choice passes its arguments is [FRAMES-14](../FRAMES-14/SPEC.md): an unknown argument name stops, an argument of the wrong type stops, and a missing one takes its parameter's default.

`id` names a clip for whatever reads or changes the document, inside it and outside it ([FRAMES-25](../FRAMES-25/SPEC.md)), since a place like `storyline[1].connected[0]` moves when clips are added. It is a string, unique within its document (a nested document has its own), and a duplicate stops. `parent` ([FRAMES-10](../FRAMES-10/SPEC.md)) and a track matte's `clip` ([FRAMES-11](../FRAMES-11/SPEC.md)) name a clip by its `id`. Messages and machine output give it with the place.

`metadata` is an object that frames does not read: what the programs that read and change a document keep on a clip ([FRAMES-25](../FRAMES-25/SPEC.md)), such as which extension added it and why, as an NLE keeps keywords and notes. Its contents are not checked, and resolve does not carry it into the resolved document.

Which media row applies depends on what the media holds and on `picture`, so those keys are checked once the media has been probed. Where the media is a template parameter, the parameter's type picks the row ([FRAMES-17](../FRAMES-17/SPEC.md)).

Keyframable properties, as the principle of [FRAMES-4](../FRAMES-4/SPEC.md) gives them (a key whose value is built from numbers and colours and whose change alters no decision resolve makes once). The table is written for reference, and where it and the principle differ the principle decides:

| Clip | Properties |
| --- | --- |
| storyline clip with media | `crop, position, scale, rotation, opacity, mask, filter, radius, border, shadow`, and `volume`, `pan` and `timeRemap` on timed media, and `audioFilter` on video with sound |
| storyline clip, solid | `solid` |
| media clip | `position, scale, rotation, opacity, crop, mask, filter, radius, border, shadow`, and `volume`, `pan` and `timeRemap` on timed media, and `audioFilter` on video with sound |
| audio clip | `volume, pan`, and `audioFilter` where it takes one |
| title clip | `position, scale, rotation, opacity, mask`, and in `character` its `color`, `stroke`, `tracking` ([FRAMES-5](../FRAMES-5/SPEC.md)), `baselineShift`, `highlight` and `underline`, and in `paragraph` its `lineHeight` and `background` |
| shape clip | `area, width, height, points, position, scale, rotation, opacity, trim, radius, outset, fill, stroke, shadow, mask` |
| adjustment clip | `opacity, mask, adjust` |

`timeRemap` is written only in keyframes ([FRAMES-8](../FRAMES-8/SPEC.md)), so a static `timeRemap` on a clip stops. A keyframe sets the leaves it writes and no others, and each leaf is timed on its own ([FRAMES-4](../FRAMES-4/SPEC.md)): `mask`, `filter`, `adjust`, `fill`, `stroke`, `shadow`, `border`, `character`, `paragraph` and `audioFilter` in a keyframe write the numbers and colours they change, timed over the merged value (the clip's static value, with the structure its keyframes give, merged over its style's), whose names and structure are static, and a leaf written `null` is the merged value at that instant.

Keys are checked over the whole JSON tree before any value is read, except the media rows, which follow the probe. A value of the wrong type also stops, with its place, and so does a key written twice in one object. A leaf written statically and given a value in every keyframe that writes it stops, since the static value would never show ([FRAMES-4](../FRAMES-4/SPEC.md)).

## Interactions

A sequence is the one document kind ([FRAMES-6](../FRAMES-6/SPEC.md)). Time is [FRAMES-8](../FRAMES-8/SPEC.md). Each clip kind's keys are explained in [FRAMES-9](../FRAMES-9/SPEC.md) (format and storyline clips), [FRAMES-10](../FRAMES-10/SPEC.md) (`parent`), [FRAMES-11](../FRAMES-11/SPEC.md) (titles, shapes, media and adjustment clips, masks and track mattes), [FRAMES-12](../FRAMES-12/SPEC.md) (`track`) and [FRAMES-13](../FRAMES-13/SPEC.md) (sound). Placement and anchor points are [FRAMES-1](../FRAMES-1/SPEC.md), areas and points [FRAMES-2](../FRAMES-2/SPEC.md), media forms [FRAMES-3](../FRAMES-3/SPEC.md), keyframes and eases [FRAMES-4](../FRAMES-4/SPEC.md), and templates and their parameters [FRAMES-17](../FRAMES-17/SPEC.md).

## Alternatives considered

Objects that ignore unknown keys, as CSS ignores an unknown property: a misspelt key would render as no effect, and nothing in the edit loop would say so. Meaning carried in `id` strings: `metadata` is the place for what frames does not read. Naming a parent or a matte by its place in the document: a place moves when a clip is added before it, and an `id` does not.

## Notes
