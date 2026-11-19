# FRAMES-15: Filter

Status: accepted

## Summary

Filter presets as chains of operations from a fixed table, each with its formula in the working space, with published parameters inside the operations, and the filter choice that applies them with arguments.

## Motivation

A grade, a blur or a film look made in one place is used on many shots and must look the same wherever the document is rendered. If an op were a name only, swapping the renderer would change every look, so the formulas are the contract and a renderer maps each op to its own. Editors also set a look per shot, as a colourist turns a grain down on a dark scene or a vignette up on a close-up, so a filter publishes the numbers worth changing and a document sets them without copying the preset.

## Rules

A filter preset is a chain of operations from this table, applied in order. The operations are frames vocabulary and their formulas are the contract, so every renderer maps them to its own and a preset looks the same on each.

```json
{ "description": "Lifted blacks, muted colour and a fine grain, like a print film stock.",
  "params": {
    "lift":  { "type": "number", "default": 0.08, "description": "how far the blacks are lifted" },
    "grain": { "type": "number", "default": 0.05, "description": "strength of the grain" } },
  "ops": [ { "op": "saturation", "amount": 0.8 },
           { "op": "levels", "input": [0, 1], "output": [{ "param": "lift" }, 0.95] },
           { "op": "grain", "amount": { "param": "grain" }, "size": 2 } ] }
```

| op | Parameters | Meaning |
| --- | --- | --- |
| `exposure` | `ev` | multiplies linear light by 2^ev |
| `contrast` | `amount` (1 is none) | (v - 0.5) × amount + 0.5 |
| `saturation` | `amount` (0 is grey, 1 is none) | L + amount × (v - L) |
| `temperature` | `kelvin` (positive is warmer) | multiplies linear light, channel by channel, by the colour of a blackbody at 6500 - kelvin K over its colour at 6500 K, each in linear sRGB at equal luminance (CIE 1931 2° observer), with the temperature kept between 1000 and 40000 K |
| `hue` | `degrees` | the `hue-rotate()` matrix of W3C Filter Effects |
| `sepia` | `amount` (0 to 1) | the `sepia()` matrix of W3C Filter Effects at that amount |
| `levels` | `input: [black, white]`, `output: [black, white]` (0 to 1) | maps input levels to output levels |
| `lut` | `file` (a `.cube` 3D LUT), `amount` (0 to 1) | maps colours through the LUT, applied to sRGB-encoded values with trilinear interpolation, and blends the result by `amount` |
| `blur` | `radius` (theme length) | Gaussian blur whose standard deviation is `radius` |
| `sharpen` | `amount`, `radius` (theme length) | unsharp mask: v + amount × (v - the blur of v at `radius`) |
| `bloom` | `amount`, `radius` (theme length), `color` optional | adds amount × the blur at `radius` of the bright parts (each pixel times smoothstep(0.5, 1, L)), times `color` when one is given (halation) |
| `vignette` | `amount`, `radius` (fraction of half the diagonal) | multiplies by 1 - amount × smoothstep(radius, 1, d), where d is the distance from the centre over half the diagonal |
| `pixelate` | `size` (theme length) | square blocks, each filled with the mean colour of the pixels it covers |
| `grain` | `amount` (0 to 1), `size` (theme length) | adds amount × 4L(1 - L) × n to each channel, where n is monochrome noise with standard deviation 1 and grains `size` across. Evaluation writes its `seed` ([FRAMES-20](../FRAMES-20/SPEC.md)), so a render made again has the same grain |

