# FRAMES-14: Presets: motion, animation and transition

Status: accepted

## Summary

Presets as data files with published parameters: how a preset declares parameters and a document passes arguments, the motion properties and spans every preset shares, animation presets (entrance, loop, exit) and transition presets (motion of the two storyline pictures, cover, matte and the sound crossfade).

## Motivation

Editors reuse motion. The same cross dissolve runs between hundreds of shots, every lower third enters the same way, and each chapter of a film dips to the same colour. Final Cut Pro and Premiere Pro keep these as effects applied by name, each with a few published controls (a colour, a direction, a softness) set per use. frames keeps them as data files with parameters, so a look is shared and sold without a rebuild, an agent writes a new one without code, and one dip with a `color` parameter gives a dip to black in one place and a dip to a brand blue in another, where two copies of the file would drift apart as soon as one is fixed. Spans of keys over progress let any entrance, loop or wipe be written without code.

## Rules

A preset is one JSON file at `presets/<transition|animation|filter|audio>/<name>.json`, an audio preset being an audio filter ([FRAMES-13](../FRAMES-13/SPEC.md)). `<pack>/<name>` is a preset in a pack ([FRAMES-17](../FRAMES-17/SPEC.md)), the ones frames ships in the pack `frames` (`frames/pop`), and an absolute path reads that file. Adding a preset needs no rebuild.

Every preset has a `description`: one line on how it looks and moves, which `presets` prints. It says what the viewer sees, not what the preset is for. Unknown keys and broken rules in a preset stop when it is read.

### Parameters and arguments

A preset may publish parameters, as an NLE effect publishes its controls. `params` maps a name to a parameter, the same object a template's parameters are ([FRAMES-17](../FRAMES-17/SPEC.md)), with these limits for a preset:

- `type` is `number`, `color` or `choice`. A preset holds no text and no media, so any other type stops.
- `default` is required, so a preset named without arguments always works.
- A `choice`'s `options` are eases ([FRAMES-4](../FRAMES-4/SPEC.md)).

Inside the preset, `{"param": "<name>"}` stands for a value of the parameter's type wherever a number, a colour or an ease is written: a key's property value or `t`, a span's `seconds` or `period`, a transition's `seconds`, `matte.softness`, a cover `color`, a spring's `bounce`, or a span's or transition's `ease`. It never stands for a key, a name (a `revealFrom` side, `over`, `audio`) or a file, and written there it is a value of the wrong type for that place, which stops as one. A number parameter stands only where a number is written, a colour parameter only where a colour is, and a choice only where an ease is.

