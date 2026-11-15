# FRAMES-24: What a correct result keeps

Status: accepted

## Summary

What a correct result keeps: the checks a render is held to.

## Motivation

Some rules show only in pixels. These are what a person or a runner checks in the output with `still` and `sheet`.

## Rules

These are the acceptance tests.

- The first frame is not black or empty unless the storyline opens with a solid. A clip visible from 0 shows on the first frame.
- Nothing of a cropped, filled or moving storyline clip shows outside the content rect.
- During a transition both units show, stacked as [FRAMES-9](../FRAMES-9/SPEC.md) says.
- An unparented connected clip plays its whole window, across edit points.
- A parented clip goes with its picture: a transition covers, wipes or moves it exactly as it does its picture.
- A connected shape follows the crop and stays on the text it points at.
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A label sits on the first side in `shapes.label.sides` where it fits.
- A tracked clip stays on its target on every frame the tracker followed, at every zoom.
- The master is ProRes and PCM at full quality. Only `--deliver` and `transcode` trade quality for size.
- A storyline image is resampled once, from its source straight to its size on the output.
- Evaluating a resolved document at the same time always gives the same display list, and rendering it twice on the same decoder and renderer gives the same frames before encoding.
- A resolved document whose files changed is refused.
- A role that lacks a feature refuses before it starts.
- No temporary files are left.

## Interactions

Each check restates a rule of [FRAMES-8](../FRAMES-8/SPEC.md), [FRAMES-9](../FRAMES-9/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md), [FRAMES-12](../FRAMES-12/SPEC.md) or [FRAMES-21](../FRAMES-21/SPEC.md), which holds it.

## Alternatives considered


## Notes
