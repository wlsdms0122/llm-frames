# FRAMES-6: Documents, image and layout

Status: accepted

## Summary

The three document kinds, and the two that make one picture: an image document, an ordered list of operations on a source, and a layout, pictures on a grid.

## Motivation

A screenshot with boxes and a band of text is the most common still result. Writing every area in the source's own coordinates and mapping them through the canvas operations lets an agent point at text it found without following how crops and resizes moved it.

## Rules

### Documents

Every document is a JSON object with a `kind` of `image`, `layout` or `sequence`. A document may carry a `theme` (a theme object, or a theme file, `<pack>/<name>` or an absolute path), which is merged over the theme in effect ([FRAMES-22](../FRAMES-22/SPEC.md)), and `params`, which make it a template ([FRAMES-17](../FRAMES-17/SPEC.md)).

### image document

An image document edits one picture with an ordered list of operations.

```json
{
  "kind": "image",
  "source": "/abs/shot.png",
  "ops": [
    { "crop": { "band": { "from": "Certificate", "to": "Last line" } } },
    { "shape": "fill", "area": "issuerDn:", "color": "#000000" },
    { "shape": "box", "area": "serialNumber: 9190809", "label": "matches the server" },
    { "shape": "dim", "area": { "from": "LV2", "to": "Cert,O=" } },
    { "shape": "arrow", "area": "serialNumber", "side": "right", "label": "here" },
    { "resize": { "width": 800 } },
    { "pad": [20, 40], "color": "#FFFFFF" },
    { "banner": [ { "text": "Bold first line", "style": "bannerHead" }, "Regular line" ], "edge": "top" },
    { "border": true }
  ]
}
```

- `source` is any media reference that gives a picture. For a video, `time` picks the frame in media seconds.
- **Every area and point is written in the media coordinates of `source`.** frames maps them through the canvas operations before them.
- Text areas are found in the source picture and grow by their padding in the source's pixels. A band spans the width of the canvas at its operation.
- `crop`, `resize`, `pad` and `banner` change the canvas. `shape`, `adjust`, `title` and `border` draw on it. Operations run in order, as layers.
- A canvas is whole pixels. A crop keeps every pixel its area touches, a resize rounds both sides of its target size to the nearest pixel and never below 1, and a banner band's height is rounded up.
- A banner band is filled with the theme `background`. `image.bannerPadding` is the room around the banner text on every side, and each line is placed by its style's alignment.
- A drawing is made on the canvas as it is at its operation, with theme lengths scaled by the canvas width at that point, and is clipped to that canvas. Later canvas operations move and scale it with the picture. Later pads and banners add room around it but never reveal what was clipped.
- A drawing wholly outside the canvas at its operation stops. A label's room is measured on the canvas at its shape's operation.
- Coordinates outside the source picture reach into pads and banners only for drawings after those operations, so a title at `y: -20` after a top pad sits in that pad.
- `adjust` is an adjustment layer: it changes everything drawn before it, inside its area or over the whole canvas, so a box drawn before a pixelate is pixelated and a box drawn after it is not.
- Any op may carry an `id` and `metadata` ([FRAMES-7](../FRAMES-7/SPEC.md)).
- Wherever a picture is taken (a layout item, a storyline clip, a connected clip), an image document can stand in for a path.

| op | Keys | What it does |
| --- | --- | --- |
| `crop` | area | Keeps the area, clipped to the picture |
| `resize` | `{scale}`, `{width}` or `{height}`, above 0 | Resizes to a target size that keeps the aspect ratio, each side rounded to the nearest pixel and never below 1. The canvas and everything on it map onto that size, one factor per axis, and a length already drawn scales by the horizontal one |
| `pad` | `n`, `[vertical, horizontal]` or `[top, right, bottom, left]`, in whole pixels of the canvas at that operation, 0 or more, `color` optional | Adds a margin. The default colour is the theme `background` |
| `shape` | `box`, `fill`, `dim` or `arrow`, with `area`, `side` for an arrow, and `id`, `label`, `color` optional | Draws a shape ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| `adjust` | filter preset, `area` optional | Applies a filter preset to everything drawn before it, inside the area when one is given |
| `title` | text, `position` (media `[x, y]` or a point of an area) and `style`, with `anchor` and `width` optional | Places a title ([FRAMES-11](../FRAMES-11/SPEC.md)), its anchor point at `position` as on a sequence ([FRAMES-1](../FRAMES-1/SPEC.md)). `width` is in media pixels of `source`, and defaults to the width of the canvas at that operation minus twice the placement padding |
| `banner` | lines and `edge` (`top` or `bottom`), both needed | Extends the picture with a band as tall as its text. A line is a string, in the `banner` style, or `{text, style}` |
| `border` | `true` (the `border` colour) or a colour | Draws a border around the picture with the theme `shapes.border.width` |

### layout document

A layout places pictures on a grid.

```json
{
  "kind": "layout",
  "banner": [ { "text": "Bold first line", "style": "bannerHead" }, "Regular line" ],
  "columns": 2,
  "border": true,
  "items": [
    { "heading": "Before", "image": { "kind": "image", "source": "/abs/before.png", "ops": [ { "shape": "box", "area": "9190799" } ] } },
    { "heading": "After", "image": "/abs/after.png" }
  ]
}
```

- Without `columns`, every item goes on one row. A layout with no items stops, and so do `columns` below 1.
- Every column is as wide as the widest item, and every row is as tall as the tallest item in it. An item is centred in its cell.
- `layout.padding` is the room around the grid, and `layout.gap` the room between cells and between rows. The canvas is filled with the theme `background` first.
- `border` is `true` (the `border` colour), a colour, or `false`, and draws a border just outside every cell with `shapes.border.width`. The default is `true`.
- `heading` sits above its cell in the `heading` style, and the headings above a row take the height of its tallest heading.
- `banner` is a band above the grid, styled as in the image `banner` operation.

## Interactions

Shapes are drawn as [FRAMES-11](../FRAMES-11/SPEC.md) says. Text areas are [FRAMES-2](../FRAMES-2/SPEC.md). Either document can stand where a picture is taken ([FRAMES-3](../FRAMES-3/SPEC.md)).

## Alternatives considered

Making an image a one-frame sequence: the canvas of an image document grows with pads and banners, which a sequence's fixed format does not.

## Notes
