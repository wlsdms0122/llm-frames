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
| `exposure` | `ev` | multiplies the linear form by 2^ev |
| `contrast` | `amount` (1 is none) | (v - 0.5) × amount + 0.5 |
| `saturation` | `amount` (0 is grey, 1 is none) | L + amount × (v - L) |
| `temperature` | `kelvin` (positive is warmer) | multiplies the linear form, channel by channel, by the colour of a blackbody at 6500 - kelvin K over its colour at 6500 K, each in linear sRGB at equal luminance (CIE 1931 2° observer), with the temperature kept between 1000 and 40000 K |
| `hue` | `degrees` | the `hue-rotate()` matrix of W3C Filter Effects |
| `sepia` | `amount` (0 to 1) | the `sepia()` matrix of W3C Filter Effects at that amount |
| `levels` | `input: [black, white]`, `output: [black, white]` (0 to 1) | maps input levels to output levels: output black + (v - input black) / (input white - input black) × (output white - output black), linear on every real number |
| `lut` | `file` (a `.cube` 3D LUT), `amount` (0 to 1), `space` (default `srgb`) | maps colours through the LUT built for the encoded values of `space`, as Premiere Pro takes the colour space a LUT was made for: the pixel converted from its working value to `space` ([FRAMES-26](../FRAMES-26/SPEC.md)), each channel clipped to the LUT's domain (its `DOMAIN_MIN` to `DOMAIN_MAX`, 0 to 1 where it gives none), looked up with trilinear interpolation, and converted back to a working value w, then mixed by `amount`: v + (w - v) × amount, a form-free formula (below) |
| `blur` | `radius` (theme length) | Gaussian blur whose standard deviation is `radius` |
| `sharpen` | `amount`, `radius` (theme length) | unsharp mask: v + amount × (v - the blur of v at `radius`) |
| `bloom` | `amount`, `radius` (theme length), `color` optional | adds the blur of the bright parts: v + amount × c × blur(w × v), where w = smoothstep(0.5, 1, clamp(L, 0, 1)) is each pixel's weight, blur is the blur at `radius` and c is the channel of `color` when one is given (halation) and 1 otherwise. w is computed from luma, and the products, the blur and the sum in the form `compositing` names ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)) |
| `vignette` | `amount`, `radius` (fraction of half the diagonal) | v × (1 - amount × smoothstep(radius, 1, d)), where d is the distance from the centre over half the diagonal: a mix towards black in the form `compositing` names ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)) |
| `displace` | `file` (a displacement map, a raster still), `amount` (theme length), `offset: [x, y]` (theme lengths, default `[0, 0]`) | moves pixels by the map: the pixel at p takes the input at p + amount × (2 × m - 1), where m is the map's red and green values at p, red for x and green for y, so a map value of 0.5 moves nothing, 1 reads from `amount` to the right or below and 0 from `amount` to the left or above ([Displacement](#displacement)) |
| `pixelate` | `size` (theme length) | square blocks, each filled with the mean colour of the pixels it covers |
| `grain` | `amount` (0 to 1), `size` (theme length) | adds amount × 4L'(1 - L') × n to each channel, with L' = clamp(L, 0, 1), where n is monochrome noise with standard deviation 1 and grains `size` across. Evaluation writes its `seed` ([FRAMES-20](../FRAMES-20/SPEC.md)), so a render made again has the same grain |

