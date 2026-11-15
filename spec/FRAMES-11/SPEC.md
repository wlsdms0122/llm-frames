# FRAMES-11: Titles, shapes, media and adjustment clips

Status: draft

## Summary

The clip kinds that draw on a sequence: titles, the four shapes and their labels, media clips (picture in picture and graphics made elsewhere), adjustment clips, and blend modes.

## Motivation

Titles and shapes are the basics of any NLE and the core of evidence shots. Their geometry belongs to frames, how they move is a preset, and how they look is the theme.

## Rules

### Titles

- `title` is the text. `style` names a theme style ([FRAMES-22](../FRAMES-22/SPEC.md)) and is required, since which kind of text a title is belongs to the document.
- `width` is the wrapping width in output pixels. The default is the output width minus twice the placement padding.
- Layout follows [FRAMES-5](../FRAMES-5/SPEC.md).

### Shapes

| shape | What it draws |
| --- | --- |
| `box` | a rounded border around the area |
| `fill` | the area filled with a colour |
| `dim` | darkens everything but the area: the content rect for a connected clip, the output frame for a sequence clip, the canvas in an image document |
| `arrow` | an arrow pointing at the area from the side named by `side` (`left`, `right`, `top`, `bottom`): `shapes.arrow.length` long from tail to tip, its tip at the middle of that side of the area (padding included), with a head `shapes.arrow.head` long and wide |

- `label` adds a one-line label in the `label` style. It goes on the first side in the theme `shapes.label.sides` where it fits inside the content rect (the output frame for a sequence clip), measured at the shape's keyframed geometry without animation. When no side fits, it stops.
- The side is measured at the clip's first visible instant at which its storyline clip is out of every transition, or at the middle of its visible window when all of that window falls in transitions. A sequence clip's side is measured at its first visible instant. Resolve evaluates that instant and writes the side into the resolved document, so `timeline` stops on a label with no room. Motion after that instant (area keyframes, tracking, a zoom) may carry the label partly out of the content rect, and then it is clipped like the shape.
- A label is part of its shape. It follows the shape's geometry and animation, and its own label animation is combined on top: `labelAnimation` on the clip (an animation choice, where `"none"` turns it off), else the `label` entry of `defaults.animation.title`.
- `color` replaces the shape's theme colour.

### Media clips

- `width` and `height` size the clip's box in output pixels. Given one, the other follows the aspect ratio of the clip's first crop, or of the media when there is no crop, and every crop conforms to that box, so the box holds still while the crop moves. Given both, the crop conforms to the box by the clip's `conform` (default `fit`).
- `radius` rounds the corners, `border` (`true` for the `border` colour, or a colour) draws a border with `shapes.border.width`, and `shadow: true` draws the theme shadow.
- `crop` and `filter` work as on a storyline clip, with the clip's own box in place of the content rect.
- `blend` sets the clip's blend mode ([Blend modes](#blend-modes)).
- A video media clip is picture in picture, and an image sequence with alpha is how a motion graphic made elsewhere comes in.

### Adjustment clips

An adjustment clip applies a filter preset (`adjust`) to everything below it, inside `area` or over the whole output when there is none, as an NLE's adjustment layer. Placed by an area on a connected clip, it is parented like a shape. Its `opacity` blends the filtered result with what is below.

### Blend modes

`blend` composites a media, title or shape clip with what is below it. The modes and their formulas are those of W3C Compositing and Blending Level 1: `normal` (default), `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`. Light leaks and film burns come in this way, as media with `screen` or `plus-lighter`.

## Interactions

Text layout is [FRAMES-5](../FRAMES-5/SPEC.md). Areas are [FRAMES-2](../FRAMES-2/SPEC.md). Animations are [FRAMES-14](../FRAMES-14/SPEC.md). Styles and shape colours are [FRAMES-22](../FRAMES-22/SPEC.md).

## Alternatives considered

Choosing a label side by a rule in the engine: the sides and their order are the theme's.

## Notes
