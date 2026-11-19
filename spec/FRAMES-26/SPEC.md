# FRAMES-26: Colour

Status: accepted

## Summary

How frames holds colour from the decoder to the encoder: working values in extended-range sRGB, with an encoded and a linear form; the colour spaces a sequence is output in, media are read in and a LUT is built for, with their primaries, transfers and tags; `format.colorSpace` and `format.compositing`; how media are converted to working values, HDR media tone mapped by the BT.2390 EETF and HLG taken to display light; the `color()` value; how a frame is clipped and encoded on output; and the pictures providers and analysis commands read.

## Motivation

A colour must mean one thing in a document, in every role and in every file frames writes, or two renderers draw the same document in two colours and a check made with `still` is not what the master holds. With one working space for every sequence, every formula of the specification (blend modes, filters, gradients, luma) has one meaning, and a sequence's colour space decides only how its output is encoded, as Final Cut Pro's Color Space project setting does. Editors now cut HDR and wide gamut media beside SDR media: a phone records HLG, a camera P3 or BT.2020, a graphic arrives as sRGB. Without a fixed rule for converting each to the working values and back, a decoder that clips at 1 loses the HDR highlights and a P3 red, and two decoders that tone map by their platform's own curve disagree (AVFoundation's HDR to SDR conversion is not a published formula). Without `format.compositing`, a dissolve that should mix light, as Premiere Pro's Composite in Linear Color does, could only be approximated by stacking clips. Without `color()`, a colour brighter than reference white or outside sRGB could not be written at all.

## Rules

### Working values