```json
{ "description": "Dips to a colour and holds a beat, then the next clip comes up out of it.",
  "params": {
    "color": { "type": "color", "default": "#000000", "description": "colour of the dip" },
    "curve": { "type": "choice", "options": ["linear", "ease-in-out"], "default": "linear", "description": "pace of the fade" } },
  "seconds": 0.7, "ease": { "param": "curve" },
  "incoming": { "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 0 }, { "t": 0.5, "opacity": 1 } ] },
  "cover": { "color": { "param": "color" },
             "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 0.6, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

A preset is checked when it is read: its keys, that every `{"param"}` names one of its parameters and stands where its type is taken, that every parameter is referred to (a declared parameter nothing refers to stops), and every value with each parameter at its default. Where a choice passes arguments, the values are checked again with them, and a value its place does not take (a `seconds` of 0, an opacity outside 0 to 1) stops, naming the choice's place. The stop names the preset and gives the reason its own check of that place gives.

A document passes arguments in its preset choices:

| Choice | Forms |
| --- | --- |
| transition choice | `"cut"`, a preset name, or `{preset, seconds, args}` |
| animation choice | `"none"`, a preset name, `{preset, args}`, or `{entrance, exit}`. On a title, either object form may also take `by` and `stagger` ([By character, word or line](#by-character-word-or-line)) |
| side of `{entrance, exit}` | `"none"`, a preset name, or `{preset, args}` |
| filter choice | [FRAMES-15](../FRAMES-15/SPEC.md) |

- A preset name is `<pack>/<name>` or an absolute path.
- An object choice needs at least one key besides `preset`: `{preset}` alone stops, since the name alone is that choice. An object without `preset` on a clip merges over the theme's default choice for that clip, and in a theme over the weaker theme's ([FRAMES-22](../FRAMES-22/SPEC.md)), so `{"by": "word"}` plays the default animation by word. Where nothing below gives a choice it stops.
- `seconds` in a transition choice replaces the preset's own. It is above 0, as a preset's own is, and 0 or less stops.
- `args` maps parameter names to values. An unknown name stops, a value of the wrong type stops (a choice value that is not one of its options included), and a parameter with no argument takes its default. An empty `args` gives every parameter its default.
- A choice is the same wherever it is written: on a clip ([FRAMES-7](../FRAMES-7/SPEC.md)), in a theme's `defaults` ([FRAMES-22](../FRAMES-22/SPEC.md)), or as a template's argument or option ([FRAMES-17](../FRAMES-17/SPEC.md)).

```json
"transition": { "preset": "studio/dip", "seconds": 1, "args": { "color": "#1B3A6B" } },
"animation": { "entrance": { "preset": "studio/spring-in", "args": { "bounce": 0.4 } }, "exit": "frames/fade" }
```

Resolve applies the arguments, so a resolved preset holds plain values and no parameters ([FRAMES-19](../FRAMES-19/SPEC.md)).

### Motion properties

| Property | Default | Meaning |
| --- | --- | --- |
| `opacity` | 1 | opacity, multiplied with the receiver's own |
| `scale` | 1 | scale around the anchor point ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| `x`, `y` | 0 | offset in multiples of the receiver's own size, its box before any scale ([FRAMES-1](../FRAMES-1/SPEC.md)). In a transition, multiples of the frame's width and height. Right and down are positive |
| `rotation` | 0 | degrees, clockwise positive, around the same point as `scale` |
| `reveal` | 1 | how much of the receiver shows: 0 nothing, 1 everything, wiped from the `revealFrom` side (below) |

`reveal` wipes every receiver the same way. The receiver's box is the bounds of everything it draws, in its own space before the animation's transform: a title's text box with its background, its runs' highlights and underlines, and its stroke, a media clip's box with its border and shadow, a shape's outline with its stroke, arrowheads and shadow, an adjustment's mask (the frame when it has none), and in a transition a storyline picture's frame. At reveal r, the part of that box from the `revealFrom` side up to r of its width (`left`, `right`) or of its height (`top`, `bottom`) shows, and the rest is hidden, with a hard straight edge. The edge lies in the receiver's own space, so it turns and moves with the receiver's transform.

**Note.** Drawing a stroke on, as an outline traced around or a line growing to its arrowhead, is a shape's `trim` keyframes ([FRAMES-11](../FRAMES-11/SPEC.md)), not a preset property. A preset that moves one kind of clip only would be a purpose built into a tool.

A span is:

```json
{ "seconds": 0.35, "ease": "back-out", "revealFrom": "left",
  "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "scale": 1 } ] }
```

- `t` is progress through the span, from 0 to 1.
- Each property joins only the keys that name it, in straight lines. Opacity can finish at 30% while scale runs to the end.
- Two keys that name a property at the same `t` make it jump there: it takes the first key's value up to that point and the second's from it.
- A property the span does not name takes its default.
- `ease` bends the progress first, and the bent value drives every property. It takes every ease form of [FRAMES-4](../FRAMES-4/SPEC.md), the spring included. Where an ease leaves 0 to 1 (`back-out`, a spring with bounce), a property whose keys reach that end goes on along its last line, so it overshoots. One whose keys stop short of it holds.
- `opacity` and `reveal` lie in 0 to 1, and a key's value outside that range stops.
- `revealFrom` is `left`, `right`, `top` or `bottom`. The default is `left`.

### animation

```json
{ "description": "...",
  "params": { ... },
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
- An animation is taken by titles, media clips with a picture, shapes and adjustments. A storyline clip takes none and moves only by its keyframes and its transitions.
- On a short clip the entrance runs first and the exit takes what time is left.
- `{entrance, exit}` as a choice takes the entrance span from one preset and the exit span from another, each with its own arguments, and no loop. Both sides are written, and a side without a span is `"none"`.
- An animation is applied over the clip's keyframes, about the same point: its scale and opacity multiply, and its x, y and rotation add. A preset's look is the same for every anchor point, made about that point.

### By character, word or line

A title's animation choice may take `by`, `character`, `word` or `line`, and `stagger`, the seconds from the start of one unit's span to the start of the next. The entrance and the exit then play on each unit of the title ([FRAMES-5](../FRAMES-5/SPEC.md)) in reading order, each unit moving about its own box, as Motion and Final Cut Pro sequence text and After Effects' text animators with a range offset move text. A span is the same motion for one unit as for a whole title, so every animation preset plays by unit without a change, and the unit, the order and the stagger are all a document has to say.

```json
"animation": { "preset": "frames/rise", "by": "word", "stagger": 0.08 }
```

| `by` | Default `stagger` |
| --- | --- |
| `character` | 0.04 |
| `word` | 0.12 |
| `line` | 0.3 |

- With n units numbered from 0 in reading order, a window from s to e, an entrance of `seconds` a and an exit of `seconds` x, unit i runs its entrance from s + i × `stagger` for a seconds, and its exit from e - x - (n - 1 - i) × `stagger` for x seconds, so the units leave in reading order too and the last one ends with the window. Before its entrance a unit holds the entrance at progress 0, and after its exit the exit at progress 1.
- On a short window the entrance runs first and the exit takes what time is left, as for a whole clip. With E = a + (n - 1) × `stagger` and X = x + (n - 1) × `stagger`, when E + X is longer than the window, the exit's `seconds` and `stagger` are both multiplied by (e - s - E) / X, and when E alone fills the window there is no exit.
- The loop, when the choice has one, plays on the whole title as it does without `by`, from the end of the last unit's entrance to the start of the first unit's exit. Its transform, opacity and `reveal` act on the title as one, in the title's own coordinates as without `by`: while it plays every unit rests, and its reveal wipes what the whole title draws, the units with it.
- A unit's motion acts about the centre of the unit's box. Its `x` and `y` are multiples of that box's size, its `reveal` wipes the bounds of everything the unit draws from the `revealFrom` side, as it wipes a receiver's box (above): its glyph box ([FRAMES-5](../FRAMES-5/SPEC.md)) grown by as far as its stroke reaches at that instant, and the parts of highlights and underlines it carries, so a unit at reveal 1 shows whole, and its opacity applies to the unit's glyphs and the parts it carries. The unit's motion is applied inside the title's own transform, so the title's keyframes, its parent and its loop carry every unit. **The units are composited as one group**: the title's opacity, blend, mask and track matte apply once, to all of its units drawn together, as they apply to the one picture of a title without `by` ([FRAMES-20](../FRAMES-20/SPEC.md)), so the units do not show through each other at the title's opacity.
- The paragraph background takes the title's keyframes and its loop, and no entrance or exit: it shows over the whole window. A run's highlight and underline are cut into parts that move with the units that carry them ([FRAMES-5](../FRAMES-5/SPEC.md)), so a highlighted word's box comes in with the word.
- `by` on the animation of a clip that is not a title stops, and so does `stagger` without `by`, a negative `stagger`, and `by` with a choice that has neither an entrance nor an exit, since `by` would move nothing. A theme's `defaults.animation.title` takes `by` and `stagger` as any title's choice does, and its `shape`, `media` and `adjust` entries do not.

### transition

```json
{ "description": "...",
  "params": { ... },
  "seconds": 0.45, "ease": "ease-in-out", "over": "incoming", "audio": "constant-power",
  "incoming": { "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
  "outgoing": { "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": -1 } ] },
  "cover":    { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

| Key | Meaning |
| --- | --- |
| `seconds` | default length, required. A transition choice's `seconds` replaces it |
| `ease` | default curve of incoming, outgoing, cover and matte, each of which may give its own `ease`. Without one it is `linear` |
| `over` | which storyline picture is on top during the transition: `incoming` (default) or `outgoing` |
| `audio` | the curve of the sound crossfade: `constant-power` (default) or `constant-gain` ([FRAMES-13](../FRAMES-13/SPEC.md)) |
| `incoming` | motion of the incoming storyline picture |
| `outgoing` | motion of the outgoing storyline picture |
| `cover` | `{color, keys}` or `{media, colorSpace, keys}`: a colour (a dip to colour) or an image or video with alpha (a stinger) over both storyline pictures, stretched over the frame. Its keys take `t` and `opacity` only |
| `matte` | `{media, colorSpace, softness, invert}`: a luma wipe (below) |

- A transition moves the two storyline pictures and nothing else. Each reads opacity, scale, x, y, rotation and reveal. The motion is applied after the picture's own transform ([FRAMES-9](../FRAMES-9/SPEC.md)): scale and rotation act around the centre of the frame, x and y move by multiples of the frame, opacity multiplies the picture's own, and reveal shows the frame from the `revealFrom` side. The two pictures and the cover are composited by source-over, a form-free formula, in the form the sequence's `compositing` names ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)), so a cross dissolve mixes light under `linear` and encoded values under `encoded`.
- `seconds` or `period` inside a span stops. A transition's time is its length.
- To change scenes while the cover hides them, cut the incoming opacity from 0 to 1 at that point.
- `matte.media` is a greyscale image or video, stretched over the frame. The incoming picture shows where the matte's luma ([FRAMES-26](../FRAMES-26/SPEC.md)), clamped to 0 to 1, is below the transition progress, with an edge `softness` wide (0 to 1 of the luma range, and a value outside stops). `invert` swaps dark and light. A still gradient gives the luma wipe (gradient wipe) of an NLE, and a black and white video gives a matte wipe that shows the incoming picture where it is black. Either gives any wipe shape without code. A matte reveals the incoming picture, so a transition with both `matte` and `"over": "outgoing"` stops.
- A cover's or a matte's `colorSpace` is a fact about its media file, as a media clip's is: a name whose Media column says yes, static, which replaces what the file says, the file's tags applying where it is left out, and every place that names the same file names the same colour space ([FRAMES-26](../FRAMES-26/SPEC.md#media)). It is a name, so no `{"param"}` stands for it.
- A cover's media take `toneMap` true and have no key for it, so an HDR stinger is tone mapped as a clip's with `toneMap` true is, and a stinger graded by hand is wrapped in a compound clip placed over the cut ([FRAMES-26](../FRAMES-26/SPEC.md#media)). A matte is a weight field, not a picture: its media are read as an analysis picture, in the colour space its `colorSpace` names or else the file's tags, whatever the sequence's colour space, so a wipe's shape and timing are the same for every output ([FRAMES-26](../FRAMES-26/SPEC.md#providers-and-analysis-pictures)).
- A video in `matte` or `cover` is stretched over the transition: at progress p it shows media time p × its duration, so the transition's seconds change its speed, not its shape.
- `audio` shapes the sound only. Its curve runs over the transition's time at an even pace, and the preset's `ease` does not bend it.

## Interactions

Presets come from packs ([FRAMES-17](../FRAMES-17/SPEC.md)), and preset parameters share the parameter table of templates there. The presets that ship are [FRAMES-16](../FRAMES-16/SPEC.md). Filter presets and the filter choice are [FRAMES-15](../FRAMES-15/SPEC.md). Ease forms, the spring included, are [FRAMES-4](../FRAMES-4/SPEC.md). Defaults are in the theme ([FRAMES-22](../FRAMES-22/SPEC.md)). Where the cover sits among the lanes is [FRAMES-9](../FRAMES-9/SPEC.md), and the crossfade gains are [FRAMES-13](../FRAMES-13/SPEC.md). Compositing and luma are [FRAMES-26](../FRAMES-26/SPEC.md). A clip parented to an animated clip or to a storyline picture in a transition follows the scale, rotation, x and y of that motion, but not its opacity or reveal ([FRAMES-10](../FRAMES-10/SPEC.md)). To have a title leave with its picture in a dissolve or a wipe, put both in a compound clip and give the transition to that clip ([FRAMES-9](../FRAMES-9/SPEC.md)).

## Alternatives considered

Effects as code: packs carry data only, so every role can draw them (README). Parameters as expressions, as After Effects writes them: an expression is code, set aside for the same reason. Presets without parameters: each variant (a dip to black, to white, to a brand colour) would be its own copy of the file, and a fix to one would not reach the others. A `reveal` that differs by receiver (an outline traced around on one kind of clip, a line grown from its tail on another): a property whose meaning depends on one kind of clip is a purpose built into a tool, and a shape's `trim` draws any stroke on. A motion property only one kind of clip reads, such as a jab towards a target: the same reason, and position keyframes or a parent give it. Transition offsets in multiples of the picture's own box: a picture scaled to half the frame would push only half a frame and leave a gap, while every NLE pushes and slides by the frame. Range selectors, as After Effects' text animators have, with per-unit randomness and wiggle: a selector is an expression of which units move how far, and the order and the stagger give the sequence text effects every NLE ships. An extension that needs each word on its own time, as a caption timed to speech, writes successive titles. Text by unit left to extensions, which could place a title for each unit from the glyph positions resolve reports: one line of text, its look and its one stagger would be spread over a title for each unit, and a change to the text or the stagger would rewrite them all ([FRAMES-25](../FRAMES-25/SPEC.md)). A loop that plays by unit: a pulse or a shake on each word at once is a wiggle by unit, and on the whole title it keeps the title one block while it stays. A transition that moves a picture together with the clips parented to it: it would move clips the editor did not put in the transition, and a compound clip already says what moves together.

## Notes
