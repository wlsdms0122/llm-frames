# FRAMES-12: Tracking

Status: accepted

## Summary

`track` makes a clip follow something in its picture: the tracker provider follows a target, and its similarity motion acts as a moving parent for the clip's geometry.

## Motivation

A recording scrolls, and a box written at one instant drifts off its line. Following the target and carrying every value through the motion keeps the box, a title beside a button, or a zooming crop on what it points at.

## Rules

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is an area in one of the finding forms of [FRAMES-2](../FRAMES-2/SPEC.md), or `true` for the clip's own `area` (a shape or adjustment) or `crop` (a storyline clip). The area is found at the clip's instant ([FRAMES-2](../FRAMES-2/SPEC.md)), before padding, and the tracker provider ([FRAMES-21](../FRAMES-21/SPEC.md)) follows it backwards and forwards from that frame until it has covered every frame the picture draws, handles included, and the frames between them and the instant, giving the target's rectangle on each.

- The track is a motion: on each frame, the similarity transform (a move, and one uniform scale about the target's centre) that takes the target's rectangle at the instant to its rectangle on that frame. The scale is the geometric mean of the width and height ratios, so a crop keeps its aspect ratio.
- The motion acts as a moving parent. Every value of the clip's geometry (its `area`, its `position`, a storyline clip's `crop`) is where it is at its own time, as a rectangle `ocr --json` gives for that time is: a keyframe's value at the keyframe's time, found by text or written as a rectangle, and a static value at the instant. Each is brought back through the inverse of the motion at its time, interpolated there, and carried by the motion on each frame. So a box stays on a scrolling line, a title beside a button stays beside it when the screen zooms ([FRAMES-1](../FRAMES-1/SPEC.md)), and a zoom keyframed on a crop goes on while the crop follows a card.
- A tracked clip's instant is the time of its first keyframe of the property it follows, when it has one, and otherwise its instant of [FRAMES-2](../FRAMES-2/SPEC.md). A clip that names its target follows none of its own properties, so its instant is always that of [FRAMES-2](../FRAMES-2/SPEC.md), and only `true` takes the first keyframe of its area or crop. `true` on a storyline clip whose crop is not an area where it starts, a `{scale}` or no crop, stops like `true` on a clip without an area. `true` follows the clip's own area or crop at that instant. It is taken by a shape, an adjustment, and a storyline clip whose crop is an area. Elsewhere it stops: a title or media clip names its target. A media clip's own `crop` is in its own media and is not moved.
- A band keeps the full width of its picture and takes the vertical part of the motion.
- `track` is taken by a storyline clip of video or image sequence, which follows its own media, and by a parented connected clip on one, which follows that storyline clip's media. Anywhere else (a sequence clip, an unparented clip, a still or compound storyline clip) it stops, since there is nothing to follow.
- A connected clip is visible only on the frames followed: its window is narrowed to them, as [FRAMES-8](../FRAMES-8/SPEC.md) narrows any window. A storyline clip whose target is lost inside its edit range stops, naming the time. In a handle its motion holds the nearest value followed, as a handle past the end of the media holds its edge frame.

## Interactions

The target is an area ([FRAMES-2](../FRAMES-2/SPEC.md)) found at the instant of [FRAMES-2](../FRAMES-2/SPEC.md). The tracker provider is [FRAMES-21](../FRAMES-21/SPEC.md). Parenting is [FRAMES-10](../FRAMES-10/SPEC.md).

## Alternatives considered

Tracking as an area form: an area cannot move a position or keep a crop's zoom apart from its target. Re-acquiring a lost target: a lost target narrows the window instead.

## Notes
