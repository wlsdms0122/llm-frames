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
- Keyframes interpolate with their eases: each property reaches its keyframe's value at the keyframe's time, `ease-in-out` is symmetric about the middle of its span, and a spring with bounce 0 settles without passing its value, while a spring with bounce above 1 − √3/2 (about 0.134) passes it and comes back, and one with a lower bounce does not pass it ([FRAMES-4](../FRAMES-4/SPEC.md)).
- A path draws with its joins, caps and arrowheads: an arrowhead's tip lies on the end point, and a trimmed stroke draws only the part of the outline its `trim` names.
- A content-fit still has the measured size: the bounding box of its pictures at time 0, plus its margin, rounded up to even numbers ([FRAMES-6](../FRAMES-6/SPEC.md)).
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A tracked clip stays on its target on every frame the tracker followed, at every zoom.
- The master is ProRes and PCM at full quality. Only `--deliver` and `transcode` write at a delivery quality.
- A PNG from `render --at` holds the frame's working values: read back as media of the sequence's colour space by a clip with `toneMap` false ([FRAMES-26](../FRAMES-26/SPEC.md#media)), it gives the working values the renderer drew at that time, clipped as the output clips them, to within the rounding of its 16 bits per channel. `still` of the same time, without its label, is the analysis picture of those values ([FRAMES-26](../FRAMES-26/SPEC.md#providers-and-analysis-pictures)), to within the rounding of its 8 bits, so for an `srgb` sequence the two give the same pixels to within that rounding. `still` is a preview and not the master: for a `display-p3`, `rec2020` or HDR sequence it clips the gamut and tone maps the light, and the master is checked on the PNG from `render --at`.
- A storyline image is resampled once, from its source straight to its size on the output.
- Evaluating a resolved document at the same time always gives the same display list, and rendering it twice on the same decoder and renderer gives the same frames before encoding.
- A resolved document whose files changed is refused.
- A role that lacks a feature refuses before it starts.
- No temporary files are left.

## Interactions

Each check restates a rule of [FRAMES-4](../FRAMES-4/SPEC.md), [FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md), [FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md), [FRAMES-12](../FRAMES-12/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md), [FRAMES-20](../FRAMES-20/SPEC.md) or [FRAMES-21](../FRAMES-21/SPEC.md), which holds it. The checks are made with the commands of [FRAMES-23](../FRAMES-23/SPEC.md).

## Alternatives considered

Checking against reference renders pixel by pixel: two renderers are promised the same geometry, text, timing and operations, not the same pixels ([FRAMES-21](../FRAMES-21/SPEC.md)), so a check names what a result keeps on any renderer.

## Notes
