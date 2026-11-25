# FRAMES-6: Documents and stills

Status: accepted

## Summary

What a document is (one kind, `sequence`, with its theme and parameters), that a still result is a sequence rendered as one frame, and content fit: a frame whose size is measured from the pictures in it, as an image editor's "reveal all".

## Motivation

A still and a video are edited with the same tools in an NLE: a poster frame, a thumbnail, a frame grab with a title, and a cut with transitions all crop, place, mask and title pictures the same way. One document kind means every tool, every check (`still`, `sheet`, `timeline`) and every pack works on both, and a still made once can play as a compound clip in a video, or a frame of a video can be delivered as a PNG, without a second model to learn or to keep in step. A fixed frame size is the right default for video, where the delivery format sets it. A still often has no size of its own until its pictures are placed (a logo with a margin round it, two pictures side by side, a cropped photo with a caption below), and measuring that by hand breaks whenever a crop or a picture changes, so the frame can be measured from its content.

## Rules

### Documents

Every document is a JSON object with a `kind`. `kind` is required and its only value is `"sequence"`. A document without `kind`, or with any other value, stops. Its keys and their shape are [FRAMES-7](../FRAMES-7/SPEC.md).

- A document may carry a `theme` (a theme object, or a theme file, `<pack>/<name>` or an absolute path), which is merged over the theme in effect ([FRAMES-22](../FRAMES-22/SPEC.md)).
- A document may carry `params`, which make it a template ([FRAMES-17](../FRAMES-17/SPEC.md)).
- A document is rendered alone, plays as media in another document as a compound clip ([FRAMES-3](../FRAMES-3/SPEC.md)), or is instantiated as a template.

### Stills

A still result is a sequence rendered as one frame. `render` with a `.png` output writes the frame at `--at <t>` in sequence seconds, default 0 ([FRAMES-23](../FRAMES-23/SPEC.md)). Any sequence gives a still. A sequence made to be one is, for example, a single still storyline clip with clips connected to it.

A still is edited as a sequence of still clips, with the keys a video uses:

| Edit | In a sequence |
| --- | --- |
| crop | the storyline clip's `crop` ([FRAMES-9](../FRAMES-9/SPEC.md)) |
| resize | `format.size`, which the storyline picture is scaled to |
| pad | `format.size` larger than the picture, with the clip's transform (`scale`, `position`), or a content fit `margin` (below) |
| border | the clip's `border` ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| draw on the picture (a title, a shape, a filter over a region) | connected title, shape and adjustment clips, parented to the picture where they should follow it ([FRAMES-10](../FRAMES-10/SPEC.md)) |
| pictures side by side | media clips placed by `position`, under a written size or content fit |

```json
{
  "kind": "sequence",
  "format": { "size": { "fit": "content", "margin": [48, 64] }, "background": "#F4F1EA" },
  "storyline": [
    { "kind": "media", "media": "/abs/harbour.jpg", "duration": 1, "crop": [0, 220, 3000, 2000],
      "connected": [
        { "kind": "media", "media": "/abs/logo.png", "width": 360, "anchor": "top-right", "position": [2952, 48] },
        { "kind": "title", "text": "Harbour at dawn", "style": "title", "width": 1800, "anchor": "bottom-left", "position": [96, 1904] } ] }
  ]
}
```

The crop gives a 3000 by 2000 picture with its top left at the origin, the logo and the title lie inside it, and the margin makes the frame 3128 by 2096. `render still.json -o still.png` writes it.

### Content fit

`format.size` ([FRAMES-9](../FRAMES-9/SPEC.md)) takes one of three forms:

| Form | Frame |
| --- | --- |
| `[w, h]` | that size |
| omitted | the default of [FRAMES-9](../FRAMES-9/SPEC.md) |
| `{"fit": "content", "margin": m}` | measured from the content, below |

- `fit` is required in the object form and its only value is `"content"`. The object takes no other key.
- `margin` is optional and defaults to 0. It is `n` (every side), `[v, h]` (top and bottom, left and right) or `[t, r, b, l]`, in the order CSS writes them, in whole output pixels. Each value is a whole number 0 or more, and any other stops.

