# FRAMES-15: Filter

Status: accepted

## Summary

Filter presets as chains of operations from a fixed table, each with its formula in the working space.

## Motivation

A preset must look the same on every renderer, or swapping the renderer changes every look. The formulas are the contract, so a renderer maps each op to its own and keeps the result.

## Rules

A filter preset is a chain of operations from this table, applied in order. The operations are frames vocabulary and their formulas are the contract, so every renderer maps them to its own and a preset looks the same on each.

```json
{ "description": "...", "ops": [ { "op": "saturation", "amount": 0 }, { "op": "contrast", "amount": 1.3 } ] }
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
| `sharpen` | `amount`, `radius` | unsharp mask: v + amount × (v - the blur of v at `radius`) |
| `bloom` | `amount`, `radius`, `color` optional | adds amount × the blur at `radius` of the bright parts (each pixel times smoothstep(0.5, 1, L)), times `color` when one is given (halation) |
| `vignette` | `amount`, `radius` (fraction of half the diagonal) | multiplies by 1 - amount × smoothstep(radius, 1, d), where d is the distance from the centre over half the diagonal |
| `pixelate` | `size` (theme length) | square blocks, each filled with the mean colour of the pixels it covers |
| `grain` | `amount` (0 to 1), `size` (theme length) | adds amount × 4L(1 - L) × n to each channel, where n is monochrome noise with standard deviation 1 and grains `size` across. Evaluation writes its `seed` ([FRAMES-20](../FRAMES-20/SPEC.md)), so a render made again has the same grain |

- An unknown op stops when the preset is read, and so does a parameter outside its range: the ranges in the table, `levels` with black at or above white, a length or size (`radius`, `size`) at or below 0, and a `vignette` radius outside 0 to 1.
- Parameters are numbers, lists of numbers, colours, or for `lut` a file: `<pack>/<name>` for `luts/<name>.cube` in a pack, or an absolute path.
- v is a channel of a pixel's colour with alpha unpremultiplied, and L is its luminance ([FRAMES-21](../FRAMES-21/SPEC.md)). Colour operations leave alpha as it is, and every operation's result is clamped to 0 to 1. smoothstep is as in GLSL.
- The result has the size of the input. Operations that pull in pixels from beyond the edge (blur) read the edge pixels extended outward, and are cropped back to the original size.
- Every renderer computes these formulas in the working space ([FRAMES-21](../FRAMES-21/SPEC.md)). Pixels differ between renderers only by rounding, and grain by its noise generator, which is the renderer's.

## Interactions

The working space is [FRAMES-21](../FRAMES-21/SPEC.md). Shipped filters are [FRAMES-16](../FRAMES-16/SPEC.md).

## Alternatives considered

Names without formulas: the meaning of a shipped preset's numbers would be each renderer's.

## Notes
