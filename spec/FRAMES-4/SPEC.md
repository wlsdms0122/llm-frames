# FRAMES-4: Keyframes and easing

Status: accepted

## Summary

How a keyframable property takes keyframes, which keys of a clip take them (every key whose value is built from numbers and colours and whose change alters no decision resolve makes once), how each leaf of a value joins only the keyframes that write it, how an ease shapes a span (springs included), and how numbers, points, areas, crops, lists and time remapping interpolate.

## Motivation

Motion written as data must come out the same in every preview, on every renderer and in every delivery, or a move checked with `still` is not the move that is rendered. Fixing the ease formulas leaves nothing to the renderer. A spring is how much modern motion design moves (a logo that settles, a title that lands with a little bounce), and given as an ease that ends exactly on its keyframe it keeps keyframes as edit points: the value arrives where and when the editor put it. Interpolating a crop's size geometrically makes a zoom keep one speed. Every value a clip draws or plays with takes keyframes, as every property of an After Effects layer does, unless a change of it would alter a decision resolve makes once, a line break, a glyph's shaping or a conform, so a colour that shifts, a stroke that thickens, a gradient that sweeps or a blur that eases off is one keyframed value on one clip, written the way a move is. Outside frames each would be spread over clips, two crossfaded or one for each frame, which is what puts it in the core ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Rules

