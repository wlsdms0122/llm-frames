# FRAMES-10: Parenting

Status: accepted

## Summary

`parent` names another clip by its id, and the clip then lives in that clip's coordinate space and follows its transform, as a layer follows its parent in After Effects. Parenting gives a space and a transform, nothing else: the child keeps its own clock, window, lane, opacity, blend and stacking.

## Motivation

Pieces of an edit move together. A name rides on a lower third bar, a rule sits under its title, a logo is pinned to a moving sign in the shot, a title stays beside the shape it marks, and a zoom on the main shot carries everything placed on it. Keyframing each piece with the same motion writes it twice and breaks the moment the leading piece changes. A transform parent writes the motion once: the child's position is written where it is in its parent, and the parent's keyframes, tracking, animation and transition motion carry it. Keeping everything else the child's own means a parent never fades, hides or reorders its children by surprise, and what does act as one group is a compound clip ([FRAMES-9](../FRAMES-9/SPEC.md)).

## Rules

### Who may be a parent

- `parent` is the `id` of a clip ([FRAMES-7](../FRAMES-7/SPEC.md)): `"parent": "<id>"`. It is taken by connected and sequence clips with a picture. A storyline clip takes no `parent`.
- The parent is any clip with a picture in the same document: a storyline clip (a solid included), a connected or sequence media clip, a title, a shape or an adjustment clip, wherever it sits in the document. A clip in a nested document is not in the same document, so a parent is never named across a compound clip's boundary.
- An id that names no clip in the document stops, and so does one that names an audio clip.
- A parent chain is followed to its end. A chain that comes back to a clip already in it, a clip parented to itself included, stops and names the clips in the cycle.

### The space a parent gives

A parented clip's coordinates are in its parent's space: its `position`, its `area`, a path's `points`, its `cornerPin`, and, for a shape or an adjustment, its `mask` ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-2](../FRAMES-2/SPEC.md)). An unparented clip's coordinates are output pixels of the frame.

| Parent | Its space | Mapped to the output by |
| --- | --- | --- |
| a storyline clip with media | media pixels of its media (a compound clip's media pixels are its own frame's output pixels) | its conformed crop scaled to its box ([FRAMES-9](../FRAMES-9/SPEC.md)), its transform, and then its transition motion (below) |
| a solid | output pixels of the frame | its transition motion (below) |
| a media clip | media pixels of its media | its crop conformed to its box ([FRAMES-11](../FRAMES-11/SPEC.md)), and its transform |
| a title | its text box with its background, at that instant, origin at that box's top left ([FRAMES-5](../FRAMES-5/SPEC.md)) | its transform |
| a rect or ellipse placed by `width` and `height` | its box, origin at the box's top left | its transform |
| a shape placed by `area` or `points` | the space its geometry is written in: its parent's space, or output pixels when it has none | its transform |
| an adjustment clip | the space its mask is written in: its parent's space, or output pixels when it has none | its transform |
| a clip with a corner pin ([FRAMES-27](../FRAMES-27/SPEC.md)) | the space its corner pin is written in: its parent's space, or output pixels when it has none, and not its plane | its transform, which is its tracked motion alone, the identity for a storyline clip, which `track` stops on ([FRAMES-12](../FRAMES-12/SPEC.md#what-is-tracked)), and for a storyline clip then its transition motion (below) |

The other rows are clips without a corner pin.

