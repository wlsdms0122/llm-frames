# FRAMES-29: Motion blur

Status: draft

## Summary

How a frame shows the motion frames gives its clips during the frame's exposure, as After Effects' Motion Blur switch does: `format.motionBlur`, the sequence's shutter (`shutterAngle`, `shutterPhase` and `samplesPerFrame`), and a clip's `motionBlur`; an output frame as the mean of N pictures of the whole frame, each at one instant of the exposure; what a sample moves (pose) and holds (content and membership); clocks; the owner whose switch moves a value; the clamp at jumps; and what the renderer and the `evaluate` and `locate` commands do with such a frame.

## Motivation

A keyframed move that a camera would smear is drawn today as a sharp picture that jumps from one place to the next: a title that slides 80 pixels a frame at 24 fps strobes, and a push made with a transition's motion stutters. After Effects blurs the motion of every layer whose switch is on, with one shutter for its composition, Fusion blurs per node, and Premiere Pro blurs the motion of its Transform effect. Without motion blur in frames, the nearest an extension can come is a compound clip that holds N copies of the clip with shifted keyframes at falling opacities, and that fails twice. Source-over at partial alpha is not a mean: co = αs × Cs + (1 - αs) × co weighs each later copy by its alpha. And every copy would need its animation spans, its transition, its parent's motion, its tracked motion and its unit animations shifted in time, which is evaluation itself. Two people writing it would choose different instants, weights and holds, and footage in the copies would be exposed several times over. So the instants of a frame's exposure, what moves between them, and their mean are frames's.

## Rules

**An output frame is an exposure of the whole picture, the mean of N samples. Sample i is one instant of the exposure, the same for the whole frame and carried by clocks to every depth. In it, every parameter of a pose that a clip with `motionBlur` owns is read at that instant, clamped to T's side of every jump written on it, and every other is read at T.**

### The shutter

`format.motionBlur` is the sequence's shutter: an object `{shutterAngle, shutterPhase, samplesPerFrame}`, each key optional.

| Key | Value | Default | Meaning |
| --- | --- | --- | --- |
| `shutterAngle` | degrees, a number above 0 and at most 720 | 180 | how long the shutter is open, A / 360 of a frame: 360 is a whole frame and 720 two |
| `shutterPhase` | degrees, a number from -`shutterAngle` to 0 | 0 | when the shutter opens, P / 360 of a frame before the frame's instant, so the exposure always holds the instant: 0 opens the shutter at it, and -`shutterAngle` closes the shutter at it |
| `samplesPerFrame` | a whole number from 2 to 256 | 16 | N, how many pictures of the frame its exposure is the mean of |

