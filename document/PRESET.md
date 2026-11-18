# Writing a preset

A preset is one JSON file. It is a transition, an animation or a filter, and frames reads it as data, so a new one needs no rebuild. The format is [FRAMES-14](../spec/FRAMES-14/SPEC.md) (transitions and animations) and [FRAMES-15](../spec/FRAMES-15/SPEC.md) (filters). This page shows how to write one of each and how to try it.

## Where a preset lives

| Name in a document | File |
| --- | --- |
| `frames/pop` | a preset of the `frames` pack, which ships with frames ([FRAMES-16](../spec/FRAMES-16/SPEC.md)) |
| `mine/drop-in` | `$FRAMES_HOME/packs/mine/presets/transition/drop-in.json` |
| `/path/to/drop-in.json` | that file |

The folder under `presets/` is the kind (`transition`, `animation` or `filter`), and the place a name is written says which kind is meant, so a transition and an animation may share a name. Every preset is named `<pack>/<name>`, the ones frames ships too. While you write a preset, an absolute path is the quickest way to try it. Once it works, put it in a pack ([PACK.md](PACK.md)) so documents name it as `<pack>/<name>`.

Every preset has a `description`: one line on how it looks and when to use it. `frames presets` prints it, and it is what an agent reads to choose, so write it for that reader.

```sh
frames presets                             # every preset of every pack, by kind, with its description
frames presets transition                  # the transitions
frames presets transition frames/fade      # the JSON of one preset
frames presets transition mine/drop-in     # the JSON of a preset in an installed pack
```

## Spans

Transitions and animations are made of spans. A span runs from progress 0 to progress 1, and its keys say what each motion property is at a point of that progress.

```json
{ "ease": "back-out", "revealFrom": "left",
  "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "scale": 1 } ] }
```

| Property | Default | What it moves |
| --- | --- | --- |
| `opacity` | 1 | opacity |
| `scale` | 1 | scale around the anchor point (a box placed by an area scales around its centre) |
| `x`, `y` | 0 | offset in multiples of the thing's own size, or of the content rect in a transition. Down is positive |
| `rotation` | 0 | degrees, clockwise |
| `reveal` | 1 | how much is shown, 0 to 1 |
| `nudge` | 0 | moves an arrow towards its target by multiples of its length |

How the rules play out when you write keys:

- **Each property joins only the keys that name it.** In the span above, opacity goes from 0 to 1 over the first 30 percent and then stays at 1, while scale runs from 0.6 to 1 over the whole span. You do not repeat `opacity: 1` on the last key.
- **A property no key names stays at its default.** A span that only names `y` never fades.
- **A property named once holds that value for the whole span.** `{ "t": 0, "opacity": 0.5 }` alone keeps it at half opacity.
- **The ease bends progress before any key is read**, so one ease drives every property. With `back-out`, progress runs past 1 near the end and comes back. A property whose keys reach `t: 1` follows its last line past the end and overshoots (scale goes a little above 1 and settles). A property whose keys stop before `t: 1`, like opacity above, just holds. That is how a pop overshoots in size without flashing above full opacity.
- **`x` and `y` are relative to the thing itself.** `"y": 0.5` on a subtitle moves it down by half its own text box, whatever its size. In a transition they are relative to the content rect, so `"x": -1` moves a picture exactly out to the left.
- **`reveal` depends on what receives it.** A box draws its border around, a fill paints from `revealFrom`, a dim closes in from everything it darkens to the area, an arrow grows from tail to head, and a title, media clip, adjustment or storyline picture is wiped from `revealFrom` (default `left`).

| ease | Use it for |
| --- | --- |
| `linear` | opacity ramps and anything that should not accelerate |
| `ease-out` | things arriving: fast, then settling (the entrance default) |
| `ease-in` | things leaving: slow, then gone (the exit default) |
| `ease-in-out` | motion between two places (the loop default) |
| `back-out` | arrivals that overshoot and settle |
| `bounce-out` | arrivals that bounce |
| `step` | holds the start until the end of the span |
| `[x1, y1, x2, y2]` | a cubic Bezier, as CSS `cubic-bezier()` writes it |

## A transition

A transition plays across the edit point between two storyline clips. It moves the incoming clip, the outgoing clip, or both, and may lay a cover or a matte over them.

`drop-in.json`, the next clip comes down from the top and covers the previous one, which darkens a little under it:

```json
{ "description": "The next clip drops in from the top and covers the previous one, which dims under it. For a change of topic in a vertical video",
  "seconds": 0.4, "ease": "ease-out",
  "incoming": { "keys": [ { "t": 0, "y": -1 }, { "t": 1, "y": 0 } ] },
  "outgoing": { "keys": [ { "t": 0, "opacity": 1 }, { "t": 1, "opacity": 0.4 } ] } }
```