Any property marked keyframable takes a static value or a list of keyframes. A keyframe is an object with `at`, one or more properties, and an optional `ease`, and sets the leaves of those properties it writes ([What takes keyframes](#what-takes-keyframes)).

```json
"opacity": 1,
"keyframes": [ { "at": 3, "position": [600, 500], "ease": { "spring": { "bounce": 0.3 } } }, { "at": 4, "position": [330, 900], "scale": 1.5 } ]
```

- **Each leaf is timed on its own: it joins only the keyframes that write it**, holds the first of their values before the first of them and the last after the last, and between two of them moves from one to the next. The unit of timing is one value an editor moves on its own, as After Effects keyframes a shape's Fill Color, Stroke Color and Stroke Width each on its own, so a title's colour that changes from 0 to 1 seconds and a highlight colour that pulses from 2 to 3 seconds are written apart, and a keyframe of one leaves the other where its own keyframes put it.
- A leaf that no keyframe writes takes the merged value's: the clip's static value merged over its look ([What takes keyframes](#what-takes-keyframes), [FRAMES-22](../FRAMES-22/SPEC.md)), or its default. A leaf written statically and given a value in every keyframe that writes it stops, since the static one would never show ([FRAMES-7](../FRAMES-7/SPEC.md)). This holds leaf by leaf, inside nested objects, so a title's static `character` gives its `size` while keyframes of `character` move its `color`. A property that takes keyframes only, `timeRemap`, stops when it is written as a static value ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A keyframe's `ease` shapes the span leaving it, towards the next keyframe of each leaf it writes, as in CSS and Lottie. The default is `linear`. An `ease` on a keyframe that no later keyframe follows for any of its leaves stops.
- A keyframe's `at` is an instant on the clock of its clip ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A leaf whose keyframes all lie before the range its clip is visible in (a storyline clip's drawn range, any other clip's visible window), or all after it, stops, since only one of its values would ever show.
- Which properties are keyframable on each clip is [FRAMES-7](../FRAMES-7/SPEC.md).

### What takes keyframes

**A key of a clip takes keyframes when its value is built from numbers and colours and a change of it alters no decision resolve makes once**: a line break, a glyph's shaping and face, and a conform, a media clip's box and the map of its crops to that box ([FRAMES-9](../FRAMES-9/SPEC.md)), as After Effects lets every property of a layer take keyframes. Resolve makes those decisions once for the whole clip and the resolved document pins them ([FRAMES-19](../FRAMES-19/SPEC.md)), so a value that changed one between instants would need it made again at each instant, and the lines, glyphs and conformed boxes the resolved document pins would not be the ones drawn. **Positions computed from those decisions at an instant are evaluation's**: where a glyph sits along its line, where a line sits in its text box, and how large a title's box is at that instant follow from the values at that instant, as a shape's outline follows its `width`. That gives a clip's transform, its geometry, its opacity and masks, its appearance (`fill`, `stroke`, `shadow`, `border`, `radius`, `outset`, a solid's colour, a title's colours, stroke, tracking, baseline shift and line height, the sizes of its highlights and underlines, and its background's colour, padding and radius), its filter and its sound. The keys that take none fail one of the two tests. Names and references (`media`, `title`, `shape`, `style`, `blend`, `conform`, `placement`, `anchor`, `align`, `closed`, `id`, `parent`, `trackMatte`, `track`, `animation`, `transition`) are not built from numbers and colours. Timing (`at`, `in`, `out`, `duration`, `speed`, `loop`, `fadeIn`, `fadeOut`, `split`) and `lane` place the clip in time and in the stack, and its keyframes lie on the clock they set. A title's `width` decides its line breaks and a media clip's `width` and `height` decide its conform, so they take none, while a shape's `width` decides nothing resolve makes once and takes keyframes. In a title's `character` ([FRAMES-11](../FRAMES-11/SPEC.md)) the font, size, weight, italic, kerning and features decide its faces, its shaping and its line breaks, and take none. Its `baselineShift`, which raises only its own run's glyphs, and the `padding` and `radius` of its highlight and the `width` and `offset` of its underline, which take no part in layout ([FRAMES-5](../FRAMES-5/SPEC.md)), take keyframes with its colours and its stroke. **`tracking` is a case of the same principle**: resolve breaks the lines once, at the largest tracking the clip takes over its whole motion, so no value it takes changes a break, and evaluation places each glyph along its line at the tracking of each instant ([FRAMES-5](../FRAMES-5/SPEC.md)). In a title's `paragraph` ([FRAMES-11](../FRAMES-11/SPEC.md)) `lineHeight` decides no break, since lines break across the width alone, and evaluation places the lines at the line height of each instant; the background's `color`, `padding` and `radius` decide none either. A point-text title's box that widens with its tracking, or a box that grows with its line height or its background's padding, is a position at an instant, which every reader of the box reads at the instant it reads ([FRAMES-2](../FRAMES-2/SPEC.md), [FRAMES-6](../FRAMES-6/SPEC.md), [FRAMES-14](../FRAMES-14/SPEC.md)). The table of [FRAMES-7](../FRAMES-7/SPEC.md) is what this principle gives for each clip, written out for reference, and where the two differ the principle decides.

A keyframable value is a number, a colour, a list or an object, nested: a point, a stroke `{color, width, join, cap}`, a gradient, a shadow, a filter choice. Its **leaves** are the values in it that an editor moves or sets on their own: each number and each colour, each point, area, crop, `scale` and `padding` moved as one, and each name (a preset, an op, a `join`, a `cap`, a gradient's kind, a mask's `shape` and `mode`), boolean and file. Its **structure** is the form each of its values takes, its names, booleans and files, and how long each of its lists is. **A value's structure is its type's, compared after its shorthands are expanded.** Every key its type has is part of it, a key that only takes its default included, so a keyframe may write a stroke's `dashOffset` over a static stroke that never wrote one. **A shorthand expands to the leaves it names, over the value below, and nothing more**, statically and in a keyframe alike ([FRAMES-22](../FRAMES-22/SPEC.md)), so it has no form of its own. `true` (`border: true`, `shadow: true`, `underline: true`) names every leaf of its value as the value below, each leaf `null`: it turns the value on with the look's leaves. A colour names only the colour: `border: "#F00"` is `{"color": "#F00"}`, its width from below. A `scale` number s is `[s, s]`. So a value written once as a shorthand and once in full has one structure, and whether it takes keyframes never depends on how it is spelt.

**The value drawn at an instant is made by two operations, the look merge and timing, and keyframes belong to timing.** The look merge ([FRAMES-22](../FRAMES-22/SPEC.md)) gives a value its structure and its static leaves: a stronger theme over a weaker one, a clip's choice over the theme's `defaults`, the clip's own layer over its style, and a title's `character` and `paragraph` over its runs' styles and its clip style's paragraph attributes, each layer over the one below by one rule, under which a layer may change the structure below it, since a value of another form replaces it whole and `false` turns it off. **The clip's own layer is its static value together with the structure its keyframes give**: the forms its keyframes write and the lengths of their lists, which agree with each other and with the clip's static value, or the clip stops, naming the key and the keyframes. That layer merges over the look by the same rule as any layer, so where a document's keyframes write a value, the form they write is the document's, and a theme change never changes the type a document's keyframes write. Timing then samples each timed leaf over the merged value: a leaf the keyframes write takes their value at that instant, and every other leaf is the merged value's. So a rect whose shape style fills it with a gradient, under keyframes that write fill colours and no static fill, takes a colour fill, since its own layer's form replaces the style's under every theme. A shape whose style strokes it with a gradient, under keyframes that write the stroke's `color`, takes a colour paint, since a stroke's `color` and `gradient` are one paint leaf. And a static `stroke: {"dash": [10, 5]}` with keyframes that move its `dashOffset` from 0 to 100 draws marching ants, since `dashOffset` is a key of every stroke.

- **The numbers and colours are its timed leaves, and its other leaves and its structure are static**: they come from the look merge, the clip's own layer included, and a keyframe that writes one stops, naming the leaf and the keyframe, since a span says that a value moves from one keyframe's to the next under its ease, which a name or a form cannot do ([Alternatives](#alternatives-considered)). A keyframe's object may write any key of its type, and its list has that list's length, element by element. So a stroke whose `cap` a keyframe writes stops, and so does a fill that is a colour on the clip and a gradient in a keyframe, a filter whose preset or op a keyframe writes, a gradient whose stops a keyframe gives in another number, and `false` or `"none"` in a keyframe, which are forms that turn a value off. `true` in a keyframe points every leaf of its value at the merged value, as a `null` at each leaf does, and a colour there writes the colour alone, so a static `border: true` beside keyframes that write `"#F00"` and `"#00F"` moves the border's colour and keeps the look's width ([FRAMES-11](../FRAMES-11/SPEC.md)).
- **A leaf written as `null` in a keyframe is the merged value at that leaf at that instant**, the clip's static value merged over its style's, or for a filter over the theme's default ([FRAMES-22](../FRAMES-22/SPEC.md)), which is how a keyframe points at the look: a stroke drawn on from `{"width": 0}` to `{"width": null}` ends on the style's width and follows a theme that changes it. `null` stands for a leaf, and `null` for an object or a list stops, as does a `null` where the merged value holds none, such as a fill colour over a style's gradient that the keyframes' colour form replaced.
- A keyframe's leaves are read as the same leaves written statically would be: a theme colour's name is its colour, an area or point given by text or by a clip is the one it gives ([below](#interpolation)), and an argument of a preset choice is that parameter of the preset, applied to its ops at each instant ([FRAMES-15](../FRAMES-15/SPEC.md)). At each instant the value is the merged value with each leaf its keyframes write at its sampled value, and where neither gives a leaf it is completed as a static value is (a shadow's missing keys from the theme `shadow`, a stroke's from their defaults), so a keyframe that writes only a stroke's `color` keeps the style's width, `join` and `cap` and follows a theme that changes them.
- **A leaf that two keyframes or more write is checked against the value's domain, not against what a static value needs in order to be seen.** Such a keyframe is one end of a change, and its value may be any value the leaf's sampled value may take between keyframes: a length 0 or more, a size (an area's `w` and `h`, a shape's `width` and `height`) 0 or more, a fraction or an op parameter within its range, a colour any colour. So a length a static value needs above 0 may be 0 there: a stroke `width`, a filter's `radius` or `size`, a radial gradient's `radius`, an area's `w` and `h`. A stroke then draws on from width 0, a blur eases in from radius 0, and a bar grows from no width. A value at 0 draws what it draws when it is sampled at 0 ([FRAMES-11](../FRAMES-11/SPEC.md), [FRAMES-15](../FRAMES-15/SPEC.md)). A leaf that one keyframe writes holds that value at every instant, so it is checked as a static value: a single keyframe of stroke `width` 0 stops as a static one does. A `dash` whose lengths are all 0 at a keyframe stops, as a static one does ([FRAMES-11](../FRAMES-11/SPEC.md)).
- A value that comes in or goes out is keyframed from or to the values at which it has no effect: a stroke of width 0, a shadow of transparent colour, a dash pattern with gaps of 0, a filter or audio filter entry at `mix` 0 ([FRAMES-15](../FRAMES-15/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md)), and its other end is often the merged value, written `null`.
- Between two keyframes that write it, a leaf interpolates as a number or per channel as a colour ([Interpolation](#interpolation)).

### Interpolation

Between two keyframes of a property, at progress u from 0 to 1 through the span, the value is `interp(a, b, ease(u))`, where `interp` is:

| Value | Interpolation |
| --- | --- |
| a number (`opacity`, `rotation`, `radius`, `volume`, `pan`, a `width` or `height`) | per component: `a + (b - a) × e` |
| `scale`, a number or `[sx, sy]` | per component, a number s taken as `[s, s]`, so a keyframe that writes a number may follow one that writes a pair ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| a colour | per channel, as a number: red, green, blue and alpha, straight (not premultiplied), on their sRGB-encoded values from 0 to 1, the working space ([FRAMES-21](../FRAMES-21/SPEC.md)). A gradient's stops across space interpolate premultiplied instead ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| a value with leaves (a `stroke`, a `fill`, a `shadow`, a `border`, a `filter` or `adjust`) | leaf by leaf, each timed leaf between the keyframes that write it as its kind above, the static leaves and the structure the same at every instant. A filter's timed leaves are its preset arguments, its op parameters and its entries' `mix` |
| `timeRemap` | as a number: the media time shown moves from one key's value to the next along the ease. Two keys with the same value hold a frame, a lower next value plays backwards, and eased keys give speed ramps ([FRAMES-8](../FRAMES-8/SPEC.md)) |
| a point, `[x, y]` | per component |
| an area, `[x, y, w, h]` | per component |
| `trim`, `[a, b]` | per component |
| `crop` | its centre per component and its size geometrically (in log space), so a zoom keeps one speed. Crops are conformed to one aspect ratio first ([FRAMES-9](../FRAMES-9/SPEC.md)), so the ratio holds between keyframes |
| a list of points (a path's `points`) | point by point. A keyframe's list of another length stops |
| a list of masks (`mask`) | mask by mask: each mask's geometry as its form above, and its `feather` as a number. Its `shape`, `invert` and `mode` are static, written on the clip's `mask`, and a keyframe that writes one, or a list of another length, stops. Its geometry's form is static too: the clip's `mask` gives it where it writes the geometry, and where it does not the keyframes give it together, as for any value with no static value, so a mask moved in every keyframe writes its geometry only there |

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

Keyframes on the transform and the geometry only, with colours, strokes and filters fixed for a clip: a colour change or a blur that eases off would be spread over clips, two crossfaded or one for each frame written by an extension, where frames keeps each editing fact one value ([FRAMES-25](../FRAMES-25/SPEC.md)). The rule that a key whose value is built from numbers and colours takes keyframes is the one After Effects follows, narrowed to the keys whose change alters no decision resolve makes once, and it decides every key added later, with the table of [FRAMES-7](../FRAMES-7/SPEC.md) following from it.

A title's font, size and the other attributes that decide its faces, its shaping and its line breaks taking keyframes, laid out again at each instant: lines would rewrap and words jump from one line to the next during the move, and the resolved document could no longer pin the glyphs that are drawn. Size animation is the title's `scale`, which moves no glyph against another. Tracking and line height are the moves an editor makes on spacing, and they keep their lines: tracking since they are broken at its widest, and line height since no break depends on it ([FRAMES-5](../FRAMES-5/SPEC.md)).

A keyframe's value as one whole value, a leaf it leaves out taken from the style at that keyframe: leaving a leaf out would reset it, so two changes with their own timing would have to be written together in every keyframe of either, and whether leaving a value out holds it or resets it would depend on how deep it lies in the JSON. After Effects times each value an editor moves on its own, and so does frames.

Keyframes as a layer of the look, merged over the clip's static value at each instant: they would merge by other rules than every other layer, since another form or `false` there would stop where a layer replaces or turns off, and `null` would point below, so one name would hold two operations. Taking their structure from the static value merged over the look instead would let a theme decide which type a document's keyframes may write: a style whose fill changed from a colour to a gradient would make colour keyframes stop. The clip's own layer gives keyframes the structure they write and merges by the look's one rule, and keyframes time leaves over the result.

Names and forms that change between keyframes taken as a hold to the next keyframe, as After Effects treats a property it cannot interpolate: a span between two keyframes says that the value moves from one to the other under its ease, which a name cannot do, so the span would not do what it says. Names and forms are static instead, written once where the look or the clip sets them. A name that changes at an instant is two clips cut there, which says so.

Keyframed colours interpolated with premultiplied alpha, as a gradient's stops are ([FRAMES-11](../FRAMES-11/SPEC.md)): a gradient spreads colour over space, where alpha is coverage, but a keyframed colour is one colour changing in time, and the channels each keyframe writes are the colours it passes through, as After Effects interpolates a colour property channel by channel. A fade to transparent is written with its own colour's channels and changes only its alpha.

## Notes
