# FRAMES-26: Colour

Status: accepted

## Summary

How frames holds colour from the decoder to the encoder: working values in extended-range sRGB on the sRGB primaries, with an encoded and a linear form, two lossless views of one value that `color()` writes as `srgb` and `srgb-linear`, what the extended sRGB curve makes of a formula above 1 and what the sRGB primaries make of a formula on each channel of a wide gamut colour; the colour spaces a sequence is output in, media are read in and a LUT is built for, with their primaries, transfers, tags and output policy; `format.colorSpace`, `format.peak` and `format.compositing`, the home of every formula and the form each form-free formula takes; how media are converted to working values by fixed formulas, inside the table of colour spaces and outside it, a `colorSpace` as a fact about a file, written where a media clip, a transition cover or a transition matte names it and one for every place that names it, HDR media tone mapped by the BT.2390 EETF from their peak to the sequence's where a clip's `toneMap` says so, and HLG taken to display light; the `color()` value; how a frame is clipped and encoded on output; and the analysis pictures, the normalised SDR pictures that providers and transition mattes read and that `still`, `sheet` and `extract` show as previews.

## Motivation

A colour must mean one thing in a document, in every role and in every file frames writes, or two renderers draw the same document in two colours. One working space serves every sequence: one coordinate system and one set of formulas, so every formula of the specification (blend modes, filters, gradients, luma) is computed one way for every output, on values above 1 as on values below it. The sequence's colour space decides the output, how it is encoded and clipped, and its peak, a PQ master's mastering peak where the sequence names one as DaVinci Resolve does, together with each clip, decides whether an HDR picture brighter than that peak is tone mapped down to it on the way in, as Premiere Pro's Auto Tone Map Media does. `still`, `sheet` and `extract` are SDR previews for looking at, the same normalised sRGB picture the providers read, and not the master: in an `srgb` or `rec709` sequence they show the master's colours to the rounding of 8 bits, and in a `display-p3`, `rec2020` or HDR sequence they clip its gamut to sRGB and tone map its light, so the master of those is checked with `render --at` ([Providers and analysis pictures](#providers-and-analysis-pictures)). Editors now cut HDR and wide gamut media beside SDR media: a phone records HLG, a camera P3 or BT.2020, a graphic arrives as sRGB. Without a fixed rule for converting each to the working values and back, a decoder that clips at 1 loses the HDR highlights and a P3 red, two decoders that tone map by their platform's own curve disagree (AVFoundation's HDR to SDR conversion is not a published formula), and two colour management modules read one ICC profile in two ways. Without `format.compositing`, a dissolve that should mix light, as Premiere Pro's Composite in Linear Color does, could only be approximated by stacking clips. Without `color()`, a colour brighter than reference white or outside sRGB could not be written at all.

## Rules

### Working values

A **working value** is a colour as frames holds it from the decoder to the encoder: red, green and blue on the sRGB primaries and D65 white point (BT.709), each any real number, and alpha from 0 to 1. One working space serves every sequence, whatever its colour space ([Sequence colour space](#sequence-colour-space)). A working value has two forms, which name the same colour:

| Form | Channels | Meaning |
| --- | --- | --- |
| encoded | R', G', B' | the extended sRGB transfer of the linear form. Documents, the resolved document and display lists write this form, and a formula that names encoded values reads it |
| linear | R, G, B | linear light, as scRGB (IEC 61966-2-2) without its quantisation |

In both forms 1 is SDR reference white, and on an HDR output it is 203 cd/m², the reference white of BT.2408. A channel below 0 is a colour outside the sRGB gamut (wide gamut). A channel above 1 is either light brighter than reference white (HDR) or a colour outside the sRGB gamut, or both, and only the colour's luminance, 0.2126 R + 0.7152 G + 0.0722 B on the linear form, says whether it is brighter than reference white: P3's red is the encoded value (1.0931, -0.2267, -0.1501), its red above 1 at a luminance of 0.2290, so it is wide gamut and not HDR. This is Apple's extended range sRGB.

**A form is a lossless view of the same working value, encoded or linear, while a colour space of the table ([Colour spaces](#colour-spaces)) is a set of coordinates with an output policy: its range, its peak and which places may write it.** `color()` writes either form on every real number, `color(srgb r g b)` the encoded working value as it is and `color(srgb-linear r g b)` its linear form ([Colour values](#colour-values)). The table's `srgb` has the encoded form's coordinates, and a sequence whose `colorSpace` is `srgb` is output in them with its output clipped to 0 to 1 ([Output](#output)), so `srgb` names one set of coordinates whether it holds a working value or a sequence's output. The table's `srgb-linear` has the linear form's, and only a `lut` names it, as the `space` of a LUT built on linear sRGB.

**The working basis is the sRGB primaries, by choice**: an `srgb` sequence computes every formula on the coordinates browsers and design tools compute it on, and gives their results. A weighted sum on the linear form (source-over, a blur, a `mix`, a product by a number) gives the same light on any primaries. A formula that acts on each channel by itself and not linearly (a product of two colours, a minimum or maximum, an absolute value, a bound of 1 on a channel) gives what it gives on the sRGB channels, and a wide gamut colour's channels lie below 0 or above 1 there, so on it such a formula can lose the character it has from 0 to 1: two negative channels multiply to a positive one. This is the cost of one working space on the sRGB primaries, and which blend modes it reaches is [FRAMES-11](../FRAMES-11/SPEC.md#blend-modes).

The **extended sRGB transfer** is the sRGB transfer of IEC 61966-2-1 taken to all real numbers, the sign kept and the same curve above 1, as CSS Color 4 extends it:

```
encode(L) = 12.92 × L                                  when |L| ≤ 0.0031308
          = sign(L) × (1.055 × |L|^(1/2.4) - 0.055)    otherwise

decode(V) = V / 12.92                                  when |V| ≤ 0.04045
          = sign(V) × ((|V| + 0.055) / 1.055)^2.4      otherwise
```

- R' = encode(R), and R = decode(R'), each channel on its own. Alpha is the same in both forms.
- A conversion between forms, or between a working value and a colour space, acts on the colour with alpha unpremultiplied and leaves alpha as it is. A picture holds its colours premultiplied by alpha ([FRAMES-21](../FRAMES-21/SPEC.md)): it is unpremultiplied before a conversion and premultiplied again after it, a pixel of alpha 0 staying 0.
- **Nothing clamps a working value but a rule that says so.** Gamut and peak are decided at the output, by clipping ([Output](#output)).
- **A weight that has a meaning only from 0 to 1 takes its value clamped to 0 to 1, and every other formula reads its values as they are.** The weights are luma in `bloom` and `grain` ([FRAMES-15](../FRAMES-15/SPEC.md)), a luma track matte ([FRAMES-11](../FRAMES-11/SPEC.md)) and a transition matte ([FRAMES-14](../FRAMES-14/SPEC.md)), and a LUT's input is clipped to its domain ([FRAMES-15](../FRAMES-15/SPEC.md)). Every blend mode is its W3C formula exactly as written, read on Cs and Cb as they are, with the bounds W3C writes inside a formula (`color-dodge`, `color-burn`, `plus-lighter`, `ClipColor`) kept as part of it, as After Effects computes its modes unclamped at 32 bits per channel. Which modes keep their character above 1 and below 0 is [FRAMES-11](../FRAMES-11/SPEC.md#blend-modes).
- **Luma** is the Rec. 709 luma of the encoded form, with alpha unpremultiplied: Y' = 0.2126 R' + 0.7152 G' + 0.0722 B'. Every rule that names luma means this value, a formula whose home is the encoded form ([Compositing](#compositing)).

**Note.** Above 1 and below 0 the encoded form is the extended sRGB curve carried on, which no HDR tool shares, and every formula whose home is the encoded form ([Compositing](#compositing)) follows that curve there, whatever `compositing` is: `contrast`, `saturation`, `hue`, `sepia`, `levels`, luma, the blend functions of `overlay`, `hard-light`, `soft-light`, `exclusion`, `hue`, `saturation`, `color` and `luminosity`, and `grain`'s weight. In a `rec2100-pq` sequence a highlight of 1000 cd/m² is the encoded value encode(1000 / 203) = 1.9952, and `contrast` at 1.2, (v - 0.5) × 1.2 + 0.5, takes it to 2.2942, which is 203 × decode(2.2942) = 1386 cd/m², while its pivot, the encoded value 0.5, is 203 × decode(0.5) = 43.45 cd/m². `grain`'s weight, 4L'(1 - L') with L' = clamp(L, 0, 1), is 0 wherever luma is at or above 1, reference white, so an HDR highlight takes no grain. Under `encoded` the form-free formulas take the same curve, so a dissolve between two HDR pictures, or a blur across a wide gamut edge, mixes values on a curve no other tool mixes them on. This is the cost of one working space whose formulas are written on encoded values, and it belongs to the working values, not to `compositing`: `linear` changes the form-free formulas only and leaves every other formula in its home. HDR grading that must act on light uses `exposure`, `temperature` or a `lut` with an HDR `space` ([FRAMES-15](../FRAMES-15/SPEC.md)), and under `linear` every form-free formula acts on light, the blend modes `add`, `multiply` and `screen` among them.

### Colour spaces

| Name | Primaries | Transfer | Range | Peak | Sequence `colorSpace` | Media `colorSpace` | `lut` `space` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `srgb` | BT.709 | sRGB (IEC 61966-2-1) | SDR | 203 cd/m² | yes, the default | yes | yes, the default |
| `display-p3` | P3 D65 (SMPTE EG 432-1) | sRGB | SDR | 203 cd/m² | yes | yes | yes |
| `rec2020` | BT.2020 | BT.1886, decoded by its EOTF and encoded by its inverse | SDR | 203 cd/m² | yes | yes | yes |
| `rec709` | BT.709 | BT.1886, decoded by its EOTF and encoded by its inverse | SDR | 203 cd/m² | yes | yes | yes |
| `rec2100-pq` | BT.2020 | PQ (SMPTE ST 2084, as BT.2100 gives it) | HDR | `format.peak`, 1000 cd/m² by default | yes | yes | yes |
| `rec2100-hlg` | BT.2020 | HLG (ARIB STD-B67, as BT.2100 gives it) | HDR | fixed 1000 cd/m² | yes | yes | yes |
| `srgb-linear` | BT.709 | linear, the identity | none, never output | none, never output | no | no | yes |

A space's **peak** is the most light its output holds: for a space of SDR range its white, the working value 1, which is 203 cd/m² ([Working values](#working-values)), for `rec2100-hlg` the fixed 1000 cd/m² of its OOTF, and for `rec2100-pq` the sequence's mastering peak, its `format.peak` ([Sequence colour space](#sequence-colour-space)), the light its output is clipped to ([Output](#output)). PQ's signal reaches 10000 cd/m², the top of its transfer's range, and that range is not a peak. A **sequence's peak** is the peak of its colour space, its `format.peak` for `rec2100-pq`.

Every space has the D65 white point, x 0.3127 and y 0.3290. Its primaries are these chromaticities:

| Primaries | Red (x, y) | Green (x, y) | Blue (x, y) |
| --- | --- | --- | --- |
| BT.709 | 0.640, 0.330 | 0.300, 0.600 | 0.150, 0.060 |
| P3 D65 | 0.680, 0.320 | 0.265, 0.690 | 0.150, 0.060 |
| BT.2020 | 0.708, 0.292 | 0.170, 0.797 | 0.131, 0.046 |

**Primaries.** The matrix N from a space's linear red, green and blue to CIE XYZ is derived from its chromaticities and the white point as SMPTE RP 177 derives it, in 64-bit floating point, and the matrix from linear values in space S to linear values in space T is N_T⁻¹ × N_S. Since every space has the same white point, no chromatic adaptation is applied. That derivation gives, to ten places:

```
linear sRGB to linear P3 D65:
   0.8224619687   0.1775380313   0
   0.0331941989   0.9668058011   0
   0.0170826307   0.0723974407   0.9105199286

linear P3 D65 to linear sRGB:
   1.2249401763  -0.2249401763   0
  -0.0420569547   1.0420569547   0
  -0.0196375546  -0.0786360456   1.0982736001

linear sRGB to linear BT.2020:
   0.6274038959   0.3292830384   0.0433130657
   0.0690972894   0.9195403951   0.0113623156
   0.0163914389   0.0880133079   0.8955952532

linear BT.2020 to linear sRGB:
   1.6604910021  -0.5876411388  -0.0728498633
  -0.1245504745   1.1328998971  -0.0083494226
  -0.0181507634  -0.1005788980   1.1187296614
```

**SDR transfers.** Each takes a space's linear value L to its encoded value V and back, on all real numbers with the sign kept:

| Transfer | encode(L) | decode(V) |
| --- | --- | --- |
| sRGB | the extended sRGB transfer ([Working values](#working-values)) | its inverse there |
| BT.1886 at a white of 1 and a black of 0 | sign(L) × \|L\|^(1/2.4) | sign(V) × \|V\|^2.4 |

`rec709` and `rec2020` are display-referred both ways, as Premiere Pro and DaVinci Resolve take Rec. 709 and SDR Rec. 2020 at gamma 2.4, and as BT.2020 names BT.1886 as its reference display: their decode is the EOTF of BT.1886, L = a × max(V + b, 0)^2.4 with a white L_W of 1 and a black L_B of 0, so a = 1 and b = 0, taken to all real numbers with the sign kept, and their encode is the inverse of that EOTF:

```
decode_BT1886(V) = sign(V) × |V|^2.4
encode_BT1886(L) = sign(L) × |L|^(1/2.4)
```

An `rec709` or `rec2020` sequence's output read back as media of the same space therefore gives its working values back, to the rounding of the file's code values.

A working value is converted to an SDR space S by L_S = M × decode_sRGB(E), V = encode_S(L_S), with M the matrix from linear sRGB to S, and back by the same steps in reverse. For `srgb` V is E itself, so no rounding is added. For `rec709` M is the identity, since its primaries are those of sRGB. A working value is converted to `srgb-linear` by its linear form, decode_sRGB(E), on every real number, and back by the extended sRGB transfer.

**HDR transfers.** An HDR space holds display light: F_D in cd/m², a working value's linear form on BT.2020 primaries times 203.

- PQ, with m1 = 2610 / 16384 = 0.1593017578125, m2 = 2523 / 4096 × 128 = 78.84375, c1 = 3424 / 4096 = 0.8359375, c2 = 2413 / 4096 × 32 = 18.8515625 and c3 = 2392 / 4096 × 32 = 18.6875:

  ```
  PQ(F_D)  = ((c1 + c2 × Y^m1) / (1 + c3 × Y^m1))^m2,         Y = F_D / 10000, F_D in [0, 10000]
  EOTF(E') = 10000 × (max(E'^(1/m2) - c1, 0) / (c2 - c3 × E'^(1/m2)))^(1/m1)
  ```

- HLG, with a = 0.17883277, b = 1 - 4a = 0.28466892 and c = 0.5 - a × ln(4a) = 0.55991073, at a nominal peak L_W of 1000 cd/m² and a black L_B of 0, so the system gamma γ is 1.2 and the black lift β of BT.2100 is 0. E is scene light from 0 to 1, each channel on its own, and Y_S and Y_D are the luminance of scene and display light on BT.2020 primaries:

  ```
  OETF(E)      = √(3E)                       when E ≤ 1/12
               = a × ln(12E - b) + c         otherwise
  OETF⁻¹(E')   = E'² / 3                     when E' ≤ 1/2
               = (exp((E' - c) / a) + b) / 12  otherwise
  OOTF(E)      = L_W × Y_S^(γ - 1) × E,      Y_S = 0.2627 R_S + 0.6780 G_S + 0.0593 B_S
  OOTF⁻¹(F_D)  = (Y_D / L_W)^((1 - γ) / γ) × F_D / L_W,   Y_D = 0.2627 R_D + 0.6780 G_D + 0.0593 B_D
  ```

  OOTF gives 0 where Y_S is 0, and OOTF⁻¹ gives 0 where Y_D is 0. HLG display light is OOTF(OETF⁻¹(E')), and HLG's encoded value of display light is OETF(OOTF⁻¹(F_D)), so a working value of 1, 203 cd/m², encodes to 0.75 as BT.2408 gives it.

PQ and HLG name light only for encoded values from 0 to 1. An HDR value outside that range, as a video's value beyond its nominal range or a `lut`'s output can be, is clipped to 0 to 1 before the PQ EOTF or the HLG OETF⁻¹ takes it, so every HDR value gives finite light.

A working value is converted to an HDR space by L_2020 = M × decode_sRGB(E), F_D = 203 × L_2020, each channel of F_D clipped to its transfer's range (0 to 10000 cd/m² for PQ, 0 to 1000 cd/m² for HLG), then encoded: E' = PQ(F_D), or E' = OETF(OOTF⁻¹(F_D)). An HDR value is converted to a working value by F_D = EOTF(E'), or F_D = OOTF(OETF⁻¹(E')), L_2020 = F_D / 203, and the steps back to E.

**Code points.** A file names its colour space by the code points of ITU-T H.273: a video by its colour primaries, transfer characteristics and matrix coefficients, a PNG by an ICC profile or an sRGB chunk, a JPEG or HEIC by an ICC profile. frames writes and reads them by this table:

| Name | Primaries | Transfer | Written in a video (primaries, transfer, matrix) |
| --- | --- | --- | --- |
| `srgb` | 1 | 13 | 1, 13, 1 (BT.709) |
| `display-p3` | 12 | 13 | 12, 13, 1 (BT.709) |
| `rec2020` | 9 | 1, 6, 14 or 15 | 9, 14, 9 (BT.2020 non-constant luminance) |
| `rec709` | 1 | 1, 6, 14 or 15 | 1, 1, 1 (BT.709) |
| `rec2100-pq` | 9 | 16 | 9, 16, 9 (BT.2020 non-constant luminance) |
| `rec2100-hlg` | 9 | 18 | 9, 18, 9 (BT.2020 non-constant luminance) |

A picture's colour space is the row whose primaries and transfer it is tagged with, and a picture tagged with any other pair is outside the table and converted by the formulas its code points name ([Media](#media)). A code point a file leaves out, or writes as 2 (unspecified), is taken as `srgb`'s, so an untagged picture is `srgb`. The matrix decides how a video's Y'CbCr is taken to R'G'B' and not which row applies. `srgb-linear` has no row: no file is written or read in it, so a picture tagged with the linear transfer (8) is outside the table.

### Sequence colour space

`format.colorSpace` is a name from the table whose Sequence column says yes, and its default is `srgb`. Any other name stops at `check`. It decides the output, and with each media clip what an HDR picture enters as, and nothing else:

- how the sequence's output is encoded and tagged ([Output](#output)),
- which gamut and peak its output is clipped to ([Output](#output)),
- by its peak and together with a clip's `toneMap`, whether an HDR picture of the clip is tone mapped on the way in: it is where `toneMap` is true and the picture's source peak is above the sequence's peak, and then to that peak ([Media](#media)).

**`format.peak` is the mastering peak of a `rec2100-pq` sequence**, in cd/m²: a number from 400 to 10000, 1000 by default, as DaVinci Resolve sets an HDR master's mastering luminance. It is the sequence's peak ([Colour spaces](#colour-spaces)), so one number is the target peak L_max an HDR picture of a clip with `toneMap` true is tone mapped to ([Tone mapping](#tone-mapping)), the light the output is clipped to ([Output](#output)), and the source peak L_W of the sequence's analysis pictures ([Providers and analysis pictures](#providers-and-analysis-pictures)). A number outside 400 to 10000 stops at `check`, and so does the key in a format whose `colorSpace` is not `rec2100-pq`: `rec2100-hlg`'s peak is the fixed 1000 cd/m² of its OOTF, and an SDR space's is its reference white. frames writes no mastering display metadata from it ([FRAMES-21](../FRAMES-21/SPEC.md#notes)).

The working space, one coordinate system with one set of formulas, is the same in every sequence, so every formula of the specification is computed the same way everywhere, and what it does above 1 is what the extended sRGB curve makes of it ([Working values](#working-values)). The values an HDR picture enters as are not: tone mapped it enters with its peak at the sequence's (a working value of 1 in a sequence of an SDR space, 1000 / 203 in a `rec2100-hlg` one, `format.peak` / 203 in a `rec2100-pq` one), and not tone mapped as its display light, so a filter on it sees the picture the clip and the sequence give it. A compound clip's or a template instance's `colorSpace` and `peak` apply only when it is rendered alone, as its `fps` does ([FRAMES-3](../FRAMES-3/SPEC.md)): inside another sequence its frames are working values, the outermost sequence's colour space and peak decide the three things for every clip it shows, its own clips included, and the keys are allowed there and have no effect. So a template's look sees the HDR pictures its host brings in, at the host's peak ([Notes](#notes)). The format's `background` is a working value like any other.

### Compositing

`format.compositing` is `encoded` or `linear`. **Its default is `encoded`.** Any other value stops at `check`.

**Every formula has a home, the form or the colour space it was written in, which it reads whichever `compositing` the sequence has. Only a form-free formula has none, and it follows `compositing`.** A formula's home is decided by one of four reasons:

- **A constant or a domain whose meaning depends on the form**, which means what it was written for on the encoded form only: the 0.5 pivot of `contrast`, the points of `levels`, luma and its weights, the grey of `saturation`, the matrices of `hue` and `sepia`, the noise weight of `grain`, and the constants of the blend functions listed below. Their home is the encoded form, `srgb`.
- **A parameter that is a quantity of light**: `exposure`'s `ev`, in stops, and `temperature`'s `kelvin`, a blackbody's colour ([FRAMES-15](../FRAMES-15/SPEC.md)), name light, so an op that takes one means it on light only. Its home is the linear form, `srgb-linear`. An op whose parameter has no unit, as `vignette`'s and `bloom`'s `amount`, is form-free or takes the home its constants give.
- **Data built for a colour space**: a LUT's grid, built for the encoded values of its `space` ([FRAMES-15](../FRAMES-15/SPEC.md)), `srgb-linear` for a LUT built on linear sRGB. A `lut`'s home is its `space`, which its data decides and the document writes.
- **A declaration, for a path through colours**: frames writes every colour as `color(srgb ...)` ([Colour values](#colour-values)) and interpolates a keyframed colour between its keyframes and a gradient between its stops there, as CSS Color 4 interpolates legacy sRGB colours in sRGB (below). Their home is the encoded form.

A **form-free formula** holds no constant whose meaning depends on the form: its constants, where it has any, are 0 and 1 on a channel, black and, for a neutral colour, reference white in both forms. It reads its colours in the form `compositing` names, the encoded form under `encoded`, as W3C Compositing, browsers and After Effects composite by default, and the linear form under `linear`, as Premiere Pro's Composite in Linear Color composites and After Effects blends with Blend Colors Using 1.0 Gamma, and its result is the working value that form names. Under `encoded` it weighs and adds code values, and under `linear` light. Alpha is the same in both forms.

The form-free formulas, in the form `compositing` names:

- an item composited onto what is below it in its display list by source-over, at its alpha after its reveal, matte, mask, track matte and `opacity` ([FRAMES-20](../FRAMES-20/SPEC.md)), the composite that weighs a blend function with Cs and Cb (below), a nested list's picture onto the list that holds it, the blend functions of `normal`, `multiply`, `screen`, `darken`, `lighten`, `difference`, `color-dodge`, `color-burn` and `add`, and the sum `plus-lighter` makes ([FRAMES-11](../FRAMES-11/SPEC.md#blend-modes)),
- the coverage of an antialiased edge (a path, a glyph, a reveal's edge, a mask's edge and feather), which is alpha,
- the parts an item draws over each other: a picture's border over it, a shadow under its item, a title's background, highlights, underlines, strokes and fills in their order,
- the two storyline pictures of a transition, so a dissolve in `linear` mixes light, and a transition cover over them ([FRAMES-14](../FRAMES-14/SPEC.md)),
- an adjustment's filtered picture onto the unfiltered one, by its `blend` and alpha ([FRAMES-11](../FRAMES-11/SPEC.md)),
- a filter entry's `mix` and a `lut`'s `amount` ([FRAMES-15](../FRAMES-15/SPEC.md)),
- the blurs inside filter ops (`blur`, and `sharpen`'s blur and its unsharp mask) and `pixelate`'s mean, premultiplied ([FRAMES-15](../FRAMES-15/SPEC.md)),
- `vignette`'s product of a pixel by its weight, a mix towards black, which is 0 in both forms ([FRAMES-15](../FRAMES-15/SPEC.md)),
- `bloom`'s product of a pixel by its weight, the blur of that product, its product by `amount` and by `color`, taken in the same form, and its addition to the picture ([FRAMES-15](../FRAMES-15/SPEC.md)),
- resampling a picture to its size, premultiplied.

At home on the encoded form, whichever `compositing` the sequence has:

- the blend functions B(Cb, Cs) of `overlay` and `hard-light`, whose threshold 0.5 and factor 2 split the range at mid-grey, of `soft-light`, whose threshold 0.5, whose 0.25 and polynomial ((16 Cb - 12) Cb + 4) Cb and whose square root are written for encoded values, of `exclusion`, Cb + Cs - 2 × Cb × Cs, which is 0.5 - 2 × (Cb - 0.5) × (Cs - 0.5), a product about the pivot 0.5 as `contrast` is, and of the non-separable modes `hue`, `saturation`, `color` and `luminosity`, whose `Lum` weighs the channels by 0.3, 0.59 and 0.11 ([FRAMES-11](../FRAMES-11/SPEC.md#blend-modes)),
- `contrast`, `levels`, `saturation`, `hue` and `sepia`, and `grain`'s noise weighed by luma and added to each channel ([FRAMES-15](../FRAMES-15/SPEC.md)),
- luma, for a luma track matte, a transition matte and the weights of `grain` and `bloom`, so `bloom`'s weight is computed from encoded luma and the rest of `bloom` follows `compositing`.

At home on the linear form, whichever `compositing` the sequence has: `exposure` and `temperature`, whose parameters are quantities of light, which take the linear form by the extended sRGB transfer and encode their result by it ([FRAMES-15](../FRAMES-15/SPEC.md)).

At home in its `space`, whichever `compositing` the sequence has: a `lut`'s lookup, the working value converted to the LUT's `space` as [Colour spaces](#colour-spaces) gives, looked up there and converted back ([FRAMES-15](../FRAMES-15/SPEC.md)). Its `amount` mixes the result with the input as a form-free formula.

**Keyframed colours ([FRAMES-4](../FRAMES-4/SPEC.md)) and a gradient's stops ([FRAMES-11](../FRAMES-11/SPEC.md)) interpolate on the encoded form, their home by declaration, whichever `compositing` the sequence has.** They are paths through colours, not mixes of pictures, and frames writes every colour in `srgb` and interpolates there, as CSS Color 4 interpolates legacy colours: near perceptual from 0 to 1, where a ramp from black to white is 0.5 encoded halfway along it in every sequence, and on the extended sRGB curve beyond. That curve is the cost: a ramp from `color(srgb-linear 0 0 0)` to `color(srgb-linear 4 4 4)`, the encoded values 0 and 1.8248, is 0.9124 encoded halfway along it, the linear 0.8122, neither half its light, 2, nor a perceptual middle.

Mask values are not colours, and multiply alpha as written ([FRAMES-11](../FRAMES-11/SPEC.md)).

**A blend mode** other than `plus-lighter` composites by W3C Compositing and Blending Level 1's source-over with the mode's blend function, as [FRAMES-20](../FRAMES-20/SPEC.md) applies it, with the source and backdrop colours Cs and Cb unpremultiplied, their alphas αs and αb. The blend function of a form-free mode, `normal`, `multiply`, `screen`, `darken`, `lighten`, `difference`, `color-dodge`, `color-burn` or `add`, is computed in the form `compositing` names. The blend function of `overlay`, `hard-light`, `soft-light`, `exclusion`, `hue`, `saturation`, `color` or `luminosity` is computed on the encoded form, and its result is taken to the form `compositing` names. Each reads Cs and Cb as they are ([Working values](#working-values)). The composite weighs B(Cb, Cs) with Cs and Cb in the form `compositing` names:

```
Cs' = (1 - αb) × Cs + αb × B(Cb, Cs)
co  = αs × Cs' + (1 - αs) × αb × Cb
αo  = αs + (1 - αs) × αb
```

co is the premultiplied result. Under `normal` B(Cb, Cs) is Cs, so a `normal` composite is source-over alone. Under `add` B(Cb, Cs) is Cb + Cs, so co = αs × Cs + αb × Cb, the two premultiplied colours added without bound. `plus-lighter` is W3C's operator of its own, co = min(1, αs × Cs + αb × Cb) and αo = min(1, αs + αb), a form-free formula with W3C's bound of 1 on each channel, which in both forms is reference white for a neutral colour and the edge of the sRGB gamut for a chromatic one ([FRAMES-11](../FRAMES-11/SPEC.md#blend-modes)). Under `linear` `multiply` of two colours inside the sRGB gamut is the light a filter passes, and under `encoded` the product of code values; on a wide gamut colour it multiplies the sRGB channels ([Working values](#working-values)). `darken` and `lighten` give the same colour in both forms, since the extended sRGB transfer is increasing and min and max pick the same value in either.

A compound clip's or a template instance's own `compositing` composites the items of its own frame, as its `background` and `conform` apply there ([FRAMES-3](../FRAMES-3/SPEC.md)). Its picture is composited onto the frame that shows it by that frame's `compositing`.

The default is `encoded` for every sequence, whatever its colour space. `linear` changes the form-free formulas only: a dissolve or a blur of HDR and wide gamut pictures mixes their light under it, and every formula with a home reads that home as before, above 1 on the extended sRGB curve where its home is the encoded form ([Working values](#working-values)).

### Colour values

A colour in a document, a theme, a preset, a template argument or an args file is a string:

```
colour     = hex | function | name
hex        = "#" 6HEXDIG | "#" 8HEXDIG
function   = "color(" *SP space 1*SP number 1*SP number 1*SP number [ *SP "/" *SP number ] *SP ")"
space      = "srgb" | "srgb-linear" | "display-p3" | "rec2020"
number     = [ "+" | "-" ] ( 1*DIGIT [ "." 1*DIGIT ] | "." 1*DIGIT ) [ ( "e" | "E" ) [ "+" | "-" ] 1*DIGIT ]
name       = the name of a theme colour (FRAMES-22)
```

HEXDIG is a hexadecimal digit of either case, DIGIT a decimal digit and SP a space, as ABNF writes them, and `color` and the space names are written in lower case, as shown. A string that starts with `#` or `color(` is read as a hex colour or a function, and one that does not match the grammar stops at `check`, naming its place. Any other string is a theme colour's name.

- A hex colour is sRGB, as in CSS: `#RRGGBB` is the encoded working value R' = RR / 255, G' = GG / 255, B' = BB / 255 with alpha 1, and `#RRGGBBAA` takes alpha AA / 255.
- `color(<space> c1 c2 c3 / a)` is CSS Color 4's `color()` with its components as numbers: c1, c2 and c3 are the red, green and blue of `<space>` encoded as CSS Color 4 defines it, any real number, so `color(display-p3 1 0 0)` is the red of P3 and `color(srgb-linear 2 2 2)` is twice reference white. `a` is alpha, from 0 to 1, and 1 when it is left out. A component that is not finite, or an alpha outside 0 to 1, stops at `check`.
- `srgb` is the encoded working value itself: R' = c1, G' = c2, B' = c3. `srgb-linear` is the linear form: R' = encode(c1), and so on. `display-p3` and `rec2020` are converted from their space as [Colour spaces](#colour-spaces) gives (the sRGB transfer and the P3 primaries for `display-p3`, the BT.1886 transfer and the BT.2020 primaries for `rec2020`, the `rec2020` row of the table).
- A theme colour is any of these but a name, and a value that names it is its colour ([FRAMES-22](../FRAMES-22/SPEC.md)).
- **The resolved document and display lists write every colour as `color(srgb r g b / a)`**: the encoded working value, its four numbers in the number form of [FRAMES-19](../FRAMES-19/SPEC.md), alpha always written, one space between the parts and around `/`. A colour of another form there stops reading, naming its place.

### Media

The decoder converts every picture it reads (a video's frames, an image, an image sequence's frames, a transition's cover or matte media) to working values.

- Its colour space is the `colorSpace` written where it is named, on the media clip that shows it or on the transition's cover or matte, or where none is written the one its tags name ([Colour spaces](#colour-spaces)). A video's Y'CbCr is taken to R'G'B' by the matrix and the range (narrow or full) the file says, as BT.709 and BT.2100 quantise them, and a value beyond the nominal range is kept, until an HDR transfer clips it ([Colour spaces](#colour-spaces)). An image whose ICC profile describes a space of the table (its primaries, white point and transfer) is in that space.
- **The media colour spaces are open, and every conversion is fixed.** A picture read by its tags outside the table is converted to linear sRGB by formulas, with no gamut clipped, so two decoders agree on it as on a picture of the table:
  - A video by the formulas of ITU-T H.273 and the standards it names for its code points. Its matrix coefficients take Y'CbCr to R'G'B' by H.273's equations for them (those of BT.601 for 5 and 6). A transfer the table reads (1, 6, 14 and 15 as BT.1886, 13 as sRGB, 16 as PQ, 18 as HLG) is decoded as the table decodes it, and any other by the inverse of the function H.273 gives for it. Its primaries are taken to linear sRGB by the matrix their chromaticities and white point give, derived as [Colour spaces](#colour-spaces) derives the table's, a white point other than D65 adapted to D65 by the Bradford transform (below). A PQ or HLG picture on other primaries is HDR media: its display light is taken on its own primaries, the HLG OOTF weighing luminance by the Y row of their N, and taken to BT.2020 primaries for [Tone mapping](#tone-mapping).
  - An image whose ICC profile (ICC.1) is a matrix and tone-curve profile, with red, green and blue colorant and tone curve tags and no lookup table for its transform. Each channel is taken through its tone curve as ICC.1 defines it (a gamma, a parametric curve, or a table interpolated linearly), then by the matrix whose columns are its colorants to CIE XYZ in the profile connection space, whose white is D50 (X 0.9642, Y 1, Z 0.8249), then to linear sRGB by N_sRGB⁻¹ × A⁻¹, where N_sRGB is the matrix of [Colour spaces](#colour-spaces) and A the Bradford adaptation from D65 to D50. This is the colorimetric conversion with relative intent and no black point compensation, which is arithmetic, and a colour management module computes the same.
  - A picture whose ICC profile is LUT-based, its transform held in lookup tables (A2B and B2A tags), or whose code points no formula defines (a value H.273 reserves), stops at `read`, where its media is probed, and in a command that reads its pictures, naming the file and suggesting `transcode` ([FRAMES-23](../FRAMES-23/SPEC.md#transcode)). A place that writes a `colorSpace` for it reads it in that space, since its tags then do not apply.

  The Bradford adaptation from a white W_S to a white W_T, each in CIE XYZ with Y 1, is B⁻¹ × diag(B × W_T / B × W_S) × B, the quotient taken channel by channel, with

  ```
  B =  0.8951   0.2664  -0.1614
      -0.7502   1.7135   0.0367
       0.0389  -0.0685   1.0296
  ```

  in 64-bit floating point. For the profile connection space that gives, to ten places:

  ```
  PCS XYZ (D50) to linear sRGB, N_sRGB⁻¹ × A⁻¹:
     3.1341863642  -1.6172089590  -0.4906940640
    -0.9787485042   1.9161300968   0.0334333992
     0.0719639278  -0.2289938735   1.4057537329
  ```

- **A page of a PDF** ([FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages)) is read when every colour it paints is in a colour space whose formula is in the file, and stops otherwise. Each colour it paints is taken to working values from the colour space it is painted in, found by the walk of its content that [FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages) gives. How its colours combine inside it (its transparency groups, soft masks and blend modes) is its decoder's PDF renderer's ([FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages)), whatever the list's `compositing`, since a page is a finished picture: a group blends in the colour space it names, and where none is named on the encoded values of the page's untagged colour. Its colour spaces are read so:
  - DeviceRGB and DeviceGray, where the resources that paint in them name no default colour space for them (`DefaultRGB`, `DefaultGray`), are the page's **untagged colour**: they are in `srgb`, or in the `colorSpace` written where the page is named, a gray g being (g, g, g) in that space. A default colour space is read in place of the device space it stands for.
  - CalRGB with `WhitePoint` W, `Gamma` [G_R, G_G, G_B] (each 1 where it writes none) and `Matrix` [X_A Y_A Z_A X_B Y_B Z_B X_C Y_C Z_C] (the identity where it writes none) takes the components A, B, C to CIE XYZ = (X_A, Y_A, Z_A) A^G_R + (X_B, Y_B, Z_B) B^G_G + (X_C, Y_C, Z_C) C^G_B, then to linear sRGB by N_sRGB⁻¹ × D × XYZ, with D the Bradford adaptation from W to the D65 white of [Colour spaces](#colour-spaces) (X 0.3127 / 0.3290, Y 1, Z 0.3583 / 0.3290). CalGray with `WhitePoint` W and `Gamma` G (1 where it writes none) takes A to XYZ = W A^G, which the same steps take to the linear sRGB (A^G, A^G, A^G). `BlackPoint` takes no part, as there is no black point compensation.
  - Lab with `WhitePoint` W = (X_W, Y_W, Z_W) and `Range` [a_min a_max b_min b_max] ([-100 100 -100 100] where it writes none) takes L*, a* and b*, with a* and b* clamped to the range, to M = (L* + 16) / 116, L = M + a* / 500 and N = M - b* / 200, then to CIE XYZ = (X_W g(L), Y_W g(M), Z_W g(N)), where g(x) is x³ for x of 6/29 or more and (108 / 841) (x - 4/29) below, as ISO 32000-1 gives it, then to linear sRGB by the same steps as CalRGB.
  - An ICCBased space whose profile is a matrix and tone-curve profile of red, green and blue is read by its tags as an image with that profile is (above). One whose profile is a monochrome profile with a gray tone curve takes g through that curve, as ICC.1 defines it, to Y, and is the linear sRGB (Y, Y, Y), since the profile connection space's gray of luminance Y is the PCS white at Y, and the adaptation takes that white to D65. A number a profile stores in fixed point (a one-entry `curv` in u8Fixed8, colorants and curve parameters in s15Fixed16) stands for every value it is the nearest stored value of, so a one-entry `curv` of 2.19921875 may be taken as the 2.2 it stands for.
  - Separation and DeviceN take their components through their tint transform, an ISO 32000-1 function held in the file, into their alternate space, which is read by these formulas. An Indexed space is read by its base space after its lookup, and a Pattern space by the colour spaces its patterns and shadings paint in.
  - These conversions hold within 1e-4 of linear light, which is the precision of the numbers an ICC profile stores, and which near black is up to 12.92 times as much in encoded values ([Notes](#notes)).
  - What no formula in the file converts stops at `read` and in a command that reads the page's pictures, as a LUT-based image does, naming the file, the page and the colour space, and suggesting `transcode` ([FRAMES-23](../FRAMES-23/SPEC.md#transcode)): DeviceCMYK, an ICCBased space whose profile is a CMYK or a LUT-based profile, and Separation, DeviceN, an Indexed space or a pattern over one of these. A JPEG 2000 image is in the colour space its dictionary names, and one whose dictionary names none, its space held in its codestream, stops the same way. A `colorSpace` written where the page is named does not change this, since it replaces only the untagged colour.
  - **A decoder refuses a page it cannot convert by these formulas.** A decoder that does not convert a colour space above by its formula within that tolerance refuses the page where it reads the file, at `read` and in a command that reads the page's pictures, naming the file, the page and the colour space, and suggesting `transcode`, as every role refuses what it does not support ([FRAMES-21](../FRAMES-21/SPEC.md#rules)). So which pages a decoder reads is the decoder's, and the colour of a page it reads is the formula's ([Notes](#notes)).

- **`colorSpace` where a media file is named** (on a storyline clip with media, a connected or sequence media clip, and a transition's cover or matte, [FRAMES-14](../FRAMES-14/SPEC.md)) is a fact about the file, written where the media is named: a name whose Media column says yes, which replaces what the file says (of a page of a PDF, its untagged colour alone) wherever that place's media is read, by the renderer and by the providers alike, so OCR and tracking for that clip read the picture in it ([Providers and analysis pictures](#providers-and-analysis-pictures)). **Every place that names the same file names the same colour space.** Two places of the document, in its compound clips, template instances and the transitions they choose included, whose media are the same file (the same SHA-256, as resolve pins it, [FRAMES-19](../FRAMES-19/SPEC.md)) and whose colour spaces differ stop at resolve, where the file is pinned, naming both places, a place that writes no `colorSpace` counting as the space the file's tags name. frames names media where it uses them, so one file named in several places must agree, as two clips trimming the same file agree on its frame rate. So OCR and tracking of a file have one answer. Premiere Pro sets the same correction, Override Media Color Space, on the project item (Modify > Color, or Interpret Footage); frames has no project items, so the place that names the media holds it. `rec709` is for a video tagged wrongly or not at all whose pictures were made for a BT.1886 display. Log footage is not a colour space: a `lut` filter takes it to a display space ([FRAMES-15](../FRAMES-15/SPEC.md)). The key is a name and static. On a clip whose media is a compound clip or a template instance it stops, as a key of another media row does ([FRAMES-7](../FRAMES-7/SPEC.md)), since such media are working values already. A name the Media column does not allow stops at `check`.
- **`toneMap` on a media clip** (a storyline clip with media, a connected or sequence media clip) says whether an HDR picture of the clip is tone mapped from its source peak to the sequence's peak on the way in, as Premiere Pro's Auto Tone Map Media does: a boolean, `true` by default, and static. Where `colorSpace` is a fact about the media, `toneMap` is how this clip brings them into the edit. On a clip whose media is a compound clip or a template instance it stops, as `colorSpace` does.
- **A transition's cover media take `toneMap` true**, and have no key for it ([FRAMES-14](../FRAMES-14/SPEC.md)): a cover is a picture over the cut, and keeps its peak as a clip's picture does. A stinger graded by hand is wrapped in a compound clip, in which a media clip shows it with `toneMap` false and the grade's filters, and that compound clip is placed over the cut.
- **A transition's matte media are a weight field, not a picture**, and are read as an analysis picture ([Providers and analysis pictures](#providers-and-analysis-pictures)), in the colour space the matte's `colorSpace` names, or the file's tags where it writes none, as the providers read media. So a wipe's shape and timing never depend on the sequence's colour space.
- **SDR media** are converted exactly, as [Colour spaces](#colour-spaces) gives, in every sequence: nothing is clipped, so a wide gamut picture in an `srgb` sequence keeps its colours until the output clips them.
- **HDR media of a clip with `toneMap` true whose source peak L_W ([Tone mapping](#tone-mapping)) is above the sequence's peak** are tone mapped at the decoder to the sequence's peak, before any filter ([Tone mapping](#tone-mapping)): in a sequence of an SDR space an HDR picture whose L_W is above 203 cd/m², as every HLG picture's and every PQ picture's without mastering display metadata is, in an `rec2100-hlg` sequence a PQ picture mastered above 1000 cd/m², and in an `rec2100-pq` sequence an HDR picture whose L_W is above its `format.peak`, as a PQ picture mastered at 4000 cd/m² is at the default 1000.
- **Every other HDR picture is taken as display light**, 203 cd/m² taken as 1, with no tone mapping, whichever HDR transfer the media and the sequence have: PQ media by the PQ EOTF, HLG media by the HLG EOTF with the OOTF at 1000 cd/m² ([Colour spaces](#colour-spaces)). These are the pictures of a clip with `toneMap` true whose source peak is at or below the sequence's peak, such as an HLG picture, or a PQ picture without mastering display metadata, in an `rec2100-pq` sequence whose `format.peak` is 1000 cd/m² or more, and every HDR picture of a clip with `toneMap` false. Light past the sequence's peak, and a colour outside its gamut, are clipped at the output, so with `toneMap` false a colourist grades the HDR picture into the sequence by hand with filters, which see its values above 1.

### Tone mapping

An HDR picture is tone mapped from its source peak to a target peak by the EETF of BT.2390 on max(R, G, B), with RGB scaled by the ratio it gives so the hue is kept. It is tone mapped only where its source peak is above the target peak, L_W > L_max, which [Media](#media) decides. For each pixel:

1. Take its display light F_D = (R_D, G_D, B_D) in cd/m² on BT.2020 primaries, by the PQ EOTF or by the HLG EOTF with its OOTF at 1000 cd/m², and M = max(R_D, G_D, B_D).
2. Take the source peak L_W, the source black L_B, the target peak L_max and the target black L_min. For a picture of a media file L_W is the maximum luminance of the file's mastering display (its SMPTE ST 2086 metadata) for PQ, or 1000 cd/m² when it has none, at most 10000 cd/m², and 1000 cd/m² for HLG, its OOTF's peak. For a frame of a sequence of an HDR space taken to an analysis picture L_W is the sequence's peak, 1000 cd/m² for `rec2100-hlg` and its `format.peak` for `rec2100-pq` ([Providers and analysis pictures](#providers-and-analysis-pictures)). L_max is the sequence's peak ([Colour spaces](#colour-spaces)), the outermost sequence's for a picture inside a compound clip, which a picture's source in the display list carries as `targetPeak` ([FRAMES-20](../FRAMES-20/SPEC.md)): 203 cd/m² (working value 1) for a space of SDR range, 1000 cd/m² for `rec2100-hlg` and its `format.peak` for `rec2100-pq`. For an analysis picture L_max is 203 cd/m². L_B = 0 and L_min = 0.
3. In PQ, with PQ the function of [Colour spaces](#colour-spaces):

   ```
   E1     = clamp((PQ(M) - PQ(L_B)) / (PQ(L_W) - PQ(L_B)), 0, 1)
   minLum = (PQ(L_min) - PQ(L_B)) / (PQ(L_W) - PQ(L_B))
   maxLum = (PQ(L_max) - PQ(L_B)) / (PQ(L_W) - PQ(L_B))
   KS     = 1.5 × maxLum - 0.5
   b      = minLum

   E2 = E1                                                         when E1 < KS
      = (2T³ - 3T² + 1) × KS + (T³ - 2T² + T) × (1 - KS) + (-2T³ + 3T²) × maxLum
                                                                   when KS ≤ E1 ≤ 1, with T = (E1 - KS) / (1 - KS)
   E3 = E2 + b × (1 - E2)⁴
   E4 = E3 × (PQ(L_W) - PQ(L_B)) + PQ(L_B)
   M' = EOTF(E4)
   ```

   Since L_W > L_max, maxLum < 1 and KS < 1, so T is defined. With L_min 0, b is 0 and E3 = E2.
4. Scale the pixel by the ratio: F_D' = F_D × M' / M, and 0 where M is 0.
5. Take F_D' to a working value as an HDR value is taken ([Colour spaces](#colour-spaces)): L_2020 = F_D' / 203, the matrix to linear sRGB, the extended sRGB transfer. Nothing is clipped.

**Tone mapping fits the source's peak into the target's, and its knee lowers reference white a little.** M' is at most L_max, since E2 is at most maxLum, and no channel of F_D is above M, so every channel of F_D' lies from 0 to L_max and of L_2020 from 0 to L_max / 203, which is 1 in a sequence of an SDR space. The curve leaves light as it is only below its knee, where E1 < KS, the light EOTF(KS × (PQ(L_W) - PQ(L_B)) + PQ(L_B)), and the knee lies below L_max: from L_W 1000 cd/m² to L_max 203 cd/m² it is 87.84 cd/m², so reference white, 203 cd/m², lands at 159.04 cd/m², the encoded value 0.898 ([Notes](#notes)). The matrix to linear sRGB may then give a channel below 0 or above L_max / 203, a colour of BT.2020 outside the sRGB gamut, which is kept as SDR wide gamut media keep theirs, and the output clips the gamut ([Output](#output)). Nothing clips the result in any sequence before the output.

Every conversion of media is fixed ([Media](#media)), and so is this formula, so two decoders agree to their rounding, apart from how each upsamples a video's chroma ([FRAMES-21](../FRAMES-21/SPEC.md)).

### Output

The encoder writes the renderer's frames of working values in the sequence's colour space:

- **SDR space:** each channel of the space's linear value, L_S = M × decode_sRGB(E), is clipped to 0 to 1, then encoded with the space's transfer. In an `srgb` sequence that is each channel of E clipped to 0 to 1.
- **HDR space:** the working value is converted as [Colour spaces](#colour-spaces) gives, with the display light clipped to the sequence's peak: 0 to its `format.peak` for `rec2100-pq`, 0 to 1000 cd/m² for `rec2100-hlg`.
- **The output clips each channel on its own and does no gamut mapping**, as NLEs clip on output: a wide gamut colour clipped to a smaller gamut, or a colour past the peak in one channel, can shift its hue. Tone mapping keeps the hue of the light it maps ([Tone mapping](#tone-mapping)), and the clip here is the only one between the decoder and the file.
- Alpha lies in 0 to 1 and is written as it is. A file that stores premultiplied alpha stores the encoded colour multiplied by it.
- An encoded value V from 0 to 1 is written at the file's bit depth n as the nearest code value: round(V × (2^n - 1)) for R'G'B', and for a video's Y'CbCr the narrow range code values BT.709 and BT.2100 give, by the matrix the table writes.
- The file is tagged with the sequence's colour space: the code points the table writes in a video, and an ICC profile of that space in a JPEG, a HEIC or a PNG, where an `srgb` PNG takes an sRGB chunk instead. Which files are written, at which depths and codecs, is [FRAMES-21](../FRAMES-21/SPEC.md) and [FRAMES-23](../FRAMES-23/SPEC.md).

### Providers and analysis pictures

An **analysis picture** is an SDR sRGB picture: encoded working values with every channel in 0 to 1. It is the one normalised colour reading of media and of frames that the providers and transition mattes read and that `still`, `sheet` and `extract` show, and it is not the master. Its resolution is the medium's: a raster's own pixels, and for a page of a PDF, which has none, the scale the reader draws it at (below).

- An analysis picture of media is the picture the decoder gives for a clip with `toneMap` true in an `srgb` sequence, so an HDR picture whose source peak is above 203 cd/m² is tone mapped to 203 cd/m² as [Tone mapping](#tone-mapping) gives, with each channel of the encoded form clipped to 0 to 1, so wide gamut is clipped. It never depends on a clip's `toneMap` or on the sequence.
- **Where a result lies and how finely it is read are two decisions.** What a provider gives for a page of a PDF lies in the page's points, its media pixels, as for any medium. The analysis picture a provider reads of a page is the whole page drawn at 4 pixels per point, 288 per inch ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), and what it finds there is divided by 4: at one pixel per point an 8 point footnote is about 8 pixels tall, below what OCR reads, and at 4 it is about 32. The 4 is fixed, not chosen by the page, the provider or the machine, so the same page gives the same lines and text areas wherever it is read. A page used as a transition matte or a cover is drawn at the size it is shown at, in the reading that role takes: a matte as an analysis picture of the part of it the renderer draws, at the scale its stretch over `dest` shows it at, so a wipe's edge is as sharp as the page's, and a cover as a picture of working values ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)).
- The providers (OCR, the tracker, [FRAMES-21](../FRAMES-21/SPEC.md)) read analysis pictures of media. They read a clip's media in its `colorSpace`, or as the file's tags say where it writes none, as the renderer does ([Media](#media)), so no recognised text and no track depends on how a clip brings its media into the edit. The `ocr` and `track` commands take the same correction as `--color-space <name>` ([FRAMES-23](../FRAMES-23/SPEC.md)), so they see what resolve sees for a clip with that `colorSpace`.
- The renderer reads a transition matte's media as an analysis picture, in the colour space the matte's `colorSpace` names, or the file's tags where it writes none ([Media](#media)), and takes its luma as the matte's weight ([FRAMES-14](../FRAMES-14/SPEC.md)).
- `still`, `sheet` and `extract` ([FRAMES-23](../FRAMES-23/SPEC.md)) write analysis pictures at 8 bits per channel, sRGB tagged: SDR previews for looking at, the same normalised picture the providers read, and not the master. A frame of a sequence of an SDR space is encoded as an `srgb` sequence's output, so in a `display-p3` or `rec2020` sequence every colour outside the sRGB gamut is clipped. A frame of a sequence of an HDR space is first encoded as its own output, with its display light clipped to its peak, then tone mapped as an HDR picture of that space whose source peak L_W is the sequence's peak, 1000 cd/m² for `rec2100-hlg` and its `format.peak` for `rec2100-pq`, to 203 cd/m² ([Tone mapping](#tone-mapping)), as a player shows a file mastered at that peak: content at reference white keeps near white, a white title at the encoded value 0.898 from 1000 cd/m², 0.956 from 400 and 0.815 from 4000, and light at the sequence's peak is white. The master of a `display-p3`, `rec2020` or HDR sequence is checked with `render --at`, which writes the frame in the sequence's colour space at 16 bits per channel ([FRAMES-23](../FRAMES-23/SPEC.md), [FRAMES-24](../FRAMES-24/SPEC.md)). A video's frames are analysis pictures of the video. Time labels are drawn on the analysis picture, composited on its encoded values.

## Interactions

The units table points here for colour values ([FRAMES-1](../FRAMES-1/SPEC.md)). Keyframed colours ([FRAMES-4](../FRAMES-4/SPEC.md)) and gradient stops ([FRAMES-11](../FRAMES-11/SPEC.md)) interpolate on the encoded form ([Compositing](#compositing)). `format.colorSpace`, `format.peak`, `format.compositing` and a media clip's `colorSpace` and `toneMap` are keys of [FRAMES-7](../FRAMES-7/SPEC.md), a transition cover's and matte's `colorSpace` keys of [FRAMES-14](../FRAMES-14/SPEC.md), the format is [FRAMES-9](../FRAMES-9/SPEC.md) and what a compound clip's format applies is [FRAMES-3](../FRAMES-3/SPEC.md). Blend modes, which of them keep their character above 1 and below 0, and track mattes are [FRAMES-11](../FRAMES-11/SPEC.md), transitions [FRAMES-14](../FRAMES-14/SPEC.md), and the domain of each filter op [FRAMES-15](../FRAMES-15/SPEC.md). The resolved document carries colours, colour spaces, the peak, `toneMap` and the compositing, and the display list carries them with each picture's target peak as `targetPeak` in place of `toneMap`, as [FRAMES-19](../FRAMES-19/SPEC.md) and [FRAMES-20](../FRAMES-20/SPEC.md) say. The roles, the files they write and the providers are [FRAMES-21](../FRAMES-21/SPEC.md), theme colours [FRAMES-22](../FRAMES-22/SPEC.md), and `probe`, `transcode`, which also reads a picture the decoder stops on, and the analysis commands, `--color-space` on `ocr` and `track` among them, [FRAMES-23](../FRAMES-23/SPEC.md). How two decoders may differ in upsampling chroma is [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered

A working space per sequence (linear P3 for a P3 sequence, linear BT.2020 for an HDR one): every formula that acts on each channel would act on the sequence's own primaries, so a wide gamut colour would keep its character under `multiply`, `darken`, `difference` and `plus-lighter` in a sequence of its gamut, but the same document would composite, blend and filter by other formulas for each output, and a resolved colour would need its sequence to be read. Giving only those formulas the sequence's primaries as their home is the same alternative for them: `multiply` of two colours would give one colour in an `srgb` sequence and another in a `display-p3` one. One working space keeps one coordinate system and one set of formulas, and every resolved colour one meaning, at the cost of the formulas on each channel of a wide gamut colour ([Working values](#working-values)). The sequence's colour space decides the output, and what an HDR picture enters as only together with the clip's `toneMap`.

A wide single basis, the BT.2020 primaries for every sequence: no colour of P3 or BT.2020 would have a channel below 0, so the formulas on each channel would keep their character on them, but an `srgb` sequence would no longer give the results of browsers and design tools, which compute on the sRGB channels: under `linear` `multiply` of sRGB's red by its green, black there, would be the linear sRGB (0.3056, 0.0462, -0.0085), a dark red, and every mode on each channel would move so. The sRGB primaries keep the results an `srgb` sequence shares with those tools, and the cost lands on wide gamut colours ([FRAMES-11](../FRAMES-11/SPEC.md#blend-modes)).

Tone mapping decided by the sequence alone, every HDR picture tone mapped in an SDR sequence: a colourist grading an HDR source into SDR by hand, as Premiere Pro's Auto Tone Map Media turned off and Final Cut Pro's HDR Tools allow, could never reach its highlights, which would be gone before the first filter. Whether a picture is brought into the sequence by the EETF or graded into it by hand is a choice for each clip, so it is a key of the clip.

`toneMap` acting only in a sequence of an SDR space, every HDR picture in a sequence of an HDR space taken as display light: a PQ source mastered at 4000 cd/m² in an `rec2100-hlg` sequence would be clipped at the output channel by channel at 1000 cd/m², its highlights flat and their hue shifted, which is the case the BT.2390 EETF is written for. What tone mapping needs is a source peak above the target's, not an SDR sequence, so `toneMap` maps the source's peak to the sequence's in every sequence, and leaves a picture at or below the sequence's peak as it is.

Tone mapping as a filter op: an HDR clip in an SDR sequence would show clipped highlights until an op was written on it, an op on an adjustment clip would tone map SDR pictures with the HDR ones, and the op would have to run first in every chain to see the light the decoder gives. A clip key that is on by default gives the usual result unwritten and the grade by hand where it is turned off.

The peak HDR pictures come in at decided by the nearest frame that grades them, a compound clip's or a template instance's own `colorSpace`, as its `compositing`, `background` and `conform` apply in its own frame: a template's look would see the same pictures in every host. The key would then hold two things with two owners, the output of the outermost sequence and the intake of each frame, and a compound clip that writes no `colorSpace` would take `srgb`, its default, and press every HDR picture in an HDR host to 203 cd/m², so it would need a default that inherits the host's peak, a concept frames has nowhere else, or a second key. The outermost sequence decides for every frame it shows, and a template meant for HDR hosts is graded on HDR pictures ([Notes](#notes)).

The sequence's colour space carried by every nested display list for the decoder: the decoder needs only the peak a picture may be tone mapped to, so a picture's source carries that one number as `targetPeak`, `null` where its clip's `toneMap` is false, and its clip's `colorSpace`, and only the outermost list carries the colour space, for the encoder. The clip's boolean in the source would leave the decoder to find the sequence's peak itself.

The display list's target peak named `toneMap`, as the documents name the clip's boolean: one key would be a boolean in a document and in the resolved document and a number of cd/m² in the display list. `targetPeak` is BT.2390's target peak, L_max, and `toneMap` stays the boolean.

A transition matte read as a cover is, a picture with `toneMap` true: its luma would depend on the sequence's peak, an HDR gradient compressed by the EETF's knee in an SDR sequence and taken as display light and clamped above 1 in an `rec2100-pq` one, so one document's wipe would change shape and timing with its output's colour space, and the display list's matte would carry a `toneMap` that could take one value only. A matte is a weight field, as the media the providers read are data, so it is read as an analysis picture.

Linear working values for every formula, as ACES and scRGB pipelines hold them: every formula whose constants are written for encoded values (the blend functions of `overlay`, `soft-light` and the non-separable modes, `contrast`, `levels`, luma) would change its meaning, and a sequence would no longer composite as browsers and After Effects do by default. `format.compositing` gives linear light where it is wanted, and the filter ops that need it (`exposure`, `temperature`) work in it already.

`compositing` taken by the display list's composites only, with a filter entry's `mix`, the blurs inside ops, resampling and colour interpolation on the encoded form: the line would follow where a sum is computed, not what it is, so under `linear` an `opacity` of 0.5 and a `mix` of 0.5 would give two pictures for one intent, and a blur, where linear light differs most, would ignore it. A form-free formula holds nothing that depends on the form, so it follows `compositing`; a formula with a home keeps its meaning by staying there.

The line drawn by a formula's shape, every weighted sum of colours following `compositing` and every formula written on encoded values staying there: `contrast`, (v - 0.5) × amount + 0.5, has the shape of a weighted sum with grey, as `sharpen` has with its blur, yet only `sharpen` would follow `compositing`; `vignette`'s mix towards black, which is 0 in both forms, would stay on the encoded form, so under `linear` a `vignette` and a gradient vignette of the same strength would leave an edge at 0.21 and at 0.5 of its light; and gradient stops and keyframed colours, paths through colours, would follow the sum, so under `linear` a ramp from black to white would be 0.735 encoded halfway along it. What decides is whether a formula has a home, and a colour path has one by declaration, the encoded values every colour is written as.

One reason for a home, a constant or a domain whose meaning depends on the form keeping a formula on the encoded form and every other formula following `compositing`: `exposure` and `temperature` hold no such constant, yet under `encoded` they would scale code values where their parameters name light, and a LUT's grid is built for its `space`, which is neither form unless it is `srgb` or `srgb-linear`. A parameter that is a quantity of light, data built for a space and a declaration for a path through colours are reasons of their own, and the four are written down ([Compositing](#compositing)).

Physics on linear light as the reason, every op whose definition speaks of light at home on the linear form: `exposure` and `temperature` would be there because their definitions say so, which is a declaration and not a reason, and the same words would take `vignette`, a lens's loss of light, and `bloom`, which adds light, to the linear form, while a gradient vignette of the same strength, a mix towards black, follows `compositing`. The reason would give two answers for one intent, and none for an op still to come. The criterion names the op's parameter instead: one in a unit of light, stops or kelvin, puts its op on the linear form, and one with no unit leaves it form-free or at the home its constants give. Under it a lift, gamma and gain op or an ASC CDL op, which this phase does not have, would be form-free, since CDL's slope, offset and power are defined on whatever signal they are given, and a gain written in stops would be at home on the linear form.

`exposure` and `temperature` form-free, following `compositing`: under `encoded` `exposure` at -1 would halve code values and take white to the encoded 0.5, 0.2140 of its light, where a stop halves light, as it does at its home, taking white to the encoded 0.7354. A parameter in stops would name another light in each form.

A home given by an external standard, every W3C blend function on the encoded form because W3C writes it there and browsers and After Effects composite so by default: that names where a formula was published, not what it means. `add`, the Linear Dodge (Add) of Photoshop and After Effects, is written on encoded values as much and followed `compositing`, so Cb + Cs followed it and Cb × Cs did not, with nothing to tell them apart; `multiply` under `linear` is the light a filter passes on colours of the sRGB gamut, the most physical of the modes; `darken` and `lighten` give the same colour in both forms, so their home could not be seen; and After Effects computes its modes in linear light when it blends at gamma 1.0, so the rule copied its default and not its linear mode. A blend function holds a constant whose meaning depends on the form or it does not, as every other formula, and that alone decides ([Compositing](#compositing)).

`exclusion` as a form-free mode, as its constants 1 and 2 might suggest: Cb + Cs - 2 × Cb × Cs is 0.5 - 2 × (Cb - 0.5) × (Cs - 0.5), so a source of 0.5 gives 0.5 over every backdrop, the mid-grey the formula turns about. Under `linear` that grey would be the linear 0.5, the encoded 0.7354, so the mode would turn about another grey for each `compositing`, as `contrast` would about its pivot. Its formula holds a constant of the form, and it stays on the encoded form with `overlay`, `hard-light` and `soft-light`.

The form-free formulas named sums of light: under `encoded` a dissolve adds code values, not light, so the name would hold in one form only. What the formulas share is that no constant of theirs depends on the form.

The forms merged into the colour spaces, `compositing` written `srgb` or `srgb-linear`: a colour space of the table holds an output policy, its range, its peak and which places may write it, and a form holds none, since it is a lossless view of the same working value. `compositing` would name a row whose Range and Peak columns say nothing of how a formula reads a value. The forms stay a concept of their own, `compositing` names one of them, and `srgb-linear` is a row of the table only so that a `lut` built on linear sRGB can name its `space`.

Colour paths at home in the space the author wrote, a ramp between two `color(srgb-linear ...)` stops interpolated in light: two stops written in two spaces, `#FF0000` and `color(srgb-linear 0 0 1)`, would have no common path, and the resolved document, which writes every colour as `color(srgb ...)`, would have to keep each colour's written space for evaluation to read. A colour's space is how it is spelled, and the colour is the same in every spelling, where a LUT's `space` names what its data was built for and changes what the data means. One declared path keeps one spelling, as CSS Color 4 interpolates legacy colours in sRGB, and its cost beyond 1 is written down ([Compositing](#compositing)).

A `space` on `contrast`, `saturation` and the other ops at home on the encoded form, as a `lut` takes one, so an HDR grade could pivot `contrast` or weigh `saturation` in the space it chooses: this phase does not take it. It is a decision of scope, not of principle: a LUT's `space` says what its data was built for, an op's `space` would be a choice of the grade with its own default and checks, and nothing in a formula's home keeps a later spec from giving these ops one.

A default `compositing` for each colour space, `linear` for an HDR sequence: one document would composite by other sums for each output, which one working space exists to prevent. One default for every sequence keeps a document one picture, and `linear` is chosen where light should mix. What the formulas at home on the encoded form do above 1 is the cost of the working values, not of `compositing`, and `linear` does not change it ([Working values](#working-values)).

A formula defined only on 0 to 1 reading its inputs clamped to 0 to 1, the W3C blend modes other than `normal`, `multiply`, `darken`, `lighten` and `difference` among them: a mode's identity would break above 1 and below 0, as a clamp of its input level would break the identity of `levels` ([FRAMES-15](../FRAMES-15/SPEC.md)). A light leak with a black ground blended with `screen` over an HDR highlight of 3 would give B(clamp(3), 0) = 1 wherever the leak covers the frame, pressing the highlight to reference white, and a P3 colour under it would lose its negative channels to the sRGB gamut, where black under `screen` should change nothing. Every mode as W3C writes it, on its values as they are, keeps every identity of `screen`, `multiply` and `add`; the modes that lose their character above 1 or below 0 are named ([FRAMES-11](../FRAMES-11/SPEC.md#blend-modes)), among them `plus-lighter`, whose own bound of 1 cuts a P3 colour towards sRGB even over black, and `add` adds light without bound, so a wide gamut light leak uses it.

Providers reading a file by its tags alone, never by its clip's `colorSpace`: an untagged HLG video drawn as HLG would be recognised and tracked as a dark sRGB picture, and the `ocr` and `track` commands would agree with resolve on the wrong picture. A media clip's `colorSpace` is a fact about the media, so every reader of that clip's media takes it.

A table of media facts apart from the places that use the media, as Premiere Pro's project items hold them: frames names media where it uses them, in clips, covers and mattes, and has no place where a file is declared, so a table would be a place of another kind that every use would still have to agree with. One file named in several places agrees as every fact of it does, as two clips trimming the same file agree on its frame rate, and resolve stops where two places disagree.

Covers and mattes read by their tags alone, with no `colorSpace`: a cover or a matte whose file is tagged wrongly could not be corrected, and the same file shown by a clip whose `colorSpace` corrects it would stop at resolve. A cover could be wrapped in a compound clip, but a matte is a weight field and cannot. Every place that names a media file may write its `colorSpace`.

A media clip's `colorSpace` as its own reading of the file, two clips of one file free to name two spaces: resolve would recognise text and follow a track on one frame of one file in two pictures, and the resolved document could pin two answers for one frame, so the `colorSpace` the providers follow would be a clip's interpretation and not a fact. Two clips that disagree about a file stop, naming both places.

The analysis picture of an `rec2100-pq` sequence tone mapped from the top of PQ's signal, 10000 cd/m²: the knee would lie at 23.49 cd/m², so reference white, 203 cd/m², would land at 110.98 cd/m², the encoded value 0.765, and a white title in `still` would be grey, about #C3C3C3, with every part of the frame at SDR levels darker with it, though the output holds no light above its `format.peak`. From the sequence's peak, as a player shows a file mastered there, a white title is 0.898 at the default 1000 cd/m², and the brightest light the master holds is white.

`rec2100-pq`'s peak the top of its signal, 10000 cd/m², with no `format.peak`: no source is brighter than 10000 cd/m², so `toneMap` would have nothing to do in a PQ sequence, a source mastered at 4000 cd/m² would pass into a master graded for a 1000 cd/m² display and be tone mapped by each player in its own way, and a second peak of 1000 cd/m² would hide in the rules, for the analysis picture as for a file without metadata. The mastering peak is a fact of the sequence, as DaVinci Resolve sets it, and one number gives `toneMap`'s target, the output's clip and the analysis picture's source.

`format.peak` on `rec2100-hlg` as well: HLG carries scene light, and a display's OOTF adapts it to that display's peak, so an HLG master has no mastering peak, and frames takes its OOTF at the nominal 1000 cd/m² both ways ([Colour spaces](#colour-spaces)), so its peak is fixed. A space of SDR range has reference white for its peak.

SMPTE ST 2086 metadata written from `format.peak`: ST 2086 names the mastering display's primaries, white point and minimum luminance as well as its peak, and frames knows only the peak, so the metadata stays unwritten ([FRAMES-21](../FRAMES-21/SPEC.md#notes)).

A luma track matte read as an analysis picture, as a transition matte is: a track matte is the picture its clip draws, through its transform, animation, opacity, mask, filters and own track matte, a picture of the renderer and not of the decoder, and a title or a shape that is a matte has no media to read. One kind of matte clip would take its weights from a picture no clip draws. A drawn matte's weights from HDR media depend on how its clip brings them in, and `toneMap` false makes them the same in every sequence ([Notes](#notes)).

`still`, `sheet` and `extract` written in the sequence's colour space, a P3 PNG for a `display-p3` sequence and an HDR one for an HDR sequence: a preview would look right only in a viewer and on a display that honour its tag, an agent reading it would see whatever its viewer makes of the values, and the preview would no longer be the picture the providers read. `render --at` already writes a frame in the sequence's colour space, so the master has its own check, and a preview stays one SDR picture.

Working values clamped to 0 to 1: HDR highlights and wide gamut colours would be lost at the decoder, before the output decides what it can hold.

Tone mapping by the platform, as AVFoundation converts HDR to SDR: measured, it maps 203 cd/m² to 0.89, near the 0.898 of the BT.2390 EETF from 1000 cd/m², so its result is no reason against it. Its formula is not published and is bound to the platform, so another decoder could not compute it and would map differently. The BT.2390 EETF is published and fixed.

A closed set of media colour spaces, every picture outside the table stopping at `read` and sent to `transcode`: a BT.601 video, or a camera's image with a matrix and tone-curve profile, which formulas define exactly, would need a second file before every edit. An open set with each ICC profile converted as a colour management module chooses: rendering intent, the interpolation of a LUT-based profile and black point compensation differ between modules, so two decoders would not agree. Every conversion frames makes is a formula, and a picture no formula reads, by a LUT-based profile or an undefined code point, stops.

Tone mapping each channel on its own: a bright saturated colour would shift its hue towards white as its largest channel is compressed more than the others. Mapping max(R, G, B) and scaling the three by one ratio keeps the hue.

The tone mapped picture clipped to 0 to 1 on the encoded form: that clip is the sRGB gamut, so in a `display-p3` or `rec2020` sequence an HDR source would lose its wide gamut where an SDR one of the same primaries keeps it, and clipping each channel would shift the hue the ratio keeps. In an `srgb` sequence the output's own clip gives the same pixel, so the difference lies in the wider spaces, where the output keeps the colours its gamut holds and clips the rest each channel on its own ([Output](#output)). Tone mapping decides the peak, and the output decides the gamut.

Tone mapping at the output instead of at the decoder: a filter in an SDR sequence would grade light it can never show, and an SDR sequence's look would change with how far an HDR source reached. At the decoder, as Premiere Pro tone maps media on the way in, every filter sees the picture at the sequence's peak it is graded on, and a clip with `toneMap` false is graded by hand instead.

`rec709` for media only, every SDR sequence output with the sRGB transfer or the BT.2020 one: an editor from Final Cut Pro or Premiere Pro delivers SDR video tagged BT.709 (1, 1, 1), and a video tagged with the sRGB transfer (13) is the exception, so a delivery would need retagging. `rec709` as a sequence colour space encoded by the BT.709 OETF: its output read back as `rec709` media, by the BT.1886 EOTF, would not give its working values back. Display-referred both ways, as Premiere Pro and DaVinci Resolve take Rec. 709 at gamma 2.4, the round trip is exact.

Log encodings (S-Log3, Log C, V-Log) as colour space names: each needs its camera's matrix and curve and a look, which a LUT carries as data ([FRAMES-15](../FRAMES-15/SPEC.md)).

CSS Color 4's whole `color()` grammar (percentages, `none`, `xyz`, `lab`, `oklch`, `a98-rgb`, `prophoto-rgb`): one spelling for each colour keeps the resolved form one form, and the four spaces are those an edit's media and outputs come in. Hex taken in the sequence's colour space: a document's colours would change with its output, where hex is sRGB everywhere, as in CSS.

A colour space no formula in the file gives on a page of a PDF (DeviceCMYK, a CMYK or LUT-based ICC profile) converted by the platform's colour management as the page is drawn: two decoders would convert it differently, against every conversion being fixed. `transcode` makes that reading once, and the file it writes is read by formulas from then on.

A page of a PDF composited in the list's `compositing`: under `linear` its own transparency and blend modes would look as no viewer shows them. Its look is the file's, as a PNG's pixels are.

The colour spaces one decoder does not convert by their formula stopped by the core, for every decoder: the list would be that decoder's measurements (a colour management module that puts a linear segment at black on a pure power curve, or draws a profile by its name and not its tags), and a decoder that converts them by the formula would be kept from a page it reads right. The core states the formula, and a decoder refuses what it cannot meet, as each role refuses what it does not support, so a document read on one decoder may be refused on another, as a codec may be.

A page whose colour a decoder does not convert by the formula read as its renderer draws it, with the difference named: the same profile on an image is read by the formula, and the page would differ from it silently. A refusal that suggests `transcode` is honest where that difference is not.

## Notes

**Note.** Measured on the reference machine: AVFoundation's linear output of HDR video is not BT.2408 display light (PQ at 203 cd/m² reads as 2.0, HLG at 0.75 as 3.17 scene light), while its PQ output agrees with BT.2408. The decoder reads HDR video as PQ and converts it in frames by the formulas above, and frames tone maps itself. Half-float and float bitmaps in extended sRGB and extended linear sRGB, with text and paths drawn into them, hold working values.

**Note.** The BT.2390 EETF fits a source's peak into the sequence's, and its knee starts below the target peak, so it lowers reference white too ([Tone mapping](#tone-mapping)). From a source peak of 1000 cd/m², every HLG picture's and every PQ picture's without mastering display metadata, to a sequence of an SDR space, the knee lies at 87.84 cd/m² and reference white, 203 cd/m², lands at 159.04 cd/m², the encoded value 0.898; from a PQ picture mastered at 4000 cd/m² it lands at 127.93 cd/m², 0.815. So beside an SDR clip, whose white is 1, an HDR clip's white wall is a little grey. This is the cost of a curve written to fit a display's peak and not to match two media's white. Where an HDR clip's white must meet the SDR media's, the clip takes `toneMap` false and a grade: its picture comes in as display light, reference white at 1, and its filters, a `lut` with an HDR `space` that rolls the highlights off among them, bring the highlights down before the output clips them.

**Note.** `color(rec2020 ...)` takes the `rec2020` row of this table, BT.1886 both ways. CSS Color 4 as published defines its `rec2020` by the BT.2020 OETF and its inverse, which the CSS Working Group has agreed is not the display-referred form (w3c/csswg-drafts issue 12574), so a component written for a browser's `rec2020` can name a slightly different colour here.

**Note.** Players that decode a video tagged with the BT.709 transfer (1) by the inverse of the BT.709 OETF, as QuickTime-style players do, show an `rec709` sequence's output lighter than a BT.1886 display does. frames writes the standard tags and does not compensate.

**Note.** The outermost sequence decides the peak every HDR picture comes in at, inside compound clips and template instances too ([Sequence colour space](#sequence-colour-space)), so a template's look sees its host's pictures. A look graded on SDR pictures, such as a `lut` of `space` `srgb` or a `contrast` tuned for 0 to 1, sees display light in an HDR host and clips or pushes the highlights there: the `lut` clips each channel above 1 to its domain of 0 to 1, so every highlight whose three channels lie above 1 takes one colour, the LUT's at (1, 1, 1), as an SDR LUT does on an HDR timeline in an NLE. A template meant for HDR hosts is graded on HDR pictures, and its `lut` takes the HDR `space` it was built for.

**Note.** A luma track matte is a drawn picture, the matte clip's own, and is not read as an analysis picture ([FRAMES-11](../FRAMES-11/SPEC.md)), so a track matte made from HDR media gives weights that depend on how its media came in. With `toneMap` true the reference white of an HLG matte, 203 cd/m², comes in tone mapped to the encoded value 0.898 in a sequence of an SDR space and weighs 0.898, and as display light, 1, in an `rec2100-pq` sequence of the default peak and weighs 1, so one document's matte cuts its clip to two opacities in two outputs. The matte clip takes `toneMap` false where its weights must not depend on the output: its media come in as display light, and its reference white weighs 1 in every sequence.

**Note.** Under `linear` compositing an antialiased edge of light text on a dark ground looks thinner than under `encoded`, as it does in every compositor that blends in linear light, and a 50% dissolve between black and white is brighter in the middle. Neither is a fault.

**Note.** Measured on the reference machine, the `avfoundation` decoder, drawing a page with Core Graphics into an extended sRGB or an extended linear floating point context, converts DeviceRGB and DeviceGray within 2e-8 of the formulas, CalRGB and CalGray at gamma 1 and 2.2 within 2.2e-5 (a D50 `WhitePoint` adapted by Bradford), a Display P3 ICC profile within 6.3e-5 of linear light, which near black is 2.3e-4 in encoded values, the profile's s15Fixed16 precision, a gray profile of gamma 2.2 within 2.9e-5, and the AdobeRGB 1998 profile, whose tone curves are one-entry `curv`s of 2.19921875, as the 2.2 they stand for. It reads DeviceRGB under a `DefaultRGB` space in that space and ignores transfer functions. So it refuses three classes, which it does not convert by the formula: a pure power curve of a gamma other than 1 and 2.2, in CalRGB, CalGray and ICC profiles alike, which its colour management gives a linear segment at black (3.8e-4 of linear light from the formula at gamma 1.8, 2.4e-3 at 2.4 and 5.3e-3 at 3.0); a profile whose tone curves are the inverse of BT.709's camera curve (ICC.1 parametric type 3 with γ 1/0.45, a 1/1.099, b 0.099/1.099, c 1/4.5 and d 0.081, as the ITU-R BT.709 and BT.2020 profiles carry), which it draws as BT.1886, 7.2e-2 and 7.9e-2 from what their tags give; and Lab, whose conversion is not measured. The sRGB profile is drawn as `srgb` (within 6e-8), as an image whose profile describes `srgb` is read.
