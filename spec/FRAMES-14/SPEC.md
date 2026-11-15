# FRAMES-14: Presets: motion, animation and transition

Status: accepted

## Summary

Presets as data files: the motion properties and spans they share, animation presets (entrance, loop, exit) and transition presets (motion, cover and matte).

## Motivation

A look is shared and sold as data, and adding one must need no rebuild. Spans of keys over progress let any entrance or wipe be written without code.

## Rules

A preset is one JSON file at `presets/<transition|animation|filter>/<name>.json`. A bare name is a preset frames ships, `<pack>/<name>` is a preset in an installed pack ([FRAMES-17](../FRAMES-17/SPEC.md)), and an absolute path reads that file. Adding a preset needs no rebuild.

Every preset has a `description`: one line on how it looks and when to use it, which `presets` prints. Unknown keys and broken rules in a preset stop when it is read.

### Motion properties

| Property | Default | Meaning |
| --- | --- | --- |
| `opacity` | 1 | opacity |
| `scale` | 1 | scale around the anchor point ([FRAMES-1](../FRAMES-1/SPEC.md)), or the centre of the box for a clip placed by an area |
| `x`, `y` | 0 | offset in multiples of the thing's own size, or of the content rect in a transition. Down is positive |
| `rotation` | 0 | degrees, clockwise positive, around the same point as `scale` |
| `reveal` | 1 | 0 shows nothing, 1 shows everything. How it reveals depends on what receives it (below) |
| `nudge` | 0 | moves an arrow towards what it points at by multiples of its length. Only arrows read it |

| Receiver of `reveal` | How it reveals |
| --- | --- |
| box | the border is drawn around |
| fill | painted from the `revealFrom` side |
| dim | closes in from all it darkens to the area |
| arrow | grows from its tail to its head |
| title, media, adjustment, storyline picture | wiped from the `revealFrom` side |

A span is:

```json
{ "seconds": 0.35, "ease": "back-out", "revealFrom": "left",
  "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "scale": 1 } ] }
```

- `t` is progress through the span, from 0 to 1.
- Each property joins only the keys that name it, in straight lines. Opacity can finish at 30% while scale runs to the end.
- A property the span does not name takes its default.
- `ease` bends the progress first, and the bent value drives every property. Where an ease leaves 0 to 1 (`back-out`), a property whose keys reach that end goes on along its last line, so it overshoots. One whose keys stop short of it holds.
- `revealFrom` is `left`, `right`, `top` or `bottom`. The default is `left`.

### animation

```json
{ "description": "...",
  "entrance": { "seconds": 0.35, "ease": "back-out", "keys": [ ... ] },
  "loop":     { "period": 0.9, "keys": [ ... ] },
  "exit":     { "seconds": 0.15, "keys": [ ... ] } }
```

| Span | When it runs | Required | Default ease |
| --- | --- | --- | --- |
| `entrance` | for `seconds` from the start of the clip's visible window | `seconds` | `ease-out` |
| `loop` | every `period` seconds from the end of the entrance to the start of the exit | `period` | `ease-in-out` |
| `exit` | for the last `seconds` of the visible window | `seconds` | `ease-in` |

- Every span is optional. Without one the clip simply shows.
- On a short clip the entrance runs first and the exit takes what time is left.
- `{entrance, exit}` as a choice takes the entrance from one preset and the exit from another. Both are written, and a side without one is `none`.
- An animation is applied over the clip's keyframes, about the same point: its scale and opacity multiply, and its x, y and rotation add. A preset's look is the same for every anchor point, made about that point.

### transition

```json
{ "description": "...",
  "seconds": 0.45, "ease": "ease-in-out", "over": "incoming",
  "incoming": { "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
  "outgoing": { "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": -1 } ] },
  "cover":    { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

| Key | Meaning |
| --- | --- |
| `seconds` | default length, required. `{preset, seconds}` in a document overrides it, and writes both |
| `ease` | default curve of incoming, outgoing, cover and matte |
| `over` | which unit is on top during the transition: `incoming` (default) or `outgoing` |
| `incoming` | motion of the incoming clip |
| `outgoing` | motion of the outgoing clip |
| `cover` | `{color, keys}` or `{media, keys}`: a colour (a dip to colour) or an image or video with alpha (a stinger) over both units, stretched over the content rect. Its keys take `t` and `opacity` only |
| `matte` | `{media, softness, invert}`: a luma wipe (below) |

- A storyline picture reads opacity, scale, x, y, rotation and reveal. Scale, x, y and rotation act around the centre of the content rect, and reveal shows the content rect from the `revealFrom` side.
- `seconds` or `period` inside a span stops. A transition's time is its length.
- To change scenes while the cover hides them, cut the incoming opacity from 0 to 1 at that point.
- `matte.media` is a greyscale image or video, stretched over the content rect. The incoming unit shows where the matte's luminance is below the transition progress, with an edge `softness` wide (0 to 1 of the luminance range). `invert` swaps dark and light. A still gradient gives the luma wipe (gradient wipe) of an NLE, and a black and white video gives a track-matte wipe that shows the incoming unit where it is black. Either gives any wipe shape without code. A matte reveals the incoming unit, so a transition with both `matte` and `"over": "outgoing"` stops.
- A video in `matte` or `cover` is stretched over the transition: at progress p it shows media time p × its duration, so the transition's seconds change its speed, not its shape.

## Interactions

Presets come from packs ([FRAMES-17](../FRAMES-17/SPEC.md)). The presets that ship are [FRAMES-16](../FRAMES-16/SPEC.md). Defaults are in the theme ([FRAMES-22](../FRAMES-22/SPEC.md)).

## Alternatives considered

Effects as code: packs carry data only, so every role can draw them (README).

## Notes
