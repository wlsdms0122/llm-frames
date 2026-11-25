# Writing a preset

A preset is one JSON file: a transition, an animation, a filter or a stroke's head. frames reads it as data, so a new one needs no rebuild. The format is [FRAMES-14](../spec/FRAMES-14/SPEC.md) for transitions and animations, [FRAMES-15](../spec/FRAMES-15/SPEC.md) for filters and [FRAMES-11](../spec/FRAMES-11/SPEC.md#shapes) for heads. This page shows how to write each kind, how to publish parameters, how a document passes arguments, and how to look at the result.

## Where a preset lives

A preset lives in a pack, in `presets/<kind>/<name>.json`, where the kind is `transition`, `animation`, `filter` or `head`. A document names it `<pack>/<name>`. The examples on this page are the presets of a pack called `studio`:

```
$FRAMES_HOME/packs/studio/
  pack.json
  presets/
    transition/dip.json             studio/dip
    transition/drop-in.json         studio/drop-in
    transition/uncover-down.json    studio/uncover-down
    transition/iris.json            studio/iris
    animation/lift.json             studio/lift
    animation/type-on.json          studio/type-on
    filter/film.json                studio/film
    head/hook.json                  studio/hook
  media/iris.png                    studio/iris.png
```

| Name in a document | File |
| --- | --- |
| `frames/pop` | a preset of the pack `frames`, which ships with frames ([FRAMES-16](../spec/FRAMES-16/SPEC.md)) |
| `studio/dip` | `$FRAMES_HOME/packs/studio/presets/transition/dip.json` |
| `/path/to/dip.json` | that file |

The place a name is written says which kind is meant, so a transition and an animation may share a name, as `frames/fade` does. While you write a preset, an absolute path is the quickest way to try it. Once it works, put it in a pack so documents name it as `<pack>/<name>`. Installing a pack and writing `pack.json` are in [PACK.md](PACK.md).

Every preset has a `description`: one sentence on how it looks and moves, which `frames presets` prints. It says what the viewer sees ("The next clip drops in from the top and covers the previous one"), never what the preset is for, since that differs from one edit to the next. Unknown keys and broken rules stop when the preset is read.

## Spans and keys

Transitions and animations are made of spans. A span runs from progress 0 to progress 1, and its keys say what each motion property is at a point of that progress.

```json
{ "seconds": 0.35, "ease": "back-out", "revealFrom": "left",
  "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "scale": 1 } ] }
```

| Property | Default | What it moves |
| --- | --- | --- |
| `opacity` | 1 | opacity, multiplied with the clip's own, 0 to 1 |
| `scale` | 1 | scale around the clip's anchor point |
| `x`, `y` | 0 | offset in multiples of the clip's own size, its box before any scale. In a transition, multiples of the frame. Right and down are positive |
| `rotation` | 0 | degrees, clockwise, around the anchor point |
| `reveal` | 1 | how much of the clip shows, 0 to 1, wiped with a hard edge from the `revealFrom` side (`left`, `right`, `top` or `bottom`, default `left`) |

How the rules play out when you write keys:

- **Each property joins only the keys that name it, in straight lines.** In the span above, opacity goes from 0 to 1 over the first 30 percent and then holds, while scale runs from 0.6 to 1 over the whole span. You do not repeat `"opacity": 1` on the last key.
- **A property no key names stays at its default.** A span that names only `y` never fades.
- **A property named once holds that value for the whole span.** `{ "t": 0, "opacity": 0.5 }` alone keeps it at half opacity.
- **Two keys of a property at the same `t` make a cut.** Before that point the first value holds, from it the second.
- **The ease bends progress before any key is read**, so one ease drives every property. With `back-out`, bent progress runs past 1 near the end and comes back. A property whose keys reach `t: 1` follows its last line past the end and overshoots, so scale goes a little above 1 and settles. A property whose keys stop before `t: 1`, like opacity above, holds. That is how a pop overshoots in size without passing full opacity.
- **`x` and `y` are relative to the clip itself.** `"y": 0.5` on a title moves it down by half its own text box, whatever its size.
- **`reveal` wipes every clip the same way**: the bounds of what the clip draws, cut with a straight edge that turns and moves with the clip. To draw a stroke on, keyframe a shape's `trim` instead ([FRAMES-11](../spec/FRAMES-11/SPEC.md)).
- `opacity` and `reveal` keys outside 0 to 1 stop, and so does a `t` outside 0 to 1.