Under content fit the frame is measured in a **measuring space**: output pixels before the frame exists, which every unparented clip's coordinates are written in. Each clip with a picture is placed in it as follows.

- **Storyline pictures.** A storyline clip with a picture of its own (video, still, image sequence, compound clip) has a box the pixel size of its crop at scale 1: the crop's width and height in media pixels (a page's points, which may be fractions, [FRAMES-1](../FRAMES-1/SPEC.md#units)), the media's size when it has no crop, the media's size divided by `s` for `{scale: s}`, and a compound clip's own frame size as its media size. Before its transform, that box has its top left at the origin, so the clip's default `position` is its anchor point on that box and a clip with no transform covers `[0, 0, w, h]`. The picture is drawn at that box, not scaled to the frame. A crop at another time is conformed to that box's aspect ratio by `format.conform` and fills it, as a media clip's crop fills its box ([FRAMES-11](../FRAMES-11/SPEC.md)).
- **Media clips.** A media clip's box follows its `width` and `height` as [FRAMES-11](../FRAMES-11/SPEC.md) says. Given neither, it is the pixel size of its first crop, or of its media, at scale 1, in place of being fitted to the frame.
- **Placement.** `placement` names the frame ([FRAMES-1](../FRAMES-1/SPEC.md#placement)), here the measured frame with its margin. A clip with a box of its own is placed by `placement` or by `position` as on a frame of a written size: by its own `placement`, or, when it writes no `position`, by its text style's, with that style's `offset`. A clip placed by `placement` depends on the frame, so it is not measured and is placed on the measured frame once that exists (rules 3 and 6). A parented clip with a box of its own needs `position` here as on any frame.
- **Default positions.** A clip with a box of its own that writes no `position` and takes no `placement` (a media clip or a rect or ellipse, whose default `center` would name the frame, or a title whose style gives none) sits with its box's top left at the origin, and is measured.
- **Boxes and lengths.** A title's box does not depend on the frame: it is its `width`, or fitted to its text without one ([FRAMES-5](../FRAMES-5/SPEC.md)). Theme lengths are scaled by the length scale of [FRAMES-1](../FRAMES-1/SPEC.md), which a content-fit sequence takes from its first storyline picture, so the `placement.padding` and a style's `offset` that place a clip on the measured frame take it too.

The frame is the bounding box of what is measured, plus the margin:

1. Each measured clip's extent is taken at sequence time 0, on the clip's own clock ([FRAMES-8](../FRAMES-8/SPEC.md)), whether or not the clip is visible then: its keyframed values at that instant (a property whose first keyframe is later holds that keyframe's value), its parent's geometry at that instant ([FRAMES-10](../FRAMES-10/SPEC.md)), and no animation and no transition motion, as `geometry(clip, t)` gives it ([the specification's shape of the system](../README.md#shape-of-the-system)).
2. A clip's extent is the axis-aligned bounding box, after its transform, of: its box for a storyline picture or a media clip; its text box, its background and its runs' highlights and underlines included, for a title; its outline with its stroke as drawn, its miter joins, square caps and arrowheads included, each head as drawn at its scale, for a shape. Masks, track mattes, borders, shadows and opacity do not change an extent, a border its `align` lays outside the box or across its edge included ([FRAMES-11](../FRAMES-11/SPEC.md)), as a shadow cast past the box is: a picture's extent is its box.
3. What is not measured: solid storyline clips (a solid fills the frame), adjustment clips (they apply to the frame), a clip placed by `placement` (it is placed on the frame) and every clip placed from one, at any depth: a clip parented to it ([FRAMES-10](../FRAMES-10/SPEC.md)) and a clip whose `area`, `points`, `position` or `cornerPin` takes its box through a clip area ([FRAMES-2](../FRAMES-2/SPEC.md#clip-areas)); audio clips; and a clip used as another clip's track matte (it is not drawn).
4. The union of every extent is `[x0, y0, x1, y1]`. It is rounded outward to whole pixels: `X0 = floor(x0)`, `Y0 = floor(y0)`, `X1 = ceil(x1)`, `Y1 = ceil(y1)`.
5. The frame is `X1 - X0 + l + r` wide and `Y1 - Y0 + t + b` tall, with `t, r, b, l` the margin, each side rounded up to an even number, the extra pixel on the right or the bottom.
6. Everything is moved by `(l - X0, t - Y0)`, so the content's top left lies at `(l, t)` with the margin round it. An unparented clip's written coordinates are measuring-space coordinates and are drawn moved by that offset. A clip placed by `placement` is placed on the measured frame, where its placement puts it on any frame of that size, and is not moved again. What is placed from it follows it: its children are in its space, and a clip area takes its box where it is placed.

- A content-fit sequence where nothing is measured stops, since it has no frame. Every storyline picture is measured, so this is a sequence whose storyline is all solids, however its other clips are placed.
- Every other rule that names the frame (transition offsets, the frame its clips are drawn on, the output size the encoder writes) uses the measured frame once it exists.
- A compound clip whose sequence uses content fit has the measured size as its own frame size ([FRAMES-3](../FRAMES-3/SPEC.md)).

**Note.** The extent is measured once, at time 0, as "reveal all" measures layers where they are. A clip keyframed or animated to move later can leave the frame and is cut at its edge like any picture outside a frame. A still rendered at `--at 0`, the default, shows every clip where it was measured.

**Note.** Rounding the union outward before the margin is added keeps a picture whose edges lie on whole pixels on whole pixels after the move, so a cropped photo under content fit is not resampled. A page of a PDF has no pixels to keep there: it is drawn at the size it is shown at, and its box, in points, is measured and rounded as any extent is.

## Interactions

A document's keys are [FRAMES-7](../FRAMES-7/SPEC.md), its format and storyline [FRAMES-9](../FRAMES-9/SPEC.md). A document as media is [FRAMES-3](../FRAMES-3/SPEC.md). `render`, `--at` and `still` are [FRAMES-23](../FRAMES-23/SPEC.md). Templates are [FRAMES-17](../FRAMES-17/SPEC.md). The length scale and placement are [FRAMES-1](../FRAMES-1/SPEC.md), clip areas [FRAMES-2](../FRAMES-2/SPEC.md), parents [FRAMES-10](../FRAMES-10/SPEC.md). Clip boxes are [FRAMES-11](../FRAMES-11/SPEC.md), text boxes [FRAMES-5](../FRAMES-5/SPEC.md).

## Alternatives considered

A separate image document kind, an ordered list of operations on one picture (crop, resize, pad, draw): it is a second editing model beside the sequence, with its own coordinates and its own rules for what a later operation does to an earlier drawing, and every tool and check would have to learn both. A still as a one-frame sequence uses the clip keys any editor already knows, and content fit gives the frame that grows with its content, which is what a separate kind would be for.

A layout document kind, pictures on a grid with headings: a grid is one arrangement among many, the kind of shape a purpose takes. Media clips placed by `position`, and a template or a pack that writes them, make any arrangement.

Content fit as the default: a frame that changes size when a clip moves would surprise every video edit, and delivery formats fix the size. A written or default size is the NLE default, and content fit is chosen, as an image editor's "reveal all" or "canvas size to fit" is.

Stopping on a style's `placement` under content fit, as on a written one: a style that places its titles could not be shared between a sequence of a written size and a content-fit one, and a clip meant to sit at the bottom of the frame would have no way to say so. A clip placed by `placement` is placed on the frame as on any other, and is left out of what measures it, as a solid and an adjustment clip are.

Resolving `placement` against the first storyline picture's box, the frame a content-fit sequence is planned on before it is measured: `placement` would name that box under content fit and the frame everywhere else, two different things under one name, and a `bottom` title would sit inside the picture and not at the bottom of the frame its margin makes.

A picture's border in its extent where its `align` lays it outside the box: a picture's extent would then be its box on one side of a theme's border and more on the other, while the shadow drawn past the same box is not measured. A picture's extent is the box its position and its clip areas name, and the margin holds what is drawn about it.

Measuring the frame over the whole timeline: the frame would depend on every keyframe and animation, and a still with an entrance would be sized by where the entrance starts. Measuring once at time 0 without animation sizes the frame by where things are placed.

## Notes
