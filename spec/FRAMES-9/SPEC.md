# FRAMES-9: Format, storyline clips and lanes

Status: accepted

## Summary

The format of the output (size, rate, background, conform, colour space, peak, compositing), how a storyline clip shows its crop in the frame and takes a transform, how a window smaller than the frame is made, and how lanes stack every clip with a picture.

## Motivation

Every picture in an edit is placed in one frame: the main shot, a punch in on it, a picture in picture, a logo. Conforming every crop to the frame's aspect ratio keeps a pan and zoom at one shape while it moves. Giving a storyline clip the transform every other picture has lets a shot be reframed, punched in or tilted where it sits in the edit, without moving it to a lane. A frame with one coordinate space, and a stacking order given by lanes alone, makes what covers what a rule an agent can read off the document instead of a renderer's choice. Where a group of pictures has to act as one (a split screen, a window with its own transitions), a compound clip is that group, as in Final Cut Pro and as a precomposition in After Effects.

## Rules

### Format

`format` holds `size`, `fps`, `background`, `conform`, `colorSpace`, `peak`, `compositing` and `motionBlur`. Everything a sequence measures on its frame is measured on this frame: the output frame of the sequence, or of the compound clip it plays in.

- `size` is `[w, h]`, a content fit object ([FRAMES-6](../FRAMES-6/SPEC.md)), or omitted. Omitted, it is the size of the first video clip on the storyline, or of the first storyline clip when there is no video. Width and height round to even numbers.
- When `size` is omitted, there is no video and the first storyline clip is a solid, which has no size of its own, the format stops.
- `fps` defaults to the nominal frame rate of the first video clip on the storyline, rounded to the nearest of 24, 25, 30, 50 and 60. A rate exactly halfway between two of them rounds to the lower one. It is 30 when that clip has no nominal rate (some variable-rate recordings) or there is no video. A written `fps` is above 0, and 0 or less stops.
- `background` defaults to the theme `background` colour, black in the base theme ([FRAMES-22](../FRAMES-22/SPEC.md)). It is a working value like any other colour ([FRAMES-26](../FRAMES-26/SPEC.md)). It fills the frame below everything, and shows wherever nothing above it covers the frame. A background that is not opaque gives a master with alpha ([FRAMES-21](../FRAMES-21/SPEC.md)).
- `conform` is `fit` (show the whole crop, and leave the rest of the frame transparent) or `fill` (fill the frame and cut what overflows), as an NLE's spatial conform. The default is `fit`.
- `colorSpace` is the sequence's colour space, which decides how its output is encoded and clipped and, by its peak and with each media clip's `toneMap`, whether HDR media are tone mapped and to which peak, `peak` the mastering peak of a `rec2100-pq` sequence in cd/m², and `compositing` (`encoded` or `linear`) the form its form-free formulas are taken in. Their values and defaults are [FRAMES-26](../FRAMES-26/SPEC.md). Inside another sequence a compound clip's `compositing` applies within its frame and its `colorSpace` and `peak` do not apply ([FRAMES-3](../FRAMES-3/SPEC.md)).
- `motionBlur` is the sequence's shutter, `{shutterAngle, shutterPhase, samplesPerFrame}`: how long each frame's exposure lasts, when it opens, and how many pictures of the frame its exposure is the mean of, each with the clips that have motion blur at one instant of it. Its values and defaults are [FRAMES-29](../FRAMES-29/SPEC.md). Inside another sequence a compound clip's `motionBlur` does not apply, and the outermost sequence's shutter is the one every clip it shows takes ([FRAMES-3](../FRAMES-3/SPEC.md)).

### Storyline clips