| Key | What it does |
| --- | --- |
| `seconds` | the default length, required. A document can write `{ "preset": "mine/drop-in", "seconds": 0.6 }` instead |
| `ease` | the default ease of every span in the preset |
| `over` | which clip is on top: `incoming` (default) or `outgoing`. An uncover moves the outgoing clip off with `outgoing` on top |
| `audio` | the curve of the sound crossfade: `constant-power` (default), for two different sounds, or `constant-gain`, for a cut inside one take. It runs at an even pace, and `ease` does not bend it |
| `incoming`, `outgoing` | spans of the two clips. A picture reads opacity, scale, x, y, rotation and reveal, all about the centre of the content rect |
| `cover` | `{color, keys}` or `{media, keys}` over both clips: a dip to a colour, or a stinger. Its keys take only `t` and `opacity` |
| `matte` | `{media, softness, invert}`: a luma wipe from a greyscale image or video |

What happens in a sequence:

- The transition belongs to the clip it brings in and is centred on the edit point. Its length is `min(seconds, previous clip's duration, next clip's duration)`, and it does not change the sequence's length.
- During it the outgoing clip plays on past its `out` and the incoming clip starts before its `in`, on media beyond them (the handles). Trim with a little media to spare on both sides, or the edge frame holds.
- Spans inside a transition take no `seconds` or `period`. Writing one stops, since a transition's time is its length.
- The first storyline clip takes no transition. To open from black, start with a solid clip and give the next one the transition.

A dip to a colour hides the change behind a cover. Keep the incoming clip invisible until the cover is at full opacity, then cut it in:

```json
{ "description": "Dips to the accent red and comes up on the next clip. For a reveal of a result",
  "seconds": 0.6, "ease": "linear",
  "cover": { "color": "accent", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 1 }, { "t": 1, "opacity": 0 } ] },
  "incoming": { "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 0 }, { "t": 0.5, "opacity": 1 } ] } }
```

Two keys at the same `t` make a cut: before it the first holds, from it the second. Here the incoming clip appears at once at the middle, behind a full cover.

A wipe of any shape is a matte: a greyscale image where the incoming clip shows first in the dark parts and last in the light ones. A horizontal gradient from black on the left to white on the right gives a left to right wipe, and a radial gradient, black at the centre and white at the corners, gives an iris. Make it at the output's aspect ratio, since it is stretched over the content rect. Any size will do for a smooth gradient. `softness` is the width of the edge, from 0 (hard) to 1, and `invert` swaps dark and light. A matte only reveals the incoming clip, so `"over": "outgoing"` with a matte stops.

```json
{ "description": "The next clip opens from the centre in a soft circle. For a calm reveal",
  "seconds": 0.6, "ease": "ease-in-out",
  "matte": { "media": "/path/to/iris.png", "softness": 0.15 } }
```

A video in a cover or a matte is stretched over the transition, so a longer transition plays it slower rather than cutting it.

## An animation

An animation moves a clip as it comes in, while it stays, and as it goes. A clip takes it through `animation`, or from the theme `defaults.animation` when it names none.

`lift.json`, rises a little as it fades in, breathes while it stays, and fades out:

```json
{ "description": "Rises a little while it fades in, breathes while it stays, then fades out. For a caption that stays on screen for a while",
  "entrance": { "seconds": 0.4, "ease": "back-out",
                "keys": [ { "t": 0, "y": 0.3, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "y": 0 } ] },
  "loop":     { "period": 1.2,
                "keys": [ { "t": 0, "scale": 1 }, { "t": 0.5, "scale": 1.04 }, { "t": 1, "scale": 1 } ] },
  "exit":     { "seconds": 0.2,
                "keys": [ { "t": 0, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

| Span | Runs | Needs | Default ease |
| --- | --- | --- | --- |
| `entrance` | for `seconds` from the start of the clip's visible window | `seconds` | `ease-out` |
| `loop` | every `period` seconds between the entrance and the exit | `period` | `ease-in-out` |
| `exit` | for the last `seconds` of the visible window | `seconds` | `ease-in` |

What happens on a clip:

- Every span is optional. A preset with only an entrance appears with it and then simply stays.
- The visible window is what counts. A title at `[2, 5]` with `lift` enters from 2 to 2.4, breathes from 2.4 to 4.8, and fades from 4.8 to 5.
- On a clip shorter than both, the entrance runs first and the exit gets what is left.
- The animation is applied over the clip's own keyframes about the same anchor point: scale and opacity multiply, and x, y and rotation add. A title keyframed to `scale: 1.5` with a `frames/pop` still pops, to 1.5.
- A loop that should end where it started gives its first and last keys the same values, or the clip jumps at each period.
- A document can take the entrance of one preset and the exit of another: `{ "entrance": "mine/lift", "exit": "none" }`. Both sides are written.
- A label on a shape animates on top of its shape with `labelAnimation`, or the theme's `label` default.

## A filter

A filter is a chain of operations from a fixed table, applied in order. Each operation has a formula, so a filter looks the same on every renderer ([FRAMES-15](../spec/FRAMES-15/SPEC.md) has the formulas).

`warm-screen.json`, a warm, slightly lifted look for screen recordings that keeps text crisp:

```json
{ "description": "Warmer and a little lifted, with crisp text. For screen recordings that look cold",
  "ops": [ { "op": "temperature", "kelvin": 900 },
           { "op": "saturation", "amount": 0.9 },
           { "op": "levels", "input": [0, 1], "output": [0.04, 0.97] },
           { "op": "sharpen", "amount": 0.4, "radius": 1.5 } ] }
