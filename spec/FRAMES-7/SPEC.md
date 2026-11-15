# FRAMES-7: The sequence document and its keys

Status: draft

## Summary

The shape of a sequence document and the closed key table of every object in it, with the keyframable properties and what `id` and `metadata` are for.

## Motivation

A typo that renders as no effect is the costliest mistake an agent can make, since nothing tells it. Fixing every object's keys lets frames stop at the place of the typo. `id` and `metadata` give the programs outside frames a place that does not move when clips are added.

## Rules

### Shape

```json
{
  "kind": "sequence",
  "format": { "size": [1080, 1920], "fps": 30, "background": "#000000", "inset": [420, 40, 120, 40], "conform": "fit" },
  "theme": { "defaults": { "transition": "push-up", "filter": "vivid", "animation": { "title": { "subtitle": "pop" }, "shape": "draw" } } },
  "storyline": [
    { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "volume": 0,
      "keyframes": [ { "at": 2, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ],
      "connected": [ { "at": [2, 8], "title": "**Emphasis** subtitle", "style": "subtitle" } ] },
    { "media": "/abs/run.mp4", "in": 17.5, "out": 23, "transition": "flash", "volume": 0,
      "keyframes": [ { "at": 18, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 19, "crop": { "from": "Enter your password", "to": "3" } } ],
      "connected": [ { "at": [19, 22], "shape": "box", "area": "Sent", "label": "done", "animation": "stamp" },
                     { "shape": "box", "area": "Account 110-", "track": true, "label": "this account" } ] },
    { "media": { "kind": "image", "source": "/abs/card.png" }, "duration": 2.5,
      "transition": { "preset": "wipe-right", "seconds": 0.5 },
      "connected": [ { "shape": "box",
                       "keyframes": [ { "at": 1.2, "area": "First line" }, { "at": 1.65, "area": "Second line" } ] } ] }
  ],
  "clips": [
    { "at": [0, 30], "title": "Top title\n**emphasis**", "style": "headline", "lane": 2 },
    { "at": [1, 6], "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
      "animation": { "entrance": "pop", "exit": "fade" }, "lane": 5,
      "keyframes": [ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ] },
    { "at": [0, 4], "media": "/abs/light-leak.mov", "blend": "screen", "lane": 3 },
    { "media": "/abs/bgm.m4a", "volume": 0.3, "loop": true, "fadeOut": 1 },
    { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 }
  ]
}
```

- `storyline` is the primary storyline. Its clips play one after another, and a transition plays across the edit point between two of them.
- `connected` clips belong to one storyline clip and live on its clip time. They move when that clip moves.
- `clips` are the sequence's clips on the sequence clock.
- A clip is a media clip (`media`), a title (`title`), a shape (`shape`), an adjustment clip (`adjust`) or a solid (`solid`, storyline only). Exactly one of these keys is present.

### Keys

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips` |
| format | `size, fps, background, inset, conform` |
| storyline clip, timed media (video, image sequence, compound) | `id, metadata, media, in, track, out, speed, crop, filter, transition, volume, fadeIn, fadeOut, keyframes, connected` |
| storyline clip, still (image, image or layout document) | `id, metadata, media, duration, crop, filter, transition, keyframes, connected` |
| storyline clip, solid | `id, metadata, solid, duration, transition, connected` |
| every connected and sequence clip | `id, metadata, at, lane, opacity, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip's, `track, anchor, media, in, out, speed, loop, volume, fadeIn, fadeOut, placement, position, parent, scale, rotation, crop, conform, filter, blend, width, height, radius, border, shadow` |
| still media clip (image, image or layout document) | every clip's, `track, anchor, media, placement, position, parent, scale, rotation, crop, conform, filter, blend, width, height, radius, border, shadow` |
| audio clip | `id, metadata, at, media, in, out, speed, loop, volume, fadeIn, fadeOut, keyframes` |
| title clip | every clip's, `track, anchor, title, style, width, placement, position, parent, scale, rotation, blend` |
| shape clip | every clip's, `shape, area, track, label, labelAnimation, color, blend`, and `side` for an arrow |
| adjustment clip | every clip's, `adjust, area, track` |
| keyframe | `at, ease`, and the keyframable properties of its clip |
| transition choice | a preset name, a `<pack>/<name>`, an absolute path, `"cut"`, or `{preset, seconds}` |
| animation choice | a preset name, a `<pack>/<name>`, an absolute path, `"none"`, or `{entrance, exit}` |
| filter choice | a preset name, a `<pack>/<name>`, an absolute path, a list of those, or `"none"` |
| image document | `kind, source, time, theme, params, ops`, and each op's keys from [FRAMES-6](../FRAMES-6/SPEC.md) |
| layout document | `kind, theme, params, banner, columns, border, items`. An item takes `heading, image` |
| template instance | `template, args` |
| parameter | `type, default, description`, and `options` for a choice |

`id` names a clip or op for whatever reads or changes the document from outside ([FRAMES-25](../FRAMES-25/SPEC.md)), since a place like `storyline[1].connected[0]` moves when clips are added. It is a string, unique within its document (a nested document has its own), and a duplicate stops. Messages and machine output give it with the place.

`metadata` is an object that frames does not read: what the programs that read and change a document keep on a clip or op ([FRAMES-25](../FRAMES-25/SPEC.md)), such as which extension added it and why, as an NLE keeps keywords and notes. Its contents are not checked, and resolve does not carry it into the resolved document.

Which media row applies depends on what the media holds, so those keys are checked once the media has been probed. Where the media is a template parameter, the parameter's type picks the row ([FRAMES-17](../FRAMES-17/SPEC.md)).

Keyframable properties:

| Clip | Properties |
| --- | --- |
| storyline clip | `crop`, and `volume` on timed media |
| media clip | `position, scale, rotation, opacity, crop`, and `volume` on timed media (audio clips: `volume` only) |
| title clip | `position, scale, rotation, opacity` |
| shape clip | `area, opacity` |
| adjustment clip | `area, opacity` |

Keys are checked over the whole JSON tree before any value is read, except the media rows, which follow the probe. A value of the wrong type also stops, with its place. A property written both as a static value and in a keyframe stops, since the static value would never show.

## Interactions

Time is [FRAMES-8](../FRAMES-8/SPEC.md). Each clip kind's keys are explained in [FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md) and [FRAMES-13](../FRAMES-13/SPEC.md).

## Alternatives considered

Meaning carried in `id` strings: `metadata` is the place for what frames does not read.

## Notes
