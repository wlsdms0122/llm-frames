# FRAMES-12: Tracking

Status: accepted

## Summary

`track` makes a clip follow something in a picture: the tracker provider follows a target's four corners on each frame of the media, or a track made outside frames is written in the document as track data, a similarity motion (move, uniform scale and rotation) is fitted to each frame's corners and carries the clip's geometry as a moving parent, and the homography those corners give carries a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md)).

## Motivation

Things in a shot move. A title pinned to a moving sign, a blur kept on a face while the camera pans, a zoom that stays on a runner, a logo replaced on a turning product: a value written at one instant drifts off its subject as soon as the subject moves, and keyframing it by hand frame by frame is the work a tracker exists to save, as in After Effects and Premiere Pro. Following the target once and carrying every value of the clip through the motion keeps each one on its subject, while the clip's own keyframes still say what it does relative to it. A tracker frames does not have, such as a planar tracker run outside it, gives the same four corners on each frame, and written in the document as track data they stay one value that keeps every rule of the track, where keyframes on every frame would not.

## Rules

### What is tracked

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is an area ([FRAMES-2](../FRAMES-2/SPEC.md)), in any form allowed where it is written, `true` for the clip's own geometry, or track data ([below](#track-data)):

- **What `track` follows is how the clip is placed**, not the clip's kind. A clip placed by points written in its parent's space ([FRAMES-10](../FRAMES-10/SPEC.md)), an `area`, a path's `points`, an adjustment clip's `mask` or a `cornerPin` ([FRAMES-27](../FRAMES-27/SPEC.md)), follows its parent's media, and those points are what moves, with a shape's `mask` written in that space. A clip placed by its box, by `position` or `placement` with its `anchor` and `scale` ([FRAMES-1](../FRAMES-1/SPEC.md)), follows inside its own media, and its `crop` and `mask`, written in its own media pixels, are what moves. A clip placed by its box with no frames of its own, a title, a still, a compound clip, or a rect or ellipse given by `width` and `height`, has nothing inside it to follow, so it follows its parent's media, and its `position`, the one point of it written in its parent's space, is what moves. Only a video or an image sequence has frames to follow, so a parent's media counts only where the parent is a storyline clip or media clip of video or image sequence without a corner pin, since a parent with a corner pin gives its children the space its corner pin is written in and not its media's pixels.
- The rule by kind is its consequence. A storyline clip or media clip of video or image sequence without a corner pin tracks its own media. A title, a shape, an adjustment clip, a still or a compound clip without a corner pin tracks its parent's media. A clip with a corner pin tracks its parent's media whatever its kind, and its own `crop` and `mask` are not followed: they lie flat on its plane and ride its corner pin, as a title's mask rides its transform ([FRAMES-27](../FRAMES-27/SPEC.md#the-key)). A storyline clip with a corner pin has no parent, so `track` on it stops, naming the corner pin, since it is placed by points in the frame, which has no media. `track` stops wherever the media to follow is a parent's and there is none (an unparented title, shape, adjustment, still, compound clip or clip with a corner pin, a clip parented to a title, a shape, a still, a compound clip, an adjustment clip or a clip with a corner pin), since there is no picture to follow.
- `true` follows the clip's own geometry in the media it tracks: its `area` (a rect or ellipse placed by area), its `mask` (the bounding box of every mask's geometry, without feather), its `crop` (a storyline or media clip whose crop is an area), or its `cornerPin` (the quadrilateral of its four corners, [FRAMES-27](../FRAMES-27/SPEC.md)). A clip that has more than one of these, or none, stops on `true`, since it must name its target. A `{scale}` crop, or no crop, is not an area. A title, still or compound clip without a corner pin has none in the media it tracks, its parent's, so it names its target, and a clip with a corner pin has only its corner pin there.
- The target is an area in the tracked media's pixels. On a clip that tracks its own media, a named target is in its own media pixels, as its crop and mask are. On a clip that tracks its parent's media, it is in its parent's space, as its position, area and corner pin are.

**Note.** A clip with video of its own that should follow its parent's picture is parented to a shape that tracks it, as an After Effects layer is parented to a tracked null. The shape can be drawn at no opacity.

### The track

