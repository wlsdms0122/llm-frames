# Measurements

A spec states rules and requirements. Where a bound or a constant takes its value from a measurement, the spec gives that basis in one sentence, and this page keeps the measurement itself: what was measured, on what, the numbers, and the spec sentence it supports. A measurement says what held on the runs made. It binds nothing, and a spec never depends on this page to say what it requires.

The reference machine is an Apple M1 Pro. A section is kept for each spec that has measurements, in the order of the specs.

## FRAMES-24

### A video frame converted by the decoder on the GPU and on the CPU

Supports: [Tolerances](../spec/FRAMES-24/SPEC.md#tolerances), the `avfoundation` decoder's conversion on the GPU within 2⁻¹⁰ × max(1, |v|) of the CPU's, mean within 2⁻¹⁸.

On: the reference machine with the `avfoundation` decoder, three frames each of 640 by 360 gradients, values from -0.05 to 1.05, written as HEVC Main 10 in `display-p3` and `rec2020` and as 8-bit H.264 in `rec709` and `srgb`; and a frame of a 1206 by 2622 Display P3 screen recording rendered with a title to a 16-bit PNG.

Numbers: the largest difference of a component over max(1, |v|) was 9.7e-4 in `display-p3` and `rec2020`, one step of a half float just above 1, and 4.9e-4 in `rec709`. The mean difference was at most 3.8e-7. `srgb`, whose conversion is the identity, gave the same bits. The screen recording's frame differed in 2 of its 12.6 million components, by one step of a half float. Two conversions of a frame on the GPU gave the same bytes.

### `metal` against `quartz` on the same display lists

Supports: [Tolerances](../spec/FRAMES-24/SPEC.md#tolerances), a renderer against `quartz` within 2⁻⁹ × max(1, |v|) per component, 2⁻¹² on average, and edges within 1/64 of a pixel; and the rule that a role gives the same bytes on every run.

On: the reference machine, twenty-three frames of nineteen cases, of 160 by 90 pixels, 400 by 20 for motion blur and 1024 by 1024 for the corner pin: a video under a moving title, in the encoded and the linear form; a still scaled down, half transparent and in `screen`; a detailed still scaled by 0.625 and by 1.375, one turned by 17 degrees, ones scaled by 0.25 and by 3, and one at its own size moved by part of a pixel; pictures with rounded corners, a border and a shadow, one turned and half transparent and one casting its shadow from outside the frame; a detailed still filtered by temperature, contrast and exposure, one blurred, and a video with rounded corners, a border and a shadow blurred and warmed; a still through a LUT; a still scaled by 0.75, turned by 23 degrees, half grey by a mix and sharpened; an adjustment with a mix and one with a feathered mask and an opacity over a filtered video under a title; the edges of a still scaled by 1.375 at fractional positions; hard edges of a shape and of a picture at positions of 3/8 and 5/8 of a pixel; shapes with a stroke, rounded corners, a shadow and a feathered mask; an adjustment cut by a track matte; a crossfade between a detailed video and a detailed still at a quarter, a half and three quarters of the way; a corner pin; and motion blur.

Numbers, agreement: the largest difference of a component over max(1, |v|) was 1.6e-3 on the adjustments over the filtered video, the same on `quartz`'s drawing of them into layers, and at most 9.8e-4, one step of a half float at 1, on every other case, at flat pixels in the linear form and at others in the crossfade, the turned still and the filtered and decorated pictures. The mean difference was at most 1.3e-4 at flat pixels and 1.2e-4 at the others, both in the crossfade. Alpha differed nowhere, and every edge lay at the same position in both. By kind of picture:

| Pictures | How `metal` draws them | Largest difference | Mean |
| --- | --- | --- | --- |
| Resampled pictures | on the GPU by the kernel `quartz` resamples with | 9.7e-4 turned, 4.9e-4 upright | at most 9.7e-6; edges the same |
| Rounded corners, border, shadow | covered, bordered and shadowed on the GPU from what the rasteriser of `quartz` draws | 9.8e-4 | 2.9e-5 |
| Filtered pictures | one Core Image image on both renderers, which `metal` lays as it is and `quartz` renders and draws | 9.8e-4 | 1.1e-5 upright, 1.0e-4 turned and half transparent |
| Adjustments | filtered on the GPU frame below them | 1.6e-3 | 3.0e-5; the one cut by a track matte not at all |
| Shapes, corner pin, motion blur | by the drawing of `quartz` into a layer | 4.9e-4, the rounding of the layer | |

Numbers, repeated runs: `metal` gave the same bytes for each of these frames drawn again by one renderer and by a new renderer on a new decoder in every run measured: 200 rounds of the twenty-three frames in each of five processes, two alone, two beside a `quartz` and a `metal` renderer drawing the same frames on another thread, and one beside those and three processes rendering 1080 by 1920 videos, 46,000 frames in all; the frames of 132 fresh processes, 30 of them with every kernel compiled anew; and 90 runs of the determinism and agreement tests together in fresh processes. `quartz` gave the same bytes for 9,200 frames drawn the same way beside the same thread. The frames of two processes differed only where the H.264 videos each process writes for these cases differed: the hardware encoder may write other bits for the same pictures, and one video kept and decoded in 30 processes gave the same bytes in each. A video frame converted on the CPU differs from the GPU's conversion by one step of a half float at one to three pixels of eleven of these frames, within every tolerance against `quartz`.

### A picture of pixels resampled against its definition

Supports: [Rules](../spec/FRAMES-24/SPEC.md#rules), "A picture of pixels is resampled by its definition": each component within 2⁻⁹ × max(1, |v|) of the definition in double precision, 2⁻¹² on average.

On: the reference machine, the set that rule names, on `quartz` and `metal`, against the definition evaluated in double precision.

Numbers: `quartz` and `metal` gave the same values, each component within 4.9e-4 of the definition at every scale and turn, a quarter of the bound, within 1.5e-4 on average turned by 17 degrees at scale 1, and at most 1.3e-4 upright. Each edge of the picture scaled by 1.375 and at its own size lay within 2.5e-4 of a pixel of its geometric position.

### A frame converted by the encoder on the GPU and on the CPU

Supports: [Tolerances](../spec/FRAMES-24/SPEC.md#tolerances), the `avfoundation` encoder's conversion on the GPU within one code value of the CPU's.

On: the reference machine with the `avfoundation` encoder, a 512 by 96 frame of half floats whose unpremultiplied colours run from -0.25 to 1.25 at alphas from 0 to 1, in `srgb`, `display-p3`, `rec2020` and `rec709`, at eight bits, as a delivery is written, and at sixteen, as a master is, with alpha kept and dropped.

Numbers: a code value converted on the GPU differed from the CPU's by at most 1, in at most 1.9 percent of the values, in `display-p3`, and in none at eight bits in `srgb`, `rec2020` and `rec709`. Two conversions of the frame on the GPU gave the same bytes.
