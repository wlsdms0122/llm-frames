# FRAMES-29: Motion blur

Status: draft

## Summary

How a clip shows the motion frames gives it during the exposure of an output frame, as After Effects' Motion Blur switch does: `format.motionBlur`, the sequence's shutter (`shutterAngle`, `shutterPhase` and `samplesPerFrame`), and a clip's `motionBlur`; the sample instants of a frame's exposure and how each is clamped into the clip's window; what is held at the frame's own instant (which clips draw, media frames, tracked motion, the grain seed, a track matte) and what moves; the group a clip with motion blur draws, a `picture` whose source is the `samples` of the clip at those instants, and their mean, a form-free formula; how the clips inside a compound clip or a template instance take the exposure of the outermost sequence through its time map; and what a renderer does to draw it.

## Motivation

A keyframed move that a camera would smear is drawn today as a sharp picture that jumps from one place to the next: a title that slides 80 pixels a frame at 24 fps strobes, and a push made with a transition's motion stutters. After Effects blurs the motion of every layer whose switch is on, with one shutter for its composition, Fusion blurs per node, and Premiere Pro blurs the motion of its Transform effect. Without motion blur in frames, the nearest an extension can come is a compound clip that holds N copies of the clip with shifted keyframes at falling opacities, and that fails twice. Source-over at partial alpha is not a mean: co = αs × Cs + (1 - αs) × co weighs each later copy by its alpha. And every copy would need its animation spans, its transition, its parent's motion, its tracked motion and its unit animations shifted in time, which is evaluation itself. Two people writing it would choose different instants, weights and holds, and footage in the copies would be exposed several times over. So the instants of a frame's exposure, what moves between them, and their mean are frames's.

## Rules

**An output frame is an exposure. A clip with motion blur shows the mean of what it draws at evenly spaced instants of that exposure, with its media frames held at the frame's own instant.**

### The shutter

`format.motionBlur` is the sequence's shutter: an object `{shutterAngle, shutterPhase, samplesPerFrame}`, each key optional.

| Key | Value | Default | Meaning |
| --- | --- | --- | --- |
| `shutterAngle` | degrees, a number above 0 and at most 720 | 180 | how long the shutter is open, A / 360 of a frame: 360 is a whole frame and 720 two |
| `shutterPhase` | degrees, a number from -360 to 360 | -`shutterAngle` / 2 | when the shutter opens, P / 360 of a frame from the frame's instant, a negative phase before it. The default centres the exposure on the instant |
| `samplesPerFrame` | a whole number from 2 to 256 | 16 | how many instants of the exposure a clip with motion blur is drawn at |

- A value outside its range, a value of another type and a `samplesPerFrame` that is not a whole number stop at `check`. A format without `motionBlur`, or with some of its keys left out, takes the defaults for what it leaves out, the default phase computed from the angle in effect.
- The shutter is static: it takes no keyframes, and it is the same for every frame and every clip of the output.
- A compound clip's or a template instance's `format.motionBlur` applies only when it is rendered alone, as its `fps` does ([FRAMES-3](../FRAMES-3/SPEC.md)). Inside another sequence the key is allowed and has no effect, and the outermost sequence's shutter is the shutter of every clip it shows, the clips inside its compound clips and template instances included ([Compound clips and template instances](#compound-clips-and-template-instances)).

A clip's `motionBlur` is `true` or `false`, and `false` by default. It is taken by every storyline clip (timed media, still and solid) and by every clip with a picture but an adjustment clip: a title, a shape, a visual media clip and a still media clip ([FRAMES-7](../FRAMES-7/SPEC.md)).

- It is a boolean, so it is static ([FRAMES-4](../FRAMES-4/SPEC.md)), and a keyframe that writes it stops.
- On an adjustment clip or an audio clip it is an unknown key and stops at `check`. An adjustment clip draws no picture of its own: it filters what is below it in its list ([FRAMES-11](../FRAMES-11/SPEC.md)), and an audio clip draws nothing.
- A theme's `defaults` and a style do not set it, as they do not set `blend` ([FRAMES-22](../FRAMES-22/SPEC.md)).
- It is the clip's own. A parent's `motionBlur` does not reach its children ([FRAMES-10](../FRAMES-10/SPEC.md)), and a compound clip's or a template instance's does not reach the clips inside it.

