# FRAMES-4: Keyframes and easing

Status: accepted

## Summary

How a keyframable property takes keyframes, which keys of a clip take them (every key evaluation reads at each instant whose value is built from numbers and colours), how each property joins only the keyframes that name it, how an ease shapes a span (springs included), and how numbers, points, areas, crops, lists and time remapping interpolate.

## Motivation

Motion written as data must come out the same in every preview, on every renderer and in every delivery, or a move checked with `still` is not the move that is rendered. Fixing the ease formulas leaves nothing to the renderer. A spring is how much modern motion design moves (a logo that settles, a title that lands with a little bounce), and given as an ease that ends exactly on its keyframe it keeps keyframes as edit points: the value arrives where and when the editor put it. Interpolating a crop's size geometrically makes a zoom keep one speed. Every value evaluation reads at each instant takes keyframes, as every property of an After Effects layer does, so a colour that shifts, a stroke that thickens, a gradient that sweeps or a blur that eases off is written the way a move is, and an extension never writes one clip per frame to get it.

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

### What takes keyframes

**A key of a clip takes keyframes when evaluation reads it at each instant and its value is built from numbers and colours**, as After Effects lets every property of a layer take keyframes. That gives a clip's transform, its geometry, its opacity and masks, its appearance (`fill`, `stroke`, `shadow`, `border`, `radius`, `outset`, a solid's colour), its filter and its sound. The keys that take none fail one of the two tests. Names and references (`media`, `title`, `shape`, `style`, `blend`, `closed`, `id`, `parent`, `trackMatte`, `track`, `animation`, `transition`) are not built from numbers and colours. Timing (`at`, `in`, `out`, `duration`, `speed`, `loop`, `fadeIn`, `fadeOut`, `split`, `lane`) and the inputs of layout and conform (a title's `width`, a media clip's `width`, `height` and `conform`, `placement`, `anchor`) are read once, by resolve, which plans time, lays out text, conforms crops and measures a content-fit frame with them ([FRAMES-19](../FRAMES-19/SPEC.md)), so a shape's `width` takes keyframes and a title's does not. A title's character attributes (its font, size, colour, stroke) belong to its text styles in the theme ([FRAMES-22](../FRAMES-22/SPEC.md)), so a title has no colour or size key to keyframe, and its text moves by character, word or line through its animation ([FRAMES-14](../FRAMES-14/SPEC.md)). The table of [FRAMES-7](../FRAMES-7/SPEC.md) is what this principle gives for each clip, written out for reference, and where the two differ the principle decides.

A keyframable value is a number, a colour, a list or an object, nested: a point, a stroke `{color, width, join, cap}`, a gradient, a shadow, a filter choice. Its **leaves** are the numbers, colours, names (a preset, an op, a `join`, a `cap`, a gradient kind), booleans and files it holds.

