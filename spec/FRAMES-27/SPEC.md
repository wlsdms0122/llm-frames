# FRAMES-27: Corner pin

Status: draft

## Summary

`cornerPin` places a clip's picture, drawn flat in its own box, by the projective map (homography) that takes the four corners of its box to four points in the clip's coordinate space, as the Corner Pin of After Effects and Premiere Pro and the Distort of Final Cut Pro move a picture's four corners. This spec gives the key and the clips that take it, the homography of four point pairs and its closed form, which corner pins stop and which draw nothing, and how a tracked corner pin rides the homography from the target's quadrilateral to its quadrilateral on each frame, so a perspective track, from a tracker provider or written in the document as track data ([FRAMES-12](../FRAMES-12/SPEC.md)), keeps a picture on a moving plane. Evaluation draws a clip with a corner pin as a group whose `picture` item carries the corner pin ([FRAMES-20](../FRAMES-20/SPEC.md)).

## Motivation

A screen replaced in a shot, a poster put on a wall, a sign given new words, a title laid on a table top: each puts a picture on a plane seen in perspective, where the far edge is shorter than the near one. The live set maps a picture by affine maps only. A compound clip turned, scaled per axis and turned again gives any parallelogram ([FRAMES-1](../FRAMES-1/SPEC.md)), and no parallelogram has edges that converge. Outside frames, such a picture would be baked into media, warped frame by frame by another tool and brought back, and every change of its content would bake it again. A tracked one would be worse: After Effects' tracker writes the four points of a Corner Pin as keyframes on every frame, one fact spread over a value per frame, and those keyframes would sit on clip time, where a hold, a reverse or a `timeRemap` must play the track by media time ([FRAMES-12](../FRAMES-12/SPEC.md)). With one key, the picture stays a clip whose content is edited as any other, and a tracked corner pin is one corner pin and one track.

## Rules

### The key

`cornerPin` is a list of four points ([FRAMES-2](../FRAMES-2/SPEC.md)), in any form a point takes where it is written, in the clip's coordinate space ([FRAMES-1](../FRAMES-1/SPEC.md), [FRAMES-10](../FRAMES-10/SPEC.md)): where the top left, top right, bottom right and bottom left corners of the clip's box go, in that order, the order of a quadrilateral ([FRAMES-21](../FRAMES-21/SPEC.md)). The four points make the clip's **corner pin**. It is keyframable, its points interpolated point by point as a list of points ([FRAMES-4](../FRAMES-4/SPEC.md)). It has no default, and a clip without it is placed as [FRAMES-1](../FRAMES-1/SPEC.md) says.

| Clip | `cornerPin` |
| --- | --- |
| a title, a media clip with a picture, a rect or ellipse given by `width` and `height` (a clip with a box of its own, [FRAMES-1](../FRAMES-1/SPEC.md)) | taken: the corners of its box ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| a storyline clip with media | taken: the corners of its storyline picture's box ([FRAMES-9](../FRAMES-9/SPEC.md)) |
| a shape placed by `area` or `points` | stops: its outline is points in its space already. A shape that must be drawn in perspective is put in a compound clip with a corner pin |
| a solid, an adjustment clip, an audio clip | not a key of theirs ([FRAMES-7](../FRAMES-7/SPEC.md)): a solid is the frame, an adjustment draws no picture of its own, and an audio clip draws none |

