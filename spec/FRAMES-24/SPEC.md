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
- **A picture carried onto a corner pin is area sampled** ([FRAMES-27](../FRAMES-27/SPEC.md#what-a-renderer-holds)). On the set below, every component of every pixel either result covers lies within 0.1 of the mean of the source over that pixel's image under the inverse map, and the components lie within 0.005 of it on average over those pixels, values on a 0 to 1 scale. The set is two still sources of 1024 × 1024 pixels, each drawn by a media clip whose box is its 1024 × 1024 pixels with each of the two corner pins below, in a 1024 × 1024 output with a transparent background, pixel (i, j) being column i and row j from the top left:
  - a checkerboard of 32 px squares, premultiplied colours (0.9, 0.25, 0.1) where ⌊i / 32⌋ + ⌊j / 32⌋ is even and (0.1, 0.35, 0.85) where it is odd, with alpha (i + 0.5) / 64 over the left 64 columns, a soft edge, and 1 elsewhere, so its other three sides are hard edges, every value rounded to a half float;
  - an opaque black grid of white 1 px lines, pixel (i, j) white where i or j is a multiple of 4;
  - the mild corner pin `[[190, 164], [840, 124], [880, 854], [150, 904]]`, at 0.63 to 0.81 output pixels a source pixel, and the steep corner pin `[[462, 24], [562, 24], [1012, 1004], [12, 1004]]`, whose far edge is a tenth of its near edge.

  The sources are stills, so the mean is computed from their own pixels and needs nothing of the renderer: the mean is defined over the picture a nested list draws, at any scale, and how a renderer rasters the list that holds them is part of the approximation tested. The bounds separate the renderers measured on this set ([FRAMES-27](../FRAMES-27/SPEC.md#notes)): one sample per output pixel is 0.25 to 0.77 from the mean at worst, and 0.069 on average on the grid under the steep corner pin, where an area-sampled renderer was 0.075 at worst and 0.003 on average.
- **Values carried onto a corner pin stay as they are**, checked on single pixels, separately from the set above: a still source whose pixels all hold one premultiplied value, (2, -0.5, 0.25) at alpha 0.5, (-1, 4, 0.1) at alpha 1, or (0.3, 0, 0) at alpha 0, carried onto any strictly convex corner pin, gives that value, to within the rounding of the working format, at every output pixel whose image under the inverse map lies at least one source pixel inside the source's edge, and nothing at a pixel whose image lies wholly half a source pixel or more outside that edge, where the ramp of the bilinear reconstruction ends ([FRAMES-27](../FRAMES-27/SPEC.md#what-a-renderer-holds)).
- Evaluating a resolved document at the same time always gives the same display list, and rendering it twice on the same decoder and renderer gives the same frames before encoding.
- A resolved document whose files changed is refused.
- A role that lacks a feature refuses before it starts.
- No temporary files are left.

## Interactions

Each check restates a rule of [FRAMES-4](../FRAMES-4/SPEC.md), [FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md), [FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md), [FRAMES-11](../FRAMES-11/SPEC.md), [FRAMES-12](../FRAMES-12/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md), [FRAMES-20](../FRAMES-20/SPEC.md), [FRAMES-21](../FRAMES-21/SPEC.md) or [FRAMES-27](../FRAMES-27/SPEC.md), which holds it. The checks are made with the commands of [FRAMES-23](../FRAMES-23/SPEC.md).

## Alternatives considered

Checking against reference renders pixel by pixel: two renderers are promised the same geometry, text, timing and operations, not the same pixels ([FRAMES-21](../FRAMES-21/SPEC.md)), so a check names what a result keeps on any renderer.

## Notes
