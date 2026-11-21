# FRAMES-29: Motion blur

Status: draft

## Summary

How a frame shows the motion frames gives its clips during the frame's exposure, as After Effects' Motion Blur switch does: `format.motionBlur`, the sequence's shutter (`shutterAngle`, `shutterPhase` and `samplesPerFrame`), and a clip's `motionBlur`; an output frame as the mean of N pictures of the whole frame, in each of which the clips with motion blur stand at one instant of the exposure; the principle of what a sample moves (pose) and holds (content and membership); how each clip's exposure is cut to where its pose is continuous; how the clips inside a compound clip or a template instance take the outermost exposure through its time map; and what the renderer, `evaluate` and `locate` do with such a frame.

## Motivation

A keyframed move that a camera would smear is drawn today as a sharp picture that jumps from one place to the next: a title that slides 80 pixels a frame at 24 fps strobes, and a push made with a transition's motion stutters. After Effects blurs the motion of every layer whose switch is on, with one shutter for its composition, Fusion blurs per node, and Premiere Pro blurs the motion of its Transform effect. Without motion blur in frames, the nearest an extension can come is a compound clip that holds N copies of the clip with shifted keyframes at falling opacities, and that fails twice. Source-over at partial alpha is not a mean: co = αs × Cs + (1 - αs) × co weighs each later copy by its alpha. And every copy would need its animation spans, its transition, its parent's motion, its tracked motion and its unit animations shifted in time, which is evaluation itself. Two people writing it would choose different instants, weights and holds, and footage in the copies would be exposed several times over. So the instants of a frame's exposure, what moves between them, and their mean are frames's.

## Rules

**An output frame is an exposure of the whole picture: the mean of N pictures of the frame, in each of which the clips with motion blur stand where they are at one instant of the exposure and everything else stands as at T.**

### The shutter

`format.motionBlur` is the sequence's shutter: an object `{shutterAngle, shutterPhase, samplesPerFrame}`, each key optional.

| Key | Value | Default | Meaning |
| --- | --- | --- | --- |
| `shutterAngle` | degrees, a number above 0 and at most 720 | 180 | how long the shutter is open, A / 360 of a frame: 360 is a whole frame and 720 two |
| `shutterPhase` | degrees, a number from -`shutterAngle` to 0 | -`shutterAngle` / 2 | when the shutter opens, P / 360 of a frame before the frame's instant, so the exposure always holds the instant. The default centres the exposure on it, -`shutterAngle` closes the shutter at it, and 0 opens the shutter at it |
| `samplesPerFrame` | a whole number from 2 to 256 | 16 | N, how many pictures of the frame its exposure is the mean of |

- A value outside its range, a value of another type and a `samplesPerFrame` that is not a whole number stop at `check`. The range of `shutterPhase` is read against the angle in effect, so a phase of -200 under the default angle of 180 stops. A format without `motionBlur`, or with some of its keys left out, takes the defaults for what it leaves out, the default phase computed from the angle in effect.
- The shutter is static: it takes no keyframes, and it is the same for every frame and every clip of the output.
- A compound clip's or a template instance's `format.motionBlur` applies only when it is rendered alone, as its `fps` does ([FRAMES-3](../FRAMES-3/SPEC.md)). Inside another sequence the key is allowed and has no effect, and the outermost sequence's shutter is the shutter of every clip it shows, the clips inside its compound clips and template instances included ([Compound clips and template instances](#compound-clips-and-template-instances)).

A clip's `motionBlur` is `true` or `false`, and `false` by default. It is taken by every storyline clip (timed media, still and solid) and by every clip with a picture: a title, a shape, a visual media clip, a still media clip and an adjustment clip ([FRAMES-7](../FRAMES-7/SPEC.md)).

- It is a boolean, so it is static ([FRAMES-4](../FRAMES-4/SPEC.md)), and a keyframe that writes it stops.
- On an audio clip it is an unknown key and stops at `check`, since an audio clip draws nothing.
- A theme's `defaults` and a style do not set it, as they do not set `blend` ([FRAMES-22](../FRAMES-22/SPEC.md)).
- It moves the clip's own values, wherever they act: a parent's moves its transform in the poses of its children, and a matte clip's its values in the track matte it gives ([What a sample moves and what it holds](#what-a-sample-moves-and-what-it-holds)). A compound clip's or a template instance's moves its own pose, and each clip inside it reads its own.