## Eases

An ease is a name, a cubic Bézier or a spring, an object that says it is a spring with `kind`. The formulas are [FRAMES-4](../spec/FRAMES-4/SPEC.md).

| ease | Shape |
| --- | --- |
| `linear` | an even rate |
| `ease-in` | starts slow and speeds up (cubic) |
| `ease-out` | starts fast and slows into place (cubic) |
| `ease-in-out` | slow at both ends |
| `back-out` | fast, past the end, and back |
| `bounce-out` | lands and bounces three times |
| `step` | holds the start until the end of the span |
| `[x1, y1, x2, y2]` | a cubic Bézier, as CSS `cubic-bezier()` writes it. `x1` and `x2` lie in 0 to 1 |
| `{ "kind": "spring", "bounce": b }` | a damped spring that lands exactly at the end of the span |

A spring's `bounce` lies between -1 and 1, both ends excluded. At 0 it settles with no overshoot. Above about 0.134 it swings past the end and back before it settles, more the higher it is. Below 0 it approaches more slowly. The span's length sets the spring's speed, so the same bounce over 0.3 seconds is a snap and over 1 second a slow settle. A spring above 0 overshoots like `back-out`: a property whose keys reach `t: 1` swings past its last value.

## A transition

A transition plays across the edit point between two storyline clips. It moves the incoming picture, the outgoing picture or both, and may lay a cover or a matte over them. It moves nothing else. A connected clip keeps its place, except one parented to a storyline picture, which follows the picture's scale, rotation, x and y but not its opacity or reveal ([FRAMES-10](../spec/FRAMES-10/SPEC.md)). To have a title leave with its picture in a dissolve or a wipe, put both in a compound clip and give the transition to that clip.

`studio/drop-in`, the next clip comes down from the top and covers the previous one, which darkens under it:

```json
{ "description": "The next clip drops in from the top and covers the previous one, which darkens under it.",
  "seconds": 0.5, "ease": "ease-out",
  "incoming": { "keys": [ { "t": 0, "y": -1 }, { "t": 1, "y": 0 } ] },
  "outgoing": { "keys": [ { "t": 0, "opacity": 1 }, { "t": 1, "opacity": 0.4 } ] } }
```

| Key | What it does |
| --- | --- |
| `seconds` | the default length, required. A document's transition choice may give its own |
| `ease` | the ease of every span in the preset that gives none. Without one it is `linear` |
| `over` | which picture is on top: `incoming` (default) or `outgoing` |
| `audio` | the curve of the sound crossfade: `constant-power` (default) or `constant-gain`. It runs at an even pace, and `ease` does not bend it |
| `incoming`, `outgoing` | spans of the two storyline pictures. Each reads opacity, scale, x, y, rotation and reveal |
| `cover` | `{"kind": "solid", color, keys}` or `{"kind": "media", media, colorSpace, keys}`: a colour or an image or video with alpha over both pictures, stretched over the frame. Its keys take `t` and `opacity` only |
| `matte` | `{media, colorSpace, softness, invert}`: a luma wipe from a greyscale image or video |

