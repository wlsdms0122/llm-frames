# FRAMES-29: Motion blur

Status: draft

## Summary

How a clip shows the motion frames gives it during the exposure of an output frame, as After Effects' Motion Blur switch does: `format.motionBlur`, the sequence's shutter (`shutterAngle`, `shutterPhase` and `samplesPerFrame`), and a clip's `motionBlur`; the principle of what a sample moves (pose) and holds (content and membership); the groups clips with motion blur form, each a `picture` whose source is the `samples` of its clips at the instants of the frame's exposure cut to where the group is, and their mean, a form-free formula; how the clips inside a compound clip or a template instance take the exposure of the outermost sequence through its time map; and what a renderer does to draw it.

## Motivation

A keyframed move that a camera would smear is drawn today as a sharp picture that jumps from one place to the next: a title that slides 80 pixels a frame at 24 fps strobes, and a push made with a transition's motion stutters. After Effects blurs the motion of every layer whose switch is on, with one shutter for its composition, Fusion blurs per node, and Premiere Pro blurs the motion of its Transform effect. Without motion blur in frames, the nearest an extension can come is a compound clip that holds N copies of the clip with shifted keyframes at falling opacities, and that fails twice. Source-over at partial alpha is not a mean: co = αs × Cs + (1 - αs) × co weighs each later copy by its alpha. And every copy would need its animation spans, its transition, its parent's motion, its tracked motion and its unit animations shifted in time, which is evaluation itself. Two people writing it would choose different instants, weights and holds, and footage in the copies would be exposed several times over. So the instants of a frame's exposure, what moves between them, and their mean are frames's.

## Rules

**Clips with motion blur are exposed in groups. A group, a run of such clips next to each other in the stack, is drawn at evenly spaced instants of the frame's exposure, its clips composited onto each other inside each instant, and shows the mean of those pictures, which is an exposure of the group. A sample moves each clip's pose and holds its content and which clips draw at the frame's own instant. The mean is composited onto what is below it once.**

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
### What a sample moves and what it holds

**A sample moves pose and holds content and membership.**

- **Pose** is a clip's own values at the instant and the chain it inherits: its keyframed values with their eases and springs, its animation and a title's unit animation ([FRAMES-14](../FRAMES-14/SPEC.md)), its parent's transform at the instant as [FRAMES-10](../FRAMES-10/SPEC.md) gives it, a storyline clip's transition motion and progress for its side, and its masks, opacity, geometry, colours and filter values, a clip area included ([FRAMES-2](../FRAMES-2/SPEC.md)). Pose is taken at each sample instant.
- **Content** is what a clip shows: its media frames, the pictures of the nested sequences it shows, the grain seed, and its tracked motion, which is a fact about the media frame it was followed on. Content is that of the frame's instant T.
- **Membership** is which clips draw and their order in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)), the storyline clips a transition holds included. Membership is decided at T.

Every case follows from this:

- A media frame is the one the clip's media time at T picks, through its time map with its `timeRemap` and handles ([FRAMES-3](../FRAMES-3/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md)). A transition matte's `frame` is content, picked at the transition's progress at T, and its `progress` is pose. So footage is never exposed twice, as After Effects blurs the motion a layer is given and not the motion inside its footage.
- A compound clip's or a template instance's picture is content: its nested display list at the media time T maps to, the same in every sample, with its own clips exposed inside it ([Compound clips and template instances](#compound-clips-and-template-instances)).
- A tracked motion, the clip's own and its parent's, is the motion of the media frame its tracked media shows at T ([FRAMES-12](../FRAMES-12/SPEC.md)), so it adds no blur inside a frame. A clip's keyframes over a tracked target are pose: they are brought back through the motion at their own times as before, interpolated at the sample instant, and carried by the motion of the frame at T.
- Every `grain` op takes the seed of the output frame, as every nested list does ([FRAMES-20](../FRAMES-20/SPEC.md#what-evaluation-has-done)).
- A clip that is not visible at T draws in no sample, and a clip that is visible at T draws in every sample of its group ([The exposure of a group](#the-exposure-of-a-group)).
- An item that no clip draws, a transition cover, has no pose of its own to sample. It is drawn at T.

### Groups

In each display list, the outermost one and every nested one, the clips that draw at T and have `motionBlur` form groups. **A run of clips next to each other in the list's stacking order, each with `motionBlur` and `blend` `normal`, is one group.** A clip with `motionBlur` and another blend is a group of its own. A clip without `motionBlur` and a transition cover end a run. A clip used as a track matte takes no place in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)), so it ends no run.

A group has N samples. Its sample at the instant tᵢ is a display list Lᵢ the size of the list that holds the group, with a transparent background and the holding list's `compositing` and seed, whose items are what all the clips of the group draw at tᵢ ([FRAMES-20](../FRAMES-20/SPEC.md)), with their pose at tᵢ and their content and membership at T, in the order they stack in, each with `blend` `normal`. So the clips of a group are composited onto each other inside each sample, at the same instant. A storyline clip draws its two items there, its inner item with its own track matte inside its outer item, which carries the transition motion, in the order [FRAMES-9](../FRAMES-9/SPEC.md) gives, and a title animated by unit draws the title's group ([FRAMES-20](../FRAMES-20/SPEC.md#glyphs-and-adjustments)).

**A track matte is part of what a clip draws at each instant.** In sample i, a clip's track matte is the matte clip's picture with the matte clip's pose at tᵢ and its content at T ([FRAMES-11](../FRAMES-11/SPEC.md)). So a matte that moves with the clip it cuts gives the mean of the matte times the picture. A clip used as a track matte is not drawn on its own ([FRAMES-11](../FRAMES-11/SPEC.md)), so its own `motionBlur` is not read: it moves in the samples of the clip it cuts, and it is held at T for a clip without motion blur.

The group draws one `picture` item in the holding list:

| Field | Value |
| --- | --- |
| `source` | `samples`, the lists L₀ to Lₙ₋₁ in the order of i |
| `rect`, `dest` | the whole frame of the holding list, `[0, 0, w, h]` |
| `transform`, `opacity` | the identity, 1 |
| `blend` | `normal` for a run, the clip's for a clip with another blend |
| `mask`, `reveal`, `trackMatte` | `null` |
| `filter`, `matte`, `radius`, `border`, `shadow` | none |

The group takes the place of its clips in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)). Its origin is its lowest clip, and the items inside its samples carry their own clips.

### The exposure of a group

A frame's instant T is k / fps for frame k of `render` ([FRAMES-21](../FRAMES-21/SPEC.md)), and the time asked for by `still`, `sheet`, `evaluate`, `locate` and a PNG ([FRAMES-23](../FRAMES-23/SPEC.md)). With A the shutter angle, P the shutter phase, N the samples per frame and fps the frame rate, all of the outermost sequence, the frame's exposure is the interval from T + P × d to T + (P + A) × d, with d = 1 / (360 × fps) seconds per degree of shutter.

**The exposure is cut to where the group is.** A group's exposure is the largest interval that holds T and lies inside the frame's exposure on which:

- every clip of the group is in its window ([FRAMES-8](../FRAMES-8/SPEC.md)), a storyline clip's drawn range and any other clip's visible window, and so is every matte clip of their track mattes. Clips of one run with different windows cut it to the part all of them share, since which clips draw is fixed at T.
- for a group inside a compound clip or a template instance, every clip that holds it is in its window, and every time map from the outermost sequence in is continuous and stays inside its nested sequence's `[0, duration)` ([FRAMES-3](../FRAMES-3/SPEC.md)). A loop seam and the ends of a nested sequence cut it. A window inside it is read at the time the maps give.

With lo and hi the ends of that interval, the group's sample instants are the midpoints of N equal parts of it, each weighing 1 / N, as a shutter that is open with the same weight over its whole interval:

```
tᵢ = lo + (hi - lo) × (i + 0.5) / N      for i = 0, 1, ..., N - 1
```

- N is the same for every group, whatever the length of its cut.
- A window `[a, b)` is half open, and a midpoint lies strictly between lo and hi, so no sample instant is ever the end b of a window or the `duration` of a nested sequence. Where the cut leaves only T, lo = hi = T, every sample instant is T.
- Under the defaults at 25 fps the exposure of frame k runs from T - 0.01 to T + 0.01 seconds, and for a group in its window over all of it t₀ is T - 0.009375.

So a cut stays a cut: the clip before it is exposed up to its end and not past it, and the clip after it, not visible at T, draws nothing on that frame. A clip visible from 0 shows whole on the first frame, and on the first and the last frame of a moving clip its N instants are spread over the part of the exposure it is in, so its trail is shorter there and weighed as evenly as on every other frame.

### The mean

**The picture of a `samples` source is the mean of the pictures of its lists.** At each point of the holding list's frame, with cᵢ the premultiplied colour and αᵢ the alpha of list i, each drawn as a nested list is drawn, at the size it is shown at ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)):

```
c = (c₀ + c₁ + ... + cₙ₋₁) / N
α = (α₀ + α₁ + ... + αₙ₋₁) / N
```

The mean is a form-free formula: it reads its colours in the form the holding list's `compositing` names, and averages code values under `encoded` and light under `linear` ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)). The group then draws the mean as any `picture` of a nested list, composited onto what is below it by its `blend`.

A renderer sums the N pictures in the order of the list, from a sum of 0, in floating point of 32 bits or more, and divides the sum by N once, so the same lists give the same picture, and the mean of N equal pictures is that picture.

**The mean of a group is an exposure of the group**, since its clips are composited onto each other at each instant. What is below the group is drawn once, and the mean is composited onto it once. Under `normal` this is an exposure of the whole frame in which what is below is held, since source-over is linear in the source over a fixed backdrop: (c₀ + (1 - α₀) × b + ... + cₙ₋₁ + (1 - αₙ₋₁) × b) / N = c + (1 - α) × b.

**Note.** The mean differs from an exposure of the whole frame in two places. A group over another group that also moves, with a clip without motion blur between them, is composited onto the lower group's mean, and an exposure would composite each instant onto the lower group at that instant: the two differ where both move over the same points. And a clip with a blend other than `normal` is composited by it once, onto its mean, which equals the mean of its samples blended one by one only where the blend's result is affine in the source over a fixed backdrop, as under `multiply`, `screen`, `overlay`, `exclusion` and `add`, and not under `darken`, `lighten`, `difference`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `plus-lighter` and the non-separable modes.

**Note.** A picture held in 16-bit floating point, as the working buffers of `quartz` are, has 11 significant bits. N times such a value, N at most 256, needs at most 19, which a 32-bit float holds exactly, and so does every partial sum of equal values, so the sum of N equal pictures divided by N gives each value back exactly.

### Transitions, parents and units

- **A push with both sides on.** The two storyline pictures stack next to each other, so two storyline clips with `motionBlur` and `blend` `normal` are one group. Each sample holds both outer items moved by the transition at tᵢ, which meet at the seam with no gap, so the seam is exposed as one moving picture and its mean alpha is 1. The transition cover is drawn above the group at T.
- **A push with one side on.** The clip with `motionBlur` is a group of its own and the other draws at T, so a blurred edge meets a sharp one. With the incoming side on, its mean is partly transparent ahead of where the outgoing picture ends at T, and with the outgoing side on, its mean is partly transparent behind where the incoming picture starts at T. In both, what lies below the storyline shows through on the blurred side, over half the length the blur spreads. A cross dissolve, which moves nothing, gives samples that differ in opacity only, and its mean is the clip's opacity averaged over the exposure.
- **A picture and a parented frame.** A bar parented to a title and stacked next to it, both with `motionBlur`, is one group with the title: each sample composites the title over the bar at the same instant, so they expose as one picture and leave no seam. A child is moved by its parent's transform at each sample instant, so a child with `motionBlur` is blurred by all its motion on the output, its parent's included, whether or not its parent has motion blur, as After Effects blurs a child layer moved by a parent. A parent with `motionBlur` and a child without it give a blurred parent and a sharp child.
- **A title animated by unit.** Each sample holds the title's group at tᵢ: every unit's motion, opacity and reveal, and the title's own opacity and mask, there. So each unit is blurred by its own motion, a unit at rest stays sharp while the one after it enters, and the passes keep their order inside every sample.

**Note.** A push whose two sides should blur as one turns `motionBlur` on for both. With one side on, the seam is the edge of one exposed picture against a picture at T, and which side shows the band is the side whose switch is on.

### Compound clips and template instances

A compound clip or a template instance C shown on a frame of instant T is evaluated at m(T), where m maps the time of the sequence that holds C to C's media time by C's time map: its `in`, `speed`, `loop` and `timeRemap` ([FRAMES-8](../FRAMES-8/SPEC.md)), within its `[0, duration)` ([FRAMES-3](../FRAMES-3/SPEC.md)). m(T) is the frame's instant inside C: which of C's clips draw, their media frames and their tracked motion are taken there.

**A group inside C takes the outer exposure mapped into C's clock.** Its sample instants are m(wᵢ), where w₀ to wₙ₋₁ are the instants of the outer exposure cut as [The exposure of a group](#the-exposure-of-a-group) cuts it, and through compound clips nested in compound clips each map applies in turn, from the outermost sequence in. So one shutter is the camera of the whole output, and the shutter of C's own format plays no part.

- Under `speed` s, the inner instants are spread s times as far apart in C's time, so a clip inside C is blurred by the motion it shows on the output.
- Where `timeRemap` holds a frame over the exposure, every m(wᵢ) is the same, the inner lists are equal, and their mean is the picture without motion blur, as a held frame shows no motion.
- Where `timeRemap` plays backwards, the inner instants decrease with i. The samples keep the order of i, and their mean is the same in any order.
- Where an eased `timeRemap` ramps the speed, the inner instants are spaced as the map spaces them.
- Where a `loop` repeats C inside the exposure, the seam cuts it: a group inside C is exposed on the side of the seam that holds T, as are its clips, and the other side is not seen on that frame.
- C's own `motionBlur` moves only C's pose in the sequence that holds it (its transform, its parent's motion, its animation, its transition motion). Its picture is content: every sample of C's group holds the same nested list, evaluated at m(T), with the groups of its own clips inside it.

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

Instants outside the window dropped: a moving clip would fade in over its first frame and out over its last, each cut would become a dissolve one frame long, and a clip visible from 0 would not show whole on the first frame ([FRAMES-24](../FRAMES-24/SPEC.md)).

Instants clamped into the window, uᵢ = min(max(tᵢ, a), b): on the first frame of a clip the instants before its start pile up on it, so its starting pose is stamped with up to half the weight and a fading entrance shows almost transparent, and inside a loop an instant past the seam maps near the start of C and is clamped to the start of an inner clip, mixing its entrance into its blur. Cutting the exposure keeps the cut and the whole first frame and spreads every instant evenly.

A mean per clip, each clip's samples holding that clip alone: two opaque pictures that move together, both sides of a push or a picture and its frame, would each be partly transparent along their shared edge, and where each covers half the samples the seam's alpha would be 0.5 + (1 - 0.5) × 0.5 = 0.75, so a quarter of what is below would show through. Compositing a run inside each sample exposes it as one picture.

A track matte held at T and carried once on the group, which the mean allows since a matte that is the same in every sample multiplies the mean as it multiplies each sample: the matte is the same only because it is held, so a matte that moves with its clip, a rounded rect parented to a picture in picture, would cut the blurred picture with a sharp matte at T, and with the matte clip's own motion blur on with the mean of the matte times the mean of the picture, neither of them the mean of the matte times the picture. The matte is part of what the clip draws at each instant, as a mask is.

A compound clip's own `format.motionBlur` applied to its inner clips: two shutters in one output, and a template would blur differently in hosts of different rates. The outermost shutter mapped through the time map is the camera of the output, as a compound clip's `colorSpace` gives way to the outermost sequence's ([FRAMES-26](../FRAMES-26/SPEC.md#sequence-colour-space)).

## Notes

**Note.** A clip with motion blur is drawn N times a frame, so it costs N nested rasters the size of its holding list, and the `evaluate` output and the JSON form of a display list hold N lists for it. A clip with motion blur inside a compound clip with motion blur is drawn N times in each of the N samples of the compound clip unless the renderer draws the nested list once and reuses it, which it can, since the N samples hold the same list. The time per frame against the same frame without motion blur, at 1080p and 4K and at 16 and 64 samples, is not yet measured.

**Note.** N samples show a fast move as N copies, steps of v × A / (360 × fps × N) pixels for a clip moving v pixels a second. Under the defaults at 25 fps a clip moving 1600 pixels a second, 64 a frame, shows steps of 2 pixels, which read as a smooth blur, and one moving 10000 pixels a second shows steps of 12.5, which read as echoes. Raising `samplesPerFrame` makes the steps smaller at the cost of the time per frame.

**Note.** The order of the sum is fixed because a float sum depends on it: the same 64 pictures summed in another order differed in a few values in a million by one unit in the last place. Summed in order in 32-bit floats and rounded to nearest into 16-bit floats, the mean of N equal pictures came back exactly for N of 2, 3, 16, 64 and 256, and the mean of pictures that differ lay within one unit in the last place of the exact mean. A sum carried in 16-bit floats goes wrong from N of 64, and an addition that clamps to 0 and 1 loses the extended range ([FRAMES-26](../FRAMES-26/SPEC.md)).
