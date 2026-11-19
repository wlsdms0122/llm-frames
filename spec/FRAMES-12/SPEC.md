# FRAMES-12: Tracking

Status: accepted

## Summary

`track` makes a clip follow something in a picture: the tracker provider follows a target's four corners on each frame of the media, a similarity motion (move, uniform scale and rotation) is fitted to them, and that motion carries the clip's geometry as a moving parent.

## Motivation

Things in a shot move. A title pinned to a moving sign, a blur kept on a face while the camera pans, a zoom that stays on a runner, a logo replaced on a turning product: a value written at one instant drifts off its subject as soon as the subject moves, and keyframing it by hand frame by frame is the work a tracker exists to save, as in After Effects and Premiere Pro. Following the target once and carrying every value of the clip through the motion keeps each one on its subject, while the clip's own keyframes still say what it does relative to it.

## Rules

### What is tracked

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is an area ([FRAMES-2](../FRAMES-2/SPEC.md)), in any form allowed where it is written, or `true` for the clip's own geometry:

- `true` follows the clip's `area` (a rect or ellipse placed by area), its `mask` (the bounding box of every mask's geometry, without feather), or its `crop` (a storyline or media clip whose crop is an area). A clip that has more than one of these, or none, stops on `true`, since it must name its target. A `{scale}` crop, or no crop, is not an area. A title, still or compound clip has none in the media it follows, its parent's, so it names its target.
- The **tracked media** is the clip's own media when the clip is a storyline clip or media clip of video or image sequence. Otherwise it is its parent's media ([FRAMES-10](../FRAMES-10/SPEC.md)), when the parent is a storyline clip or media clip of video or image sequence. Anywhere else (an unparented title, shape or adjustment, a still or compound clip, a clip parented to a title, a shape or a still) `track` stops, since there is no picture to follow.
- The target is an area in the tracked media's pixels. On a clip that tracks its own media, a named target is in its own media pixels, as its crop and mask are. On a clip that tracks its parent's media, it is in its parent's space, as its position and area are.

**Note.** A clip with video of its own that should follow its parent's picture is parented to a shape that tracks it, as an After Effects layer is parented to a tracked null. The shape can be drawn at no opacity.

### The track

The target is found at the clip's instant ([FRAMES-2](../FRAMES-2/SPEC.md)), before its padding, and the tracker provider ([FRAMES-21](../FRAMES-21/SPEC.md)) follows it backwards and forwards from that frame of the tracked media until it has covered every media frame the clip can show at the instants it draws (through the time map of the tracked media's clip, `timeRemap` and handles included, [FRAMES-8](../FRAMES-8/SPEC.md)), and the frames between them and the instant. On each frame it gives the target's quadrilateral (quad): four points in media pixels, the target's top left, top right, bottom right and bottom left corners in that order, as the target faces on the frame where it was found. The target as found is given to the tracker as the quad of its four corners. A tracker reads only the media's pixels, so it is given the part of the target inside the picture, and the motion fitted to what it reports carries the whole target. A target with no part inside the picture is followed on no frame, and the rules of where the target is lost apply.

- The track is a motion, a function of the tracked media's media time: on each frame, the similarity transform (a move, one uniform scale and one rotation) that takes the target's quad at the instant, corners p₁ to p₄, nearest by least squares to its quad on that frame, corners q₁ to q₄ in the same order. With p̄ and q̄ the centroids, pᵢ' = pᵢ - p̄ and qᵢ' = qᵢ - q̄:

  ```
  a = Σ (pᵢ'x qᵢ'x + pᵢ'y qᵢ'y)
  b = Σ (pᵢ'x qᵢ'y - pᵢ'y qᵢ'x)
  θ = atan2(b, a)                       rotation, clockwise positive in y-down pixels
  s = sqrt(a² + b²) / Σ |pᵢ'|²          uniform scale
  M(x) = s R(θ) (x - p̄) + q̄            R(θ) = [[cos θ, -sin θ], [sin θ, cos θ]]
  ```

  At the instant the motion is the identity. The resolved document writes the track as `{media, time, target, frames}`: the tracked media, the media time of the instant, the target's quad there, and every frame followed as `{time, quad, motion}` with the fitted motion written out ([FRAMES-19](../FRAMES-19/SPEC.md)). At an instant of the clip, the motion is that of the media frame the tracked media shows there, so a hold holds the motion and a reverse plays it back. A clip that follows its parent's media takes the frame its parent's time map gives at the instant, also where the parent itself is not visible.