A **working value** is a colour as frames holds it from the decoder to the encoder: red, green and blue on the sRGB primaries and D65 white point (BT.709), each any real number, and alpha from 0 to 1. One working space serves every sequence, whatever its colour space ([Sequence colour space](#sequence-colour-space)). A working value has two forms, which name the same colour:

| Form | Channels | Meaning |
| --- | --- | --- |
| encoded | R', G', B' | the extended sRGB transfer of the linear form. Documents, the resolved document and display lists write this form, and a formula that names encoded values reads it |
| linear | R, G, B | linear light, as scRGB (IEC 61966-2-2) without its quantisation |

In both forms 1 is SDR reference white, and on an HDR output it is 203 cd/m², the reference white of BT.2408. A channel above 1 is brighter than reference white (HDR), and a channel below 0 or above 1 reaches a colour outside the sRGB gamut (wide gamut). This is Apple's extended range sRGB.

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
- **Luma** is the Rec. 709 luma of the encoded form, with alpha unpremultiplied: Y' = 0.2126 R' + 0.7152 G' + 0.0722 B'. Every rule that names luma means this value, whichever `compositing` the sequence has. A rule that weighs by luma where only 0 to 1 makes sense says that it clamps it.

### Colour spaces

| Name | Primaries | Transfer | Range | Sequence `colorSpace` | Media `colorSpace` | `lut` `space` |
| --- | --- | --- | --- | --- | --- | --- |
| `srgb` | BT.709 | sRGB (IEC 61966-2-1) | SDR | yes, the default | yes | yes, the default |
| `display-p3` | P3 D65 (SMPTE EG 432-1) | sRGB | SDR | yes | yes | yes |
| `rec2020` | BT.2020 | the BT.2020 transfer, which is the BT.709 OETF | SDR | yes | yes | yes |
| `rec709` | BT.709 | BT.709, displayed by the BT.1886 EOTF | SDR | no | yes | yes |
| `rec2100-pq` | BT.2020 | PQ (SMPTE ST 2084, as BT.2100 gives it) | HDR | yes | yes | yes |
| `rec2100-hlg` | BT.2020 | HLG (ARIB STD-B67, as BT.2100 gives it) | HDR | yes | yes | yes |

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
| BT.2020, with α = 1.09929682680944 and β = 0.018053968510807, as CSS Color 4 gives them | 4.5 × L when \|L\| < β, otherwise sign(L) × (α × \|L\|^0.45 - (α - 1)) | V / 4.5 when \|V\| < 4.5 × β, otherwise sign(V) × ((\|V\| + α - 1) / α)^(1/0.45) |
| BT.1886 at a white of 1 and a black of 0 | sign(L) × \|L\|^(1/2.4) | sign(V) × \|V\|^2.4 |

A working value is converted to an SDR space S by L_S = M × decode_sRGB(E), V = encode_S(L_S), with M the matrix from linear sRGB to S, and back by the same steps in reverse. For `srgb` V is E itself, so no rounding is added.

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

A working value is converted to an HDR space by L_2020 = M × decode_sRGB(E), F_D = 203 × L_2020, each channel of F_D clipped to the space's range (0 to 10000 cd/m² for PQ, 0 to 1000 cd/m² for HLG), then encoded: E' = PQ(F_D), or E' = OETF(OOTF⁻¹(F_D)). An HDR value is converted to a working value by F_D = EOTF(E'), or F_D = OOTF(OETF⁻¹(E')), L_2020 = F_D / 203, and the steps back to E.

**Code points.** A file names its colour space by the code points of ITU-T H.273: a video by its colour primaries, transfer characteristics and matrix coefficients, a PNG by an ICC profile or an sRGB chunk, a JPEG or HEIC by an ICC profile. frames writes and reads them by this table:

| Name | Primaries | Transfer | Written in a video (primaries, transfer, matrix) |
| --- | --- | --- | --- |
| `srgb` | 1 | 13 | 1, 13, 1 (BT.709) |
| `display-p3` | 12 | 13 | 12, 13, 1 (BT.709) |
| `rec2020` | 9 | 1, 6, 14 or 15 | 9, 14, 9 (BT.2020 non-constant luminance) |
| `rec709` | 1 | 1, 6, 14 or 15 | never written, since no sequence is output in it |
| `rec2100-pq` | 9 | 16 | 9, 16, 9 (BT.2020 non-constant luminance) |
| `rec2100-hlg` | 9 | 18 | 9, 18, 9 (BT.2020 non-constant luminance) |

A picture's colour space is the row whose primaries and transfer it is tagged with, and a picture tagged with any other pair is outside the table. A code point a file leaves out, or writes as 2 (unspecified), is taken as `srgb`'s, so an untagged picture is `srgb`. The matrix decides how a video's Y'CbCr is taken to R'G'B' and not which row applies.

### Sequence colour space

`format.colorSpace` is a name from the table whose Sequence column says yes, and its default is `srgb`. Any other name stops at `check`. It decides three things, and nothing else:

- how the sequence's output is encoded and tagged ([Output](#output)),
- which gamut and peak its output is clipped to ([Output](#output)),
- whether HDR media are tone mapped on the way in: in a sequence of an SDR space they are, in one of an HDR space they are not ([Media](#media)).

The working values, and so every formula of the specification, are the same in every sequence. A compound clip's or a template instance's `colorSpace` applies only when it is rendered alone, as its `fps` does ([FRAMES-3](../FRAMES-3/SPEC.md)): inside another sequence its frames are working values, the outermost sequence's colour space decides the three things for every clip it shows, and the key is allowed there and has no effect. The format's `background` is a working value like any other.

### Compositing

`format.compositing` is `encoded` or `linear`. **Its default is `encoded`.** Any other value stops at `check`.

Every composite of a colour onto what is below it uses the formulas of W3C Compositing and Blending Level 1 that [FRAMES-20](../FRAMES-20/SPEC.md) applies, with the source and backdrop colours Cs and Cb, and their premultiplied forms, read in the form `compositing` names: the encoded form under `encoded`, as W3C Compositing, browsers and After Effects write and composite them, and the linear form under `linear`, as Premiere Pro's Composite in Linear Color and After Effects' Blend Colors Using 1.0 Gamma composite them. A blend mode's formula is applied to the values of that form as they are. The result is in the same form, and it is the working value that form names.

| Taken by `compositing` | Not taken by it |
| --- | --- |
| an item composited onto what is below it in its display list, by its `blend` and its alpha after its reveal, matte, mask, track matte and `opacity` ([FRAMES-20](../FRAMES-20/SPEC.md)); a nested list's picture onto the list that holds it | the filter ops, each in its own domain ([FRAMES-15](../FRAMES-15/SPEC.md)), and a filter entry's `mix`, on the encoded form |
| the coverage of an antialiased edge (a path, a glyph, a reveal's edge, a mask's edge and feather), which is alpha | the interpolation of keyframed colours and of a gradient's stops, on the encoded form ([FRAMES-4](../FRAMES-4/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md)) |
| the parts an item draws over each other: a picture's border over it, a shadow under its item, a title's background, highlights, underlines, strokes and fills in their order | luma, for a luma track matte and a transition matte, on the encoded form |
| the two storyline pictures of a transition, so a dissolve in `linear` mixes light, and a transition cover over them ([FRAMES-14](../FRAMES-14/SPEC.md)) | mask values, which are not colours and multiply alpha as written ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| an adjustment's filtered picture onto the unfiltered one by its `blend` ([FRAMES-11](../FRAMES-11/SPEC.md)) | resampling a picture to its size and the blurs inside filter ops, on the encoded form premultiplied |

A compound clip's or a template instance's own `compositing` composites the items of its own frame, as its `background` and `conform` apply there ([FRAMES-3](../FRAMES-3/SPEC.md)). Its picture is composited onto the frame that shows it by that frame's `compositing`.

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
- `srgb` is the encoded working value itself: R' = c1, G' = c2, B' = c3. `srgb-linear` is the linear form: R' = encode(c1), and so on. `display-p3` and `rec2020` are converted from their space as [Colour spaces](#colour-spaces) gives (the sRGB transfer and the P3 primaries for `display-p3`, the BT.2020 transfer and primaries for `rec2020`).
- A theme colour is any of these but a name, and a value that names it is its colour ([FRAMES-22](../FRAMES-22/SPEC.md)).
- **The resolved document and display lists write every colour as `color(srgb r g b / a)`**: the encoded working value, its four numbers in the number form of [FRAMES-19](../FRAMES-19/SPEC.md), alpha always written, one space between the parts and around `/`. A colour of another form there stops reading, naming its place.

### Media

The decoder converts every picture it reads (a video's frames, an image, an image sequence's frames, a transition's cover or matte media) to working values.

- Its colour space is the one its tags name ([Colour spaces](#colour-spaces)), or the `colorSpace` written on the media clip that shows it. A video's Y'CbCr is taken to R'G'B' by the matrix and the range (narrow or full) the file says, as BT.709 and BT.2100 quantise them, and a value beyond the nominal range is kept. An image whose ICC profile describes a space of the table (its primaries, white point and transfer) is in that space. Any other tagged picture is converted as its code points' standards or its ICC profile define (colorimetric, to linear sRGB, no gamut clipped).
- **`colorSpace` on a media clip** (a storyline clip with media, a connected or sequence media clip) overrides what the file says, as Premiere Pro's Override Media Color Space does: a name whose Media column says yes. `rec709` is for a video tagged wrongly or not at all whose pictures were made for a BT.1886 display. Log footage is not a colour space: a `lut` filter takes it to a display space ([FRAMES-15](../FRAMES-15/SPEC.md)). The key is a name and static. On a clip whose media is a compound clip or a template instance it stops, as a key of another media row does ([FRAMES-7](../FRAMES-7/SPEC.md)), since such media are working values already. A name the Media column does not allow stops at `check`.
- **SDR media** are converted exactly, as [Colour spaces](#colour-spaces) gives, in every sequence: nothing is clipped, so a wide gamut picture in an `srgb` sequence keeps its colours until the output clips them.
- **HDR media in a sequence of an HDR space** are display light, 203 cd/m² taken as 1, with no tone mapping, whichever HDR transfer the media and the sequence have: PQ media by the PQ EOTF, HLG media by the HLG EOTF with the OOTF at 1000 cd/m² ([Colour spaces](#colour-spaces)). Light past the sequence's peak is clipped at the output.
- **HDR media in a sequence of an SDR space** are tone mapped at the decoder, before any filter, as Premiere Pro tone maps media on the way in ([Tone mapping](#tone-mapping)).

### Tone mapping

An HDR picture is tone mapped to SDR by the EETF of BT.2390 on max(R, G, B), with RGB scaled by the ratio it gives so the hue is kept. For each pixel:

1. Take its display light F_D = (R_D, G_D, B_D) in cd/m² on BT.2020 primaries, by the PQ EOTF or by the HLG EOTF with its OOTF at 1000 cd/m², and M = max(R_D, G_D, B_D).
2. Take the source peak L_W, the source black L_B, the target peak L_max and the target black L_min. L_W is the maximum luminance of the file's mastering display (its SMPTE ST 2086 metadata) for PQ, or 1000 cd/m² when it has none, at most 10000 cd/m², and 1000 cd/m² for HLG, its OOTF's peak. L_B = 0, L_max = 203 cd/m² (working value 1) and L_min = 0.
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

   When L_W is at most L_max, E2 = E1. With L_min 0, b is 0 and E3 = E2.
4. Scale the pixel by the ratio: F_D' = F_D × M' / M, and 0 where M is 0.
5. Take F_D' to a working value as an HDR value is taken ([Colour spaces](#colour-spaces)): L_2020 = F_D' / 203, the matrix to linear sRGB, the sRGB transfer. Then clip each channel of the encoded form to 0 to 1.

The formula is fixed, so two decoders agree to their rounding.

### Output

The encoder writes the renderer's frames of working values in the sequence's colour space:

- **SDR space:** each channel of the space's linear value, L_S = M × decode_sRGB(E), is clipped to 0 to 1, then encoded with the space's transfer. In an `srgb` sequence that is each channel of E clipped to 0 to 1.
- **HDR space:** the working value is converted as [Colour spaces](#colour-spaces) gives, with the display light clipped to the space's range: 0 to 10000 cd/m² for `rec2100-pq`, 0 to 1000 cd/m² for `rec2100-hlg`.
- Alpha lies in 0 to 1 and is written as it is. A file that stores premultiplied alpha stores the encoded colour multiplied by it.
- An encoded value V from 0 to 1 is written at the file's bit depth n as the nearest code value: round(V × (2^n - 1)) for R'G'B', and for a video's Y'CbCr the narrow range code values BT.709 and BT.2100 give, by the matrix the table writes.
- The file is tagged with the sequence's colour space: the code points the table writes in a video, and an ICC profile of that space in a JPEG, a HEIC or a PNG, where an `srgb` PNG takes an sRGB chunk instead. Which files are written, at which depths and codecs, is [FRAMES-21](../FRAMES-21/SPEC.md) and [FRAMES-23](../FRAMES-23/SPEC.md).

### Providers and analysis pictures

An **analysis picture** is an SDR sRGB picture: encoded working values with every channel in 0 to 1.

- The providers (OCR, the tracker, [FRAMES-21](../FRAMES-21/SPEC.md)) read analysis pictures of media: the picture the decoder gives for an `srgb` sequence, so HDR media are tone mapped as [Tone mapping](#tone-mapping) gives, with each channel of the encoded form clipped to 0 to 1, so wide gamut is clipped. They read a file as its tags say, never by a clip's `colorSpace`, so no recognised text and no track depends on the sequence or the clip, and the `ocr` and `track` commands see what resolve sees.
- `still`, `sheet` and `extract` ([FRAMES-23](../FRAMES-23/SPEC.md)) write analysis pictures at 8 bits per channel, sRGB tagged, since they are for looking at. A frame of a sequence of an SDR space is encoded as an `srgb` sequence's output. A frame of a sequence of an HDR space is first encoded as its own output, with its display light clipped to its range, then tone mapped as an HDR picture of that space with no mastering display metadata. A video's frames are analysis pictures of the video. Time labels are drawn on the analysis picture, composited on its encoded values.

## Interactions

The units table points here for colour values ([FRAMES-1](../FRAMES-1/SPEC.md)). Keyframed colours interpolate on the encoded form ([FRAMES-4](../FRAMES-4/SPEC.md)), and so do gradient stops ([FRAMES-11](../FRAMES-11/SPEC.md)). `format.colorSpace`, `format.compositing` and a media clip's `colorSpace` are keys of [FRAMES-7](../FRAMES-7/SPEC.md), the format is [FRAMES-9](../FRAMES-9/SPEC.md) and what a compound clip's format applies is [FRAMES-3](../FRAMES-3/SPEC.md). Blend modes and track mattes are [FRAMES-11](../FRAMES-11/SPEC.md), transitions [FRAMES-14](../FRAMES-14/SPEC.md), and the domain of each filter op [FRAMES-15](../FRAMES-15/SPEC.md). The resolved document and the display list carry colours, colour spaces and the compositing as [FRAMES-19](../FRAMES-19/SPEC.md) and [FRAMES-20](../FRAMES-20/SPEC.md) say. The roles, the files they write and the providers are [FRAMES-21](../FRAMES-21/SPEC.md), theme colours [FRAMES-22](../FRAMES-22/SPEC.md), and `probe`, `transcode` and the analysis commands [FRAMES-23](../FRAMES-23/SPEC.md).

## Alternatives considered

A working space per sequence (linear P3 for a P3 sequence, linear BT.2020 for an HDR one): the same document would composite, blend and filter differently by its output, and a resolved colour would need its sequence to be read. One working space keeps every formula and every resolved colour one meaning, and the sequence's colour space decides only its output, as Final Cut Pro's wide gamut library does.

Linear working values for every formula, as ACES and scRGB pipelines hold them: every formula written on encoded values (the W3C blend modes, `contrast`, `levels`, a LUT's input, luma) would change its meaning, and a sequence would no longer composite as browsers and After Effects do by default. `format.compositing` gives linear light where it is wanted, and the filter ops that need it (`exposure`, `temperature`) work in it already.

Working values clamped to 0 to 1: HDR highlights and wide gamut colours would be lost at the decoder, before the output decides what it can hold.

Tone mapping by the platform, as AVFoundation converts HDR to SDR: measured, it maps 203 cd/m² to 0.89 rather than 1, follows no published formula, and another decoder would map differently. The BT.2390 EETF is published and fixed.

Tone mapping each channel on its own: a bright saturated colour would shift its hue towards white as its largest channel is compressed more than the others. Mapping max(R, G, B) and scaling the three by one ratio keeps the hue.

Tone mapping at the output instead of at the decoder: a filter in an SDR sequence would grade light it can never show, and an SDR sequence's look would change with how far an HDR source reached. At the decoder, as Premiere Pro tone maps media on the way in, every filter sees the SDR picture it is graded on.

Log encodings (S-Log3, Log C, V-Log) as colour space names: each needs its camera's matrix and curve and a look, which a LUT carries as data ([FRAMES-15](../FRAMES-15/SPEC.md)).

CSS Color 4's whole `color()` grammar (percentages, `none`, `xyz`, `lab`, `oklch`, `a98-rgb`, `prophoto-rgb`): one spelling for each colour keeps the resolved form one form, and the four spaces are those an edit's media and outputs come in. Hex taken in the sequence's colour space: a document's colours would change with its output, where hex is sRGB everywhere, as in CSS.

## Notes

**Note.** Measured on the reference machine: AVFoundation's linear output of HDR video is not BT.2408 display light (PQ at 203 cd/m² reads as 2.0, HLG at 0.75 as 3.17 scene light), while its PQ output agrees with BT.2408. The decoder reads HDR video as PQ and converts it in frames by the formulas above, and frames tone maps itself. Half-float and float bitmaps in extended sRGB and extended linear sRGB, with text and paths drawn into them, hold working values.

**Note.** Under `linear` compositing an antialiased edge of light text on a dark ground looks thinner than under `encoded`, as it does in every compositor that blends in linear light, and a 50% dissolve between black and white is brighter in the middle. Neither is a fault.