### The samples

**When a clip that draws at T, at any depth of nesting, has `motionBlur`, the frame's display list holds N sample lists** ([FRAMES-20](../FRAMES-20/SPEC.md)). Sample i is a whole list of the frame: every clip that draws at T, in its order, with its blend, masks, track matte, adjustments and nested lists as usual, each clip at its pose in sample i. The frame is the mean of the pictures of its samples ([The mean](#the-mean)). Otherwise the frame is one list, as without motion blur.

- Only the outermost list of a frame holds samples, and a nested list never does: a compound clip's picture in sample i is its nested list as it stands in sample i ([Compound clips and template instances](#compound-clips-and-template-instances)).
- Evaluation writes the N samples whether or not they differ, so a frame in which a clip with motion blur draws has one form.

### What a sample moves and what it holds

**A sample moves pose and holds content and membership.** In sample i a clip with `motionBlur` takes its pose at its own instant i ([The exposure of a clip](#the-exposure-of-a-clip)), and a clip without it takes its pose at T.

- **Pose** is a clip's own values and the chain it inherits: its keyframed values with their eases and springs, its animation and a title's unit animation ([FRAMES-14](../FRAMES-14/SPEC.md)), a storyline clip's transition motion and progress for its side, and its masks, opacity, geometry, colours and filter values, a clip area included ([FRAMES-2](../FRAMES-2/SPEC.md)); and, inherited, its parent's transform ([FRAMES-10](../FRAMES-10/SPEC.md)) and its track matte, the values of its matte clip ([FRAMES-11](../FRAMES-11/SPEC.md)), each with the chain that clip inherits in turn.
- **Content** is what a clip shows: its media frames, the grain seed, and its tracked motion, which is a fact about the media frame it was followed on. Content is that of T.
- **Membership** is which clips draw and their order in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)), the storyline clips a transition holds included. Membership is decided at T.

**The chain is taken stage by stage, each stage by its own switch.** A clip's pose in sample i is its own values, at its instant i where it has `motionBlur` and at T where it has not, carried by each stage it inherits, a parent's transform or a matte clip's values, at the clip's instant i where that stage's clip has `motionBlur` and at T where it has not. That is what "pose and the chain it inherits" means: the switch is read on the clip whose value moves, so a parent's motion blurs its child only when the parent has the switch, and a child's own motion only when the child has it.

- A title with `motionBlur` slides, and a bar without it is parented to the title: in each sample the bar's own values are at T and the title's transform carries it at the instant, so the bar moves with the title, the two blur as one picture, and no seam opens between them.
- A title without `motionBlur` slides, and a bar with it, parented to the title, grows by keyframes of its own `width`: the title's transform is at T in every sample, so the bar is blurred by its growth alone and stays sharp along the title's motion, as the title does.

**So blends, track mattes, parents, transitions and adjustment clips need no rule of their own**: each acts inside each sample as it always acts, on the poses of that sample. Every case follows:

- A media frame is the one the clip's media time at T picks, through its time map with its `timeRemap` and handles ([FRAMES-3](../FRAMES-3/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md)). A transition matte's `frame` is content, picked at the transition's progress at T, and its `progress` is pose. So footage is never exposed twice, as After Effects blurs the motion a layer is given and not the motion inside its footage.
- A tracked motion, the clip's own and its parent's, is the motion of the media frame its tracked media shows at T ([FRAMES-12](../FRAMES-12/SPEC.md)), so it adds no blur inside a frame. A clip's keyframes over a tracked target are pose: brought back through the motion at their own times as before, interpolated at the clip's instant, and carried by the motion of the frame at T.
- Every `grain` op takes the seed of the output frame, in every sample ([FRAMES-20](../FRAMES-20/SPEC.md#what-evaluation-has-done)).
- A clip that is not visible at T draws in no sample, and one that is visible at T draws in every sample. A transition cover, which no clip draws, has no pose and stands as at T.
- **A push.** With both sides on, each sample holds both storyline pictures moved by the transition at the same instant, meeting at the seam with no gap, so the frame is as opaque along the seam as each picture. With one side on, that side moves over the exposure and the other stands at T, so along the seam what lies below the storyline shows through on the side that moves, over half the length its blur spreads: a push whose two sides should blur as one turns the switch on for both.

### The exposure of a clip

A frame's instant T is k / fps for frame k of `render` ([FRAMES-21](../FRAMES-21/SPEC.md)), and the time asked for by `still`, `sheet`, `evaluate`, `locate` and a PNG ([FRAMES-23](../FRAMES-23/SPEC.md)). With A the shutter angle, P the shutter phase, N the samples per frame and fps the frame rate, all of the outermost sequence, the frame's exposure is the interval from T + P × d to T + (P + A) × d, with d = 1 / (360 × fps) seconds per degree of shutter.

**Each clip's exposure is cut to where its pose is continuous around T.** A clip's cut is the largest interval that holds T, lies inside the frame's exposure and inside the clip's window ([FRAMES-8](../FRAMES-8/SPEC.md): a storyline clip's drawn range, any other clip's visible window), and holds no discontinuity of its pose. A pose is discontinuous only at the end of a span eased by `step` ([FRAMES-4](../FRAMES-4/SPEC.md)), a keyframe's or a preset span's, of a value that moves in the samples: one of the clip's own values where it has `motionBlur`, or a value of a stage of its chain whose clip has it. A step span jumps at its end and takes the new value there, so the cut starts at the last such end at or before T and stops at the first after it. Each of these is an instant the resolved document writes or a span's keys give, so the cut is found in closed form, with no root to find. A stage outside its clip's window holds the values at the window's edge, as a parent does ([FRAMES-10](../FRAMES-10/SPEC.md)), so it cuts nothing.

With lo and hi the ends of the cut, the clip's instants are the midpoints of N equal parts of it, each weighing 1 / N, as a shutter that is open with the same weight over its whole interval:

```
tᵢ = lo + (hi - lo) × (i + 0.5) / N      for i = 0, 1, ..., N - 1
```

- N is the same for every clip, whatever the length of its cut. Different clips may have different instants in one sample: sample i takes each clip at its own instant i.
- A window `[a, b)` is half open, and a midpoint lies strictly between lo and hi, so no instant is ever the end b of a window. Where the cut leaves only T, lo = hi = T, every instant is T.
- Under the defaults at 25 fps the exposure of frame k runs from T - 0.01 to T + 0.01 seconds, and for a clip cut nowhere t₀ is T - 0.009375.
- **An edit point under a connected title.** At 25 fps under the default shutter, a storyline clip with `motionBlur` starts at 2 after another, and a title with `motionBlur` connected to the first plays on over the edit point. The frame at T = 2 is exposed from 1.99 to 2.01. The outgoing clip is not visible at T and draws in no sample. The incoming clip's cut is [2, 2.01], so its trail is half as long there. The title's cut is the whole exposure, so its trail keeps its length and its centre on T, as on every other frame.
- **A position keyframed with `step`.** A title with `motionBlur` holds its position by `step` from a keyframe at 1 to the next at 1.515, where it jumps. The frame at 1.52 is exposed from 1.51 to 1.53 and the title's cut is [1.515, 1.53], so the frame shows the title at its new place, sharp, and not a double image of both places.

So a cut stays a cut and a jump stays a jump: the clip before a cut is exposed up to its end and not past it, the clip after it, not visible at T, draws nothing on that frame, and a clip visible from 0 shows whole on the first frame. On the first and the last frame of a moving clip its N instants are spread over the part of the exposure it is in, so its trail is shorter there and weighed as evenly as on every other frame.

### The mean

**A frame given as samples is the mean of the pictures of its sample lists.** At each point of the frame, with cᵢ the premultiplied colour and αᵢ the alpha of sample i, each drawn as the frame would be drawn from that list without motion blur, background included:

```
c = (c₀ + c₁ + ... + cₙ₋₁) / N
α = (α₀ + α₁ + ... + αₙ₋₁) / N
```

The mean is a form-free formula: it reads its colours in the form the outermost list's `compositing` names, and averages code values under `encoded` and light under `linear` ([FRAMES-26](../FRAMES-26/SPEC.md#compositing)).

A renderer sums the N pictures in the order of the samples, from a sum of 0, in floating point of 32 bits or more, and divides the sum by N once, so the same samples give the same picture, and the mean of N equal pictures is that picture.

**Note.** A picture held in 16-bit floating point, as the working buffers of `quartz` are, has 11 significant bits. N times such a value, N at most 256, needs at most 19, which a 32-bit float holds exactly, and so does every partial sum of equal values, so the sum of N equal pictures divided by N gives each value back exactly.

### Adjustment clips

An adjustment clip takes `motionBlur` like any clip: its pose (its reveal, mask, track matte, opacity, animation and filter values) moves, and in each sample it filters what is below it in that sample ([FRAMES-11](../FRAMES-11/SPEC.md)). An adjustment over clips with motion blur therefore gives the mean of the filtered samples.

**Note.** For a filter that is linear in its picture, as a `blur`, the mean of the filtered samples is the filter of the mean. For one that is not, it differs where the samples differ, at blurred edges. A `bloom` over a bright title that moves fast glows along its whole trail, since each sharp picture of the title is bright, where a bloom of the blurred title would glow less, its trail dimmer than the title. A `lut` or `levels` over a blurred edge maps each sharp edge and then averages them, so a high contrast look leaves the trail soft where grading the blurred picture would harden it.

### Compound clips and template instances

A compound clip or a template instance C shown on a frame of instant T is evaluated at m(T), where m maps the time of the sequence that holds C to C's media time by C's time map: its `in`, `speed`, `loop` and `timeRemap` ([FRAMES-8](../FRAMES-8/SPEC.md)), within its `[0, duration)` ([FRAMES-3](../FRAMES-3/SPEC.md)). m(T) is the frame's instant inside C: which of C's clips draw, their media frames and their tracked motion are taken there.

**A nested sequence decomposes by the same rule.** C's picture in sample i is its nested list in which each clip inside C takes its pose by the rule above, a clip with `motionBlur` at its instant i inside C and a clip without it at m(T), with the content and membership of m(T). C's own item takes C's pose in sample i. So motion composes as trajectories, as it does under a parent.

**C carries the exposure in through its time map.** What C passes to its clips is the part of its exposure (the frame's, or the one its holder passes to it) that holds T, lies inside C's window, and on which the time map is continuous: a loop seam cuts it, and so does the end of a `timeRemap` span eased by `step`. A loop's map is a line, so its seam is found in closed form. A nested time past the ends of `[0, duration)` is clamped as [FRAMES-3](../FRAMES-3/SPEC.md) clamps media time, a held picture, and does not cut. With lo and hi the ends of that part, the exposure inside C runs from m(lo) to m(hi), widened to hold m(T) where the map turns back inside it. Each clip inside C is cut in it around m(T) as [The exposure of a clip](#the-exposure-of-a-clip) cuts in the outermost sequence, against its window and the step ends of its pose, which C's resolved sequence writes in C's time, and its instants are the midpoints of N equal parts of its cut, in order from the end of m(lo). Through compound clips nested in compound clips each map applies in turn, from the outermost sequence in. So one shutter is the camera of the whole output, and the shutter of C's own format plays no part.

- Under `speed` s the exposure inside C is s times as long, so a clip inside C is blurred by the motion it shows on the output, and under a map that is a line, the instants inside C are the outer instants carried through it.
- Where `timeRemap` holds a frame over the exposure, m(lo) = m(hi) = m(T), every instant inside C is m(T), and C's clips stand still, as a held frame shows no motion.
- Where `timeRemap` plays backwards, the instants inside C decrease with i.
- Where an eased `timeRemap` ramps the speed, the exposure inside C spans the media times the map reaches at the ends of the outer one, and its instants are spaced evenly over them.
- Where a `loop` repeats C inside the exposure, the seam cuts it, and the clips inside C are exposed on the side of the seam that holds T.

With C sliding right at v pixels a second, a clip X inside it sliding left at v in C's frame, C at speed 1 and every window over the whole exposure:

- **Both on.** Sample i takes C and X at the same instant, so X's place on the output is the same in every sample: X is sharp, and what else C shows blurs with C.
- **C on, X off.** X stands at m(T) inside C in every sample and C carries it, so X is smeared by C's motion, the motion C's switch exposes.
- **C off, X on.** C stands at T, and X is blurred by its own motion inside C.

### Roles

- The renderer draws a frame given as samples by the mean above ([FRAMES-21](../FRAMES-21/SPEC.md)). A renderer that lacks it refuses before it starts, naming the first frame that holds samples, as for any item it lacks.
- `evaluate` and `locate` report the frame as at T: every pose at T, the list the frame would have without motion blur. For an item of a clip whose pose moves over the exposure, `bounds` is the union of its bounds over the samples, and `locate` gives one hit per item ([FRAMES-23](../FRAMES-23/SPEC.md)).
- The decoder is asked for the media frames of T only, the same in every sample. The mixer and the mix plan are unchanged: motion blur acts on pictures only ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)). The encoder is unchanged.

## Interactions

The keys are in the tables of [FRAMES-7](../FRAMES-7/SPEC.md), the format is [FRAMES-9](../FRAMES-9/SPEC.md), and what a compound clip's format applies is [FRAMES-3](../FRAMES-3/SPEC.md). Windows, drawn ranges, clip time and time maps are [FRAMES-8](../FRAMES-8/SPEC.md), `step` and the other eases [FRAMES-4](../FRAMES-4/SPEC.md), parents [FRAMES-10](../FRAMES-10/SPEC.md), track mattes and adjustment clips [FRAMES-11](../FRAMES-11/SPEC.md), tracked motion [FRAMES-12](../FRAMES-12/SPEC.md), animations, units and transitions [FRAMES-14](../FRAMES-14/SPEC.md). The resolved document writes the shutter and every clip's `motionBlur` ([FRAMES-19](../FRAMES-19/SPEC.md)). The samples and their JSON form are the display list's ([FRAMES-20](../FRAMES-20/SPEC.md)), the renderer draws their mean ([FRAMES-21](../FRAMES-21/SPEC.md)), `evaluate` and `locate` report the frame ([FRAMES-23](../FRAMES-23/SPEC.md)), and the checks are in [FRAMES-24](../FRAMES-24/SPEC.md). The mean is a form-free formula of [FRAMES-26](../FRAMES-26/SPEC.md#compositing).

## Alternatives considered

Every output frame drawn N times with every value at each instant, averaged in the render loop: every clip would blur, a static title over moving footage among them, footage would be exposed across two of its frames, and nothing could turn it off for one clip. Holding content and membership at T and moving only the poses of clips with the switch keeps the exposure of the whole frame and blurs what the editor asks for.

A mean per clip, composited once onto what is below it: two opaque pictures that move together, both sides of a push or a title and its bar, would each be partly transparent along their shared edge, and where each covers half the samples a quarter of what is below would show through the seam.

Runs of clips next to each other in the stack exposed together, each run's mean composited once: the run is a fact of the list, not of the edit, so a sharp logo between a title and its bar would split them and open the seam again, and a run's shared cut would shorten a title's trail at every edit point of the storyline below it.

Adjustment clips after the shutter, filtering the mean of what is below them: it needs a rule for where the shutter sits against each adjustment, an adjustment's own motion would have no exposure, and inside a nested sequence, whose picture is already one of N samples, the rule could not be followed.

The switch read on the drawn clip for its whole chain, as After Effects reads it: a bar without the switch under a title with it would stand at T while the title moves in each sample, so the two would part along their edge, and a parent's motion would blur its child by the child's switch, one switch deciding for a value it does not own.

A shutter angle on each clip, as Premiere Pro's Transform effect has: two exposures in one frame, which no camera gives, and After Effects keeps one shutter for a composition.

An adaptive count, more samples where a clip moves further, as After Effects' Adaptive Sample Limit chooses for 2D layers: it depends on a measure of motion that every implementation would have to compute alike, and a document that needs more samples raises `samplesPerFrame`.

The samples as N items of the clip at opacity 1 / N: source-over at partial alpha is not a mean, since each item composites over the ones below it and weighs them by 1 - αs, and the clip's blend would apply N times.

Media frames picked at each instant: footage at the sequence's rate would be exposed twice where an instant crosses into the next media frame, and a still shot would ghost, against the rule After Effects keeps that motion inside a layer is not blurred. Blurring the motion inside footage is optical flow, a different topic (README).

Tracked motion taken at each instant, between the tracked frames: a track is known only on the frames it was followed on, so the motion between two of them would be an interpolation the tracker never measured, and the clip would blur on its own while the footage it sits on, held at T, does not move.

Samples at the ends of the exposure, t₀ at its opening and tₙ₋₁ at its closing: two of the N weights would fall on the edges of the interval, and under a shutter of 360 the instant between two frames would be exposed in both of them.

Instants outside the window dropped: a moving clip would fade in over its first frame and out over its last, each cut would become a dissolve one frame long, and a clip visible from 0 would not show whole on the first frame ([FRAMES-24](../FRAMES-24/SPEC.md)).

Instants clamped into the window: on the first frame of a clip the instants before its start pile up on it, so its starting pose is stamped with up to half the weight, and a fading entrance shows almost transparent. Cutting the exposure keeps the cut and spreads every instant evenly.

A `step` span averaged as any other: a jump would show both places at once, a one-frame dissolve, and a blink of opacity would show at half. A `step` end is a jump the editor wrote, so it cuts the exposure as an edit point does.

The instants inside a compound clip carried one by one through its time map: under a map that is a line they are the same instants, and under an eased `timeRemap` the cut at a window or a `step` end inside it would need the ease inverted, a root to find to a precision no rule names, and a spring can cross a time several times.

A shutter phase from -360 to 360: an exposure that does not hold T would show content and membership decided at an instant the shutter never saw. A phase from -`shutterAngle` to 0 keeps T inside every exposure, and covers the leading, centred and trailing shutters.

Equal samples written as one list by evaluation: the comparison needs the N lists built anyway, so it saves only rasters, which a renderer saves by the same comparison, and the display list and the `evaluate` output would switch form on a float comparison. Evaluation writes one form, and the saving is the renderer's.

Adjustment clips kept without `motionBlur`: an adjustment has a pose, a sliding mask or a fading opacity, and an adjustment that follows a blurred picture would cut a sharp edge through its blur.

`evaluate` reporting each sample's items at their opacity divided by N, and `locate` an item once for each sample: the opacity is neither the item's nor the weight it shows with where samples overlap, and an agent asking where a title is would have to merge N boxes.

A compound clip's own `format.motionBlur` applied to its inner clips: two shutters in one output, and a template would blur differently in hosts of different rates. The outermost shutter carried through the time map is the camera of the output, as a compound clip's `colorSpace` gives way to the outermost sequence's ([FRAMES-26](../FRAMES-26/SPEC.md#sequence-colour-space)).

## Notes

**Note.** What a renderer may save, each exact since it gives the same picture: samples whose lists are equal are drawn once; the items that are the same in every sample from the bottom of the list up, a common prefix, are drawn once, and each sample goes on from that picture; and a nested list that is the same in several samples is rastered once. Evaluation writes every sample either way.

**Note.** A frame with motion blur is N pictures of the whole frame, and its JSON form holds N lists of its items. With the savings above, a frame whose moving clips lie near the top of the stack draws its sharp lower part once. The time per frame against the same frame without motion blur, at 1080p and 4K and at 16 and 64 samples, is not yet measured.

**Note.** N samples show a fast move as N copies, steps of v × A / (360 × fps × N) pixels for a clip moving v pixels a second. Under the defaults at 25 fps a clip moving 1600 pixels a second, 64 a frame, shows steps of 2 pixels, which read as a smooth blur, and one moving 10000 pixels a second shows steps of 12.5, which read as echoes. Raising `samplesPerFrame` makes the steps smaller at the cost of the time per frame.

**Note.** The order of the sum is fixed because a float sum depends on it: the same 64 pictures summed in another order differed in a few values in a million by one unit in the last place. Summed in order in 32-bit floats and rounded to nearest into 16-bit floats, the mean of N equal pictures came back exactly for N of 2, 3, 16, 64 and 256, and the mean of pictures that differ lay within one unit in the last place of the exact mean. A sum carried in 16-bit floats goes wrong from N of 64, and an addition that clamps to 0 and 1 loses the extended range ([FRAMES-26](../FRAMES-26/SPEC.md)).