- Each keyframe's value is read as the same value written statically on the clip would be: `true` for the theme `shadow` or `border` is that value, a shadow's missing keys come from the theme `shadow`, a stroke's missing keys take their defaults, a theme colour's name is its colour, and a preset choice is its preset's op list with the keyframe's arguments applied and its missing arguments at their defaults ([FRAMES-15](../FRAMES-15/SPEC.md)). A keyframed key merges over its style's value leaf by leaf, as a static one does ([FRAMES-11](../FRAMES-11/SPEC.md)), and the merge is done for each keyframe before it interpolates: a leaf a keyframe leaves out takes the style's value, or the default where the style has none, so a keyframe that writes only a stroke's `color` keeps the style's width, `join` and `cap` and follows a theme that changes them. Each keyframe is then one whole value.
- **A keyframe's value is checked against its value's domain, not against what a static key needs in order to be seen.** A keyframe is one end of a change, and its value may be any value the key's sampled value may take between keyframes: a length 0 or more, a size (an area's `w` and `h`, a shape's `width` and `height`) 0 or more, a fraction or an op parameter within its range, a colour any colour. So a length a static key needs above 0 may be 0 in a keyframe: a stroke `width`, the lengths of a `dash`, a filter's `radius` or `size`, a radial gradient's `radius`, an area's `w` and `h`. A stroke then draws on from width 0, a blur eases in from radius 0, and a bar grows from no width. A value at 0 draws what it draws when it is sampled at 0 ([FRAMES-11](../FRAMES-11/SPEC.md), [FRAMES-15](../FRAMES-15/SPEC.md)). Keys, forms and names are checked in a keyframe as they are statically.
- Read so, every keyframe of one key has the same structure: the same keys in each object, the same length in each list, and the same leaf at each place that holds neither a number nor a colour. A keyframe that differs stops, naming the key and the places of both keyframes: a stroke whose `cap` changes, a fill that is a colour in one keyframe and a gradient in the next, a filter whose preset changes, a gradient whose stops differ in number, `false` or `"none"` in one keyframe and a value in another. A value that comes in or goes out is keyframed from or to the values at which it has no effect: a stroke of width 0, a shadow of transparent colour, a filter op at its identity ([FRAMES-15](../FRAMES-15/SPEC.md)). The rows for `points` and `mask` below are cases of this rule.
- Between two keyframes the value interpolates leaf by leaf, each number as a number and each colour per channel ([Interpolation](#interpolation)).

### Interpolation

Between two keyframes of a property, at progress u from 0 to 1 through the span, the value is `interp(a, b, ease(u))`, where `interp` is:

| Value | Interpolation |
| --- | --- |
| a number (`opacity`, `rotation`, `radius`, `volume`, `pan`, a `width` or `height`) | per component: `a + (b - a) × e` |
| `scale`, a number or `[sx, sy]` | per component, a number s taken as `[s, s]`, so a keyframe of one form may follow a keyframe of the other ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| a colour | per channel, as a number: red, green, blue and alpha, straight (not premultiplied), on their sRGB-encoded values from 0 to 1, the working space ([FRAMES-21](../FRAMES-21/SPEC.md)). A gradient's stops across space interpolate premultiplied instead ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| a value with leaves (a `stroke`, a `fill`, a `shadow`, a `border`, a `filter` or `adjust`) | leaf by leaf: each number and each colour as above, every other leaf the same in both keyframes. A filter interpolates its op lists op by op, parameter by parameter |
| `timeRemap` | as a number: the media time shown moves from one key's value to the next along the ease. Two keys with the same value hold a frame, a lower next value plays backwards, and eased keys give speed ramps ([FRAMES-8](../FRAMES-8/SPEC.md)) |
| a point, `[x, y]` | per component |
| an area, `[x, y, w, h]` | per component |
| `trim`, `[a, b]` | per component |
| `crop` | its centre per component and its size geometrically (in log space), so a zoom keeps one speed. Crops are conformed to one aspect ratio first ([FRAMES-9](../FRAMES-9/SPEC.md)), so the ratio holds between keyframes |
| a list of points (a path's `points`) | point by point. Two keyframes whose lists differ in length stop |
| a list of masks (`mask`) | mask by mask: each mask's geometry as its form above, and its `feather` as a number. Two keyframes whose lists differ in length, or whose masks at one place differ in `shape`, geometry form, `invert` or `mode`, stop |

- An area or point given by text resolves at its own keyframe's time before it interpolates, and becomes a rectangle or a point (on a tracked clip it is then brought back through the motion, as every value is, [FRAMES-12](../FRAMES-12/SPEC.md)). A point given as `{area, point}` interpolates as the point it resolves to. A clip area ([FRAMES-2](../FRAMES-2/SPEC.md)) is the named clip's box at the instant being evaluated, so between a keyframe that holds one and its neighbour the value interpolates from that box at each instant.
- An ease that overshoots (`back-out`, a spring with a `bounce` above 1 - √3/2, about 0.134, whose first peak falls inside the span) carries a value past its keyframes. Where a property's rule gives it a range (an opacity from 0 to 1, a `trim` end from 0 to 1), the value is clamped to that range where it is used. Each value is clamped where it is sampled, before it is combined with another: a clip's keyframed opacity and its motion opacity are each clamped to 0 to 1, then multiplied. A sampled length (a stroke width, a dash length, a radius, an outset, a shadow radius, a filter length) and a sampled size (an area's `w` and `h`, a shape's `width` and `height`) are clamped to 0 or more, each channel of a colour to 0 to 1, an op parameter to its range ([FRAMES-15](../FRAMES-15/SPEC.md)), and a gradient's offsets as [FRAMES-11](../FRAMES-11/SPEC.md) says.

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

**Spring.** `bounce` b is a number greater than -1 and less than 1. 0 settles with no overshoot, a bounce above 1 − √3/2 (about 0.134) swings past 1 and back, more the higher it is, before it settles, and a lower one approaches 1 more slowly with no overshoot. A bounce of -1 or less, or of 1 or more, stops, since at -1 the spring never moves and at 1 it never settles (below). From b:

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

Keyframes on the transform and the geometry only, with colours, strokes and filters fixed for a clip: a colour change or a blur that eases off would be two clips crossfaded, or one clip per frame written by an extension. The rule that a key read at each instant whose value is built from numbers and colours takes keyframes is the one After Effects follows, and it decides every key added later, with the table of [FRAMES-7](../FRAMES-7/SPEC.md) following from it.

Each leaf of a value joining its own keyframes, as each property does: one key would carry several timings, a leaf one keyframe leaves out would take its value from the keyframes of that leaf around it rather than from the style, and the resolved document would need a keyframe list for every leaf. A keyframe's value is one whole value, merged over the style's and read as a static one, and one ease shapes all of it.

Names that change between keyframes taken as a hold to the next keyframe, as After Effects treats a property it cannot interpolate: a span between two keyframes says that the value moves from one to the other under its ease, which a name cannot do, so the span would not do what it says, and it stops. A name that changes at an instant is two clips cut there, which says so.

Keyframed colours interpolated with premultiplied alpha, as a gradient's stops are ([FRAMES-11](../FRAMES-11/SPEC.md)): a gradient spreads colour over space, where alpha is coverage, but a keyframed colour is one colour changing in time, and the channels each keyframe writes are the colours it passes through, as After Effects interpolates a colour property channel by channel. A fade to transparent is written with its own colour's channels and changes only its alpha.

## Notes