- `in` defaults to 0 and `out` to the end of the media, here and on media clips. A video, image sequence or compound clip needs `in < out` and `speed > 0`. An `out` past the end of the media is trimmed to the end, and an `in` before 0 is moved to 0. These defaults, and the need for `in < out` and `speed > 0`, hold on every timed media clip, connected and sequence clips and sounds included. On a storyline clip with `timeRemap`, `in` and `out` are clip times that need not lie in the media, so an `out` past the end of the media is kept ([FRAMES-8](../FRAMES-8/SPEC.md)).
- A still or solid clip needs `duration > 0`. `solid` is a colour, and fills the frame.
- An empty storyline stops, and so does a storyline clip whose media holds only sound.
- `crop` is the region of the media shown in the frame. It is an area ([FRAMES-2](../FRAMES-2/SPEC.md)) in the media pixels of the clip's media, or `{scale: s}` for a centred region `1/s` the size of the picture (`s = 1` is the whole picture, and `s` is above 0). It is keyframable, which gives a pan and zoom (Ken Burns). A crop may reach past the edges of the picture, and what lies beyond them is transparent, so an area and the `{scale: s}` that names the same region show the same picture.
- Resolve conforms every crop to the aspect ratio of the clip's box around its centre. `fit` grows it until the written region fits inside, and what lies beyond the picture is transparent: lower lanes and the background show there, and during a transition the other storyline picture does. `fill` shrinks it until it lies inside the written region. The conformed crop is exactly what fills the box, and keyframes between conformed crops keep their ratio.
- A clip without `track` whose crop is static and, once conformed, shows none of its picture is never visible, and it stops.
- A storyline clip with media takes a transform as a media clip does ([FRAMES-1](../FRAMES-1/SPEC.md)): `anchor`, `position`, `scale`, `rotation`, `opacity` and `blend` ([FRAMES-11](../FRAMES-11/SPEC.md)), with `mask` and `trackMatte` ([FRAMES-11](../FRAMES-11/SPEC.md)). Its **box** is the frame, which its conformed crop fills, except under content fit, where it is the pixel size of its crop at the position [FRAMES-6](../FRAMES-6/SPEC.md) gives. The defaults are `position` the centre of the frame (under content fit, the position [FRAMES-6](../FRAMES-6/SPEC.md) gives), `anchor` `center`, `scale` 1, `rotation` 0, `opacity` 1 and `blend` `normal`, so a clip that writes none of them fills its box exactly. A storyline clip takes no `placement` and no `parent`.
- `radius`, `border` and `shadow` act on a storyline picture's box as they do on a media clip's ([FRAMES-11](../FRAMES-11/SPEC.md)): the corners of its box are rounded, the border lies inside it, and the shadow falls below it. They show where the transform leaves the box smaller than the frame or moved within it.
- Each frame of a storyline clip with media is made in this order: take the conformed crop, scale it to its box, apply the filter at that size in output pixels, round its corners and draw its border, then apply its transform, its opacity, its mask and its track matte, then the transition motion ([FRAMES-14](../FRAMES-14/SPEC.md)). The shadow is the picture's shape at that point, drawn below it. So a mask cuts the picture before a transition moves it, and the cut picture leaves with the transition.
- Every storyline clip, a solid included, takes `motionBlur` ([FRAMES-29](../FRAMES-29/SPEC.md)). With it the order above is made in each picture of the frame's exposure at the clip's instant of that picture, the transition motion included, with the media frame of the frame's instant. During a transition each side's switch moves that side's picture, and two sides that both have it meet at the seam in every picture.
- A storyline clip with sound takes `split` ([FRAMES-13](../FRAMES-13/SPEC.md)): its sound starts before its picture or runs on after it, a J or an L cut, while its picture keeps its edit range. A visual media clip with sound takes it too, connected or in `clips`, about its visible window.
- `filter` and `transition` take preset choices ([FRAMES-7](../FRAMES-7/SPEC.md)). `"none"` turns off a default filter for one clip, and `"cut"` turns off a default transition.
- Every storyline kind with media takes crop, filter, transform, mask, track matte and transition the same way. A solid takes a transition and keyframes of its colour only ([FRAMES-4](../FRAMES-4/SPEC.md)), and fills the frame.

### Windows and compound clips