- The motion acts after the picture's own transform: scale and rotation about the centre of the frame, x and y in multiples of the frame, so `"x": -1` moves a picture exactly out to the left.
- Spans in a transition take no `seconds` or `period`, since a transition's time is its length.
- A cover's or a matte's `colorSpace` names the colour space of its media over what the file says, as a media clip's does. A cover's HDR media are tone mapped as a clip's with `toneMap` true are, and a matte is read as an SDR picture whatever the sequence's colour space, so a wipe is the same for every output ([FRAMES-14](../spec/FRAMES-14/SPEC.md), [FRAMES-26](../spec/FRAMES-26/SPEC.md#media)).
- In a sequence the transition belongs to the clip it brings in and is centred on the edit point. It lasts the shorter of its seconds and the two clips' durations, and it does not change the sequence's length. During it the outgoing clip plays on past its `out` and the incoming one starts before its `in`, so trim with media to spare on both sides ([FRAMES-8](../spec/FRAMES-8/SPEC.md)).

**A dip.** A cover hides the change. Keep the incoming picture invisible until the cover is opaque, then cut it in with two keys at the same `t`. `studio/dip` publishes the colour and the pace as parameters ([Parameters](#parameters)):

```json
{ "description": "Dips to a colour and holds a beat, then the next clip comes up out of it.",
  "params": {
    "color": { "type": "color", "default": "#000000", "description": "colour of the dip" },
    "curve": { "type": "choice", "options": ["linear", "ease-in-out"], "default": "linear", "description": "pace of the fade" } },
  "seconds": 0.7, "ease": { "param": "curve" },
  "incoming": { "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 0 }, { "t": 0.5, "opacity": 1 } ] },
  "cover": { "kind": "solid", "color": { "param": "color" },
             "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 0.6, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

**An uncover.** With `"over": "outgoing"` the previous picture stays on top and moves away. `studio/uncover-down` also crossfades the sound at constant gain, which keeps the level of two sounds that are the same signal, such as a cut inside one take ([FRAMES-13](../spec/FRAMES-13/SPEC.md)):

```json
{ "description": "The previous clip falls away downwards and uncovers the next one, which waits still beneath.",
  "seconds": 0.5, "ease": "ease-in", "over": "outgoing", "audio": "constant-gain",
  "outgoing": { "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": 1 } ] } }
```

**A wipe of any shape** is a matte: a greyscale image stretched over the frame, where the incoming picture shows first in the dark parts and last in the light ones. A horizontal gradient from black on the left to white on the right wipes left to right, and a radial gradient, black at the centre and white at the corners, opens an iris. Make it at the output's aspect ratio. `softness` is the width of the edge, from 0 (hard) to 1, and `invert` swaps dark and light. A matte reveals the incoming picture, so a matte with `"over": "outgoing"` stops. A video in a cover or a matte is stretched over the transition, so a longer transition plays it slower.

```json
{ "description": "The next clip opens from the centre of the frame in a soft-edged circle.",
  "params": { "softness": { "type": "number", "default": 0.15, "description": "width of the circle's edge" } },
  "seconds": 0.6, "ease": "ease-in-out",
  "matte": { "media": "studio/iris.png", "softness": { "param": "softness" } } }
```

## An animation

An animation moves a clip as it comes in, while it stays, and as it goes. Titles, media clips with a picture, shapes and adjustment clips take one through `animation`, or from the theme's `defaults.animation` when they name none ([FRAMES-22](../spec/FRAMES-22/SPEC.md)). A storyline clip takes none.

`studio/lift` springs up a little as it fades in, breathes while it stays, and fades out:

```json
{ "description": "Springs up a little from below as it fades in, breathes while it stays, and fades out.",
  "params": { "bounce": { "type": "number", "default": 0.3, "description": "how far it springs past its place" } },
  "entrance": { "seconds": 0.5, "ease": { "kind": "spring", "bounce": { "param": "bounce" } },
                "keys": [ { "t": 0, "y": 0.3, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "y": 0 } ] },
  "loop":     { "period": 1.2,
                "keys": [ { "t": 0, "scale": 1 }, { "t": 0.5, "scale": 1.04 }, { "t": 1, "scale": 1 } ] },
  "exit":     { "seconds": 0.2,
                "keys": [ { "t": 0, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

`studio/type-on` wipes a clip in and out with `reveal`, and publishes the length of its entrance:

```json
{ "description": "Wiped in from the left at an even pace and wiped away from the right.",
  "params": { "seconds": { "type": "number", "default": 0.8, "description": "how long the wipe in takes" } },
  "entrance": { "seconds": { "param": "seconds" }, "ease": "linear", "revealFrom": "left",
                "keys": [ { "t": 0, "reveal": 0 }, { "t": 1, "reveal": 1 } ] },
  "exit":     { "seconds": 0.3, "revealFrom": "left",
                "keys": [ { "t": 0, "reveal": 1 }, { "t": 1, "reveal": 0 } ] } }
```

| Span | Runs | Needs | Default ease |
| --- | --- | --- | --- |
| `entrance` | for `seconds` from the start of the clip's visible window | `seconds` | `ease-out` |
| `loop` | every `period` seconds from the end of the entrance to the start of the exit | `period` | `ease-in-out` |
| `exit` | for the last `seconds` of the visible window | `seconds` | `ease-in` |

- Every span is optional. A preset with only an entrance appears with it and then stays. A preset with no span shows the clip as it is.
- The visible window is what counts. A title at `[2, 5]` with `studio/lift` enters from 2 to 2.5, breathes from 2.5 to 4.8, and fades from 4.8 to 5. On a clip too short for both, the entrance runs first and the exit takes what is left.
- The animation acts over the clip's own keyframes about the same anchor point: scale and opacity multiply, and x, y and rotation add. A title keyframed to `"scale": 1.5` with `frames/pop` still pops, to 1.5.
- An entrance starts hidden and ends with every property at its default, an exit does the opposite, and a loop starts and ends at the defaults, or the clip jumps where one span hands over to the next.
- Clips parented to an animated clip follow its scale, rotation, x and y, but not its opacity or reveal ([FRAMES-10](../spec/FRAMES-10/SPEC.md)).

## A filter

A filter is a chain of operations from a fixed table, applied in order. Each operation has a formula, so a filter looks the same on every renderer. The formulas and ranges are [FRAMES-15](../spec/FRAMES-15/SPEC.md).

`studio/film`, lifted blacks, muted colour and a fine grain:

```json
{ "description": "Lifted blacks, muted colour and a fine grain, like a print film stock.",
  "params": {
    "lift":  { "type": "number", "default": 0.08, "description": "how far the blacks are lifted" },
    "grain": { "type": "number", "default": 0.05, "description": "strength of the grain" } },
  "ops": [ { "kind": "saturation", "amount": 0.8 },
           { "kind": "levels", "input": [0, 1], "output": [{ "param": "lift" }, 0.95] },
           { "kind": "grain", "amount": { "param": "grain" }, "size": 2 } ] }
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
| `lut` | `file` (`<pack>/<name>` for a pack's `luts/<name>.cube`, or an absolute path), `amount` (0 to 1), `space` (the colour space the LUT was built for, `srgb` by default) |
| `blur` | `radius` |
| `sharpen` | `amount`, `radius` |
| `bloom` | `amount`, `radius`, `color` optional |
| `vignette` | `amount`, `radius` (0 to 1 of half the diagonal) |
| `displace` | `file` (a displacement map, a raster still: `<pack>/<name.ext>` for a file in a pack's `media/`, or an absolute path), `amount`, `offset: [x, y]` (`[0, 0]` by default) |
| `pixelate` | `size` |
| `grain` | `amount` (0 to 1), `size` |

- Each operation in `ops` names its op with `kind` and takes the parameters of its row, as an op written in a document's `filter` does.
- Order matters: a sharpen after a blur sharpens the blurred picture, and a blur after a sharpen softens the sharpened one.
- `radius`, `size` and a `displace`'s `amount` and `offset` are theme lengths, so a blur of 8 looks the same on a 1080 and a 2160 wide output.
- An unknown op or a value out of range stops when the preset is read.
- A look made of colour alone is usually one `lut` op. Put the `.cube` file in the pack's `luts/`, and give `space` when the LUT was not built for sRGB: `srgb-linear` for one built on linear sRGB, or the HDR or wide gamut space it was made in ([FRAMES-26](../spec/FRAMES-26/SPEC.md#colour-spaces)).

A filter goes on a storyline clip or a media clip as `filter`, and on everything below an adjustment clip as `adjust`.

## A head

A head is what a stroke draws at its `start` or `end`: a closed outline filled in the stroke's paint. frames ships six in the pack `frames`: `frames/arrow`, `frames/line-arrow`, `frames/circle`, `frames/square`, `frames/diamond` and `frames/bar` ([FRAMES-16](../spec/FRAMES-16/SPEC.md)). A head is written in units of its stroke's width, with its tip at the origin, pointing along +x, y running to the right of the direction it points.

`studio/hook`, a filled arrow with a notch cut into its base:

```json
{ "description": "A filled arrow 5 widths long and wide, its base notched 1.5 widths deep.",
  "points": [[0, 0], [-5, 2.5], [-3.5, 0], [-5, -2.5]],
  "length": 5,
  "inset": 3.5 }
```

| Key | Meaning |
| --- | --- |
| `points` | the outline, at least two vertices, each `[x, y]` or `{vertex, inTangent, outTangent}` as a path's vertex is written. Nothing of it, its tangents included, lies past the tip at x = 0 |
| `length` | how much of the stroke the head takes, the distance back from the tip to its base, above 0 |
| `inset` | how far back from the tip the stroke's line stops, from 0 to `length`. Put it where the line's end is hidden inside the head, here the notch |

- A document names it as `"end": "studio/hook"` or `"end": { "preset": "studio/hook", "scale": 1.5 }`. Its size is the stroke's width times `scale`, so a head takes no `params`.
- On a curved end the head keeps its shape: its tip sits on the end, its base on the stroke `length` back along it, and it is smaller by the chord between them over its length.
- A point past the tip, a `length` of 0 or less, an `inset` outside 0 to `length` or fewer than two vertices stops when the preset is read.

## Parameters

A preset may publish parameters, as an NLE effect publishes its controls, so one dip gives a dip to black in one edit and to a brand blue in another. `params` maps a name to a parameter: its `type`, its `default` and a one-line `description` of what it changes, with `options` for a choice. The parameter object and its keys are the same for templates and presets, and [PACK.md](PACK.md#parameters) has the table. A preset adds these limits:

- `type` is `number`, `color` or `choice`. A preset holds no text and no media.
- `default` is required, so a preset named without arguments always works.
- A `choice`'s `options` are eases. A filter has no ease, so its parameters are `number` or `color`.

Inside the preset, `{"param": "<name>"}` stands for a value of the parameter's type where one is written:

| Type | Where `{"param"}` may stand |
| --- | --- |
| `number` | a key's property value or `t`, a span's `seconds` or `period`, a transition's `seconds`, `matte.softness`, a spring's `bounce`, a filter op's number, an element of `levels` `input` and `output` |
| `color` | a cover `color`, a `bloom` `color` |
| `choice` | a span's or a transition's `ease` |

It never stands for a key, for a name (`revealFrom`, `over`, `audio`, a `kind`, a `colorSpace`, a `lut` `space`) or for a file (`media`, a `lut`, `displace` or `convolve` file). frames checks a preset when it reads it: every `{"param"}` names one of its parameters and stands where its type is taken, every parameter is used somewhere, and every value is in range with each parameter at its default. When a document passes arguments, the values are checked again with them, and the stop names the place in the document.

## Passing arguments

A document passes arguments in its preset choices. The same choice may be written on a clip, in a theme's `defaults`, or as a template's argument.

| Choice | Forms |
| --- | --- |
| transition | `"cut"`, a preset name, or `{preset, seconds, args}` |
| animation | `"none"`, a preset name, or `{preset, args, entrance, exit}`, each key optional, and on a title `by`, `stagger` and `order` |
| a side, `entrance` or `exit` | `"none"`, a preset name, or `{preset, args}` with both keys |
| filter | `"none"`, a preset name, a preset entry `{"kind": "preset", "preset": ..., "args": ..., "mix": m}`, an op `{"kind": <op>, ...}`, or a list of those applied in turn |

```json
"transition": { "preset": "studio/dip", "seconds": 1, "args": { "color": "#1B3A6B", "curve": "ease-in-out" } },
"animation": { "preset": "studio/lift", "args": { "bounce": 0.5 } },
"animation": { "entrance": { "preset": "studio/type-on", "args": { "seconds": 1.2 } }, "exit": "frames/fade" },
"adjust": [ "frames/warm", { "kind": "preset", "preset": "studio/film", "args": { "grain": 0.02 } } ]
```

- An object choice that names `preset` needs at least one other key, since the name alone is the plain form. One that names none merges over the theme's default choice key by key ([FRAMES-22](../spec/FRAMES-22/SPEC.md)), so `{"exit": "none"}` is the default animation without its exit, and `{"kind": "preset", "mix": 0.5}` is a default filter of one preset entry at half strength. A choice that names a preset replaces the default whole.
- `seconds` in a transition choice replaces the preset's own and is above 0.
- `args` maps parameter names to values. An unknown name, or a value of the wrong type (for a choice, one that is not among its options), stops. A parameter without an argument takes its default.
- An animation choice takes its entrance, loop and exit from its `preset`, or from the default it merges over where it names none, and `entrance` and `exit` each replace that one span with the span of the same name in the side's own preset, with its own arguments. So `{entrance, exit}` takes the entrance of one preset and the exit of another and keeps the default's loop, and a choice that must play no loop names a `preset` that has none. A side with no span is `"none"`.
- The presets of the pack `frames` publish no parameters, so they are named bare, and an argument given to one stops as unknown.

## Trying a preset

List what frames finds, with each preset's description and parameters:

```sh
frames presets                              # every preset of every pack, by kind
frames presets transition                   # the transitions
frames presets transition studio/dip        # the JSON of one preset
frames packs studio                         # what the pack holds, with each preset's parameters
```

Then try the preset in a document small enough to read at a glance:

```json
{ "kind": "sequence",
  "format": { "size": [1920, 1080], "fps": 30 },
  "storyline": [
    { "kind": "solid", "color": "#1F2937", "duration": 3,
      "connected": [ { "at": [0.5, 3], "kind": "title", "text": "Before", "style": "title",
                       "animation": { "preset": "studio/lift", "args": { "bounce": 0.5 } } } ] },
    { "kind": "solid", "color": "#F59E0B", "duration": 3,
      "transition": { "preset": "studio/dip", "seconds": 1, "args": { "color": "#1B3A6B", "curve": "ease-in-out" } },
      "connected": [ { "kind": "title", "text": "After", "style": "title",
                       "animation": { "entrance": { "preset": "studio/type-on", "args": { "seconds": 1.2 } }, "exit": "frames/fade" } } ] },
    { "kind": "solid", "color": "#0F766E", "duration": 3, "transition": "studio/iris",
      "connected": [ { "kind": "adjustment", "adjust": [ "frames/warm", { "kind": "preset", "preset": "studio/film", "args": { "grain": 0.02 } } ] } ] }
  ] }
```

```sh
frames timeline /path/to/try.json
frames still /path/to/try.json --at 2.6,2.8,3,3.2,3.4 -o /path/to/out/dip.png
frames sheet /path/to/try.json -o /path/to/out/lift.png --from 0.5 --to 1 --step 0.05 --cols 11
frames evaluate /path/to/try.json --at 0.5
```

- `timeline` shows each transition with the length it really gets, which is shorter than `seconds` when a clip is short, and each clip's animation.
- `still` with several times lays the frames side by side, each labelled with its time. Five frames across an edit point show the shape of a transition.
- `sheet` lays out every frame of a range. A small `--step` over an entrance shows each step of its motion.
- `evaluate` prints each clip's `bounds` and `opacity` at one instant, to check that a key lands where you meant: at the start of `studio/lift` the title's opacity is 0 and its bounds sit 30 percent of its height lower.

Every path given to frames is absolute. Neither `still` nor `sheet` encodes a video. Render one only to judge motion at speed or to hear a crossfade.
