# FRAMES-10: Parenting

Status: accepted

## Summary

`parent` names another clip by its id, and the clip then lives in that clip's coordinate space and follows its transform, as a layer follows its parent in After Effects. Parenting gives a space and a transform, nothing else: the child keeps its own clock, window, lane, opacity, blend and stacking.

## Motivation

Pieces of an edit move together. A name rides on a lower third bar, a rule sits under its title, a logo is pinned to a moving sign in the shot, a title stays beside the shape it marks, and a zoom on the main shot carries everything placed on it. Keyframing each piece with the same motion writes it twice and breaks the moment the leading piece changes. A transform parent writes the motion once: the child's position is written where it is in its parent, and the parent's keyframes, tracking, animation and transition motion carry it. Keeping everything else the child's own means a parent never fades, hides or reorders its children by surprise, and what does act as one group is a compound clip ([FRAMES-9](../FRAMES-9/SPEC.md)).

## Rules

### Who may be a parent

- `parent` is the `id` of a clip ([FRAMES-7](../FRAMES-7/SPEC.md)): `"parent": "<id>"`. It is taken by connected and sequence clips with a picture. A storyline clip takes no `parent`: its box is the frame.
- The parent is any clip with a picture in the same document: a storyline clip (a solid included), a connected or sequence media clip, a title, a shape or an adjustment clip, wherever it sits in the document. A clip in a nested document is not in the same document, so a parent is never named across a compound clip's boundary.
- An id that names no clip in the document stops, and so does one that names an audio clip.
- A parent chain is followed to its end. A chain that comes back to a clip already in it, a clip parented to itself included, stops and names the clips in the cycle.

### The space a parent gives

A parented clip's coordinates are in its parent's space: its `position`, its `area`, a path's `points`, and, for a shape or an adjustment, its `mask` ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-2](../FRAMES-2/SPEC.md)). An unparented clip's coordinates are output pixels of the frame.

| Parent | Its space | Mapped to the output by |
| --- | --- | --- |
| a storyline clip with media | media pixels of its media (a compound clip's media pixels are its own frame's output pixels) | its conformed crop scaled to its box ([FRAMES-9](../FRAMES-9/SPEC.md)), its transform, and its transition motion |
| a solid | output pixels of the frame | its transition motion |
| a media clip | media pixels of its media | its crop conformed to its box ([FRAMES-11](../FRAMES-11/SPEC.md)), and its transform |
| a title | its text box, origin at the box's top left ([FRAMES-5](../FRAMES-5/SPEC.md)) | its transform |
| a rect or ellipse placed by `width` and `height` | its box, origin at the box's top left | its transform |
| a shape placed by `area` or `points` | the space its geometry is written in: its parent's space, or output pixels when it has none | its transform |
| an adjustment clip | the space its mask is written in: its parent's space, or output pixels when it has none | its transform |

A clip's **transform** at t, here, is the map from its space to its own parent's space (or to the output when it has none) made of its keyframed `position`, `anchor`, `scale` and `rotation` ([FRAMES-1](../FRAMES-1/SPEC.md)), the tracked motion of a clip that follows its parent's media ([FRAMES-12](../FRAMES-12/SPEC.md); a clip that follows its own media moves its crop and mask instead), the transform part of its animation (`scale`, `rotation`, `x`, `y`, [FRAMES-14](../FRAMES-14/SPEC.md)), and, for a storyline clip, the transform part of its transition motion. It does not include opacity, reveal, mask, track matte or a transition matte. An adjustment clip has no keyframed transform of its own, so its transform is its tracked motion and its animation's transform part, which act around the centre of its masks' bounding box, or of the frame when it has no mask. A chain composes: a parent's own space is carried by its parent's transform, and so on to the frame.

Every part of that map is a move, a uniform scale or a rotation, so the parent's full map to the output, P(t), is a similarity transform: a move, one scale s and one rotation θ.

### How a child follows

