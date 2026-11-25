# Measurements

This is not part of the specification. A spec states rules and requirements, and where a bound or a constant takes its value from a measurement, the spec gives that basis in one sentence. This page keeps the measurement itself: what was measured, on what, the numbers, and the spec sentence it supports, which each entry names on its Supports line. A measurement says what held on the runs made. It binds nothing, and no spec depends on this page or links to it.

The reference machine is an Apple M1 Pro. A section is kept for each spec that has measurements, in the order of their numbers.

## FRAMES-21

### A render's file bytes

Supports: [Rules](../spec/FRAMES-21/SPEC.md#rules), "File bytes are not promised, since hardware encoders differ", and the Note on a file's bytes.

On: the reference machine, two renders of one document to an `.mp4` by the same decoder, renderer and conversion.

Numbers: the two files had the same length and differed in the creation and modification times of the movie, track and media headers and in two bytes of the user data message the hardware H.264 encoder writes into the first frame.

### Regions of a page drawn apart

Supports: [Rules](../spec/FRAMES-21/SPEC.md#rules), "two draws of different regions need not agree to the last value where they overlap", and "The same page, scale and region give the same picture".

On: the reference machine with the `avfoundation` decoder, a page of 400 by 300 points drawn at scale 3.3 as four tiles at whole pixel origins of the same grid, against one draw of the whole page.

Numbers: text set from an embedded font gave the same pixels. An axial gradient differed by up to 3.2e-3 and filled curves by up to 3.9e-3 (1/255). Strokes 0.1 and 0.35 points wide differed by up to 0.208, on 7 % of the pixels and mostly away from the seams (965 of 94740 within 1 pixel of one). A region whose origin is half a pixel off the grid differed by up to 0.996, since it is resampled. Three processes drawing the same page, scale and region gave the same hash.

### The cost of drawing a dense page

Supports: the Note in [Notes](../spec/FRAMES-21/SPEC.md#notes) on what a dense page costs and that a decoder may draw pictures of one document in parallel.

On: the reference machine (10 processors) with the `avfoundation` decoder, a page of 1920 by 1080 points holding 50,000 paths about 30 points across and 2,000 runs of text in 4 fonts.

Numbers: 1.9 s for the whole page at scale 2 (3840 by 2160 pixels), 1.1 s for a region at a 10 times zoom and 1.0 s at scale 1, most of it a fixed cost of about 20 microseconds per object. Paths that span the page cost up to 58 s. 16 draws in parallel from one shared document gave the serial draw's pixels, at about 4 times its throughput on 10 cores.

### The `planar` tracker losing a target

Supports: the Note in [Notes](../spec/FRAMES-21/SPEC.md#notes) on when the `planar` tracker reports its target lost.

On: 640 by 360 H.264 video of a textured poster in perspective with a bar growing over the target from its left or its top edge, and a target of one flat grey.

Numbers: the poster was followed to 30 % covered and lost at 32 %, within 0.3 pixels on every frame followed. The flat grey target was lost on the first frame after its own.

### AVFoundation's reads and the threads they need

Supports: [Rules](../spec/FRAMES-21/SPEC.md#rules), the decoder paragraph's "waits on threads of either pool, or near 64 reads at once on any threads, hold every thread that work needs, and no read ends", and the Note that AVFoundation's reads stop finishing at 64 at once.

On: the reference machine (10 processors, macOS 27.2).

Numbers: with every thread of Swift's shared pool blocked on a semaphore, one AVAssetReader read of a small video on a thread of its own did not finish in six minutes, and with one of the ten free it finished in 0.02 s. Sixty reads at once on a concurrent Dispatch queue held 60 of its 64 threads, AVFoundation's waits to make sample data ready held the other four, and none finished. With 64 threads of such a queue blocked, one read on a thread of its own waited until they were freed. Eighty reads on eighty serial queues finished in 0.3 s. A hundred reads on threads of their own finished in 0.5 s once, and once held 64 threads in those waits and none finished. VideoToolbox made forty H.264 or HEVC compression sessions of 1920 by 1080 at once and encoded a frame with each, 31 of them on a hardware encoder.

### Readers, memory and swap

Supports: [Rules](../spec/FRAMES-21/SPEC.md#rules), the decoder paragraph's bound of 48 readers and of a quarter of the machine's memory, and the Note on a reader opened while 64 decode.

On: the reference machine (10 processors, 16 GB of memory, macOS 27.2), H.264 videos of 1206 by 2622 pixels and 258 MB each, High 4:4:4 Predictive profile streams of 8-bit 4:2:0, 180 frames by `quartz`.

Numbers, read as `16-bit float RGBA`: while 64 AVAssetReaders decoded in one process, a 65th failed its first frame with AVFoundation's error -11821, Cannot Decode. Each reader decoding held about 35 MB in the process and about 335 MB in VideoToolbox's decoding service, which held about 127 MB for a reader of the same video read as 8-bit 4:2:0 Y'CbCr.

Numbers, hashing: a resolve that hashed its media in chunks through FileHandle on a thread that drained no pool held every file whole: renders of 8, 16, 24 and 32 such videos shown at once peaked at 5.8, 11.3, 16.7 and 22.2 GB of memory that way, and at 1.6, 3.0, 4.3 and 5.6 GB with each chunk's pool drained.

Numbers, textures and kept pictures: with each chunk's pool drained, a texture kept with each surface and only the pictures of the frame drawn last kept, renders of 8 and 16 such videos shown at once took 19.7 and 31.3 s and peaked at 1.2 and 2.2 GB, against 19.7 and 49 s and 1.6 and 3.0 GB with a texture made for each conversion and four pictures kept for each file. The GPU ran each frame's conversion in 2.7 ms however many videos were shown, and the rest of a conversion's time was its command buffer's wait to be submitted. With 24 such videos the decoding service held 8.6 GB, the machine's free memory stayed under 100 MB and about 9 GB was swapped out during each render, which took 60 to 70 s with 3.0 GB peak in the process.

Numbers, read as `8-bit integer Y'CbCr 4:2:0`: renders of 8, 16 and 24 such videos shown at once took 14.9, 28.7 and 44.3 s, the process's footprint peaked at 1.1, 2.0 and 2.8 GB, the decoding service's at 1.06, 1.91 and 2.78 GB, wired memory at 4.0, 5.4 and 6.7 GB, and no page was swapped out, against 15.5, 29.0 and 59.9 s, 2.9, 6.0 and 8.7 GB in the service and 8.9 GB swapped out during the render of 24 read as `16-bit float RGBA`. A render of 32 such videos took 39.4 s, the service peaked at 3.19 GB, the process at 3.76 GB and wired memory at 7.7 GB, no page was swapped out and no reader was closed: 32 readers of 133 MB each by the decoder's cost hold 4.25 GB, within a quarter of 16 GB, so the memory bound first closes a reader at 33 such videos, and the service held three quarters of what the cost gives.

### Frames a reader holds in the decoding service

Supports: [Rules](../spec/FRAMES-21/SPEC.md#rules), the decoder paragraph's cost of a reader, 28 frames given as Y'CbCr and 19 given as `16-bit float RGBA`.

On: the reference machine (10 processors, 16 GB of memory, macOS 27.2), each reader decoding a video with 30 frames read and the last kept, counted in frames of the stored size in the form the reader gives.

Numbers:

| Video | Given as Y'CbCr | Given as `16-bit float RGBA` |
| --- | --- | --- |
| H.264, 1206 by 2622 | 26.8 (`420v`) | 13.2 |
| H.264, 1920 by 1080 | 17.5 (`420v`) | 12.5 |
| HEVC of 10 bits, 1920 by 1080 | 13.1 (`x420`) | 13.0 |
| ProRes 422, 1920 by 1080 | 6.4 (`x422`) | 15.0 |
| ProRes 4444, 1920 by 1080 | | 18.4 |

A render of 8 videos of 1206 by 2622 pixels read as `8-bit integer Y'CbCr 4:2:0` held 132 MB a reader in the service, 27.8 such frames.

### A surface read by `quartz`

Supports: [Pictures](../spec/FRAMES-21/SPEC.md#pictures), "a role that reads pixels reads a surface's where they lie, with no copy and no conversion", and the Note on drawing a surface through a Core Graphics image.

On: the reference machine, 180 frames of a 1206 by 2622 Display P3 recording conformed to fill 1080 by 1920 under a title.

Numbers: `quartz` resampling the decoder's surface from a Core Graphics image of its memory had Core Image copy it into a surface of its own on every frame, a fifth of the time it drew, and keep those copies, so the render peaked at 4.6 GB. Reading the surface where it lies took the render from 3.47 to 3.04 s, its drawing from 2.86 to 2.42 s, and its peak to 0.3 GB.

### VideoToolbox's conversion of Y'CbCr against the formulas

Supports: [Rules](../spec/FRAMES-21/SPEC.md#rules), the decoder taking a video's Y'CbCr to R'G'B' itself, and the Note on VideoToolbox's gain.

On: the reference machine, 8-bit narrow range Y'CbCr converted by VideoToolbox to `16-bit float RGBA`, and H.264 videos of 1206 by 2622 pixels.

Numbers: 100% white, Y' 235, came out 1.0039, and the 75% colour bars of BT.709 and of BT.601 up to 0.0039 from the formulas' values for their code values, mostly above them by a gain of about 1.0042, and black as 0. On the H.264 videos the decoder's conversion and VideoToolbox's differ by 0.0032 to 0.0040 in the mean and at most 0.0106 at the edges of colours, where the chroma filters differ as well.

### Alternatives considered

Supports: the reasons [Alternatives considered](../spec/FRAMES-21/SPEC.md#alternatives-considered) gives.

- Every picture converted on the CPU: 84 % of a render's time on a Display P3 screen recording.
- Core Graphics at `medium` interpolation: where a picture's antialiased edge and its cut to `dest` met, a pixel covered 0.624 came out 0.388 and the edge lay a quarter of a pixel inward. Core Image's bilinear sampling differed from it by up to 0.44 in a component on a detailed still scaled by 0.625 and 1.375.
- The corner pin's definition for every picture: its warp cost 17 to 23 ms a frame at 1024 by 1024.
- A picture converted on the GPU copied out as a bitmap: the copy cost a 1206 by 2622 frame 2.3 ms against 0.7 ms for its conversion.
- Every video's frames as `16-bit float RGBA`: about 335 MB in the decoding service for each reader decoding a video of 1206 by 2622 pixels, against about 127 MB for the same reader given 8-bit 4:2:0.
- Closing the reader read longest ago with no turns: a render of 64 videos of 320 by 180 pixels shown at once, 240 frames, took 73.1 s that way, 31 s with a reader open on each and 25.0 s with turns, which opened 515 readers again and decoded each of the 15360 frames it read once.
- Reading ahead up to 32 frames: renders of 16 and 24 videos of 1206 by 2622 pixels shown at once took 31.3 and 70.7 s reading up to 10 frames ahead and 30.8 and 70.0 s reading up to 32, and with up to 32 a render of 64 small videos shown at once had a reader give no frame.
- Several Metal command queues: a render of 24 videos of 1206 by 2622 pixels took 131 s with four queues against 121 s with one, and 129 s of system time against 90 s.

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

## FRAMES-26

### AVFoundation's output of HDR video

Supports: [Media](../spec/FRAMES-26/SPEC.md#media), the decoder reading HDR video as PQ and converting it by frames' formulas, and the Note on AVFoundation's linear output.

On: the reference machine, HDR video read through AVFoundation as linear and as PQ output.

Numbers: in the linear output, PQ at 203 cd/m² read as 2.0 and HLG at 0.75 as 3.17, scene light, where BT.2408 display light gives 1. The PQ output agreed with BT.2408.

### AVFoundation's tone mapping against the BT.2390 EETF

Supports: the alternative of tone mapping by the platform in [Alternatives considered](../spec/FRAMES-26/SPEC.md#alternatives-considered).

On: the reference machine, AVFoundation's conversion of HDR to SDR.

Numbers: it mapped 203 cd/m² to 0.89, where the BT.2390 EETF from 1000 cd/m² gives 0.898.

### Core Graphics drawing a page's colour spaces

Supports: the Note in [Notes](../spec/FRAMES-26/SPEC.md#notes) that a page's tagged colour is as exact as its renderer's colour management.

On: the reference machine, Core Graphics drawing into an extended sRGB or an extended linear floating point context.

Numbers: DeviceRGB and DeviceGray within 2e-8 of `srgb`; a Display P3 profile within 6.3e-5 of linear light; the sRGB profile within 6e-8 of `srgb`. A pure power curve at 2.4 drawn with a linear segment at black, max(x^g, x / 16), 3.2e-3 of linear light from the power. An RGB profile whose tone curves are the inverse of BT.709's camera curve drawn as BT.1886, 8.8e-2 from the image formula. Lab taken to XYZ relative to D50 whatever its `WhitePoint`, its `Range` mapped onto [-127.5, 127.5], 0.15 from ISO 32000-1 at the default range.

## FRAMES-27

### Carrying a picture onto a corner pin

Supports: the corner pin bounds of [FRAMES-24](../spec/FRAMES-24/SPEC.md#rules), "A picture carried onto a corner pin is area sampled", and the Note in [Notes](../spec/FRAMES-27/SPEC.md#notes) on what separates one sample per pixel from area sampling.

On: the reference machine, half float premultiplied pictures, the set FRAMES-24 names, against the mean of [What a renderer holds](../spec/FRAMES-27/SPEC.md#what-a-renderer-holds) taken over at least 16 × 16 samples per output pixel, more where neighbouring samples would land over a quarter of a source pixel apart.

Numbers:

| Method | Worst | Average on the grid under the steep corner pin | Checkerboards, worst and average | Time a frame |
| --- | --- | --- | --- | --- |
| Core Image's `CIPerspectiveTransform`, one bilinear sample at each output pixel's centre | 0.246 on the checkerboard under the mild corner pin, 0.444 under the steep one, 0.769 on the grid under the steep one | 0.069 | | |
| The picture rastered smaller first, or filtered with Lanczos first | | 0.146 to 0.187 | | |
| A Metal kernel of 4 × 4 subsamples, each a trilinear read from a 2 × 2 box pyramid, levels transparent past the edge | 0.075 on the grid | 0.003 | 0.025 and 0.0002 | 10 to 14 ms |
| The Quartz renderer's kernel, levels with edge pixels repeated outward and subsamples weighted by coverage, on the set as FRAMES-24 writes it in y-down pixels | 0.077 on the grid | 0.003 | 0.025 and 0.0002 | 17 to 23 ms |
| An n × n kernel without a pyramid, n adapted to the local shrink | 0.025 on the grid | 0.002 | | up to 48 ms |

The Metal kernel gave the same bytes over 20 renders and three processes. Its levels, transparent past the source's edge, darkened what lies just inside the edge under minification. Through the whole path, with the list that holds the still rastered at the stretch held to the pixel limit, below 1 under the mild corner pin and about 1.41 under the steep one, the result was 0.16 to 0.27 from the mean at worst, and on the grid 0.016 on average under the mild corner pin and 0.008 under the steep one. With the list at its own size, every case was within the bounds.

## FRAMES-28

### The limiter's true peak over its ceiling

Supports: the limiter check of [FRAMES-24](../spec/FRAMES-24/SPEC.md#rules), a `truePeak` at most the ceiling plus 0.05 dB, and the range of `lookahead` from 0.0015 in [Limiter](../spec/FRAMES-28/SPEC.md#limiter).

On: the limiter at a `ceiling` of -1, the output's `truePeak` read by frames' meter from the output's own samples.

Numbers: at a `lookahead` of 0.0015, 0.005 and 0.05 and a `release` of 0.000001, 0.1 and 1, the five signals of the limiter check of FRAMES-24 read at most 0.019 dB over the ceiling, on the noise bursts at a `lookahead` of 0.0015 and a `release` of 0.000001, and under 0.004 dB over it from a `lookahead` of 0.005. Other sounds (sines from 50 Hz to 0.45 of the sample rate, square waves, clicks, white noise and noise bursts up to 50 dB over full scale, and a dense mix 8 dB over full scale, at a `release` from 0.000001 to 1) read at most 0.025 dB over, on white noise 50 dB over full scale at a `lookahead` of 0.0015 and a `release` of 0.000001. With a look-ahead of one sample or none the output read up to 2 dB over the ceiling.

### A limited mix on another meter

Supports: the Note in [Limiter](../spec/FRAMES-28/SPEC.md#limiter) that another meter interpolates otherwise than the four points of the Annex 2 filter.

On: mixes limited by frames' limiter, read with a 16 times interpolator.

Numbers: the mixes read up to 0.23 dB above their ceiling, and the same mixes limited 0.25 dB lower read under the ceiling there.

## FRAMES-29

### The cost of motion blur

Supports: the Note in [Notes](../spec/FRAMES-29/SPEC.md#notes) that a frame's time and display list grow with N.

On: `render` built for release on the reference machine with 16 GB, 25 frames of a zooming storyline image, a sliding title under `frames/rise`, a turning rect and a sliding picture in picture clip, all with `motionBlur`, timed from the start of the command to the written master.

Numbers:

| Size | Without motion blur | 16 samples | 64 samples |
| --- | --- | --- | --- |
| 1080p, time a frame | 54 ms | 440 ms | 1648 ms |
| 4K, time a frame | 180 ms | 1652 ms | 6289 ms |
| Display list of the frame at 0.5, either size | 4800 bytes | 80358 bytes | 321383 bytes |

### The order of the sum

Supports: [The mean](../spec/FRAMES-29/SPEC.md#the-mean), the samples summed in order, and the Note on why the order is fixed.

On: pictures of 16-bit floats summed in 32-bit floats and rounded to nearest into 16-bit floats.

Numbers: the same 64 pictures summed in another order differed in a few values in a million by one unit in the last place. The mean of N equal pictures came back exactly for N of 2, 3, 16, 64 and 256, and the mean of pictures that differ lay within one unit in the last place of the exact mean. A sum carried in 16-bit floats went wrong from N of 64.