The target is found at the clip's instant ([FRAMES-2](../FRAMES-2/SPEC.md)), before its padding, on the frame of the tracked media the instant shows, and the tracker provider ([FRAMES-21](../FRAMES-21/SPEC.md)) follows it backwards and forwards from that frame until it has covered every media frame the clip can show at the instants it draws (through the time map of the tracked media's clip, `timeRemap` and handles included, [FRAMES-8](../FRAMES-8/SPEC.md)), and the frames between them and the instant. On each frame it gives the target's quadrilateral (quad): four points in media pixels, the target's top left, top right, bottom right and bottom left corners in that order, as the target faces on the frame where it was found. The target as found is its quad: an area's four corners, a corner pin's four points, or, for track data, the quad of the frame its `time` names ([Track data](#track-data)). A tracker reads only the media's pixels, so it is given the target's quad when the quad lies inside the picture, and otherwise the rectangle that bounds the part of the target inside the picture, as its four corners. Each quad it reports for what it was given, r for g, is carried to the whole target p by the homography between them, so the target's quad on that frame is H(g → r) applied to each corner of p ([FRAMES-27](../FRAMES-27/SPEC.md#the-homography)). A target with no part inside the picture is followed on no frame, and the rules of where the target is lost apply.

- The track is a motion, a function of the tracked media's media time: on each frame, the similarity transform (a move, one uniform scale and one rotation) that takes the target's quad, corners p₁ to p₄, nearest by least squares to its quad on that frame, corners q₁ to q₄ in the same order. With p̄ and q̄ the centroids, pᵢ' = pᵢ - p̄ and qᵢ' = qᵢ - q̄:

  ```
  a = Σ (pᵢ'x qᵢ'x + pᵢ'y qᵢ'y)
  b = Σ (pᵢ'x qᵢ'y - pᵢ'y qᵢ'x)
  θ = atan2(b, a)                       rotation, clockwise positive in y-down pixels
  s = sqrt(a² + b²) / Σ |pᵢ'|²          uniform scale
  M(x) = s R(θ) (x - p̄) + q̄            R(θ) = [[cos θ, -sin θ], [sin θ, cos θ]]
  ```

  On each frame the track also has its **homography**, H(p → q) of [FRAMES-27](../FRAMES-27/SPEC.md#the-homography): the projective map that takes the target's quad exactly to its quad on that frame. The motion and the homography are the identity on the frame the target is taken from: for a tracker, the frame the clip's instant shows, and for track data, the frame its `time` names. The resolved document writes the track as `{media, time, target, frames}`: the tracked media, the media time of that frame, the target's quad there, and every frame followed as `{time, quad, motion}` with the fitted motion written out ([FRAMES-19](../FRAMES-19/SPEC.md)). The homography is not written: it is the closed form of the target's quad and the frame's ([FRAMES-27](../FRAMES-27/SPEC.md#the-homography)), which are, and evaluation computes it from them. At an instant of the clip, the motion is that of the media frame the tracked media shows there, so a hold holds the motion and a reverse plays it back. A clip that follows its parent's media takes the frame its parent's time map gives at the instant, also where the parent itself is not visible.
- The motion acts as a moving parent, between the clip's values and the space they are written in. Every value of the clip's geometry in that space (on its own media: its `crop` and `mask`; on its parent's media: its `position`, `area`, `points`, and for a shape or adjustment its `mask`) is where it is at its own time, as a rectangle `ocr --json` gives for that time is: a keyframe's value at the keyframe's time, found by text or written, a static value found by text on the frame it is searched in ([FRAMES-2](../FRAMES-2/SPEC.md#the-search-instant)), and a static value written on the frame the track is the identity on. Each is brought back through the inverse of the motion at its time, interpolated there, and carried by the motion on each frame. So a rect stays on a moving sign, a title beside a product turns with it, and a zoom keyframed on a crop goes on while the crop follows a runner. A clip's corner pin is the one value carried by the homography in place of the motion, as [FRAMES-27](../FRAMES-27/SPEC.md#a-tracked-corner-pin) says, and the motion stays its moving parent.
- A crop takes the move and the scale of the motion and not its rotation, since a crop is an upright region of its media: it keeps its aspect ratio and stays upright. Every other value takes the whole motion, and a clip with a box of its own turns with it and keeps its size, as under any parent ([FRAMES-10](../FRAMES-10/SPEC.md)). A rectangle (an `area`, a rect or ellipse mask) is brought back by its centre and its size divided by the motion's scale, upright in the space the motion carries, so it turns with the motion as under any parent.
- A tracked clip's instant is the time of its first keyframe of the property it follows, when it has one, and otherwise its instant of [FRAMES-2](../FRAMES-2/SPEC.md). A clip that names its target or writes track data follows none of its own properties, so its instant is always that of [FRAMES-2](../FRAMES-2/SPEC.md), and only `true` takes the first keyframe of its area, mask, crop or corner pin. For a clip that writes track data the instant decides nothing of the track: its target and the frame its written values are true on are the frame its `time` names, and its keyframes stay at their times on its clip's clock, each brought back through the motion of the frame it shows. Its instant is still where its text forms are searched ([FRAMES-2](../FRAMES-2/SPEC.md#the-search-instant)) and where its window is narrowed from ([Where the target is lost](#where-the-target-is-lost)).

### Where the target is lost

- A connected or sequence clip is visible only where its target was followed: from its instant, its window ends, in each direction, at the first instant whose media frame was not followed, as [FRAMES-8](../FRAMES-8/SPEC.md) narrows any window. Its parent's window does not bound it ([FRAMES-10](../FRAMES-10/SPEC.md)): outside that window a clip that follows its parent's media follows the frames its parent's time map gives there, while its parent's transform holds at the window's edge.
- A storyline clip whose target is lost inside its edit range stops, naming the time. In a handle its motion holds the nearest value followed, as a handle past the end of the media holds its edge frame.
- A frame whose quad, as carried to the whole target, is not strictly convex, or is strictly convex with the other orientation than the target's quad ([FRAMES-27](../FRAMES-27/SPEC.md#the-homography)), is not followed, for every tracked clip, and the track ends before it in that direction, as where the tracker reports the target lost: a plane folded over itself, or seen from its back, is not a plane followed.
- A value of the clip at a time whose media frame was not followed, a keyframe beyond the window or in a handle, is brought back through the motion of the nearest frame followed, the edge of the track in that direction, as a storyline clip's motion holds in a handle. So such a keyframe still shapes the span it begins or ends.

**Note.** The tracker contract is a quad on each frame, which holds perspective, so a tracker that follows perspective drives a corner pin through it ([FRAMES-27](../FRAMES-27/SPEC.md)). The `point` tracker reports similarity images of its target, so its homography is its motion.

### Track data

Track data is a track made outside frames, written as the value of `track` in place of a target for the tracker provider: an object of two keys, `time` and `frames`, both required. A `track` object that holds `frames` is track data, and any other object is an area ([FRAMES-2](../FRAMES-2/SPEC.md)).

| Key | Form | Meaning |
| --- | --- | --- |
| `time` | a media time | the frame of the tracked media on which the clip's written values in that media's pixels are true, its corner pin, area, points or position, or on its own media its crop and mask: that frame's quad in `frames` is the target |
| `frames` | a list of `{time, quad}`, at least one, each key required | every frame followed, in time order: a media time, and the target's quad on that frame, four points `[x, y]` of numbers in media pixels of the tracked media, its top left, top right, bottom right and bottom left corners |

The target is the quad of the frame `time` names, so the motion and the homography are the identity on that frame by construction, and no target is written beside it. So what the document writes does not depend on where the clip starts: a corner pin written on the frame `time` names stays there, and trimming the clip's head moves nothing. An extension that turns the object `track --json` prints ([FRAMES-23](../FRAMES-23/SPEC.md)) into track data keeps its `time` and `frames` and drops its `track` and `target` keys and each frame's `motion`.

- The clip follows the target as a clip that names its target does. Its tracked media is the one the rules above give, the quads given stand where the tracker's would, resolve fits each frame's motion to them as [The track](#the-track) says and pins the resolved track, and windows narrow where the data names no frame, as where the target is lost. `--tracker` is not called for a clip that writes track data.
- **Its conventions are the document's.** A `time` is a media time as [FRAMES-3](../FRAMES-3/SPEC.md) defines it and as `extract`, `ocr` and `track` print it ([FRAMES-23](../FRAMES-23/SPEC.md)): for a video, time 0 is the start of its presentation timeline after its edit list, not its timecode and not its first frame's timestamp, and for an image sequence, frame index / fps, so its first file is at 0 whatever number it carries. A time names the frame of the tracked media whose presentation interval holds it ([FRAMES-3](../FRAMES-3/SPEC.md)), so an outside tracker's times need not match the media's to the microsecond. A quad is in media pixels as [FRAMES-1](../FRAMES-1/SPEC.md) defines them: the picture as displayed, its rotation metadata applied and its pixels made square, origin at its top left, x right and y down, with whole numbers at the corners of pixels. The resolved track writes each frame's `time` as the timestamp of the frame it names, and its `time` and `target` as those of the frame `time` names.
- A clip with a corner pin that writes track data rides the homography of its quads, so a planar tracker run outside frames drives a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md#a-tracked-corner-pin)).
- **A written quad that is wrong stops, where a tracker's is a lost frame.** A quad of the data that is not strictly convex, or whose orientation is not that of the quad of the frame `time` names, stops (below), where the same quad from a tracker is a frame not followed (above). A tracker's quad is a measurement, which can fail on a frame, and the track ends there; a written quad is a value, checked as every written value is, and a wrong one is the document's mistake.

Track data stops at `resolve`, naming its place, `...track` or `...track.frames[i]`:

- a key other than `time` and `frames`, or than `time` and `quad` in a frame, or a missing one;
- a point that is not two finite numbers, or a quad that is not four points;
- a quad that is not strictly convex, or whose orientation is not that of the quad of the frame `time` names ([FRAMES-27](../FRAMES-27/SPEC.md#the-homography));
- frames out of time order, or two frames that name one media frame;
- a gap: a media frame between the first frame named and the last that no frame names;
- a `time` that names no frame of `frames`, since the data would give no target;
- a frame the clip's instant shows ([FRAMES-2](../FRAMES-2/SPEC.md)) that no frame of `frames` names, naming that frame's media time, since the window is narrowed from the instant and would hold none;
- tracked media that is not a video or an image sequence, as for every `track`.

```json
"track": { "time": 2.04,
           "frames": [ { "time": 2, "quad": [ [810, 301], [1130, 350], [1101, 916], [777, 858] ] },
                       { "time": 2.04, "quad": [ [812, 304], [1131, 352], [1102, 918], [779, 861] ] },
                       { "time": 2.08, "quad": [ [815, 306], [1131, 355], [1102, 921], [781, 863] ] } ] }
```

The frames are cut short. The clip's written values are true on media second 2.04, so the quad there is the target, the clip follows it from media second 2 to 2.08, and it is visible where its instants show those frames, wherever it starts among them.

**Note.** A tracker run on a constant rate export of a variable rate file gives the times of the export's frames. Two of them can fall in one presentation interval of the file, which stops as two frames that name one media frame, and an interval that none falls in is a gap. The tracker is run on the file the document names, or its quads are written at the times of that file's frames, which `extract` and `track` print.

## Interactions

The target is an area ([FRAMES-2](../FRAMES-2/SPEC.md)) or a corner pin found at the instant of [FRAMES-2](../FRAMES-2/SPEC.md), or given by track data. Time maps and windows are [FRAMES-8](../FRAMES-8/SPEC.md). Parenting is [FRAMES-10](../FRAMES-10/SPEC.md), and masks are [FRAMES-11](../FRAMES-11/SPEC.md). Keyframed values interpolate as [FRAMES-4](../FRAMES-4/SPEC.md) says. The tracker provider is [FRAMES-21](../FRAMES-21/SPEC.md), and the resolved document pins the track it reported or the data gave ([FRAMES-19](../FRAMES-19/SPEC.md)). The homography and a tracked corner pin are [FRAMES-27](../FRAMES-27/SPEC.md). Track data is the object `track` prints ([FRAMES-23](../FRAMES-23/SPEC.md)).

## Alternatives considered

Tracking as an area form: an area cannot move a position or keep a crop's zoom apart from its target. Re-acquiring a lost target: a lost target narrows the window instead.

An outside track written as keyframes on a parent, one for each frame, as After Effects' tracker writes them: a crop and a mask that follow their own media cannot be carried by a parent, the keyframes lie on clip time where a hold, a reverse or a `timeRemap` must play the motion by media time, and a lost target would not narrow the window. One fact would be spread over a value for each frame and kept in step by hand. Track data keeps it one value.

Track data that also takes each frame's `motion` and ignores it: a value that does nothing breaks the rule that unknown keys stop, and the fit is resolve's to make.

Track data without a `time`, its target the quad of the frame the clip's instant shows: a written corner pin would be true only on the frame the clip's start shows through its parent's time map, which its author would work out by hand, and trimming the clip's head would carry the same numbers from another frame and move the pin off its screen on every frame. The values are written on a frame of the media, so the data names that frame.

Track data with a `target` beside its `time`: the quad of the frame `time` names is the target already, and a second one would need a rule to agree with it.

A tracked media chosen by the clip's kind: a clip placed by points in its parent's space, as a corner pin is, would follow media its points are not written in.

A clip with a corner pin that also follows its own crop or mask, or stops when it has both: a track follows one picture, so the two would need a compound clip to be split into, while a crop or a mask drawn flat on the plane rides the corner pin as a title's mask rides its transform, and needs no track of its own.

A tracker that reports a rectangle, with move and scale only: a turning subject would leave its title upright and drifting. Four corners give the rotation, and the same report leaves room for perspective later.

The homography carrying every tracked value: rectangles and boxes would stop being rectangles, a path and a rect on one target would disagree, and a parent's map would stop being affine ([FRAMES-10](../FRAMES-10/SPEC.md)). A similarity covers a title, a blur or a crop that follows a subject, only a corner pin takes perspective, and a shape that must follow it is put in a compound clip with a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md)).

A tracked frame's quad carried to the whole target by the similarity fitted to what the tracker reported: a perspective quad would lose its perspective wherever the target reaches past the picture. The homography of what was given to what was reported carries the whole plane, and for a tracker that reports similarity images it is that similarity.

Tracking any clip's picture: only media has frames for a tracker to follow. A drawn picture moves by its own keyframes.

## Notes