```

| op | Parameters |
| --- | --- |
| `exposure` | `ev` |
| `contrast` | `amount` (1 is none) |
| `saturation` | `amount` (0 is grey, 1 is none) |
| `temperature` | `kelvin` (positive is warmer) |
| `hue` | `degrees` |
| `sepia` | `amount` (0 to 1) |
| `levels` | `input: [black, white]`, `output: [black, white]` (0 to 1) |
| `lut` | `file` (`<pack>/<name>` for a pack's `luts/<name>.cube`, or an absolute path), `amount` (0 to 1) |
| `blur` | `radius` |
| `sharpen` | `amount`, `radius` |
| `bloom` | `amount`, `radius`, `color` optional |
| `vignette` | `amount`, `radius` (0 to 1 of half the diagonal) |
| `pixelate` | `size` |
| `grain` | `amount` (0 to 1), `size` |

- Order matters. Sharpen after a blur gives crisp blur; blur after a sharpen undoes it.
- `radius` and `size` are theme lengths: points at the theme `baseWidth`, scaled to the output. A `blur` radius of 8 looks the same on a 1080 and a 2160 wide output.
- An unknown op or a value out of range stops when the preset is read, so a typo never renders as no effect.
- A look made of colour alone is usually one `lut` op. Put the `.cube` file in the pack's `luts/` and name it `<pack>/<name>`.

A filter goes on a storyline or media clip as `filter`, on everything below an adjustment clip as `adjust`, and in an image document as an `adjust` operation. A list of filters runs one after another: `"filter": ["mine/warm-screen", "frames/vignette"]`.

## Trying a preset

Try it in a document small enough to read at a glance, then check frames with `still` or `sheet`. Neither encodes a video.

**As a document choice.** Name the file in the place that takes it:

```json
{ "kind": "sequence",
  "format": { "size": [1080, 1920], "fps": 30 },
  "storyline": [
    { "solid": "#1F2937", "duration": 2,
      "connected": [ { "at": [0.2, 2], "title": "Before", "style": "headline", "animation": "/path/to/lift.json" } ] },
    { "solid": "#F59E0B", "duration": 2, "transition": "/path/to/drop-in.json",
      "connected": [ { "title": "After", "style": "headline" } ] }
  ] }
```

**As a theme default.** A theme file sets it for every clip that names none, without touching the document:

```json
{ "defaults": { "transition": "/path/to/drop-in.json", "animation": { "title": { "headline": "/path/to/lift.json" } } } }
```

```sh
frames --theme /path/to/try.json still /path/to/try-document.json --at 1.8,2,2.2 -o /path/to/out/try.png
```

Then look at it:

```sh
frames timeline /path/to/try-document.json                                   # the transition and its real length
frames still /path/to/try-document.json --at 1.8,1.9,2,2.1,2.2 -o /path/to/out/edit.png
frames sheet /path/to/try-document.json -o /path/to/out/entrance.png --from 0.2 --to 0.7 --step 0.05 --cols 5
frames evaluate /path/to/try-document.json --at 0.3                          # bounds and opacity as numbers
```

- `timeline` shows the transition with the length it really gets, which is shorter than `seconds` when a clip is short.
- `still` with several times puts them side by side, each labelled with its time. Five frames across an edit point show a transition's shape.
- `sheet` with a small `--step` lays out every frame of an entrance.
- `evaluate` prints each item's `bounds` and `opacity` at one instant. Use it to check that a key lands where you meant: at `t = 0` of `lift` the title's opacity is 0 and its bounds sit 30 percent of its height lower.