- **Points and geometry follow whole.** A child's points (its `position`, the corners of its `area`, its path points, a shape's or adjustment's mask geometry) are mapped by P(t). So a rect placed by area grows, shrinks and turns with its parent, and a path's points stay on what they were written on.
- **A clip with a box of its own keeps its size.** A title, a media clip, or a rect or ellipse given by `width` and `height` puts its anchor point at P(t)(`position`) and turns by θ added to its own rotation, at its own scale: its box keeps its size in output pixels whatever its parent's scale.
- **Lengths stay.** Lengths a clip draws with (stroke widths, a corner `radius`, an `outset`, text sizes, borders, shadows, a mask's feather, filter lengths) are theme lengths ([FRAMES-1](../FRAMES-1/SPEC.md)) and do not grow with a parent's scale, as in an NLE's text and stroke settings. A clip's own `scale` and its animation's scale do scale them.
- **A media clip's own media is its own.** A parented media clip's `crop` and mask stay in its own media pixels ([FRAMES-11](../FRAMES-11/SPEC.md)), carried by its own transform, which follows its parent.
- A parented clip with a box of its own needs `position`, and one with a `placement` stops, since a placement names the frame and not the parent's space ([FRAMES-1](../FRAMES-1/SPEC.md)). Text forms in a parented clip's coordinates are allowed where its parent's space is the media pixels of a video, image or image sequence ([FRAMES-2](../FRAMES-2/SPEC.md)).

### Time and visibility

- The child's clock is its own container's: a connected clip is on its storyline clip's clip time, and a sequence clip on sequence time ([FRAMES-8](../FRAMES-8/SPEC.md)). Its window, lane, opacity, blend and place in the stack are its own ([FRAMES-9](../FRAMES-9/SPEC.md)).
- The parent's transform is evaluated at the same instant t of the sequence, whether or not the parent is visible at t. Outside its window it holds the values it has at the window's edge: its keyframes and tracked motion as they are there, its animation at the first or last instant of its window, and a storyline clip's transition motion as it is at the edge of its drawn range.
- A parent's opacity, reveal, mask, track matte and window do not reach its children. A child that should fade, wipe or disappear with its parent is put in a compound clip with it ([FRAMES-9](../FRAMES-9/SPEC.md)).

**Note.** A label on a shape is a title parented to the shape, its `position` a point of the shape's area. A name on a lower third bar is a title parented to the bar, or the bar is a shape parented to the title. A clip that follows something moving in a shot is parented to the shot's clip and tracked in its media ([FRAMES-12](../FRAMES-12/SPEC.md)), and other clips can be parented to that one, as an After Effects null carries a group of layers.

## Interactions

Units, placement and anchor points are [FRAMES-1](../FRAMES-1/SPEC.md). Areas and points, and where text forms are allowed, are [FRAMES-2](../FRAMES-2/SPEC.md). `id` is [FRAMES-7](../FRAMES-7/SPEC.md). A storyline clip's frame order and stacking are [FRAMES-9](../FRAMES-9/SPEC.md). Boxes, masks and track mattes are [FRAMES-11](../FRAMES-11/SPEC.md). Tracked motion is [FRAMES-12](../FRAMES-12/SPEC.md). Animation and transition motion are [FRAMES-14](../FRAMES-14/SPEC.md). Evaluation composes the transforms ([FRAMES-20](../FRAMES-20/SPEC.md)).

## Alternatives considered

Parenting only to the clip's own storyline picture, switched on with a flag: a name on its bar, a title on its shape and a logo on a picture in picture all need another clip as their parent, and an id names any clip.

Parenting implied by how a clip is placed (a clip placed by an area always parented to the picture under it): whether a clip follows another is the document's to say, and a hidden rule makes the same keys mean two things.

A parent that also passes on its opacity, window and stacking, as a group does: that is a compound clip, which frames already has. A transform parent, as After Effects parents layers, keeps the two ideas apart.

A child whose drawn lengths grow with its parent's scale: a zoom on the main shot would thicken every stroke and enlarge every title on it, where an editor expects them to keep their size and stay on their place.

## Notes