- The motion acts as a moving parent, between the clip's values and the space they are written in. Every value of the clip's geometry in that space (on its own media: its `crop` and `mask`; on its parent's media: its `position`, `area`, `points`, and for a shape or adjustment its `mask`) is where it is at its own time, as a rectangle `ocr --json` gives for that time is: a keyframe's value at the keyframe's time, found by text or written, and a static value at the instant. Each is brought back through the inverse of the motion at its time, interpolated there, and carried by the motion on each frame. So a rect stays on a moving sign, a title beside a product turns with it, and a zoom keyframed on a crop goes on while the crop follows a runner.
- A crop takes the move and the scale of the motion and not its rotation, since a crop is an upright region of its media: it keeps its aspect ratio and stays upright. Every other value takes the whole motion, and a clip with a box of its own turns with it and keeps its size, as under any parent ([FRAMES-10](../FRAMES-10/SPEC.md)). A rectangle (an `area`, a rect or ellipse mask) is brought back by its centre and its size divided by the motion's scale, upright in the space the motion carries, so it turns with the motion as under any parent.
- A tracked clip's instant is the time of its first keyframe of the property it follows, when it has one, and otherwise its instant of [FRAMES-2](../FRAMES-2/SPEC.md). A clip that names its target follows none of its own properties, so its instant is always that of [FRAMES-2](../FRAMES-2/SPEC.md), and only `true` takes the first keyframe of its area, mask or crop.

### Where the target is lost

- A connected or sequence clip is visible only where its target was followed: from its instant, its window ends, in each direction, at the first instant whose media frame was not followed, as [FRAMES-8](../FRAMES-8/SPEC.md) narrows any window. Its parent's window does not bound it ([FRAMES-10](../FRAMES-10/SPEC.md)): outside that window a clip that follows its parent's media follows the frames its parent's time map gives there, while its parent's transform holds at the window's edge.
- A storyline clip whose target is lost inside its edit range stops, naming the time. In a handle its motion holds the nearest value followed, as a handle past the end of the media holds its edge frame.

**Note.** Perspective (corner pin) is left out (README). The tracker already reports four corners, so a later contract can fit a projective transform to the same quads without changing the provider.

## Interactions

The target is an area ([FRAMES-2](../FRAMES-2/SPEC.md)) found at the instant of [FRAMES-2](../FRAMES-2/SPEC.md). Time maps and windows are [FRAMES-8](../FRAMES-8/SPEC.md). Parenting is [FRAMES-10](../FRAMES-10/SPEC.md), and masks are [FRAMES-11](../FRAMES-11/SPEC.md). Keyframed values interpolate as [FRAMES-4](../FRAMES-4/SPEC.md) says. The tracker provider is [FRAMES-21](../FRAMES-21/SPEC.md), and the resolved document pins the track it reported ([FRAMES-19](../FRAMES-19/SPEC.md)).

## Alternatives considered

Tracking as an area form: an area cannot move a position or keep a crop's zoom apart from its target. Re-acquiring a lost target: a lost target narrows the window instead.

A tracker that reports a rectangle, with move and scale only: a turning subject would leave its title upright and drifting. Four corners give the rotation, and the same report leaves room for perspective later.

Perspective tracking (corner pin) now: it needs a projective transform in every display list item and every renderer, and a similarity covers a title, a blur or a crop that follows a subject. Left out (README).

Tracking any clip's picture: only media has frames for a tracker to follow. A drawn picture moves by its own keyframes.

## Notes
