# FRAMES-10: Parenting

Status: accepted

## Summary

A connected clip can be parented to its storyline clip's picture, so it stays in that picture's media coordinates, follows its crop, and is composited and transitioned with it.

## Motivation

A box on a recording must stay on its line while the picture zooms, and must leave with its picture in a transition instead of floating over the next clip.

## Rules

A connected clip can be parented to its storyline clip's picture. Shapes and adjustments placed by `area` always are. A title or media clip is when it has `parent: true`, and then its `position` is in the media pixels of that picture. `parent: true` with a `placement` stops, since placement names the output frame.

A parented clip is one compositing unit with its picture ([FRAMES-9](../FRAMES-9/SPEC.md)). It stays in the media coordinates of its picture and follows the crop, so a box, or a title beside a button, stays on what it points at while the picture zooms, and with `track` while it scrolls ([FRAMES-12](../FRAMES-12/SPEC.md)). A transition moves, fades, wipes and mattes the unit as one picture, so a parented clip goes with its picture and never floats over the next clip. Its blend, and an adjustment parented to the same picture, reach only that unit. A clip is parented only to its storyline clip's picture: a box on a picture in picture is made by putting both in a compound clip, where that picture is the storyline.

Parenting maps positions and areas. The lengths a clip draws with (stroke widths, text and label sizes, filter lengths) stay in output pixels and do not grow with a zoom.

A sequence clip has no parent, and its `area` takes only `[x, y, w, h]` in output pixels.

## Interactions

Units are [FRAMES-1](../FRAMES-1/SPEC.md). Tracking adds a moving parent ([FRAMES-12](../FRAMES-12/SPEC.md)). Compositing units are [FRAMES-9](../FRAMES-9/SPEC.md).

## Alternatives considered

Parenting to any clip by reference: a box on a picture in picture is made in a compound clip, where that picture is the storyline.

## Notes
