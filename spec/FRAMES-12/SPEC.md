# FRAMES-12: Tracking

Status: accepted

## Summary

`track` makes a clip follow something in a picture from the frame of the media its values are written on. Its value is track data, the target's four corners on each frame of the media a tracker followed it on, as `track` prints it ([FRAMES-23](../FRAMES-23/SPEC.md)) or a tracker outside frames gives it. A similarity motion (move, uniform scale and rotation) is fitted to each frame's corners and carries the clip's geometry as a moving parent, and the homography those corners give carries a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md)).

## Motivation

Things in a shot move. A title pinned to a moving sign, a blur kept on a face while the camera pans, a zoom that stays on a runner, a logo replaced on a turning product: a value written at one instant drifts off its subject as soon as the subject moves, and keyframing it by hand frame by frame is the work a tracker exists to save, as in After Effects and Premiere Pro. Following the target once and carrying every value of the clip through the motion keeps each one on its subject, while the clip's own keyframes still say what it does relative to it. A tracker gives four corners on each frame, and written in the document as track data they stay one value that keeps every rule of the track, where keyframes on every frame would not, and the document says what it shows before any tracker runs again.

## Rules

### What is tracked

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is track data ([Track data](#track-data)), and the media it is followed in, the **tracked media**, is given by how the clip is placed:

- **What `track` follows is how the clip is placed**, not the clip's kind. A clip placed by points written in its parent's space ([FRAMES-10](../FRAMES-10/SPEC.md)), an `area`, a path's `points`, an adjustment clip's `mask` or a `cornerPin` ([FRAMES-27](../FRAMES-27/SPEC.md)), follows its parent's media, and those points are what moves, with a shape's `mask` written in that space. A clip placed by its box, by `position` or `placement` with its `anchor` and `scale` ([FRAMES-1](../FRAMES-1/SPEC.md)), follows inside its own media, and its `crop` and `mask`, written in its own media pixels, are what moves. A clip placed by its box with no frames of its own, a title, a still, a compound clip, or a rect, an ellipse or a null given by `width` and `height`, has nothing inside it to follow, so it follows its parent's media, and its `position`, the one point of it written in its parent's space, is what moves. Only a video or an image sequence has frames to follow, so a parent's media counts only where the parent is a storyline clip or media clip of video or image sequence without a corner pin, since a parent with a corner pin gives its children the space its corner pin is written in and not its media's pixels.
- The rule by kind is its consequence. A storyline clip or media clip of video or image sequence without a corner pin tracks its own media. A title, a shape, an adjustment clip, a null, a still or a compound clip without a corner pin tracks its parent's media. A clip with a corner pin tracks its parent's media whatever its kind, and its own `crop` and `mask` are not followed: they lie flat on its plane and ride its corner pin, as a title's mask rides its transform ([FRAMES-27](../FRAMES-27/SPEC.md#the-key)). A storyline clip with a corner pin has no parent, so `track` on it stops, naming the corner pin, since it is placed by points in the frame, which has no media. `track` stops wherever the media to follow is a parent's and there is none (an unparented title, shape, adjustment, null, still, compound clip or clip with a corner pin, a clip parented to a title, a shape, a null, a still, a compound clip, an adjustment clip or a clip with a corner pin), since there is no picture to follow.
- The quads of track data are in the tracked media's pixels. On a clip that tracks its own media, they are in its own media pixels, as its crop and mask are. On a clip that tracks its parent's media, they are in its parent's space, as its position, area and corner pin are. `timeline` gives every clip's tracked media and the first and last frame of it the clip shows as `tracked` ([FRAMES-23](../FRAMES-23/SPEC.md#a-clips-times-and-spaces)), so track data is written for them without this rule kept again.

**Note.** A clip with video of its own that should follow its parent's picture is parented to a null that tracks it ([FRAMES-11](../FRAMES-11/SPEC.md#null-clips)), as an After Effects layer is parented to a tracked null.

### The track

The static values a tracked clip writes in the tracked media's pixels, its corner pin, area, points or position, or on its own media its crop and mask, are true on one frame of the tracked media, the **track's frame**, a name this spec gives, which track data names by its `time` ([Track data](#track-data)), a media time of the tracked media. The track's motion and homography are the identity there. What the document writes does not depend on where the clip starts, and trimming the clip's head moves nothing.

Each frame of the data gives the target's quadrilateral (quad) on that frame: four points in media pixels, the target's top left, top right, bottom right and bottom left corners in that order, as the target faces on the track's frame. The frames the data names are the frames **followed**, and the **target** is the quad of the track's frame.

- The track is a motion, a function of the tracked media's media time: on each frame, the similarity transform (a move, one uniform scale and one rotation) that takes the target's quad, corners p₁ to p₄, nearest by least squares to its quad on that frame, corners q₁ to q₄ in the same order. With p̄ and q̄ the centroids, pᵢ' = pᵢ - p̄ and qᵢ' = qᵢ - q̄:

  ```
  a = Σ (pᵢ'x qᵢ'x + pᵢ'y qᵢ'y)
  b = Σ (pᵢ'x qᵢ'y - pᵢ'y qᵢ'x)
  θ = atan2(b, a)                       rotation, clockwise positive in y-down pixels
  s = sqrt(a² + b²) / Σ |pᵢ'|²          uniform scale
  M(x) = s R(θ) (x - p̄) + q̄            R(θ) = [[cos θ, -sin θ], [sin θ, cos θ]]
  ```

  On each frame the track also has its **homography**, H(p → q) of [FRAMES-27](../FRAMES-27/SPEC.md#the-homography): the projective map that takes the target's quad exactly to its quad on that frame. The motion and the homography are the identity on the track's frame. The resolved document writes the track as `{media, time, target, frames}`: the tracked media, the timestamp of the track's frame, the target, and every frame followed as `{time, quad, motion}` with the fitted motion written out ([FRAMES-19](../FRAMES-19/SPEC.md)). The homography is not written: it is the closed form of the target's quad and the frame's ([FRAMES-27](../FRAMES-27/SPEC.md#the-homography)), which are, and evaluation computes it from them. At an instant of the clip, the motion is that of the media frame the tracked media shows there, so a hold holds the motion and a reverse plays it back. A clip that follows its parent's media takes the frame its parent's time map gives at the instant, also where the parent itself is not visible.
- The motion acts as a moving parent, between the clip's values and the space they are written in. Every value of the clip's geometry in that space (on its own media: its `crop` and `mask`; on its parent's media: its `position`, `area`, `points`, and for a shape or adjustment its `mask`) is where it is at its own time: a keyframe's value at the keyframe's time, and a static value on the track's frame. Each keyframe is brought back through the inverse of the motion at its time, interpolated there, and carried by the motion on each frame. A static value is not brought back, since the motion is the identity on the track's frame, and the resolved document writes it as a static so that evaluation can tell it from a keyframe at the instant ([FRAMES-19](../FRAMES-19/SPEC.md)). So a rect stays on a moving sign, a title beside a product turns with it, and a zoom keyframed on a crop goes on while the crop follows a runner. A clip's corner pin is the one value carried by the homography in place of the motion, as [FRAMES-27](../FRAMES-27/SPEC.md#a-tracked-corner-pin) says, and the motion stays its moving parent.
- A crop takes the move and the scale of the motion and not its rotation, since a crop is an upright region of its media: it keeps its aspect ratio and stays upright. Every other value takes the whole motion, a path's tangents, which are offsets and not places, by its linear part, its scale and rotation, and a clip with a box of its own turns with it and keeps its size, as under any parent ([FRAMES-10](../FRAMES-10/SPEC.md)). A rectangle (an `area`, a rect or ellipse mask) is brought back by its centre and its size divided by the motion's scale, upright in the space the motion carries, so it turns with the motion as under any parent.
- A tracked clip's keyframes stay at their times on its clip's clock, each brought back through the motion of the frame it shows, and its window is narrowed from its instant ([FRAMES-8](../FRAMES-8/SPEC.md#a-clips-instant), [Where the target is lost](#where-the-target-is-lost)).
- What a tracked motion and its homography are in each sample of a frame with motion blur is [FRAMES-29](../FRAMES-29/SPEC.md#what-a-sample-moves-and-what-it-holds).

### Where the target is lost

- A connected or sequence clip is visible only where its target was followed: from its instant, its window ends, in each direction, at the first instant whose media frame the data does not name, as [FRAMES-8](../FRAMES-8/SPEC.md) narrows any window. Its parent's window does not bound it ([FRAMES-10](../FRAMES-10/SPEC.md)): outside that window a clip that follows its parent's media follows the frames its parent's time map gives there, while its parent's transform holds at the window's edge.
- A connected or sequence clip whose instant shows a media frame that was not followed stops, naming that frame's media time, since its window is narrowed from its instant and would hold none.
- A storyline clip whose target is lost inside its edit range stops, naming the time. In a handle its motion holds the nearest value followed, as a handle past the end of the media holds its edge frame.
- A value of the clip at a time whose media frame was not followed, a keyframe beyond the window or in a handle, is brought back through the motion of the nearest frame followed, the edge of the track in that direction, as a storyline clip's motion holds in a handle. So such a keyframe still shapes the span it begins or ends.

**Note.** Track data is a quad on each frame, which holds perspective, so the data of a tracker that follows perspective drives a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md)). `track` with the `point` tracker gives similarity images of its target, so its homography is its motion, and with the `planar` tracker the image of its target under the homography of the plane it lies on ([FRAMES-21](../FRAMES-21/SPEC.md)).

### Track data

Track data is the value of `track`: an object `{time, frames}`, both keys required and no other key, the object `track` prints without its first key, the version ([FRAMES-23](../FRAMES-23/SPEC.md)). Any other value of `track` stops at `resolve`, naming `...track`.

| Key | Form | Meaning |
| --- | --- | --- |
| `time` | a media time | the track's frame ([The track](#the-track)): that frame's quad in `frames` is the target |
| `frames` | a list of `{time, quad}`, at least one, each key required | every frame followed, in time order: a media time, and the target's quad on that frame, four points `[x, y]` of numbers in media pixels of the tracked media, its top left, top right, bottom right and bottom left corners |

The target is the quad of the frame `time` names, so the motion and the homography are the identity on that frame by construction, and no target is written beside it.

- Its tracked media is the one [What is tracked](#what-is-tracked) gives, resolve fits each frame's motion to its quads as [The track](#the-track) says and pins the resolved track, and windows narrow where the data names no frame ([Where the target is lost](#where-the-target-is-lost)). Resolve calls no tracker.
- **Its conventions are the document's.** A `time` is a media time as [FRAMES-3](../FRAMES-3/SPEC.md) defines it and as `extract`, `ocr` and `track` print it ([FRAMES-23](../FRAMES-23/SPEC.md)): for a video, time 0 is the start of its presentation timeline after its edit list, not its timecode and not its first frame's timestamp, and for an image sequence, frame index / fps, so its first file is at 0 whatever number it carries. A time names the frame of the tracked media whose presentation interval holds it ([FRAMES-3](../FRAMES-3/SPEC.md)), so an outside tracker's times need not match the media's to the microsecond. A quad is in media pixels as [FRAMES-1](../FRAMES-1/SPEC.md) defines them: the picture as displayed, its rotation metadata applied and its pixels made square, origin at its top left, x right and y down, with whole numbers at the corners of pixels. The resolved track writes each frame's `time` as the timestamp of the frame it names, and its `time` and `target` as those of the frame `time` names.
- A clip with a corner pin rides the homography of its quads, so the data of a planar tracker drives a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md#a-tracked-corner-pin)).
- **A written quad that is wrong stops, where a tracker's is a lost frame.** A quad of the data that is not strictly convex, or whose orientation is not that of the quad of the frame `time` names, stops (below), where the same quad from a tracker ends the data `track` prints before it ([FRAMES-23](../FRAMES-23/SPEC.md)). A tracker's quad is a measurement, which can fail on a frame; a written quad is a value, checked as every written value is, and a wrong one is the document's mistake.

Track data stops at `resolve`, naming its place, `...track` or `...track.frames[i]`:

- a key other than `time` and `quad` in a frame, or a missing one;
- a point that is not two finite numbers, or a quad that is not four points;
- a quad that is not strictly convex, or whose orientation is not that of the quad of the frame `time` names ([FRAMES-27](../FRAMES-27/SPEC.md#the-homography));
- a frame whose `time` names no frame of the tracked media, before its first frame or past the end of its last;
- frames out of time order, or two frames that name one media frame;
- a gap: a media frame between the first frame named and the last that no frame names;
- a `time` that names no frame of `frames`, since the data would give no target;
- tracked media that is not a video or an image sequence.

```json
"track": { "time": 2.04,
           "frames": [ { "time": 2, "quad": [ [810, 301], [1130, 350], [1101, 916], [777, 858] ] },
                       { "time": 2.04, "quad": [ [812, 304], [1131, 352], [1102, 918], [779, 861] ] },
                       { "time": 2.08, "quad": [ [815, 306], [1131, 355], [1102, 921], [781, 863] ] } ] }
```

The frames are cut short. The clip's written values are true on media second 2.04, so the quad there is the target, the clip follows it from media second 2 to 2.08, and it is visible where its instants show those frames, wherever it starts among them.

**Note.** A tracker run on a constant rate export of a variable rate file gives the times of the export's frames. Two of them can fall in one presentation interval of the file, which stops as two frames that name one media frame, and an interval that none falls in is a gap. The tracker is run on the file the document names, or its quads are written at the times of that file's frames, which `extract` and `track` print.

## Interactions

The track's frame is the frame track data's `time` names, and a clip's instant is [FRAMES-8](../FRAMES-8/SPEC.md#a-clips-instant). Time maps and windows are [FRAMES-8](../FRAMES-8/SPEC.md). Parenting is [FRAMES-10](../FRAMES-10/SPEC.md), and masks are [FRAMES-11](../FRAMES-11/SPEC.md). Keyframed values interpolate as [FRAMES-4](../FRAMES-4/SPEC.md) says. The resolved document pins the track the data gave ([FRAMES-19](../FRAMES-19/SPEC.md)). The homography and a tracked corner pin are [FRAMES-27](../FRAMES-27/SPEC.md). Track data is the object `track` prints ([FRAMES-23](../FRAMES-23/SPEC.md)) with the tracker provider ([FRAMES-21](../FRAMES-21/SPEC.md)), and a document that asks for a target to be followed is turned into one that writes track data by a tool ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Alternatives considered

Tracking as an area form: an area cannot move a position or keep a crop's zoom apart from its target. Re-acquiring a lost target: a lost target narrows the window instead.

An outside track written as keyframes on a parent, one for each frame, as After Effects' tracker writes them: a crop and a mask that follow their own media cannot be carried by a parent, the keyframes lie on clip time where a hold, a reverse or a `timeRemap` must play the motion by media time, and a lost target would not narrow the window. One fact would be spread over a value for each frame and kept in step by hand. Track data keeps it one value.

Track data that also takes each frame's `motion` and ignores it: a value that does nothing breaks the rule that unknown keys stop, and the fit is resolve's to make.

A track whose frame is always the one the clip's instant shows: a written corner pin would be true only on the frame the clip's start shows through its parent's time map, which its author would work out by hand, and trimming the clip's head would carry the same numbers onto another frame, where the data would move the pin off its screen on every frame. The values are written on a frame of the media, so the track names that frame.

Track data with a `target` beside its `time`: the quad of the frame `time` names is the target already, and a second one would need a rule to agree with it.

A tracked media chosen by the clip's kind: a clip placed by points in its parent's space, as a corner pin is, would follow media its points are not written in.

A clip with a corner pin that also follows its own crop or mask, or stops when it has both: a track follows one picture, so the two would need a compound clip to be split into, while a crop or a mask drawn flat on the plane rides the corner pin as a title's mask rides its transform, and needs no track of its own.

Track data of a rectangle on each frame, with move and scale only: a turning subject would leave its title upright and drifting. Four corners give the rotation, and the same report leaves room for perspective later.

The homography carrying a path's points, or every tracked value: a homography takes a polygon to a polygon, but a cubic Bézier to a rational curve that no path writes, so a curved path would not stay a path. A clip with a corner pin moves apart from a sibling rect on the same track already, and that does not decide it. What stands besides is that every followed value of a clip other than a corner pin is carried by one fit, the similarity, so values written in one space keep the relations they were written with: a path mask's point laid on a rect mask's corner stays on it, where a path carried by the homography beside a rect carried by the similarity would part them. A clip with a corner pin follows its corner pin alone, so the homography is its one fit. A similarity covers a title, a blur or a crop that follows a subject, a filter that must follow a plane is an adjustment clip whose track matte is a shape with a corner pin ([FRAMES-11](../FRAMES-11/SPEC.md#adjustment-clips)), and a shape that must follow it is put in a compound clip with a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md)).

Tracking any clip's picture: only media has frames for a tracker to follow. A drawn picture moves by its own keyframes.

A target still to be followed written as `track`, which resolve answers by calling the tracker provider on the media: a value in the document would not be the value, and resolve would carry rules kept for that one feature, how a target is found from a clip's area, mask, crop or corner pin, which frame the search starts on, which frames the tracker must cover, and the tracker settings of resolve. `track` prints track data, one value for one fact ([FRAMES-23](../FRAMES-23/SPEC.md)), so a target still to be followed is a request in a document for a tool, which the tool fills with track data before resolve ([FRAMES-25](../FRAMES-25/SPEC.md#requests)).

## Notes
