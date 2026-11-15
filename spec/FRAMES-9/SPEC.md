# FRAMES-9: Format, storyline clips and lanes

Status: accepted

## Summary

The format of the output (size, rate, background, inset, conform), how a storyline clip shows its crop in the content rect, and how lanes and compositing units stack.

## Motivation

Vertical shorts and evidence shots need a content rect smaller than the frame, and crops that keep one aspect ratio while they zoom. Stacking by lane, with each storyline picture and its parented clips as one unit, makes what covers what a rule instead of a renderer's choice.

## Rules

### Format

- `size` defaults to the size of the first video clip on the storyline, or the first storyline clip when there is no video. Width and height round to even numbers.
- `fps` defaults to the nominal frame rate of the first video clip on the storyline, rounded to the nearest of 24, 25, 30, 50 and 60. It is 30 when that clip has no nominal rate (some variable-rate recordings) or there is no video.
- `background` defaults to the theme `background`. Transparent parts of storyline pictures show it.
- `inset` is `[top, right, bottom, left]` and shrinks the content rect, where storyline clips are drawn. An inset that leaves no content rect stops.
- `conform` is `fit` (show the whole crop, fill the rest with the background) or `fill` (fill the content rect and cut what overflows), as an NLE's spatial conform. The default is `fit`.
- Outside the content rect is always the background. A cropped, filled or moving storyline clip never shows outside it.

### Storyline clips

- `in` defaults to 0 and `out` to the end of the media, here and on media clips. A video, image sequence or compound clip needs `in < out` and `speed > 0`. An `out` past the end of the media is trimmed to the end.
- A still or solid clip needs `duration > 0`. `solid` is a colour, and fills the content rect.
- An empty storyline stops, and so does a storyline clip whose media holds only sound.
- `crop` is the region of the media shown in the content rect. It is an area, or `{scale: s}` for a centred region `1/s` the size of the picture (`s = 1` is the whole picture). It is keyframable, which gives a pan and zoom (Ken Burns).
- Resolve conforms every crop to the aspect ratio of the content rect around its centre. `fit` grows it until the written region fits inside, and what lies beyond the picture is transparent: lower lanes and the background show there, and during a transition the other unit does. `fill` shrinks it until it lies inside the written region. The conformed crop is exactly what fills the content rect, and keyframes between conformed crops keep their ratio.
- Each frame of a storyline clip is made in this order: take the conformed crop, scale it to the content rect, apply the filter at that size in output pixels, then apply the transition motion.
- `filter` and `transition` take preset choices. `"none"` turns off a default filter for one clip, and `"cut"` turns off a default transition.
- Every storyline kind with a picture takes crop, filter and transition the same way. A solid takes a transition only.

### Lanes and stacking

The storyline is lane 0. Every other clip with a picture has a lane: a non-zero integer, 1 unless `lane` says otherwise. Negative lanes are below the storyline, positive lanes above it. A `lane` of 0 stops.

A storyline clip's picture and its parented clips form one compositing unit: the parented clips on negative lanes right before the picture, then the picture, then the parented clips on positive lanes, each side by lane and then in document order. From the bottom:

```
background < unparented clips on negative lanes < storyline units < transition cover
           < background outside the content rect < unparented clips on positive lanes
```

- During a transition the incoming unit is above the outgoing one. A preset with `"over": "outgoing"` puts the outgoing unit above.
- Unparented clips stack by lane, and within a lane in document order: storyline clips in order, each with its unparented connected clips in order, then the sequence clips in order.
- Audio-only clips have no lane.
- A lane orders a clip among the clips it is composited with: a parented clip within its unit, as a nested sequence's lanes order its own clips, and an unparented clip within the sequence.

## Interactions

Parenting is [FRAMES-10](../FRAMES-10/SPEC.md). Transitions are [FRAMES-14](../FRAMES-14/SPEC.md). Filters are [FRAMES-15](../FRAMES-15/SPEC.md).

## Alternatives considered


## Notes
