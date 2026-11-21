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
- Keyframes interpolate with their eases: each property reaches its keyframe's value at the keyframe's time, `ease-in-out` is symmetric about the middle of its span, and a spring with bounce 0 settles without passing its value, while a spring with bounce above 1 − √3/2 (about 0.134) passes it and comes back, and one with a lower bounce does not pass it ([FRAMES-4](../FRAMES-4/SPEC.md)).
- A clip with motion blur that moves is smeared along its motion over the distance it moves while the shutter is open, in `samplesPerFrame` steps, and a frame in which nothing with motion blur moves over the exposure is the same picture, value for value, as the frame without motion blur, since its N sample lists are equal and their mean is exact ([FRAMES-29](../FRAMES-29/SPEC.md)).
- The two pictures of a push whose incoming clip has motion blur meet at the seam on every frame of the transition, the first and the last included: where they cover the frame together, the frame is as opaque as each picture.
- A value that jumps inside a frame's exposure, at a `step` end or between two keys at one `t`, shows no double image: the frame shows it on the side of the jump that holds the frame's instant. A loop that meets itself blurs through its seam, and a keyframed move under a looped animation keeps its whole trail on every frame.
- Under the default shutter a clip that starts or ends on a frame boundary moves over the whole exposure of its first and last frames.
- Footage in a clip with motion blur shows one media frame on each output frame, never two, and a tracked clip with motion blur stays on its target as it does without it.
- A path draws with its joins, caps and arrowheads: an arrowhead's tip lies on the end point, and a trimmed stroke draws only the part of the outline its `trim` names.
- A content-fit still has the measured size: the bounding box of its pictures at time 0, plus its margin, rounded up to even numbers ([FRAMES-6](../FRAMES-6/SPEC.md)).
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A tracked clip stays on its target on every frame the tracker followed, at every zoom.
- The master is ProRes and PCM at full quality. Only `--deliver` and `transcode` write at a delivery quality.
- A PNG from `render --at` holds the frame's working values: read back as media of the sequence's colour space by a clip with `toneMap` false ([FRAMES-26](../FRAMES-26/SPEC.md#media)), it gives the working values the renderer drew at that time, clipped as the output clips them, to within the rounding of its 16 bits per channel. `still` of the same time, without its label, is the analysis picture of those values ([FRAMES-26](../FRAMES-26/SPEC.md#providers-and-analysis-pictures)), to within the rounding of its 8 bits, so for an `srgb` sequence the two give the same pixels to within that rounding. `still` is a preview and not the master: for a `display-p3`, `rec2020` or HDR sequence it clips the gamut and tone maps the light, and the master is checked on the PNG from `render --at`.
- A storyline image is resampled once, from its source straight to its size on the output.
- A page of a PDF has the colour the formulas of [FRAMES-26](../FRAMES-26/SPEC.md#media) give where they fix it, and a case checks it only there: an opaque fill in Normal blend mode outside every transparency group, or inside groups each drawn opaque, in Normal blend mode and under no soft mask, whose colour spaces hold its colour, and the inside of an image of one colour outside every group, each away from its edges.
- Evaluating a resolved document at the same time always gives the same display list, and rendering it twice on the same decoder and renderer gives the same frames before encoding.
- A resolved document whose files changed is refused.
- A role that lacks a feature refuses before it starts.
- No temporary files are left.

## Interactions

Each check restates a rule of [FRAMES-4](../FRAMES-4/SPEC.md), [FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md), [FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md), [FRAMES-12](../FRAMES-12/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md), [FRAMES-20](../FRAMES-20/SPEC.md), [FRAMES-21](../FRAMES-21/SPEC.md) or [FRAMES-28](../FRAMES-28/SPEC.md), which holds it. The checks are made with the commands of [FRAMES-23](../FRAMES-23/SPEC.md).

The checks of motion blur restate [FRAMES-29](../FRAMES-29/SPEC.md).

## Alternatives considered

Checking against reference renders pixel by pixel: two renderers are promised the same geometry, text, timing and operations, not the same pixels ([FRAMES-21](../FRAMES-21/SPEC.md)), so a check names what a result keeps on any renderer.

## Notes