### The exposure of a frame

A frame's instant T is k / fps for frame k of `render` ([FRAMES-21](../FRAMES-21/SPEC.md)), and the time asked for by `still`, `sheet`, `evaluate`, `locate` and a PNG ([FRAMES-23](../FRAMES-23/SPEC.md)). With A the shutter angle, P the shutter phase, N the samples per frame and fps the frame rate, all of the outermost sequence, the frame's exposure is the interval from T + P × d to T + (P + A) × d, and its sample instants tᵢ are the midpoints of N equal parts of it:

```
d   = 1 / (360 × fps)                       seconds per degree of shutter
tᵢ = T + (P + A × (i + 0.5) / N) × d       for i = 0, 1, ..., N - 1
```

Each sample weighs 1 / N: the shutter is a box, open with the same weight over its whole interval. Under the defaults at 25 fps the exposure of frame k runs from T - 0.01 to T + 0.01 seconds, and t₀ is T - 0.009375.

**A sample instant is clamped into the clip's window.** A clip's sample instant uᵢ is tᵢ clamped into its window from a to b, a storyline clip's drawn range and any other clip's visible window ([FRAMES-8](../FRAMES-8/SPEC.md)), with its end b included:

```
uᵢ = min(max(tᵢ, a), b)
```

Every window lies inside the sequence, from 0 to its `duration`, so every uᵢ does too. The clip's values at b are those its values reach at the end of its window: its keyframes and eases there, its exit at progress 1 ([FRAMES-14](../FRAMES-14/SPEC.md)) and a storyline clip's transition motion at the end of its drawn range.

**Which clips draw is decided at T.** A clip draws on a frame where it is visible at T, as without motion blur, and its sample instants only move what it draws. A clip whose window starts after T draws nothing on that frame, even where its start lies inside the exposure, and on the first frame it draws its instants before its start are moved to its start. A clip whose window ends inside the exposure draws on its last frame, with its instants after its end moved to its end. So a cut stays on the frame it is on without motion blur, and a clip visible from 0 shows whole on the first frame ([FRAMES-24](../FRAMES-24/SPEC.md)).

**Note.** Clamped instants gather at the edge of the window, so on the first and the last frame of a moving clip its picture is weighed towards where it is at that edge, and the trail of its blur is shorter there.

### What is held and what moves

A clip with `motionBlur` is evaluated at each of its sample instants uᵢ as [FRAMES-20](../FRAMES-20/SPEC.md) evaluates any clip at an instant, with these taken at the frame's instant T instead:

- **Which clips draw, and the stack.** The clips that draw, the storyline clips a transition holds, and their order in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)) are those at T.
- **Media frames.** Every media frame the clip shows is the frame its media time at T picks ([FRAMES-3](../FRAMES-3/SPEC.md)): its media's, through its time map with its `timeRemap` and handles ([FRAMES-8](../FRAMES-8/SPEC.md)), and a transition matte's `frame` on an incoming storyline picture, picked at the transition's progress at T ([FRAMES-14](../FRAMES-14/SPEC.md)). A compound clip's or a template instance's picture is its nested display list at the media time T maps to. So footage in a clip with motion blur is never exposed twice, as After Effects blurs the motion a layer is given and not the motion inside its footage.
- **Tracked motion.** A track is a fact about the media frame it was followed on, so a tracked motion, the clip's own and its parent's, is the motion of the media frame its tracked media shows at T ([FRAMES-12](../FRAMES-12/SPEC.md)), and it adds no blur inside a frame. The values the motion carries still move with uᵢ: a clip's keyframes over a tracked target are brought back through the motion at their own times as before, interpolated at uᵢ, and carried by the motion of the frame at T.
- **The grain seed.** Every `grain` op takes the seed of the output frame, as every nested list does ([FRAMES-20](../FRAMES-20/SPEC.md#what-evaluation-has-done)).
- **The track matte.** The clip's track matte is the matte clip's picture at T ([FRAMES-11](../FRAMES-11/SPEC.md)). It is blurred only by the matte clip's own `motionBlur`, and not by the motion of the clip it cuts.

Everything else is taken at uᵢ: every keyframed value with its ease and spring, the clip's position, anchor, scale, rotation, opacity, crop, geometry, mask, colours, stroke, shadow and filter values, a clip area at uᵢ ([FRAMES-2](../FRAMES-2/SPEC.md)), its animation and a title's unit animation ([FRAMES-14](../FRAMES-14/SPEC.md)), its parent's transform at uᵢ with the parent's keyframes and transition motion there, held at the edge of the parent's window as [FRAMES-10](../FRAMES-10/SPEC.md) holds it, and a storyline clip's transition motion, its opacity, reveal and matte `progress` at uᵢ.

### The group

A clip with `motionBlur` has N samples. Its sample at uᵢ is a display list Lᵢ the size of the list that holds the clip, with a transparent background and the holding list's `compositing` and seed, whose items are what the clip draws at uᵢ ([FRAMES-20](../FRAMES-20/SPEC.md)) with the values above:

- for a storyline clip, its outer item with `blend` `normal`. Its inner item keeps its own track matte, at T, inside the transition motion, in the order [FRAMES-9](../FRAMES-9/SPEC.md) makes a storyline picture in, so the cut picture leaves with the transition.
- for any other clip, the items it draws (a `picture`, a `path`, a `glyphs` item, or the group of a title animated by unit) with `blend` `normal` and `trackMatte` `null`.

Where the N lists are equal, field by field, the clip draws in place of the group the items of L₀ with its own `blend`, and for a clip other than a storyline clip its own track matte: what it draws without motion blur at u₀. Otherwise it draws one `picture` item, the **group**:

| Field | Value |
| --- | --- |
| `source` | `samples`, the lists L₀ to Lₙ₋₁ in the order of i |
| `rect`, `dest` | the whole frame of the holding list, `[0, 0, w, h]` |
| `transform`, `opacity` | the identity, 1 |
| `blend` | the clip's |
| `mask`, `reveal` | `null` |
| `trackMatte` | the clip's track matte at T, and `null` for a storyline clip, whose track matte is inside its samples |
| `filter`, `matte`, `radius`, `border`, `shadow` | none |

The group's origin is the clip, as its items' are. It takes the clip's place in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)), and a storyline clip's group stands where its outer item would, stacked with the other storyline picture of a transition as `over` says ([FRAMES-14](../FRAMES-14/SPEC.md)).

**Note.** A track matte multiplies the alpha of each sample of a clip other than a storyline clip at the same point by the same value v, so the mean of the cut samples is the mean cut once, (v × c₀ + ... + v × cₙ₋₁) / N = v × (c₀ + ... + cₙ₋₁) / N, and the group carries it once. A storyline clip's track matte is in the coordinates of its inner list, which its transition motion moves differently in each sample, so it stays inside them.

### The mean

**The picture of a `samples` source is the mean of the pictures of its lists.** At each point of the holding list's frame, with cᵢ the premultiplied colour and αᵢ the alpha of list i, each drawn as a nested list is drawn, at the size it is shown at ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)):

```
c = (c₀ + c₁ + ... + cₙ₋₁) / N
α = (α₀ + α₁ + ... + αₙ₋₁) / N
```

The mean is a form-free formula: it reads its colours in the form the holding list's `compositing` names, and averages code values under `encoded` and light under `linear` ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)). The group then draws the mean as any `picture` of a nested list: its alpha multiplied by its track matte, composited onto what is below it by its `blend`.

A renderer sums the N pictures in floating point of 32 bits or more and divides the sum by N once, and the mean of N equal pictures is that picture.

**Note.** A picture held in 16-bit floating point, as the working buffers of `quartz` are, has 11 significant bits. N times such a value, N at most 256, needs at most 19, which a 32-bit float holds exactly, and so does every partial sum of equal values, so the sum of N equal pictures divided by N gives each value back exactly.

### Compound clips and template instances

A compound clip or a template instance C shown on a frame of instant T is evaluated at m(T), where m maps the time of the sequence that holds C to C's media time by C's time map: its `in`, `speed`, `loop` and `timeRemap` ([FRAMES-8](../FRAMES-8/SPEC.md)), clamped into its `[0, duration)` ([FRAMES-3](../FRAMES-3/SPEC.md)). m(T) is the frame's instant inside C: which of C's clips draw, their media frames and their tracked motion are taken there.

**A clip inside C with `motionBlur` takes the outer exposure mapped into C's clock.** Its sample instants are m(wᵢ), where wᵢ is the outer sample instant tᵢ clamped into C's window in the sequence that holds it, and each m(wᵢ) is then clamped into the inner clip's own window as [The exposure of a frame](#the-exposure-of-a-frame) clamps it. Through compound clips nested in compound clips each map and window applies in turn, from the outermost sequence in. So one shutter is the camera of the whole output, and the shutter of C's own format plays no part.

- Under `speed` s, the inner instants are spread s times as far apart in C's time, so a clip inside C is blurred by the motion it shows on the output.
- Where `timeRemap` holds a frame over the exposure, every m(wᵢ) is the same, the inner clip's N lists are equal, and it draws as without motion blur, as a held frame shows no motion.
- Where `timeRemap` plays backwards, the inner instants decrease with i. The samples keep the order of i, and their mean is the same in any order.
- Where an eased `timeRemap` ramps the speed, the inner instants are spaced as the map spaces them.
- Where a `loop` repeats C inside the exposure, an instant past the end of the loop maps to its start, so the exposure across the seam sees both ends, as the output shows them one after the other.
- C's own `motionBlur` blurs only C's motion in the sequence that holds it (its transform, its parent's motion, its animation, its transition motion). Its picture is held: every one of C's samples holds the same nested list, evaluated at m(T), with the groups of its own clips with motion blur inside it.

### Transitions, units, mattes and parents

- **A transition between two storyline clips of which one has motion blur.** The clip without it draws its two items at T as without motion blur. The clip with it draws its group: in each sample its outer item carries the transition's motion, opacity, reveal and matte `progress` at uᵢ, clamped into its drawn range, so the incoming clip's instants before the transition starts are moved to its start, while its media frame and the matte's `frame` are those at T. A cross dissolve that moves nothing gives samples that differ in opacity only, and their mean is the clip's opacity averaged over the exposure. A transition cover is no clip's: it is drawn at T, above both storyline pictures.
- **A title animated by unit.** Each sample holds the title's group ([FRAMES-20](../FRAMES-20/SPEC.md#glyphs-and-adjustments)) at uᵢ: every unit's motion, opacity and reveal at uᵢ, and the title's own opacity and mask at uᵢ. The motion blur group carries the title's blend and track matte. So each unit is blurred by its own motion, a unit at rest stays sharp while the one after it enters, and the passes keep their order inside every sample.
- **A track matte.** A clip used as a matte with `motionBlur` draws its group into the matte's source, so the matte is soft along its own motion. A clip cut by a matte takes the matte at T whatever its own `motionBlur`.
- **A parent and a child.** A child with `motionBlur` is blurred by all its motion on the output, its parent's motion at its sample instants included, whether or not its parent has motion blur, as After Effects blurs a child layer moved by a parent. A parent with `motionBlur` and a child without it give a blurred parent and a sharp child, each drawn as its own key says. A child that should blur with its parent turns its own `motionBlur` on.

### Roles

- The renderer draws the `samples` source by the mean above ([FRAMES-21](../FRAMES-21/SPEC.md)). A renderer that lacks it refuses before it starts, naming the first group and its place, as for any item it lacks.
- The decoder is asked for each media frame of a clip with motion blur once per output frame, the frame at T. The mixer and the mix plan are unchanged: motion blur acts on pictures only ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)). The encoder is unchanged.

## Interactions

The keys are in the tables of [FRAMES-7](../FRAMES-7/SPEC.md), the format is [FRAMES-9](../FRAMES-9/SPEC.md), and what a compound clip's format applies is [FRAMES-3](../FRAMES-3/SPEC.md). Windows, drawn ranges, clip time and time maps are [FRAMES-8](../FRAMES-8/SPEC.md), parents [FRAMES-10](../FRAMES-10/SPEC.md), track mattes [FRAMES-11](../FRAMES-11/SPEC.md), tracked motion [FRAMES-12](../FRAMES-12/SPEC.md), animations, units and transitions [FRAMES-14](../FRAMES-14/SPEC.md). The resolved document writes the shutter and every clip's `motionBlur` ([FRAMES-19](../FRAMES-19/SPEC.md)). The group, the `samples` source and its JSON form are items of the display list ([FRAMES-20](../FRAMES-20/SPEC.md)), the renderer draws them ([FRAMES-21](../FRAMES-21/SPEC.md)), `evaluate` and `locate` report them ([FRAMES-23](../FRAMES-23/SPEC.md)), and the checks are in [FRAMES-24](../FRAMES-24/SPEC.md). The mean is a form-free formula of [FRAMES-26](../FRAMES-26/SPEC.md#compositing).

## Alternatives considered

Every output frame drawn N times and the frames averaged in the render loop: every clip would blur, a static title over moving footage among them, footage at the sequence's rate would be exposed across two of its frames where an instant crosses a frame boundary, and nothing could turn it off for one clip. A key on each clip with one shutter for the output blurs what the editor asks for and keeps one camera.

A shutter angle on each clip, as Premiere Pro's Transform effect has: two exposures in one frame, which no camera gives, and After Effects, whose model is the richest of the four, keeps one shutter for a composition.

An adaptive count, more samples where a clip moves further, as After Effects' Adaptive Sample Limit chooses for 2D layers: it depends on a measure of motion that every implementation would have to compute alike, and a document that needs more samples raises `samplesPerFrame`.

The samples as N items of the clip at opacity 1 / N: source-over at partial alpha is not a mean, since each item composites over the ones below it and weighs them by 1 - αs, and the clip's blend would apply N times.

Media frames picked at each instant: footage at the sequence's rate would be exposed twice where an instant crosses into the next media frame, and a still shot would ghost, against the rule After Effects keeps that motion inside a layer is not blurred. Blurring the motion inside footage is optical flow, a different topic (README).

Tracked motion taken at each instant, between the tracked frames: a track is known only on the frames it was followed on, so the motion between two of them would be an interpolation the tracker never measured, and the clip would blur on its own while the footage it sits on, held at T, does not move.

Samples at the ends of the exposure, t₀ at its opening and tₙ₋₁ at its closing: two of the N weights would fall on the edges of the interval, where the midpoints of a box of N parts put none, and under a shutter of 360 the instant between two frames would be exposed in both of them.

Instants outside the window dropped instead of clamped: a moving clip would fade in over its first frame and out over its last, each cut would become a dissolve one frame long, and a clip visible from 0 would not show whole on the first frame ([FRAMES-24](../FRAMES-24/SPEC.md)).

A storyline clip's track matte moved from its inner item to the group, as for other clips: the matte would no longer move with the transition's motion, and a matted storyline picture would leave a transition differently with motion blur on, against the order of [FRAMES-9](../FRAMES-9/SPEC.md).

A compound clip's own `format.motionBlur` applied to its inner clips: two shutters in one output, and a template would blur differently in hosts of different rates. The outermost shutter mapped through the time map is the camera of the output, as a compound clip's `colorSpace` gives way to the outermost sequence's ([FRAMES-26](../FRAMES-26/SPEC.md#sequence-colour-space)).

## Notes

**Note.** A clip with motion blur is drawn N times a frame, so it costs N nested rasters the size of its holding list, and the `evaluate` output and the JSON form of a display list hold N lists for it. A clip with motion blur inside a compound clip with motion blur is drawn N times in each of the N samples of the compound clip unless the renderer draws the nested list once and reuses it, which it can, since the N samples hold the same list. The time per frame against the same frame without motion blur, at 1080p and 4K and at 16 and 64 samples, is not yet measured.

**Note.** N samples show a fast move as N copies, steps of v × A / (360 × fps × N) pixels for a clip moving v pixels a second. Under the defaults at 25 fps a clip moving 1600 pixels a second, 64 a frame, shows steps of 2 pixels, which read as a smooth blur, and one moving 10000 pixels a second shows steps of 12.5, which read as echoes. Raising `samplesPerFrame` makes the steps smaller at the cost of the time per frame.

**Note.** Whether Core Image sums a long chain of pictures in the order written, and so gives the same bytes twice ([FRAMES-24](../FRAMES-24/SPEC.md)), and whether its sum of N equal 16-bit pictures divided by N gives them back exactly, is not yet measured.