- An unknown op stops when the preset is read, and so does a parameter outside its range: the ranges in the table, `levels` with black at or above white, a length or size (`radius`, `size`) at or below 0, and a `vignette` radius outside 0 to 1. A length or size that two keyframes or more write may be 0 in them, as its sampled value may ([FRAMES-4](../FRAMES-4/SPEC.md)), while one a single keyframe writes is checked as a static value, and an op at a length or size of 0 leaves the picture as it is. An op written in place on a choice is checked by the same ranges, statically and with each keyframe's parameters over it.
- Every op has values at which it leaves the picture as it is, its identity: `exposure` `ev` 0, `contrast` and `saturation` `amount` 1, `temperature` `kelvin` 0, `hue` `degrees` 0, `levels` `input` and `output` `[0, 1]`, `sepia`, `lut`, `sharpen`, `bloom`, `vignette` and `grain` `amount` 0, and `blur` `radius` and `pixelate` `size` 0. An op eases in or out by keyframing its parameters from or to its identity, and a whole entry by its `mix` ([Filter choice](#filter-choice)), since `"none"` against a preset stops.
- Op parameters are numbers, lists of numbers, colours, or for `lut` a file: `<pack>/<name>` for `luts/<name>.cube` in a pack, or an absolute path.
- v is a channel of a pixel's colour with alpha unpremultiplied, and L is its luminance ([FRAMES-21](../FRAMES-21/SPEC.md)). Colour operations leave alpha as it is, and every operation's result is clamped to 0 to 1. smoothstep is as in GLSL.
- Blur, sharpen, bloom and pixelate work on colour premultiplied by alpha, so a transparent pixel adds nothing to its neighbours, and their result is clamped so that alpha and the unpremultiplied colour lie in 0 to 1. A bloom colour's alpha scales the bloom.
- `pixelate` blocks lie on a grid from the picture's top left corner, and a block holds the pixels whose centres lie in it, so a block at the right or bottom edge averages fewer pixels.
- A `vignette` radius of 1 leaves every pixel nearer the centre than half the diagonal as it is.
- A grain is a square `size` pixels across on a grid from the picture's top left corner, and n is one value for the whole grain, drawn from the seed and the grain's place on the grid.
- The result has the size of the input. Operations that pull in pixels from beyond the edge (blur) read the edge pixels extended outward, and are cropped back to the original size.
- Every renderer computes these formulas in the working space ([FRAMES-21](../FRAMES-21/SPEC.md)). Pixels differ between renderers only by rounding, and grain by its noise generator, which is the renderer's.

### Parameters

A filter preset publishes `params` as every preset does ([FRAMES-14](../FRAMES-14/SPEC.md)), with the parameter table of [FRAMES-17](../FRAMES-17/SPEC.md). Inside `ops`, `{"param": "<name>"}` stands for a number wherever an op takes a number, an element of `input` and `output` included, and for a colour where an op takes a colour (`bloom` `color`). It never stands for an `op` name, a key or a `lut` file. A filter has no ease, so its parameters are `number` or `color`, and a `choice` stops. The ranges above are checked when the preset is read, with every parameter at its default, again with the arguments a choice gives, naming that choice, and with the arguments each keyframe gives over them, naming that keyframe, where an argument that two keyframes or more write may put a length or size at 0.

### Filter choice

| Form | Meaning |
| --- | --- |
| `"none"` | no filter. On a clip it turns off the theme's default filter |
| a preset name | that preset with its defaults: `<pack>/<name>` or an absolute path |
| `{preset, args, mix}` | that preset with arguments, as [FRAMES-14](../FRAMES-14/SPEC.md) checks them, and its `mix`. At least one of `args` and `mix` is required, since the name alone is the form above. Without `preset` it merges over the theme's default filter when that is one entry ([FRAMES-22](../FRAMES-22/SPEC.md)), so `{"mix": 0.5}` is the default filter at half strength |
| an op | one operation of the op table above written in place, `{"op": ..., ..., "mix": m}`, as a preset's `ops` holds it, with numbers where a preset would take `{"param"}`, and its `mix` |
| a list of names, `{preset, args}` and ops | each in turn, the first applied first |

- A list holds at least one entry and no `"none"`. An empty list, or one that holds `"none"`, stops.
- The same preset may appear twice in a list, each time with its own arguments.
- **An entry written as an object takes `mix`, from 0 to 1, default 1: its result is its input mixed with the entry's filtered result by `mix`**, as Premiere Pro's effect opacity and After Effects' Blend With Original mix an effect with the picture it was applied to. Each channel is `input + (filtered - input) × mix`, premultiplied by alpha, on the working space's sRGB-encoded values ([FRAMES-21](../FRAMES-21/SPEC.md)), so `mix` 0 leaves the picture as it is and `mix` 1 is the entry alone. A preset entry mixes the result of its whole chain, and the next entry takes the mixed picture. `mix` is keyframable, so a preset fades in by its `mix` from 0 with none of its op parameters written out, and a fix to the preset still reaches it. `mix` is checked against 0 to 1 as an op parameter is. A preset's own ops take no `mix`, since an entry is what a choice writes.
- A filter choice is keyframable on every clip that takes one, and so is an adjustment clip's `adjust` ([FRAMES-7](../FRAMES-7/SPEC.md)). Its structure is static, written on the clip or taken from the theme's default filter ([FRAMES-22](../FRAMES-22/SPEC.md)): its entries in order, their presets and ops, and their `lut` files. Its timed leaves are its preset arguments, its op parameters that are numbers or colours and its entries' `mix`: a keyframe's `filter` writes the ones it moves, over that structure, each preset's ops taking its arguments at each instant, and between two keyframes that write it each leaf interpolates by the keyframe's ease ([FRAMES-4](../FRAMES-4/SPEC.md)). A keyframe that writes a preset, an op, a `lut` or `"none"`, or a list of another length, stops. A sampled parameter is clamped to its op's range, and a length to 0 or more, where 0 leaves the picture as it is.

```json
"filter": [ "frames/warm", { "preset": "studio/film", "args": { "grain": 0.02 } } ]
```

## Interactions

The working space is [FRAMES-21](../FRAMES-21/SPEC.md). Which clips take a filter, and at what size it is applied, is [FRAMES-9](../FRAMES-9/SPEC.md) and [FRAMES-11](../FRAMES-11/SPEC.md). An adjustment clip's `adjust` is a filter choice ([FRAMES-11](../FRAMES-11/SPEC.md)). The default filter is in the theme ([FRAMES-22](../FRAMES-22/SPEC.md)). Shipped filters are [FRAMES-16](../FRAMES-16/SPEC.md). Parameters share the table of [FRAMES-17](../FRAMES-17/SPEC.md).

## Alternatives considered

Names without formulas: the meaning of a shipped preset's numbers would be each renderer's. A filter without parameters: a grain turned down for one dark shot would be a copy of the whole preset. A parameter that stands for a LUT file or an op: the preset's files and chain would then be the document's, while a preset is checked whole when it is read. A pack ships one filter per LUT instead, and a template's `choice` picks among them ([FRAMES-17](../FRAMES-17/SPEC.md)).

## Notes