A clip's **transform** at t, here, is the map from its space to its own parent's space (or to the output when it has none) made of its keyframed `position`, `anchor`, `scale` and `rotation` ([FRAMES-1](../FRAMES-1/SPEC.md)), the tracked motion of a clip that follows its parent's media ([FRAMES-12](../FRAMES-12/SPEC.md); a clip that follows its own media moves its crop and mask instead), the transform part of its animation (`scale`, `rotation`, `x`, `y`, [FRAMES-14](../FRAMES-14/SPEC.md)). It does not include opacity, reveal, mask, track matte, a transition matte, or a transition's motion. A storyline clip's transition motion is a stage of its own after its transform: it maps the frame to the frame and is carried by the storyline picture's outer item ([FRAMES-20](../FRAMES-20/SPEC.md#storyline-pictures-and-transitions)). A chain that reaches the output passes through it, so a child of a storyline clip moves with that clip's transition. A chain that ends inside a storyline picture S's own nested list (S's mask, the source of S's track matte) stops before S's transition motion and keeps every other one. An adjustment clip has no keyframed transform of its own, so its transform is its tracked motion and its animation's transform part, which act around the centre of its masks' bounding box, or of the frame when it has no mask. A clip with a corner pin has no `position`, `anchor`, `scale` or `rotation`, and its animation acts on its plane, inside its box ([FRAMES-27](../FRAMES-27/SPEC.md#the-key)), so its transform is its tracked motion alone, and the identity when it is not tracked. Its corner pin is not part of its transform: the clip's picture is carried onto it inside the transform ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)). **A corner pin carries no children.** Every transform is affine, so a child of a clip with a corner pin cannot lie on its plane: the child is placed in the space the corner pin is written in and follows the clip's tracked motion, a similarity, and not the plane, and under an untracked corner pin it is placed as under the clip's own parent. What should lie on the plane goes inside the clip with the corner pin, which is then a compound clip with a corner pin. A chain composes: a parent's own space is carried by its parent's transform, and so on to the frame.

Every part of that map is a move, a scale (per axis, and mirroring where a factor is negative, [FRAMES-1](../FRAMES-1/SPEC.md)) or a rotation, so the parent's full map to the output, P(t), is an affine map, a parent with a corner pin included. Its **rotation** θ(t) is taken from that map's geometry alone, so two documents that give the same map turn a child alike, however their stages are written. It is the rotation of the polar decomposition of P(t)'s linear part L = R × S (R orthogonal, S symmetric with no negative eigenvalue), the rotation nearest to L. Where L mirrors (its determinant is negative), R is a mirror, and θ is the rotation of L with its own x axis mirrored first, L × diag(-1, 1). With L mapping (x, y) to (ax + cy, bx + dy), clockwise positive in y-down pixels as in [FRAMES-12](../FRAMES-12/SPEC.md):

```
θ = atan2(b - c, a + d)        when ad - bc ≥ 0
θ = atan2(-(b + c), d - a)     when ad - bc < 0
```

θ is 0 where both arguments are 0, as for a parent at scale 0. Where P(t) is a similarity, a move, one scale and one rotation, θ is its rotation. **A child with a box of its own takes the parent's rotation and is never mirrored. This is a convention for text, which a mirror makes unreadable in either direction it reads in: a mirror in the parent's map is read as a horizontal flip before that rotation**, which is the x axis mirrored first in the formula above. So a parent flipped horizontally and turned by α gives α, and a box child on it keeps reading in the direction it was set; one flipped vertically and turned by α gives α + 180°, since a vertical flip is a horizontal one turned half a turn, and a box child on it is turned by 180 degrees.

### How a child follows

- **Points and geometry follow whole.** A child's points (its `position`, the corners of its `area`, its path points, a shape's or adjustment's mask geometry) are mapped by P(t), and a path's tangents, offsets from their points ([FRAMES-11](../FRAMES-11/SPEC.md#shapes)), by P(t)'s linear part. An affine map takes a cubic Bézier to the cubic Bézier of its mapped control points, so a curved path is drawn as exactly the image of the curve it was written as. So a rect placed by area grows, shrinks and turns with its parent, and a path's points stay on what they were written on. A parent scaled per axis stretches them, mirrors them where a factor is negative, and with a rotation inside it skews them: a rect placed by its area is then drawn as a parallelogram.
- **A clip with a corner pin follows by its corners.** Its corner pin's points are mapped by P(t), as a path's points are, and its picture is carried onto them with everything it draws in its box, its lengths included ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)). So a card with a corner pin on a parent scaled per axis is stretched with it, and it is mirrored where the parent mirrors.
- **A clip with a box of its own and no corner pin keeps its size.** A title, a media clip, or a rect or ellipse given by `width` and `height` puts its anchor point at P(t)(`position`) and turns by θ added to its own rotation, at its own scale: its box keeps its size and its shape in output pixels whatever its parent's scale, so a parent's per-axis scale does not reach it. It is never mirrored: by the convention above, a title on a horizontally flipped picture still reads in the direction it was set, and one on a vertically flipped picture is turned by 180 degrees.
- **Lengths stay.** Lengths a clip draws with (stroke widths, a corner `radius`, an `outset`, text sizes, borders, shadows, a mask's feather, filter lengths) are theme lengths ([FRAMES-1](../FRAMES-1/SPEC.md)) and do not grow with a parent's scale, as in an NLE's text and stroke settings. A clip's own `scale` and its animation's scale do scale them, by the clip's scale factor ([FRAMES-1](../FRAMES-1/SPEC.md)). The widths of drawn lines (stroke widths, borders), a shadow's radius and a mask's feather are drawn in output pixels ([FRAMES-20](../FRAMES-20/SPEC.md)), so a parent scaled per axis stretches none of them. The lengths that are part of an outline (a corner `radius`, an `outset`, dash lengths) follow the map with the outline ([FRAMES-1](../FRAMES-1/SPEC.md)): a parent scaled per axis stretches them with it, and they keep their size on average, as the geometric mean of its scales. A clip with a corner pin is the exception: it draws its lengths in its box, and they are carried with its picture, by its corner pin and by P(t) ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)).
- **A media clip's own media is its own.** A parented media clip's `crop` and mask stay in its own media pixels ([FRAMES-11](../FRAMES-11/SPEC.md)), carried by its own transform, which follows its parent.
- A parented clip with a box of its own needs `position` or `cornerPin`, and one with a `placement` stops, since a placement names the frame and not the parent's space ([FRAMES-1](../FRAMES-1/SPEC.md)).

### Time and visibility

- The child's clock is its own container's: a connected clip is on its storyline clip's clip time, and a sequence clip on sequence time ([FRAMES-8](../FRAMES-8/SPEC.md)). Its window, lane, opacity, blend and place in the stack are its own ([FRAMES-9](../FRAMES-9/SPEC.md)).
- The parent's transform is evaluated at the same instant t of the sequence, whether or not the parent is visible at t. Outside its window it holds the values it has at the window's edge: its keyframes and tracked motion as they are there, its animation at the first or last instant of its window, and a storyline clip's transition motion as it is at the edge of its drawn range.
- A parent's opacity, reveal, mask, track matte and window do not reach its children. A child that should fade, wipe or disappear with its parent is put in a compound clip with it ([FRAMES-9](../FRAMES-9/SPEC.md)).

**Note.** A label on a shape is a title parented to the shape, its `position` a point of the shape's area. A name on a lower third bar is a title parented to the bar, or the bar is a shape parented to the title, whose `area` may be the title's box so that it fits the name it follows ([FRAMES-2](../FRAMES-2/SPEC.md)). A clip that follows something moving in a shot is parented to the shot's clip and tracked in its media ([FRAMES-12](../FRAMES-12/SPEC.md)), and other clips can be parented to that one, as an After Effects null carries a group of layers.

## Interactions

Units, placement and anchor points are [FRAMES-1](../FRAMES-1/SPEC.md). Areas and points are [FRAMES-2](../FRAMES-2/SPEC.md). `id` is [FRAMES-7](../FRAMES-7/SPEC.md). A storyline clip's frame order and stacking are [FRAMES-9](../FRAMES-9/SPEC.md). Boxes, masks and track mattes are [FRAMES-11](../FRAMES-11/SPEC.md). Tracked motion is [FRAMES-12](../FRAMES-12/SPEC.md). A corner pin is [FRAMES-27](../FRAMES-27/SPEC.md). Animation and transition motion are [FRAMES-14](../FRAMES-14/SPEC.md). Evaluation composes the transforms ([FRAMES-20](../FRAMES-20/SPEC.md)).

## Alternatives considered

Parenting only to the clip's own storyline picture, switched on with a flag: a name on its bar, a title on its shape and a logo on a picture in picture all need another clip as their parent, and an id names any clip.

Parenting implied by how a clip is placed (a clip placed by an area always parented to the picture under it): whether a clip follows another is the document's to say, and a hidden rule makes the same keys mean two things.

A parent that also passes on its opacity, window and stacking, as a group does: that is a compound clip, which frames already has. A transform parent, as After Effects parents layers, keeps the two ideas apart.

A child whose drawn lengths grow with its parent's scale: a zoom on the main shot would thicken every stroke and enlarge every title on it, where an editor expects them to keep their size and stay on their place.

A child with a box of its own that takes its parent's whole map, as an After Effects layer does: a title on a flipped or stretched picture would be drawn mirrored or stretched, against the rule that such a child keeps its size. Its anchor point follows the map, and its box turns with the parent's rotation only.

A parent's rotation summed from its stages, each rotation's sign reversed under an odd number of mirrors outside it: a map can be written as different stages (a rotation inside a per-axis scale and another outside it, or a flip and a half turn), and two documents with the same map would turn a child differently. The polar rotation is the nearest rotation to the map, the one a box keeping its shape can take. Under a mirror no rotation is nearest, and a function of the map alone cannot leave a box child upright under both flips, since a vertical flip is a horizontal one turned half a turn. Mirroring the y axis first would keep it upright under a vertical flip and turn it half a turn under a horizontal one. The x axis is taken so that a horizontal flip, the one that mirrors a shot, leaves text reading as it was written.

## Notes
