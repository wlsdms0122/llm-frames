# FRAMES-24: What a correct result keeps

Status: accepted

## Summary

What a correct result keeps: the checks a render is held to.

## Motivation

Some rules show only in pixels and sound: whether a held frame holds, whether a feathered mask fades where it should, whether a title moves with the picture it is parented to, whether a crossfade dips. An editor checks these by scrubbing and listening. These are the checks a person or a runner makes on the output with `still`, `sheet` and the rendered file, the same on every renderer.

## Rules

These are the acceptance tests.

- The first frame is not black or empty unless the storyline opens with a solid or with black media. A clip visible from 0 shows on the first frame.
- A storyline picture at its default transform fills the frame with its conformed crop. Where `fit` or the picture's own transform leaves part of the frame uncovered, what is below shows there: lower lanes and the background.
- During a transition both storyline pictures show, stacked as [FRAMES-9](../FRAMES-9/SPEC.md) says, each with the transition's motion, and a cover above both.
- An unparented connected clip plays its whole window, across edit points.
- A parented clip follows its parent's transform: it moves, scales and rotates with the parent at every frame, through the parent's keyframes, tracked motion and transition motion, and keeps its own stroke widths and text sizes under the parent's scale. Its opacity, window and lane stay its own.
- A time-remapped clip shows on each frame the media frame its `timeRemap` gives: two keys with the same value hold one frame, decreasing values play the media backwards, and outside its first and last keys it holds their frames.
- A mask cuts the region it names: the picture shows inside it (outside it when inverted), fades across its edge, the part from 16 to 84 percent about twice its feather wide, and several masks combine in order by their modes. A track matte shows its clip where the matte clip's alpha or luma is high (low when inverted), and the matte clip itself is not drawn.
- Sounds that overlap are mixed, each at its volume and pan. A storyline transition crossfades on its preset's `audio` curve: `constant-power` with no dip in loudness at the middle for uncorrelated sounds, `constant-gain` with a 3 dB dip there.
- A compound clip's `volume` and fades scale its bus's output, after its chain: a `fadeOut` on it gives at each sample the fade's gain times the sound the clip gives without the fade ([FRAMES-28](../FRAMES-28/SPEC.md#buses)).
- A sequence whose `audioFilter` ends with a `limiter` whose entry's `mix` is 1 and takes no keyframes has a mix each of whose samples n is at or under that limiter's `ceiling` at n, |s_c[n]| ≤ 10^(`ceiling`[n] / 20) on both channels, to within the rounding of its arithmetic, whatever its sounds ([FRAMES-28](../FRAMES-28/SPEC.md#limiter)). Where its `ceiling` holds over the mix, the mix's `samplePeak`, as `loudness` of the document gives it, is at most that `ceiling`, to within the rounding of the measures. With a `ceiling` of -1, every `lookahead` of 0.0015, 0.005 and 0.05 and every `release` of 0.000001, 0.1 and 1, its `truePeak` is at most the ceiling plus 0.05 dB, to within that rounding, on each of these stereo sounds at 48 kHz, t the time in seconds and n the sample:
  - A 997 Hz sine at amplitude 2, 2 sin(2π 997 t), the same on both channels, 5 s long.
  - Noise bursts: white noise uniform in [-2, 2], drawn on each channel on its own, over the first half of each second and silent over the second half, 10 s long.
  - A mix: on the left the sines 0.3 sin(2π 110 t), 0.25 sin(2π 220 t + 1), 0.2 sin(2π 330 t + 2), 0.1 sin(2π 1760 t + 0.5) and 0.05 sin(2π 3520 t), on the right 0.3 sin(2π 110 t + 0.3), 0.25 sin(2π 277 t + 1), 0.2 sin(2π 440 t + 2), 0.1 sin(2π 2637 t + 0.5) and 0.05 sin(2π 5274 t), on both a kick 0.9 e^(-u / 0.06) sin(2π 60 u) with u the time since the last half second, and on each channel on its own Gaussian noise of standard deviation 0.08, the whole scaled to a sample peak of 8 dBFS, 10 s long.
  - A sine at a quarter of the sample rate and 45 degrees, √2 sin(2π n / 4 + π / 4), whose samples are ±1 and whose peak between them is √2, 3.01 dB over full scale (case 19 of EBU Tech 3341), the same on both channels, 2 s long.
  - A 50 Hz sine at amplitude 2, 2 sin(2π 50 t), the same on both channels, 5 s long.
- `loudness` of a rendered master gives the document's measures to within the rounding of 24-bit PCM, where the mix stays within full scale ([FRAMES-28](../FRAMES-28/SPEC.md#measuring-loudness)).
- Keyframes interpolate with their eases: each property reaches its keyframe's value at the keyframe's time, `ease-in-out` is symmetric about the middle of its span, and a spring with bounce 0 settles without passing its value, while a spring with bounce above 1 − √3/2 passes it and comes back, and one with a lower bounce does not pass it ([FRAMES-4](../FRAMES-4/SPEC.md)).
- A clip with motion blur that moves is smeared along its motion over the distance it moves while the shutter is open, in `samplesPerFrame` steps, and a frame in which nothing with motion blur moves over the exposure is the same picture, value for value, as the frame without motion blur, since its N sample lists are equal and their mean is exact ([FRAMES-29](../FRAMES-29/SPEC.md)).
- The two pictures of a push whose incoming clip has motion blur meet at the seam on every frame of the transition, the first and the last included: where they cover the frame together, the frame is as opaque as each picture.
- A value that jumps inside a frame's exposure, at a `step` end, between two keyframes at one `at` or between two keys at one `t` of a span, shows no double image: the frame shows it on the side of the jump that holds the frame's instant. A loop that meets itself blurs through its seam, and a keyframed move under a looped animation keeps its whole trail on every frame.
- Under the default shutter a clip that starts or ends on a frame boundary moves over the whole exposure of its first and last frames.
- Footage in a clip with motion blur shows one media frame on each output frame, never two, and a tracked clip with motion blur stays on its target as it does without it.
- A path draws with its joins, caps and arrowheads: an arrowhead's tip lies on the end point, and a trimmed stroke draws only the part of the outline its `trim` names.
- A content-fit still has the measured size: the bounding box of its pictures at time 0, plus its margin, rounded up to even numbers ([FRAMES-6](../FRAMES-6/SPEC.md)).
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A tracked clip stays on its target on every frame the tracker followed, at every zoom.
- The master is ProRes and PCM at full quality. Only a delivery file, from `render` to an `.mp4` or from `--deliver`, and `transcode` write at a delivery quality.
- A PNG from `render --at` holds the frame's working values: read back as media of the sequence's colour space by a clip with `toneMap` false ([FRAMES-26](../FRAMES-26/SPEC.md#media)), it gives the working values the renderer drew at that time, clipped as the output clips them, to within the rounding of its 16 bits per channel. `still` of the same time, without its label, is the analysis picture of those values ([FRAMES-26](../FRAMES-26/SPEC.md#providers-and-analysis-pictures)), to within the rounding of its 8 bits, so for an `srgb` sequence the two give the same pixels to within that rounding. `still` is a preview and not the master: for a `display-p3`, `rec2020` or HDR sequence it clips the gamut and tone maps the light, and the master is checked on the PNG from `render --at`.
- A storyline image is resampled once, from its source straight to its size on the output.
- **A picture carried onto a corner pin is area sampled** ([FRAMES-27](../FRAMES-27/SPEC.md#what-a-renderer-holds)). On the set below, every component of every pixel either result covers lies within 0.1 of the mean of the source over that pixel's image under the inverse map, and the components lie within 0.005 of it on average over those pixels, values on a 0 to 1 scale. The set is two still sources of 1024 × 1024 pixels, each drawn by a media clip whose box is its 1024 × 1024 pixels with each of the two corner pins below, in a 1024 × 1024 output with a transparent background, pixel (i, j) being column i and row j from the top left:
  - a checkerboard of 32 px squares, premultiplied colours (0.9, 0.25, 0.1) where ⌊i / 32⌋ + ⌊j / 32⌋ is even and (0.1, 0.35, 0.85) where it is odd, with alpha (i + 0.5) / 64 over the left 64 columns, a soft edge, and 1 elsewhere, so its other three sides are hard edges, every value rounded to a half float;
  - an opaque black grid of white 1 px lines, pixel (i, j) white where i or j is a multiple of 4;
  - the mild corner pin `[[190, 164], [840, 124], [880, 854], [150, 904]]`, at 0.63 to 0.81 output pixels a source pixel, and the steep corner pin `[[462, 24], [562, 24], [1012, 1004], [12, 1004]]`, whose far edge is a tenth of its near edge.

  The sources are stills, so the mean is computed from their own pixels and needs nothing of the renderer: the mean is defined over the picture a nested list draws, at any scale, and how a renderer rasters the list that holds them is part of the approximation tested. The bounds separate area sampling from one sample per output pixel ([FRAMES-27](../FRAMES-27/SPEC.md#notes)): one sample per output pixel lies 0.25 to 0.77 from the mean at worst, and 0.069 on average on the grid under the steep corner pin, where area sampling lies 0.075 at worst and 0.003 on average.
- **Values carried onto a corner pin stay as they are**, checked on single pixels, separately from the set above: a still source whose pixels all hold one premultiplied value, (2, -0.5, 0.25) at alpha 0.5, (-1, 4, 0.1) at alpha 1, or (0.3, 0, 0) at alpha 0, carried onto any strictly convex corner pin, gives that value, to within the rounding of the working format, at every output pixel whose image under the inverse map lies at least one source pixel inside the source's edge, and nothing at a pixel whose image lies wholly half a source pixel or more outside that edge, where the ramp of the bilinear reconstruction ends ([FRAMES-27](../FRAMES-27/SPEC.md#what-a-renderer-holds)).
- **A picture of pixels is resampled by its definition** ([FRAMES-21](../FRAMES-21/SPEC.md#rules)). On the set below, every component of every pixel lies within 2⁻⁹ × max(1, |v|) of the definition evaluated in double precision, v being that value, coverage included, and the components lie within 2⁻¹² of it on average over the pixels the picture reaches, values on a 0 to 1 scale. The set is one still source of 64 × 48 pixels, pixel (i, j) being column i and row j from the top left, holding the premultiplied colour (((3i + 5j) mod 17) / 16, ((7i + 2j) mod 13) / 12, (i + j) mod 2) at alpha 1, every value rounded to a half float, drawn by a media clip's picture whose `rect` is the whole source, in a 256 × 256 output with a transparent background, its `dest` with its top left corner at (5.375, 3.625), 64 s wide and 48 s high:
  - for each scale s of 0.25, 0.625, 1, 1.375 and 3, upright;
  - for s of 1 and of 0.625, turned by 17 degrees about the centre of its `dest`.
- A page of a PDF fixes the colour of its untagged colour alone ([FRAMES-26](../FRAMES-26/SPEC.md#media)), and a case checks a page's colour only there: an opaque fill of its untagged colour in Normal blend mode outside every transparency group, away from its edges.
- Evaluating a resolved document at the same time always gives the same display list, and rendering it twice on the same decoder and renderer gives the same frames before encoding.
- A resolved document whose files changed is refused.
- A role that lacks a feature refuses before it starts.
- No temporary files are left.

### Tolerances

**A role gives the same bytes on every run, and a second one of a role lies within a tolerance of the reference** ([FRAMES-21](../FRAMES-21/SPEC.md#rules)). Rendering the same resolved document twice on the same machine, decoder and renderer gives frames before encoding whose bytes hash the same. The bounds below compare each component on a 0 to 1 scale, v being the reference's value at that pixel.

- A renderer against `quartz` on the same display lists and the same decoder, checked on `metal` ([Notes](#notes)): at every pixel each component within 2⁻⁹ × max(1, |v|), and the mean difference of the components within 2⁻¹² over the pixels no edge of a picture, path, mask or glyph and no detail of a picture reaches, and again over the others, and a hard edge of a shape or of a picture at a fractional position lies at the same position within 1/64 of a pixel, its position being where the area of its alpha across the edge puts it.
- The `avfoundation` decoder's conversion of a video frame on the GPU against its conversion of the same frame on the CPU, which is the reference ([FRAMES-21](../FRAMES-21/SPEC.md#pictures)): each component within 2⁻¹⁰ × max(1, |v|), and the mean difference of the components over the frame within 2⁻¹⁸. Two conversions of the same frame on the GPU give the same bytes.
- The `avfoundation` encoder's conversion of a frame on the GPU to the output's values against its conversion of the same frame on the CPU, which is the reference ([FRAMES-21](../FRAMES-21/SPEC.md#pictures)): each code value within 1. Two conversions of the same frame on the GPU give the same bytes.

## Interactions

Each check restates a rule of [FRAMES-4](../FRAMES-4/SPEC.md), [FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md), [FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md), [FRAMES-12](../FRAMES-12/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md), [FRAMES-20](../FRAMES-20/SPEC.md), [FRAMES-21](../FRAMES-21/SPEC.md), [FRAMES-27](../FRAMES-27/SPEC.md) or [FRAMES-28](../FRAMES-28/SPEC.md), which holds it. The checks are made with the commands of [FRAMES-23](../FRAMES-23/SPEC.md).

The checks of motion blur restate [FRAMES-29](../FRAMES-29/SPEC.md).

## Alternatives considered

A renderer checked against `quartz` to the bit, or against no reference at all: a GPU's single precision arithmetic differs from the CPU's in the last bits of a half float, so the same bits would hold every renderer to `quartz`'s arithmetic, and checks that name only what a result keeps, as the rules above do, leave a renderer free to drift in colour by more than rounding. So the rules name what a result keeps on any renderer, and [Tolerances](#tolerances) hold a renderer to `quartz` on the same display lists, within bounds that rounding stays inside and a wrong formula does not.

## Notes

**Note.** The decoder's component bound, 2⁻¹⁰, is one step of a half float just above 1, the largest difference measured between a video frame converted on the GPU and the same frame converted on the CPU, and its mean bound, 2⁻¹⁸, holds the largest mean measured, 3.8e-7, with a factor of ten.

**Note.** The bounds of a renderer against `quartz` are set on `metal` drawing the same display lists. The component bound, 2⁻⁹, holds the largest difference measured, 1.6e-3 on adjustments over a filtered video, with a factor of 1.2, and every other difference measured, at most 9.8e-4, one step of a half float at 1, with a factor of two. The mean bound holds the largest mean measured, 1.3e-4, with a factor of 1.8: that mean is the rounding of one half float at values from 0.5 to 1, where a step is 2⁻¹¹ and a rounding is a quarter of a step on average, so 2⁻¹² is two such roundings, and a formula wrong by one percent at values near 0.5 lies twenty times above it. The edge bound, 1/64 of a pixel, is the precision to which a position is measured in alpha of half floats over ten to twenty pixels.

**Note.** The bounds of a picture resampled by its definition hold both `quartz` and `metal`: the largest difference of a component from the definition measured is 4.9e-4, a quarter of the component bound, and the largest mean 1.5e-4, which 2⁻¹² holds with a factor of 1.6. That mean is the rounding of the result to a half float, a quarter of a step on average, at values from 0.5 to 1 where a step is 2⁻¹¹.

**Note.** The encoder's bound of one code value is the largest difference measured between a frame converted on the GPU and the same frame converted on the CPU, over unpremultiplied colours from -0.25 to 1.25 at alphas from 0 to 1, at eight and at sixteen bits, in every colour space.