A window smaller than the frame (a 16:9 picture inside a 9:16 frame, each half of a split screen, a picture that carries its own transitions inside a larger edit) is a compound clip of that size ([FRAMES-3](../FRAMES-3/SPEC.md)) placed with a transform: as a media clip on a lane, or as a storyline clip under `fit`, which conforms its whole frame into the outer one. Its conform, its transitions and the stacking of its clips happen inside the compound clip, on its own frame.

A compound clip is also how a group of pictures acts as one. A clip that should leave with a picture in a wipe or a dissolve, a blend that should reach only one picture, and an adjustment that should reach only some clips are put in a compound clip with what they act on. Its picture then moves, fades, wipes and blends as one, and an adjustment inside it reaches only the clips inside it. Its clips are composited inside it by its own `compositing`, and its picture onto the frame that shows it by that frame's ([FRAMES-26](../FRAMES-26/SPEC.md)).

### Lanes and stacking

The storyline is lane 0. Every other clip with a picture has a lane: a non-zero integer, 1 unless `lane` says otherwise. Negative lanes are below the storyline, positive lanes above it, and a higher lane is above a lower one. A `lane` of 0 stops. Audio-only clips have no lane.

From the bottom, a frame is:

```
background
< clips on negative lanes, lowest lane first
< the storyline
< clips on positive lanes, lowest lane first
```

- The storyline is the storyline picture at t. During a transition it is both storyline pictures, the incoming one above the outgoing one, or the outgoing one above for a preset with `"over": "outgoing"` ([FRAMES-14](../FRAMES-14/SPEC.md)), and then the transition cover above both.
- Within a lane, clips stack in document order: the connected clips of each storyline clip in storyline order, each storyline clip's in its own order, then the sequence clips in order.
- A clip's place in the stack is its own. Its parent ([FRAMES-10](../FRAMES-10/SPEC.md)) moves it and does not change its lane or its order.
- A clip used as another clip's track matte is not drawn and takes no place in the stack ([FRAMES-11](../FRAMES-11/SPEC.md)).
- Motion blur leaves the stack as it is: a frame with motion blur is the mean of pictures of the whole frame, each stacked and composited as here, with the clips that have `motionBlur` at one instant of the exposure ([FRAMES-29](../FRAMES-29/SPEC.md)).
- Each clip is composited onto what is below it by its `blend`, in the form the sequence's `compositing` names ([FRAMES-26](../FRAMES-26/SPEC.md)), and an adjustment clip filters everything below it in its frame ([FRAMES-11](../FRAMES-11/SPEC.md)).

## Interactions

Placement, anchor points and the frame's units are [FRAMES-1](../FRAMES-1/SPEC.md). Content fit is [FRAMES-6](../FRAMES-6/SPEC.md). Compound clips are [FRAMES-3](../FRAMES-3/SPEC.md). Time and `timeRemap` are [FRAMES-8](../FRAMES-8/SPEC.md). Parenting is [FRAMES-10](../FRAMES-10/SPEC.md). Blend modes, masks, track mattes and media clip boxes are [FRAMES-11](../FRAMES-11/SPEC.md). Transitions are [FRAMES-14](../FRAMES-14/SPEC.md). Filters are [FRAMES-15](../FRAMES-15/SPEC.md). Display list items are [FRAMES-20](../FRAMES-20/SPEC.md). Colour spaces and compositing are [FRAMES-26](../FRAMES-26/SPEC.md).

## Alternatives considered

A storyline drawn in a region of the frame smaller than the frame, set in the format: it gives a sequence two spaces to measure in, and every placement, offset and transition would have to say which. A window is a compound clip of its size placed with a transform, which is how an NLE nests one edit in another.

Grouping a storyline picture with the clips on it, composited and transitioned together: it makes a clip's stacking depend on what it is attached to, and a lane mean one thing inside such a group and another outside it. Lanes alone order the frame, and a compound clip is the group where one is wanted.

A storyline that takes no transform, so a reframed shot is moved to a lane: the shot would leave the storyline, its transitions and its connected clips. A transform on the storyline clip keeps it there, as Final Cut Pro's transform on a primary storyline clip does.

## Notes
