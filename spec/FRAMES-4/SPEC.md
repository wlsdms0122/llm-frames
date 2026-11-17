# FRAMES-4: Keyframes and easing

Status: accepted

## Summary

How a keyframable property takes keyframes, how each property joins only the keyframes that name it, how an ease shapes a span (springs included), and how numbers, points, areas, crops, lists and time remapping interpolate.

## Motivation

Motion written as data must come out the same in every preview, on every renderer and in every delivery, or a move checked with `still` is not the move that is rendered. Fixing the ease formulas leaves nothing to the renderer. A spring is how much modern motion design moves (a logo that settles, a title that lands with a little bounce), and given as an ease that ends exactly on its keyframe it keeps keyframes as edit points: the value arrives where and when the editor put it. Interpolating a crop's size geometrically makes a zoom keep one speed.

## Rules

Any property marked keyframable takes a static value or a list of keyframes. A keyframe is an object with `at`, one or more properties, and an optional `ease`.

```json
"opacity": 1,
"keyframes": [ { "at": 3, "position": [600, 500], "ease": { "spring": { "bounce": 0.3 } } }, { "at": 4, "position": [330, 900], "scale": 1.5 } ]
```

- Each property joins only the keyframes that name it. Before its first keyframe it holds the first value. After its last it holds the last value.
- A property that no keyframe names uses its static value, or its default. A property written both as a static value and in a keyframe stops ([FRAMES-7](../FRAMES-7/SPEC.md)). A property that takes keyframes only, `timeRemap`, stops when it is written as a static value ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A keyframe's `ease` shapes the span leaving it, towards the next keyframe of each property it names, as in CSS and Lottie. The default is `linear`. An `ease` on a keyframe that no later keyframe follows for any of its properties stops.
- A keyframe's `at` is an instant on the clock of its clip ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A property whose keyframes all lie before the range its clip is visible in (a storyline clip's drawn range, any other clip's visible window), or all after it, stops, since only one of its values would ever show.
- Which properties are keyframable on each clip is [FRAMES-7](../FRAMES-7/SPEC.md).

### Interpolation

Between two keyframes of a property, at progress u from 0 to 1 through the span, the value is `interp(a, b, ease(u))`, where `interp` is:

