# FRAMES-4: Keyframes and easing

Status: accepted

## Summary

How a keyframable property takes keyframes, how each property joins only the keyframes that name it, how an ease shapes a span, and how numbers, areas and crops interpolate.

## Motivation

Animation written by an agent must come out the same on every renderer. Fixing the ease formulas, and interpolating a crop's size geometrically so a zoom keeps one speed, leaves nothing to the renderer.

## Rules

Any property marked keyframable takes a static value or a list of keyframes. A keyframe is an object with `at`, one or more properties, and an optional `ease`.

```json
"opacity": 1,
"keyframes": [ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ]
```

- Each property joins only the keyframes that name it. Before its first keyframe it holds the first value. After its last it holds the last value.
- A property that no keyframe names uses its static value, or its default. A property written both as a static value and in a keyframe stops ([FRAMES-7](../FRAMES-7/SPEC.md)).
- A keyframe's `ease` shapes the span leaving it, towards the next keyframe of each property it names, as in CSS and Lottie. The default is `linear`. An `ease` on a keyframe that no later keyframe follows for any of its properties stops.
- A keyframe's `at` is an instant on the clock of its clip ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A property whose keyframes all lie before the range its clip is visible in (a storyline clip's drawn range, any other clip's visible window), or all after it, stops, since only one of its values would ever show.
- Numbers and points interpolate per component. An `area` interpolates per component. A `crop` interpolates its centre per component and its size geometrically (in log space), so a zoom keeps one speed. Crops are conformed to one aspect ratio first ([FRAMES-9](../FRAMES-9/SPEC.md)), so the ratio holds between keyframes.
- An area given by text resolves at its own keyframe's time before it interpolates (on a tracked clip it is then brought back through the motion, as every value is, [FRAMES-12](../FRAMES-12/SPEC.md)).

| ease | f(u), u from 0 to 1 |
| --- | --- |
| `linear` | u |
| `ease-in` | u³ |
| `ease-out` | 1 - (1-u)³ |
| `ease-in-out` | 4u³ when u < 0.5, otherwise 1 - (2 - 2u)³ / 2 |
| `back-out` | 1 + 2.70158(u-1)³ + 1.70158(u-1)² |
| `bounce-out` | standard bounce-out with n = 7.5625, d = 2.75 |
| `step` | 0 when u < 1, otherwise 1 |
| `[x1, y1, x2, y2]` | cubic Bézier, as CSS `cubic-bezier()` |

## Interactions

Which clock an instant is on is [FRAMES-8](../FRAMES-8/SPEC.md). Which properties are keyframable is [FRAMES-7](../FRAMES-7/SPEC.md). Tracked values are brought back through the motion as [FRAMES-12](../FRAMES-12/SPEC.md) says.

## Alternatives considered


## Notes