- An unknown op stops when the preset is read, and so does a parameter outside its range: the ranges in the table, `levels` with black at or above white, a length or size (`radius`, `size`, a `displace` `amount`) at or below 0, and a `vignette` radius outside 0 to 1. A length or size that two keyframes or more write may be 0 in them, as its sampled value may ([FRAMES-4](../FRAMES-4/SPEC.md)), while one a single keyframe writes is checked as a static value, and an op at a length or size of 0 leaves the picture as it is. An op written in place on a choice is checked by the same ranges, statically and with each keyframe's parameters over it.
- Every op has values at which it leaves the picture as it is, its identity: `exposure` `ev` 0, `contrast` and `saturation` `amount` 1, `temperature` `kelvin` 0, `hue` `degrees` 0, `levels` `input` and `output` `[0, 1]`, `sepia`, `lut`, `sharpen`, `bloom`, `vignette` and `grain` `amount` 0, and `blur` `radius`, `pixelate` `size` and `displace` `amount` 0. Each identity leaves every value as it is, HDR and wide gamut values included. An op eases in or out by keyframing its parameters from or to its identity, and a whole entry by its `mix` ([Filter choice](#filter-choice)), since `"none"` against a preset stops.
- Op parameters are numbers, lists of numbers, colours, or for `lut` a file, `<pack>/<name>` for `luts/<name>.cube` in a pack or an absolute path, and a `space`, a name whose `lut` column in the table of [FRAMES-26](../FRAMES-26/SPEC.md) says yes, and for `displace` a file, named as a media file is ([FRAMES-3](../FRAMES-3/SPEC.md)): `<pack>/<name.ext>` for a file in a pack's `media/` or an absolute path. Any other name stops when the preset is read.
- v is a channel of a pixel's working value with alpha unpremultiplied, any real number, in the form the op takes (below), and L is its luma ([FRAMES-26](../FRAMES-26/SPEC.md)). Each formula is read on every real value as it is written, and **no op clamps its result**: a value above 1 or below 0 goes to the next op as it is, as the floating point pipelines of After Effects at 32 bits per channel, Final Cut Pro and Premiere Pro keep overbright values between effects, and only the output clips it ([FRAMES-26](../FRAMES-26/SPEC.md#output)). A weight that only has a meaning from 0 to 1 takes its value clamped to that range, as the table writes it and as [FRAMES-26](../FRAMES-26/SPEC.md#working-values) gives: L in `bloom` and `grain`; `lut` clips to its domain, and `vignette` weighs by distance, not by colour. `levels` is linear on every real number and clamps nothing. Colour operations leave alpha as it is. smoothstep is as in GLSL.
- Every op gives a finite value from finite values: `exposure` and `temperature` take the linear form by the extended sRGB transfer, which keeps the sign, and encode their result by it ([FRAMES-26](../FRAMES-26/SPEC.md#working-values)), `levels` divides by its input range, which is never 0, `lut` clips what it looks up to its domain and takes its output back from an HDR `space` from encoded values clipped to 0 to 1 ([FRAMES-26](../FRAMES-26/SPEC.md#colour-spaces)), and the other ops add and multiply finite values by finite weights.
- An `srgb` sequence therefore differs from a pipeline that clamps every op's result to 0 to 1 only where an op's result lies outside 0 to 1 and is read again before the output: by a later op, a `mix` below 1, a blend or a composite at partial alpha. Where the output reads it first, the output's clip to 0 to 1 gives the same pixel.
- Blur, sharpen, bloom, pixelate and displace work on colour premultiplied by alpha and on alpha, so a transparent pixel adds nothing to its neighbours. Their result's alpha is clamped to 0 to 1, the range of alpha, and a pixel whose alpha is then 0 is transparent with colour 0. Their colour is not clamped. A bloom colour's alpha scales the bloom.
- `pixelate` blocks lie on a grid from the picture's top left corner, and a block holds the pixels whose centres lie in it, so a block at the right or bottom edge averages fewer pixels.
- A `vignette` radius of 1 leaves every pixel nearer the centre than half the diagonal as it is.
- A grain is a square `size` pixels across on a grid from the picture's top left corner, and n is one value for the whole grain, drawn from the seed and the grain's place on the grid.
- An op's lengths are in the pixels of the box the filter is written for ([FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-20](../FRAMES-20/SPEC.md#pictures)). A picture is filtered at the scale it is shown at, with each length multiplied by the factor of the unit it is written in, a carried length by one factor and a width in output pixels by another, as [FRAMES-20](../FRAMES-20/SPEC.md#pictures) gives, so a length keeps its size against the box at any scale.
- The result has the size of the input. Operations that pull in pixels from beyond the edge (blur, displace) read the edge pixels extended outward, and are cropped back to the original size.
- Every renderer computes these formulas on working values, each in the form [FRAMES-26](../FRAMES-26/SPEC.md#compositing) gives it: every formula in its home, the encoded form `srgb`, for `exposure` and `temperature`, whose parameters are quantities of light, the linear form `srgb-linear`, and for a `lut`'s lookup its `space`, and every form-free formula in the form the sequence's `compositing` names, the interpolation of a `displace` among them. Above 1 an op at home on the encoded form follows the extended sRGB curve whatever `compositing` is ([FRAMES-26](../FRAMES-26/SPEC.md#working-values)). Pixels differ between renderers only by rounding, and grain by its noise generator, which is the renderer's.

### Displacement

A displacement map says, for every pixel of a picture, where its colour is read from: red moves along x and green along y. It is data as a LUT is, a LUT mapping colours and a map positions, so a refraction, a heat haze, a ripple, a bulge or a twirl is a file and no code, and a renderer swapped for another moves the same pixels.

- **The map is a weight field, not a picture.** Its `file` is a raster still, read as a picture of encoded working values in the colour space its tags name, an untagged one as `srgb` ([FRAMES-26](../FRAMES-26/SPEC.md#media)), with no tone mapping, so an untagged or sRGB file gives its code values, at the precision of a working picture ([FRAMES-21](../FRAMES-21/SPEC.md)). Each value is a weight and is clamped to 0 to 1 ([FRAMES-26](../FRAMES-26/SPEC.md#working-values)), which a file tagged with a wider space can leave, so `amount` is the farthest a pixel moves. A video, an image sequence, a page of a PDF or a sequence document stops, and so does a still whose colour no formula defines ([FRAMES-26](../FRAMES-26/SPEC.md#media)), since a map has no `colorSpace` to write. A map is read by its tags whatever `colorSpace` another place writes for the same file, since that key corrects a picture and a map is not one. Its colour is read alone, premultiplied as every picture's is, so a transparent part reads as 0. Its blue channel and its alpha are not read.
- **The map is laid over the box the filter is written for, stretched to it, moved by `offset` and repeated beyond its edges.** With the box w by h and its origin at its top left, the map's value at a point p of the box is the map sampled at ((p.x - offset.x) / w, (p.y - offset.y) / h) in the map's own unit square, each coordinate taken modulo 1, with bilinear interpolation between the centres of the map's pixels, the pixels across an edge of the map being those of its other side. A map of any size therefore covers the box once at `offset` `[0, 0]`, and a map that tiles scrolls without a seam as `offset` moves.
- **A pixel whose centre is at p takes the input at p + amount × (2 × m(p) - 1)**, m(p) the map's red and green values there, with bilinear interpolation between the centres of the input's pixels, each channel premultiplied by alpha, a form-free formula (above). Where that point lies beyond the picture's edge it reads the edge pixels extended outward. The values are not clamped.
- `amount` and `offset` are lengths in the pixels of the box, scaled as every length of an op is (above), so a map moves a picture by the same share of its box at any scale. `offset` takes any real number and is keyframable, its two numbers moved as one, as a point is ([FRAMES-4](../FRAMES-4/SPEC.md)).
- At 8 bits a channel a map has no code value for 0.5: 128 moves by amount / 255. A map that must leave a part still is written at 16 bits, where 32768 moves by at most amount / 65535.

### Parameters

A filter preset publishes `params` as every preset does ([FRAMES-14](../FRAMES-14/SPEC.md)), with the parameter table of [FRAMES-17](../FRAMES-17/SPEC.md). Inside `ops`, `{"param": "<name>"}` stands for a number wherever an op takes a number, an element of `input` and `output` included, and for a colour where an op takes a colour (`bloom` `color`). It never stands for an `op` name, a key, a `lut` or `displace` file or a `lut` `space`. A filter has no ease, so its parameters are `number` or `color`, and a `choice` stops. The ranges above are checked when the preset is read, with every parameter at its default, again with the arguments a choice gives, naming that choice, and with the arguments each keyframe gives over them, naming that keyframe, where an argument that two keyframes or more write may put a length or size at 0.

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
- **An entry written as an object takes `mix`, from 0 to 1, default 1: its result is its input mixed with the entry's filtered result by `mix`**, as Premiere Pro's effect opacity and After Effects' Blend With Original mix an effect with the picture it was applied to. Each channel is `input + (filtered - input) × mix`, premultiplied by alpha, a form-free formula in the form the sequence's `compositing` names ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)), so `mix` 0 leaves the picture as it is and `mix` 1 is the entry alone. A preset entry mixes the result of its whole chain, and the next entry takes the mixed picture. `mix` is keyframable, so a preset fades in by its `mix` from 0 with none of its op parameters written out, and a fix to the preset still reaches it. `mix` is checked against 0 to 1 as an op parameter is. A preset's own ops take no `mix`, since an entry is what a choice writes.
- A filter choice is keyframable on every clip that takes one, and so is an adjustment clip's `adjust` ([FRAMES-7](../FRAMES-7/SPEC.md)). Its structure is static, written on the clip or taken from the theme's default filter ([FRAMES-22](../FRAMES-22/SPEC.md)): its entries in order, their presets and ops, and their `lut` and `displace` files and `lut` spaces. Its timed leaves are its preset arguments, its op parameters that are numbers or colours and its entries' `mix`: a keyframe's `filter` writes the ones it moves, over that structure, each preset's ops taking its arguments at each instant, and between two keyframes that write it each leaf interpolates by the keyframe's ease ([FRAMES-4](../FRAMES-4/SPEC.md)). A keyframe that writes a preset, an op, a `lut` or `displace` file, a `lut` `space` or `"none"`, or a list of another length, stops. A sampled parameter is clamped to its op's range, and a length to 0 or more, where 0 leaves the picture as it is. Every parameter of an op but `bloom`'s `color`, `lut`'s `space` and `displace`'s `offset` is required: an op written in place, on the clip or as the theme's default, may leave one to its keyframes, which give it at every instant, and a parameter that neither the op nor its keyframes write stops, as one a preset's op leaves out does.

```json
"filter": [ "frames/warm", { "preset": "studio/film", "args": { "grain": 0.02 } } ]
```

## Interactions

Working values, their forms, luma and the colour spaces a LUT is built for are [FRAMES-26](../FRAMES-26/SPEC.md). Which clips take a filter, and at what size it is applied, is [FRAMES-9](../FRAMES-9/SPEC.md) and [FRAMES-11](../FRAMES-11/SPEC.md). An adjustment clip's `adjust` is a filter choice ([FRAMES-11](../FRAMES-11/SPEC.md)). The default filter is in the theme ([FRAMES-22](../FRAMES-22/SPEC.md)). Shipped filters are [FRAMES-16](../FRAMES-16/SPEC.md). Parameters share the table of [FRAMES-17](../FRAMES-17/SPEC.md).

## Alternatives considered

Every op's result clamped to 0 to 1: the first filter would cut an HDR highlight and a wide gamut colour back to SDR sRGB, and a grade could not bring down a highlight an earlier op pushed above white.

`levels` with its input level clamped to 0 to 1, as image editors map levels: its identity would clip HDR and wide gamut values, so an op eased in from its identity would cut the highlights at its first frame, and a grade could not bring them down. Linear on every real number, its identity is exact.

Names without formulas: the meaning of a shipped preset's numbers would be each renderer's. A filter without parameters: a grain turned down for one dark shot would be a copy of the whole preset. A parameter that stands for a LUT file or an op: the preset's files and chain would then be the document's, while a preset is checked whole when it is read. A pack ships one filter per LUT instead, and a template's `choice` picks among them ([FRAMES-17](../FRAMES-17/SPEC.md)).

A displacement written as code, a shader or an expression per pixel: every renderer would have to run that language, and a look would be a program. A map holds the same field as data, and a tool outside frames computes it.

A map that is another clip of the document, as After Effects takes a displacement map layer: a filter op would then name a clip, while a preset is checked whole when it is read and is used on many documents. A map that moves is a map that tiles with its `offset` keyed, two entries scrolling against each other where the field must change shape, or a clip cut where the map changes.

A map that is a video: its frame would need a time, the clip's or the sequence's, looped or held past its end, a second timing model inside a filter.

Transparent pixels beyond the edge, as `feDisplacementMap` of W3C Filter Effects reads them: a displaced video would show holes along its edges, and an editor would scale it up to hide them. Edge pixels extended outward are what `blur` reads.

The W3C form, scale × (m - 0.5), where `scale` is the whole span of the move: `amount` is the farthest a pixel moves, the number an editor sets as After Effects's Max Displacement.

## Notes