| Value | Interpolation |
| --- | --- |
| a number (`opacity`, `scale`, `rotation`, `radius`, `volume`, `pan`, a `width` or `height`) | per component: `a + (b - a) × e` |
| `timeRemap` | as a number: the media time shown moves from one key's value to the next along the ease. Two keys with the same value hold a frame, a lower next value plays backwards, and eased keys give speed ramps ([FRAMES-8](../FRAMES-8/SPEC.md)) |
| a point, `[x, y]` | per component |
| an area, `[x, y, w, h]` | per component |
| `trim`, `[a, b]` | per component |
| `crop` | its centre per component and its size geometrically (in log space), so a zoom keeps one speed. Crops are conformed to one aspect ratio first ([FRAMES-9](../FRAMES-9/SPEC.md)), so the ratio holds between keyframes |
| a list of points (a path's `points`) | point by point. Two keyframes whose lists differ in length stop |
| a list of masks (`mask`) | mask by mask: each mask's geometry as its form above, and its `feather` as a number. Two keyframes whose lists differ in length, or whose masks at one place differ in `shape`, geometry form, `invert` or `mode`, stop |

- An area or point given by text resolves at its own keyframe's time before it interpolates, and becomes a rectangle or a point (on a tracked clip it is then brought back through the motion, as every value is, [FRAMES-12](../FRAMES-12/SPEC.md)). A point given as `{area, point}` interpolates as the point it resolves to.
- An ease that overshoots (`back-out`, a spring with a `bounce` above 1 - √3/2, about 0.134, whose first peak falls inside the span) carries a value past its keyframes. Where a property's rule gives it a range (an opacity from 0 to 1, a `trim` end from 0 to 1), the value is clamped to that range where it is used.

### Eases

An ease is a name, a cubic Bézier, or a spring.

| ease | f(u), u from 0 to 1 |
| --- | --- |
| `linear` | u |
| `ease-in` | u³ |
| `ease-out` | 1 - (1-u)³ |
| `ease-in-out` | 4u³ when u < 0.5, otherwise 1 - (2 - 2u)³ / 2 |
| `back-out` | 1 + 2.70158(u-1)³ + 1.70158(u-1)² |
| `bounce-out` | with n = 7.5625 and d = 2.75: n·u² when u < 1/d; n(u - 1.5/d)² + 0.75 when u < 2/d; n(u - 2.25/d)² + 0.9375 when u < 2.5/d; otherwise n(u - 2.625/d)² + 0.984375 |
| `step` | 0 when u < 1, otherwise 1 |
| `[x1, y1, x2, y2]` | cubic Bézier from (0, 0) to (1, 1) with control points (x1, y1) and (x2, y2), as CSS `cubic-bezier()`: f(u) is the y of the curve's point whose x is u. `x1` and `x2` lie in [0, 1], and one outside stops. `y1` and `y2` may be any number |
| `{"spring": {"bounce": b}}` | a damped spring settling from 0 to 1, below |

**Spring.** `bounce` b is a number greater than -1 and less than 1. 0 settles with no overshoot, a higher bounce swings past 1 and back more before it settles, and a lower one approaches 1 more slowly with no overshoot. A bounce of -1 or less, or of 1 or more, stops, since at -1 the spring never moves and at 1 it never settles (below). From b:

```
damping ratio      ζ = 1 - b          when b ≥ 0
                   ζ = 1 / (1 + b)    when b < 0
natural frequency  ω = 2π / L         L the span's length in seconds
time in the span   τ = u × L
```

so ωτ = 2πu, and the ease depends on u and b alone. The spring's position x is the step response of a damped harmonic oscillator that starts at rest at 0 and is pulled toward 1. Writing θ = 2πu:

| case | x(u) |
| --- | --- |
| under-damped, ζ < 1 (b > 0) | 1 - e^(-ζθ) × ( cos(θ√(1 - ζ²)) + ζ/√(1 - ζ²) × sin(θ√(1 - ζ²)) ) |
| critically damped, ζ = 1 (b = 0) | 1 - e^(-θ) × (1 + θ) |
| over-damped, ζ > 1 (b < 0) | 1 - e^(-ζθ) × ( cosh(θ√(ζ² - 1)) + ζ/√(ζ² - 1) × sinh(θ√(ζ² - 1)) ) |

The ease is that response normalised to end on its keyframe: f(u) = x(u) / x(1), so f(0) = 0 and f(1) = 1 exactly. x(1) is above 0 for every b inside the range, and it reaches 0 at b = 1, which is why that end stops.

**Note.** The over-damped form multiplies a vanishing exponential by a growing hyperbolic function, which loses precision when ζ is large (b near -1). The same curve written as 1 - (r₂e^(r₁θ) - r₁e^(r₂θ)) / (r₂ - r₁), with r₁,₂ = -ζ ± √(ζ² - 1), is the stable way to compute it. Close to b = 1 the normalisation divides by a small x(1), so the curve swings far past its keyframes; the clamping above keeps ranged values in range.

An ease value or a spring's `bounce` may be `{"param": "<name>"}` where a parameter of that type may stand: inside a preset, filled from the preset's arguments, and inside a template, filled from the template's arguments ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-17](../FRAMES-17/SPEC.md)).

## Interactions

Which clock an instant is on, and what `timeRemap` maps, is [FRAMES-8](../FRAMES-8/SPEC.md). Which properties are keyframable is [FRAMES-7](../FRAMES-7/SPEC.md). Tracked values are brought back through the motion as [FRAMES-12](../FRAMES-12/SPEC.md) says. Presets use the same eases for their motion ([FRAMES-14](../FRAMES-14/SPEC.md)). Areas and points are [FRAMES-2](../FRAMES-2/SPEC.md), masks and paths [FRAMES-11](../FRAMES-11/SPEC.md).

## Alternatives considered

A spring simulated with its own settle time, as a physics engine runs it: the value would not land at its keyframe's time, and a keyframe would stop being an edit point. Normalising the step response to the span keeps the keyframe as the place and time it arrives.

A spring given by mass, stiffness and damping: three numbers with one effect an editor sees. One `bounce`, as SwiftUI's spring takes it, gives the same range of looks, and the span's length gives its speed.

Interpolating a crop's size linearly: a zoom from 1 to 2 would slow as it went, since each step is a smaller share of the picture. Log space keeps one speed.

Eases as renderer curves (a platform's built-in timing functions): two renderers would draw the same keyframes differently. Every ease is a formula here.

## Notes