- **A clip with a corner pin is placed by it**, as a shape is placed by its `area` ([FRAMES-1](../FRAMES-1/SPEC.md)). A clip that writes `cornerPin` and any of `placement`, `position`, `anchor`, `scale` and `rotation`, on the clip or in a keyframe, stops, naming both keys. It takes none of the placement defaults of [FRAMES-1](../FRAMES-1/SPEC.md), a style's placement included, so a title whose style gives a placement is placed by its corner pin.
- Its box is what it draws, at the size [FRAMES-1](../FRAMES-1/SPEC.md) gives it: a title's text box with its background, a media clip's box by its `width`, `height` and crop, a storyline picture's box, a rect's or ellipse's `width` by `height`. The corner pin decides only where that box's corners go.
- **Its own size, for placing, is the bounding box of its corner pin**: the box an animation's `x` and `y` are multiples of, whose centre its animation's scale and rotation act around ([FRAMES-14](../FRAMES-14/SPEC.md)), taken at t in the space its animation acts in ([A tracked corner pin](#a-tracked-corner-pin)), and the box a clip area that names it takes ([FRAMES-2](../FRAMES-2/SPEC.md)), taken from the corner pin as written at that instant, without its tracking, as a shape placed by its area gives its area.

### The homography

A **homography** of the plane maps a point (x, y) to (x', y'):

```
x' = (a x + c y + tx) / w
y' = (b x + d y + ty) / w          w = g x + h y + i
```

It is written `[a, b, c, d, tx, ty, g, h, i]`, the order of the display list's `transform` ([FRAMES-20](../FRAMES-20/SPEC.md)) with the three numbers of w after it, and it is the matrix `[[a, c, tx], [b, d, ty], [g, h, i]]` acting on (x, y, 1). Two matrices that differ by a factor other than 0 give the same map. With g = h = 0 it is affine.

**Strict convexity.** A quadrilateral q₀, q₁, q₂, q₃ (top left, top right, bottom right, bottom left) is **strictly convex** when its four turns, with indices taken modulo 4,

```
z_k = (x_{k+1} - x_k) (y_{k+2} - y_{k+1}) - (y_{k+1} - y_k) (x_{k+2} - x_{k+1})        k = 0, 1, 2, 3
```

are all above 0 or all below 0. All above 0 runs clockwise in y-down pixels, and all below 0 is that quadrilateral mirrored, as a negative scale mirrors a clip ([FRAMES-1](../FRAMES-1/SPEC.md)). Every three of its four corners are three consecutive ones, so a strictly convex quadrilateral has no three corners on one line.

**The square to a quadrilateral.** S(q) is the homography that takes the corners of the unit square, (0, 0), (1, 0), (1, 1), (0, 1), to q₀, q₁, q₂, q₃, with i = 1. For q strictly convex it is:

```
Δx₁ = x₁ - x₂      Δx₂ = x₃ - x₂      Σx = x₀ - x₁ + x₂ - x₃
Δy₁ = y₁ - y₂      Δy₂ = y₃ - y₂      Σy = y₀ - y₁ + y₂ - y₃
D   = Δx₁ Δy₂ - Δx₂ Δy₁

g  = (Σx Δy₂ - Δx₂ Σy) / D          h  = (Δx₁ Σy - Σx Δy₁) / D
a  = x₁ - x₀ + g x₁                 b  = y₁ - y₀ + g y₁
c  = x₃ - x₀ + h x₃                 d  = y₃ - y₀ + h y₃
tx = x₀                             ty = y₀                    i = 1
```

**Note.** The closed form solves the eight unknowns from the four point pairs, two equations a pair. (0, 0) to q₀ gives w = 1, tx = x₀ and ty = y₀. (1, 0) to q₁ gives w = 1 + g, so x₁ (1 + g) = a + x₀ and y₁ (1 + g) = b + y₀. (0, 1) to q₃ gives w = 1 + h, so x₃ (1 + h) = c + x₀ and y₃ (1 + h) = d + y₀. (1, 1) to q₂ gives w = 1 + g + h, so x₂ (1 + g + h) = a + c + x₀, which with a and c put in is g (x₁ - x₂) + h (x₃ - x₂) = x₀ - x₁ + x₂ - x₃, that is g Δx₁ + h Δx₂ = Σx, and from y the same, g Δy₁ + h Δy₂ = Σy. Cramer's rule on these two gives g and h, and they give a, b, c and d. D is 0 only where q₁, q₂ and q₃ lie on one line. Σx = Σy = 0 exactly where q is a parallelogram (q₀ + q₂ = q₁ + q₃), and then g = h = 0 and S(q) is the affine map of the parallelogram.

**From one quadrilateral to another.** For strictly convex p and q, **H(p → q)** is the one homography that takes p₀, p₁, p₂, p₃ to q₀, q₁, q₂, q₃: the matrix S(q) × S(p)⁻¹, divided by its w at the centroid of p, p̄ = (p₀ + p₁ + p₂ + p₃) / 4, so that w is 1 there. Its w then has one sign over the inside of p exactly when q is strictly convex, and it is above 0 there, so H(p → q) takes the inside of p onto the inside of q without passing through infinity. For a q that is not strictly convex, part of p would go through infinity and the picture would fold.

**Note.** w is scaled at the centroid and not by i = 1 because a homography between two strictly convex quadrilaterals can send the origin of the media's pixels to infinity, and then its i is 0 and no form with i = 1 writes it. The centroid lies inside p, where w is never 0.

### What stops and what draws nothing

The **corner pin's map** at t, K(t), is H(B → Q(t)), from the corners of the clip's box B, `[0, 0, w, h]` with its origin at the box's top left, to the corner pin Q(t) as the clip's item draws it at t ([A tracked corner pin](#a-tracked-corner-pin)). What the clip draws reaches past its box, by a stroke, an outset or a shadow, and evaluation draws it inside D(t), the bounds of what it draws in its box coordinates ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)).

- A corner pin, written or found, at a keyframe's time, or at the clip's instant ([FRAMES-2](../FRAMES-2/SPEC.md)) for a static one, that is not strictly convex stops at `resolve`, naming the place and the time. So does one whose map carries the four corners of D at that time to a quadrilateral that is not strictly convex, since part of what the clip draws would pass through infinity.
- A corner pin sampled at t, between keyframes after its ease or carried by a track, whose map does not carry the corners of D(t) to a strictly convex quadrilateral draws nothing at that instant, as a scale of 0 draws nothing. On either side of such an instant the clip draws as its values say.
- A tracked frame whose quadrilateral is not strictly convex is not followed ([FRAMES-12](../FRAMES-12/SPEC.md)), for every tracked clip.

### A tracked corner pin

A clip with a corner pin follows its parent's media, and `true` follows its corner pin ([FRAMES-12](../FRAMES-12/SPEC.md)). On each frame followed, the track has its motion M, the similarity of [FRAMES-12](../FRAMES-12/SPEC.md), and its homography H, which takes the target's quadrilateral to that frame's, H(target → quad). At an instant τ of the clip, M(τ) and H(τ) are those of the media frame the tracked media shows at τ, as for every tracked value.

- **A corner pin is where it is at its own time**, as every tracked value is. Each keyframe's corner pin Q_k, at its time τ_k, is brought back through H(τ_k)⁻¹, corner by corner. The brought-back corner pins interpolate between keyframes as [FRAMES-4](../FRAMES-4/SPEC.md) says, giving Q'(t), and the corner pin at t is H(t) applied to each corner of Q'(t), in the clip's coordinate space. A static corner pin is one keyframe at the clip's instant. So a corner pin written on one frame with its corners on a screen's corners stays on them on every frame followed, whichever tracker or track data gave the quadrilaterals.
- **The motion stays the moving parent.** The clip's transform holds M(t), as every tracked clip's does ([FRAMES-10](../FRAMES-10/SPEC.md)), so its children follow it as they follow a tracked shape. The corner pin is drawn inside that transform as Q(t) = M(t)⁻¹ H(t) applied to each corner of Q'(t), the part of the homography the motion does not carry, and the clip's animation acts in that space, about the centre of the bounding box of Q(t). An untracked corner pin is drawn as written, Q(t) its keyframes interpolated at t.
- Where every quadrilateral of the track is a similarity image of the target, as the `point` tracker reports, H is M, the corner pin is drawn as Q'(t), and a tracked corner pin moves as a tracked shape placed by its area moves.

```json
{ "id": "phone", "media": "/abs/broll/phone.mov", "in": 0, "out": 6,
  "connected": [
    { "id": "screen", "at": [0, 6], "parent": "phone", "media": "/abs/ui/app-demo.mov",
      "cornerPin": [ [812, 304], [1131, 352], [1102, 918], [779, 861] ],
      "track": { "time": 0,
                 "target": [ [812, 304], [1131, 352], [1102, 918], [779, 861] ],
                 "frames": [ { "time": 0, "quad": [ [812, 304], [1131, 352], [1102, 918], [779, 861] ] },
                             { "time": 0.04, "quad": [ [815, 302], [1133, 355], [1103, 921], [781, 862] ] } ] } } ] }
```

A recording of an app is placed on a phone's screen in the shot, its corner pin written on the shot's first frame in the shot's media pixels, and the track data of a planar tracker run outside frames, cut short here, keeps it on the screen as the phone turns. With `"track": true` in place of the data, the tracker provider follows the corner pin itself.

## Interactions

Placement and a clip's box are [FRAMES-1](../FRAMES-1/SPEC.md), points and clip areas [FRAMES-2](../FRAMES-2/SPEC.md), keyframes [FRAMES-4](../FRAMES-4/SPEC.md), keys [FRAMES-7](../FRAMES-7/SPEC.md). A clip with a corner pin gives its children the space its corner pin is written in ([FRAMES-10](../FRAMES-10/SPEC.md)), and its masks stay in its own space, carried with its picture ([FRAMES-11](../FRAMES-11/SPEC.md)). The track, its homography, track data and lost frames are [FRAMES-12](../FRAMES-12/SPEC.md). Its animation is [FRAMES-14](../FRAMES-14/SPEC.md). The resolved document writes the corner pin and each track frame's homography ([FRAMES-19](../FRAMES-19/SPEC.md)). Evaluation draws a clip with a corner pin as a group whose `picture` carries a `cornerPin` ([FRAMES-20](../FRAMES-20/SPEC.md)), and the renderer draws it ([FRAMES-21](../FRAMES-21/SPEC.md)). `evaluate` and `locate` report the items of a clip with a corner pin ([FRAMES-23](../FRAMES-23/SPEC.md)).

## Alternatives considered

A projective `transform` on every display list item, nine numbers in place of six: every renderer would draw strokes, glyphs, masks and feathers under a projective map, which Core Graphics and SVG draw under affine maps only, when only a picture needs to be carried onto a quadrilateral. `cornerPin` is a field of a `picture`, and a clip with a corner pin is drawn as a group, so its strokes, glyphs and masks are drawn flat in its box and carried with its picture.

Corner pins in the clip's box coordinates with its `position`, `scale` and `rotation` applied after them: two ways to place one clip, and a picture placed on a moving screen is written where the screen is, in its parent's space, not where a transform will take it.

Lengths, strokes and shadows drawn after the corner pin, in output pixels: a stroke around a card with a corner pin would keep one width while the card's far edge shrinks, and a shadow would fall off the plane it belongs to. Drawn in the box and carried with the picture, they lie on the plane as the picture does.

The homography for every tracked value (points, areas, masks, crops): rectangles and boxes would stop being rectangles, a path and a rect on one target would disagree, and P(t) would stop being affine ([FRAMES-10](../FRAMES-10/SPEC.md)). A shape that must follow perspective is put in a compound clip with a corner pin.

A bilinear map of the four corners, as Fusion's Corner Positioner offers beside its perspective mapping: it bends straight lines, so a screen's straight edges and the lines inside it would curve, and it is not the map a plane seen through a camera takes.

A corner pin of three points with the fourth computed so that the sides stay parallel: that is an affine map, which a compound clip already gives ([FRAMES-1](../FRAMES-1/SPEC.md)), and four points hold it as the case Σx = Σy = 0.

Corner pins that are not strictly convex drawn anyway, folded or cut at the horizon: the picture would pass through infinity, which no plane in a shot does, so such a corner pin is not a placement of a picture and stops, or draws nothing between keyframes.

## Notes

**Note.** A renderer draws a picture with a corner pin by warping a raster of its nested list ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)). The area factor of a homography over a convex region is largest at a corner, since w is linear there, but the factor along one direction can be largest inside it, so a renderer bounds the raster's scale over the whole of `dest`, not at its corners only. Core Image's `CIPerspectiveTransform` takes the four corners a picture goes to, which is the form `cornerPin` gives.

**Note.** How cleanly a warp draws a picture's edges and a fine pattern at steep foreshortening, and how much a 4K compound clip with a corner pin costs to raster and warp, are measured on the renderer and decide nothing here.