- A value outside its range, a value of another type and a `samplesPerFrame` that is not a whole number stop at `check`. The range of `shutterPhase` is read against the angle in effect, so a phase of -200 under the default angle of 180 stops. A format without `motionBlur`, or with some of its keys left out, takes the defaults for what it leaves out.
- The default phase is 0 because frame k is the interval `[k / fps, (k + 1) / fps)` ([FRAMES-20](../FRAMES-20/SPEC.md#what-evaluation-has-done)). At a phase of 0 and an angle of at most 360 the exposure lies inside the frame's own interval, so an edit on a frame boundary cuts no exposure, frame 0 reads no time before 0, and T's pose, which the `evaluate` and `locate` commands report, lies at the start of the trail, on the side of the first instant. A camera's shutter also opens at the frame's start.
- The shutter is static: it takes no keyframes, and it is the same for every frame and every clip of the output.
- A compound clip's or a template instance's `format.motionBlur` applies only when it is rendered alone, as its `fps` does ([FRAMES-3](../FRAMES-3/SPEC.md)). Inside another sequence the key is allowed and has no effect, and the outermost sequence's shutter is the shutter of every clip it shows, the clips inside its compound clips and template instances included ([Compound clips and template instances](#compound-clips-and-template-instances)).

A clip's `motionBlur` is `true` or `false`, and `false` by default. It is taken by every storyline clip (timed media, still and solid) and by every clip with a picture: a title, a shape, a visual media clip, a still media clip and an adjustment clip ([FRAMES-7](../FRAMES-7/SPEC.md)).

- It is a boolean, so it is static ([FRAMES-4](../FRAMES-4/SPEC.md)), and a keyframe that writes it stops.
- On an audio clip it is an unknown key and stops at `check`, since an audio clip draws nothing.
- A theme's `defaults` and a style do not set it, as they do not set `blend` ([FRAMES-22](../FRAMES-22/SPEC.md)).
- It moves the values the clip owns, wherever they are read ([A value and its owner](#a-value-and-its-owner)).

### The instants

A frame's instant T is k / fps for frame k of `render` ([FRAMES-21](../FRAMES-21/SPEC.md)), and the time asked for by `still`, `sheet`, `evaluate`, `locate` and a PNG ([FRAMES-23](../FRAMES-23/SPEC.md)). With A the shutter angle, P the shutter phase, N the samples per frame and fps the frame rate, all of the outermost sequence, the frame's exposure is the interval from T + P × d to T + (P + A) × d, with d = 1 / (360 × fps) seconds per degree of shutter. Its N instants are the midpoints of N equal parts of it, each weighing 1 / N, as a shutter that is open with the same weight over its whole interval:

```
tᵢ = T + (P + A × (i + 0.5) / N) × d      for i = 0, 1, ..., N - 1
```

- The instants are the frame's, the same for every clip at any depth of nesting: sample i is the frame at tᵢ.
- Under the defaults at 25 fps the exposure of frame k runs from T to T + 0.02 seconds, and t₀ is T + 0.000625.

### The samples

**When a clip with `motionBlur` owns a value that the frame at T reads, the frame's display list holds N sample lists** ([FRAMES-20](../FRAMES-20/SPEC.md)). The frame reads the values of every clip that draws at T, at any depth of nesting, and of every parent, matte clip and clip named by a clip area or point of a clip whose values it reads. Sample i is a whole list of the frame at tᵢ: every clip that draws at T, in its order, with its blend, masks, track matte, adjustments and nested lists as usual. The frame is the mean of the pictures of its samples ([The mean](#the-mean)). Otherwise the frame is one list, as without motion blur.

- Only the outermost list of a frame holds samples, and a nested list never does: a compound clip's picture in sample i is its nested list as it stands at tᵢ ([Compound clips and template instances](#compound-clips-and-template-instances)).
- Evaluation writes the N samples whether or not they differ, so such a frame has one form.
- The samples of one frame hold the same items in the same order and differ only in the fields the item tables of [FRAMES-20](../FRAMES-20/SPEC.md) mark as moving, since content and membership are those of T in each, and a list read back is checked for it ([FRAMES-20](../FRAMES-20/SPEC.md#json-form)).

### What a sample moves and what it holds

**A sample moves pose and holds content and membership, and clocks carry its instant.**

- **Pose** is what a clip's parameters that take time move: its keyframed properties at their times, an animation's and a title's unit animation's progress ([FRAMES-14](../FRAMES-14/SPEC.md)), and a transition's progress with the motion, cover opacity and matte progress it drives, and through them transform, masks, opacity, geometry, colours, filter values and clip areas ([FRAMES-2](../FRAMES-2/SPEC.md)).
- **A clock** carries an instant to the time something is read at: a clip's `in`, `speed`, `loop` and `timeRemap` ([FRAMES-8](../FRAMES-8/SPEC.md)), and the clip time a connected clip rides on its storyline clip. A clock always carries the instant, and what is read at its end follows its own kind: media content is as at T, and a nested sequence's values follow their owners' switches ([Compound clips and template instances](#compound-clips-and-template-instances)).
- **Content** is what a clip shows from its media: its media frames, the grain seed, and its tracked motion, which is a fact about the media frame it was followed on. Content is that of T.
- **Membership** is which clips draw and their order in the stack ([FRAMES-9](../FRAMES-9/SPEC.md)), the storyline clips a transition holds and whether a matte clip gives its track matte ([FRAMES-11](../FRAMES-11/SPEC.md)) included. Membership is decided at T, and so is whether an item of the frame or a field of an item is there: by which clips draw and what the document writes, never by a value, so only values follow the instant. A clip that draws at T gives its items in every sample, an item a value collapses drawing nothing in the samples it is collapsed in, as a shape whose plane a scale of 0 flattens, and a stroke or a border the document writes is written in every sample with its width, 0 included, and a dash with its lengths, all 0 included ([FRAMES-20](../FRAMES-20/SPEC.md#items)). A clip that does not draw at T gives no item in any sample.

### A value and its owner

**A value has one owner, and the owner's switch decides.** Every parameter of a pose belongs to the clip it is written on. In sample i it is read at tᵢ where its owner has `motionBlur`, and at T where it has not. This is a definition, wherever the value is read:

- A parent's transform is the parent's ([FRAMES-10](../FRAMES-10/SPEC.md)), so a child rides a parent with the switch whatever its own switch, and its own values move by its own.
- A clip area or a point that names another clip is read from that clip's values, each by its owner's switch ([FRAMES-2](../FRAMES-2/SPEC.md)).
- A track matte's values are its matte clip's ([FRAMES-11](../FRAMES-11/SPEC.md)).
- A transition's progress belongs to the clip that brings it in ([FRAMES-8](../FRAMES-8/SPEC.md)), and it holds 0 before the transition and 1 after it. So both sides of a push move by one progress in every sample and meet at the seam on every frame, the first and the last included. The outgoing clip's switch moves its own values and does not blur a transition another clip brings in.

A title with `motionBlur` slides, and a bar without it is parented to the title or placed by `area: {"clip": "title"}`: in each sample the title's position is at tᵢ, so the bar moves with the title and the two blur as one picture. With the switches the other way round, and the bar growing by keyframes of its own `width`, the bar is blurred by its growth alone and stays sharp along the title's motion, as the title does.

**So blends, track mattes, parents, transitions and adjustment clips need no rule of their own**: each acts inside each sample as it always acts, on the values of that sample. What a sample holds follows:

- A media frame is the one the clip's media time at T picks, through its clock with its `timeRemap` and handles ([FRAMES-3](../FRAMES-3/SPEC.md), [FRAMES-8](../FRAMES-8/SPEC.md)). A transition matte's and a cover's media frame are picked at the transition's progress at T. So footage is never exposed twice, as After Effects blurs the motion a layer is given and not the motion inside its footage.
- A tracked motion, the clip's own and its parent's, is the motion of the media frame its tracked media shows at T ([FRAMES-12](../FRAMES-12/SPEC.md)), so it adds no blur inside a frame. A clip's keyframes over a tracked target are pose: brought back through the motion at their own times as before, interpolated at the sample's instant, and carried by the motion of the frame at T.
- Every `grain` op takes the seed of the output frame, in every sample ([FRAMES-20](../FRAMES-20/SPEC.md#what-evaluation-has-done)).
- A clip draws in every sample where it is visible at T, and in none where it is not.

### Jumps

**Every parameter that takes time is read at the instant clamped to T's side of every jump written on it, and the value at a jump is the limit from T's side.** The parameters that take time are a keyframed property's time, an animation's progress, a transition's progress and a clock's input, and T's side of a jump is the side T's own value is read on. Terms combine after that, as [FRAMES-14](../FRAMES-14/SPEC.md) combines them at T, so a keyframed slide under a looped animation keeps moving whatever the animation does. A jump is what the document writes as one:

- the end of a span eased by `step` ([FRAMES-4](../FRAMES-4/SPEC.md)), a keyframe span's or a preset span's,
- two keys that name one property at the same `t` of a span ([FRAMES-14](../FRAMES-14/SPEC.md)),
- the ends of the owner's window ([FRAMES-8](../FRAMES-8/SPEC.md): a storyline clip's drawn range, any other clip's visible window), so a clip stands at its first pose before its window and at its last after it, as a parent does ([FRAMES-10](../FRAMES-10/SPEC.md)).

The clamp is taken in the parameter's own terms, with nothing inverted: a `step` end or a window end on the clock the parameter is written on, and two keys at one `t` on the span's eased progress, so under an ease that leaves 0 to 1 (`back-out`, a spring with bounce) an instant is clamped, to T's key's line at `t`, only while its eased progress lies past `t` from T's.

- **A position keyframed with `step`.** At 25 fps under the default shutter, a title with `motionBlur` holds its position by `step` from a keyframe at 1 to the next at 1.53, where it jumps. The frame at 1.52 is exposed from 1.52 to 1.54 and T is before the jump, so its instants after 1.53 take the position just before it: that frame shows the title sharp at its old place and the next at its new one, never both.
- **An edit point under a connected title.** At 25 fps under the default shutter, a storyline clip with `motionBlur` starts at 2 after another, and a title with `motionBlur` connected to the first plays on over the edit point. The frame at 2 is exposed from 2 to 2.02, inside the incoming clip's window, and the frame at 1.96 from 1.96 to 1.98, inside the outgoing clip's, so each clip moves over its whole exposure: a cut stays a cut.

**Note.** A loop seam, of a looped animation or of a looped clock, and the instant one of a clip's animations hands over to the next are not jumps: the curve is read at the instant as it is. Where one or more of them lie between T and the instant, the clamp still runs from T to the instant: the jumps of every span and loop period on the way count, each over the part of it the way crosses, and the first jump met gives the limit from T's side. So a loop made to meet itself (a spinner, a ticker, a looped background) blurs through its seam, and one that does not meet itself shows both of its ends in the one frame that holds the seam, as it is written.

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

An adjustment clip takes `motionBlur` like any clip: the values it owns (its reveal, mask, opacity, animation and filter values) move, and in each sample it filters what is below it in that sample ([FRAMES-11](../FRAMES-11/SPEC.md)). An adjustment over clips with motion blur therefore gives the mean of the filtered samples.

**Note.** For a filter that is linear in its picture, as a `blur`, the mean of the filtered samples is the filter of the mean. For one that is not, it differs where the samples differ, at blurred edges. A `bloom` over a bright title that moves fast glows along its whole trail, since each sharp picture of it is bright, where a bloom of the blurred title would glow less. A `lut` or `levels` over a blurred edge maps each sharp edge and then averages them, so a high contrast look leaves the trail soft where grading the blurred picture would harden it.

### Compound clips and template instances

A compound clip or a template instance C shown on a frame of instant T is evaluated at m(T), where m is C's clock, its `in`, `speed`, `loop` and `timeRemap` ([FRAMES-8](../FRAMES-8/SPEC.md)), carrying the time of the sequence that holds C to C's nested time, clamped into `[0, duration)` as [FRAMES-3](../FRAMES-3/SPEC.md) clamps a compound clip's time. m(T) is the frame's instant inside C: which of C's clips draw, their media frames and their tracked motion are taken there.

**Nested time is carried per instant.** In sample i C's nested time is m(tᵢ), whatever C's switch, its input clamped to T's side of the jumps written on it (a `step` end or two keys at one `t` of its `timeRemap`, and C's window ends). Inside C every parameter is read by the same rule with m(T) as T: at m(tᵢ) where its owner has `motionBlur`, and at m(T) where it has not. C's own item takes C's pose by C's own switch. Through nested compound clips each clock applies in turn, from the outermost in. So motion composes as trajectories under any map, an eased one included, the outermost sequence's shutter exposes the whole output with the same weight on each of its instants, and the shutter of C's own format plays no part.

- Under `speed` s the nested time moves s times as fast, so a clip inside C is blurred by the motion it shows on the output.
- Where `timeRemap` holds a frame over the exposure, every nested time is m(T), and C's clips stand still, as a held frame shows no motion.
- Where `timeRemap` plays backwards or ramps, the nested times follow it instant by instant, and where it turns back inside the exposure, the nested times it passes twice are read twice, as a shutter sees them.

With C sliding right at v pixels a second, a clip X inside it sliding left at v in C's frame, C at speed 1 and every window over the whole exposure:

- **Both on.** Sample i reads C at tᵢ and X at m(tᵢ), the same instant, so X's place on the output is the same in every sample: X is sharp, and what else C shows blurs with C.
- **C on, X off.** X stands at m(T) inside C in every sample and C carries it, so X is smeared by C's motion, the motion C's switch exposes.
- **C off, X on.** C stands as at T in every sample, and its clock still carries each instant, so X is read at m(tᵢ) and blurs by its own motion inside C, and what else C shows is sharp: a clip's switch blurs its motion wherever the clip sits.

### Roles

- The renderer draws a frame given as samples by the mean above ([FRAMES-21](../FRAMES-21/SPEC.md)). A renderer that lacks it refuses before it starts, naming the first frame that holds samples, as for any item it lacks.
- The `evaluate` and `locate` commands report the frame as at T ([FRAMES-23](../FRAMES-23/SPEC.md)): the list the frame would have without motion blur, every field at T, `bounds` included, and `locate` tests each item's shape as it is at T. Neither takes a union over the samples.
- The decoder is asked for the media frames of T only, the same in every sample. A page of a PDF ([FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages)) is the page of T in every sample, and is asked for by the region and scale each sample list shows it at ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)): samples whose region and scale agree read one picture of it, and where a blurred zoom makes the scale differ between samples, each sample asks for its own. The mixer and the mix plan are unchanged: motion blur acts on pictures only ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)). The encoder is unchanged.

## Interactions

The keys are in the tables of [FRAMES-7](../FRAMES-7/SPEC.md), the format is [FRAMES-9](../FRAMES-9/SPEC.md), and what a compound clip's format applies is [FRAMES-3](../FRAMES-3/SPEC.md). Windows, drawn ranges, clip time and time maps are [FRAMES-8](../FRAMES-8/SPEC.md), `step` and the other eases [FRAMES-4](../FRAMES-4/SPEC.md), parents [FRAMES-10](../FRAMES-10/SPEC.md), track mattes and adjustment clips [FRAMES-11](../FRAMES-11/SPEC.md), tracked motion [FRAMES-12](../FRAMES-12/SPEC.md), animations, units and transitions [FRAMES-14](../FRAMES-14/SPEC.md). The resolved document writes the shutter and every clip's `motionBlur` ([FRAMES-19](../FRAMES-19/SPEC.md)). The samples, their JSON form and the fields that may move between them are the display list's ([FRAMES-20](../FRAMES-20/SPEC.md)), the renderer draws their mean ([FRAMES-21](../FRAMES-21/SPEC.md)), the `evaluate` and `locate` commands report the frame ([FRAMES-23](../FRAMES-23/SPEC.md)), and the checks are in [FRAMES-24](../FRAMES-24/SPEC.md). The mean is a form-free formula of [FRAMES-26](../FRAMES-26/SPEC.md#compositing).

## Alternatives considered

Every output frame drawn N times with every value at each instant, averaged in the render loop: every clip would blur, a static title over moving footage among them, footage would be exposed across two of its frames, and nothing could turn it off for one clip. Holding content and membership at T and moving only the poses of clips with the switch keeps the exposure of the whole frame and blurs what the editor asks for.

A mean per clip, composited once onto what is below it: two opaque pictures that move together, both sides of a push or a title and its bar, would each be partly transparent along their shared edge, and where each covers half the samples a quarter of what is below would show through the seam.

Runs of clips next to each other in the stack exposed together, each run's mean composited once: the run is a fact of the list, not of the edit, so a sharp logo between a title and its bar would split them and open the seam again.

Adjustment clips after the shutter, filtering the mean of what is below them: it needs a rule for where the shutter sits against each adjustment, an adjustment's own motion would have no exposure, and inside a nested sequence, whose picture is already one of N samples, the rule could not be followed.

Per-clip cuts of the exposure, each clip's instants spread over the part where its own pose is continuous: clips that move together stopped sharing an instant, so a child stood ahead of its parent on its first frame, and a push parted at the seam on its first and last.

A switch read on the clip that draws, for every value it takes from other clips: a parent's motion would blur its child only by the child's switch, a switch deciding for a value it does not own.

A shutter angle on each clip, as Premiere Pro's Transform effect has: two exposures in one frame, which no camera gives, and After Effects keeps one shutter for a composition.

An adaptive count, more samples where a clip moves further, as After Effects' Adaptive Sample Limit chooses for 2D layers: it depends on a measure of motion that every implementation would have to compute alike, and a document that needs more samples raises `samplesPerFrame`.

The samples as N items of the clip at opacity 1 / N: source-over at partial alpha is not a mean, since each item composites over the ones below it and weighs them by 1 - αs, and the clip's blend would apply N times.

Media frames picked at each instant: footage at the sequence's rate would be exposed twice where an instant crosses into the next media frame, and a still shot would ghost, against the rule After Effects keeps that motion inside a layer is not blurred. Blurring the motion inside footage is optical flow, a different topic (README).

Tracked motion taken at each instant, between the tracked frames: a track is known only on the frames it was followed on, so the motion between two of them would be an interpolation the tracker never measured, and the clip would blur on its own while the footage it sits on, held at T, does not move.

Samples at the ends of the exposure, t₀ at its opening and tₙ₋₁ at its closing: two of the N weights would fall on the edges of the interval, and under a shutter of 360 the instant between two frames would be exposed in both of them.

Instants outside the window dropped: a clip whose window ends inside a frame's exposure would fade out over that frame, and a cut there would become a dissolve one frame long.

A `step` span averaged as any other: a jump would show both places at once, a one-frame dissolve, and a blink of opacity would show at half. A `step` end is a jump the editor wrote, so each instant is clamped to the side of it that T is on.

Holding at loop seams and animation handovers: a seamless loop would freeze once a period.

Cutting the exposure at jumps found by inverting eases: a jump on a span's eased progress, or under an eased `timeRemap`, lies at the ease's inverse on the sequence clock, a root to find to a precision no rule names, which a spring can cross several times.

A shutter phase from -360 to 360: an exposure that does not hold T would show content and membership decided at an instant the shutter never saw. A phase from -`shutterAngle` to 0 keeps T inside every exposure, and covers the leading, centred and trailing shutters.

A centred exposure by default: half of every frame's exposure would lie in the frame before, so every clip that starts on a frame boundary would stand still for half of its first frame.

Equal samples written as one list by evaluation: the comparison needs the N lists built anyway, so it saves only rasters, which a renderer saves by the same comparison, and the display list and the `evaluate` output would switch form on a float comparison. Evaluation writes one form, and the saving is the renderer's.

Adjustment clips kept without `motionBlur`: an adjustment has a pose, a sliding mask or a fading opacity, and an adjustment that follows a blurred picture would cut a sharp edge through its blur.

The `evaluate` command reporting each sample's items at their opacity divided by N, or `bounds` as their union, and `locate` an item once for each sample: the opacity is neither the item's nor the weight it shows with, a union from the exposure would not match a transform at T, and an agent asking where a title is would have to merge N boxes.

A compound clip's own `format.motionBlur` applied to its inner clips: two shutters in one output, and a template would blur differently in hosts of different rates. The outermost shutter carried through the time map is the camera of the output, as a compound clip's `colorSpace` gives way to the outermost sequence's ([FRAMES-26](../FRAMES-26/SPEC.md#sequence-colour-space)).

## Notes

**Note.** What a renderer may save, each exact since it gives the same picture: samples whose lists are equal are drawn once; the items that are the same in every sample from the bottom of the list up, a common prefix, are drawn once, and each sample goes on from that picture; and a nested list that is the same in several samples is rastered once.

**Note.** Window ends clamp an exposure only where a window starts or ends off a frame boundary, under a phase below 0, or under an angle above 360. A title that slides at 1600 pixels a second and ends at 2.01, at 25 fps under the default shutter, stands at its last place for 8 of the 16 instants of the frame at 2: that frame shows half of it spread over the 16 pixels it moves until 2.01 and half sharp at its last place.

**Note.** A frame with motion blur is N pictures of the whole frame, and its JSON form holds N lists of its items. Measured with `render` built for release on an Apple M1 Pro with 16 GB, over 25 frames of a zooming storyline image, a sliding title under `frames/rise`, a turning rect and a sliding picture in picture clip, all with `motionBlur`, from the start of the command to the written master: at 1080p a frame took 54 ms without motion blur, 440 ms at 16 samples and 1648 ms at 64, and at 4K 180 ms, 1652 ms and 6289 ms. The time grows about as N, since each sample is drawn whole. The display list of that document's frame at 0.5 is 4800 bytes of JSON without motion blur, 80358 at 16 samples and 321383 at 64, at either size.

**Note.** N samples show a fast move as N copies, steps of v × A / (360 × fps × N) pixels for a clip moving v pixels a second. Under the defaults at 25 fps a clip moving 1600 pixels a second, 64 a frame, shows steps of 2 pixels, which read as a smooth blur, and one moving 10000 pixels a second shows steps of 12.5, which read as echoes. Raising `samplesPerFrame` makes the steps smaller at the cost of the time per frame.

**Note.** The order of the sum is fixed because a float sum depends on it: the same 64 pictures summed in another order differed in a few values in a million by one unit in the last place. Summed in order in 32-bit floats and rounded to nearest into 16-bit floats, the mean of N equal pictures came back exactly for N of 2, 3, 16, 64 and 256, and the mean of pictures that differ lay within one unit in the last place of the exact mean. A sum carried in 16-bit floats goes wrong from N of 64, and an addition that clamps to 0 and 1 loses the extended range ([FRAMES-26](../FRAMES-26/SPEC.md)).
