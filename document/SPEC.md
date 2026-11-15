# frames specification

frames is an image and video editing tool that an agent drives. The agent writes a document in JSON, frames resolves and evaluates it, and a decoder, a renderer, a mixer and an encoder turn the result into a PNG, a master file or a delivery file.

This document is the contract, versioned as section 10.1 says. It says what frames takes, what it gives back, and how it behaves, and leaves out how any implementation is built.

- **Must:** behaviour an implementation keeps. Document shapes, time and coordinate rules, packs and templates, the resolved document, the display list, the role contracts and error behaviour are here.
- **Recommended:** structure that makes the contract easier to keep. An implementation may ignore it.

---

## 1. What frames is

frames is built like a non-linear editor (NLE) such as Final Cut Pro or Premiere Pro, with a sequence, a primary storyline of clips, clips connected to them, lanes, transitions, keyframes and filters. The same model edits a still and a video: a screenshot with boxes and a band of text is a document of it, and so is a vertical short or a demo with titles and transitions. What a kind of result needs beyond the tools is a form, shipped as a pack (section 17).

- A resolved document and the files it pins are enough to make the result again.
- Places in a picture are named by the text on screen, found by text recognition (OCR), instead of measured by hand.
- frames composites media and does not generate it. Motion graphics, illustrations and diagrams are made with other tools (HTML in a headless browser, an image model, a design tool) and arrive as media: a PNG, a PNG sequence, or a video with alpha.
- Titles and shapes are built in, as the basics of any NLE. A shape points at an area: its geometry is part of frames, and how it moves is a preset.
- Looks and edits can be shared and sold as packs: presets, themes, LUTs, mattes, overlays and templates with published parameters (section 10).

## 2. Principles

| Principle | Meaning |
| --- | --- |
| The editing model is the product | Documents, time, text areas, presets, themes, templates, text layout (fonts, line breaks, wrapping, boxes) and evaluation at a time are defined once, here, and implemented once. Recognising text, shaping it and tracking are providers (section 13.1) |
| Rendering is replaceable roles | A decoder reads media files, a renderer draws display lists, a mixer mixes the mix plan, and an encoder writes the file (section 13). None of them knows clips, keyframes or presets. Swift fills every role first. A renderer is a 2D compositor with a font rasterizer (Core Graphics and Core Image, Skia), and ffmpeg can fill the decoder, the mixer or the encoder |
| Standard vocabulary | Names come from NLEs and compositing tools: storyline, connected clip, in and out points, lane, keyframe, transition, crop, title, parenting, compound clip, published parameter, blend mode, LUT, matte, display list |
| Composite, do not generate | Anything beyond titles and shapes arrives as media |
| Tools, not purposes | frames gives editing tools: clips, shapes, tracking, filters. What to do with them for a purpose (hiding personal data, choosing highlights, cutting to a beat) is composition: the theme, template, guide and data of the next row, or an extension, a program that reads what frames reports and writes documents (section 17.1). The test: a new form or purpose is added without changing frames |
| Look is theme, a reusable piece is a template, judgement is guide, effect is data | Sizes, colours, text styles and default presets live in a theme. A piece of fixed structure made to be used again (a lower third, an intro, an end card), with its media and text as parameters, is a template. Who a form is for and the rules it keeps, each with its reason, live in a guide. Transitions, animations, filters, LUTs and mattes are data files, and adding one needs no rebuild. Packs carry them |
| Unknown keys stop | Every object has a fixed set of keys. A typo stops with the place it was found instead of rendering as "no effect" |
| Ambiguity stops | A text area that matches more than one line stops and lists the matches |
| A value that still does what it says is clamped, one that cannot stops | A transition longer than its clips, an out point past the end of the media, an area partly outside the picture: each is cut to what fits and still does its job. A clip that is never visible, an area wholly outside the picture, a one-line label that does not fit: each stops |
| No legacy keys | When a key changes, old documents stop. There is no compatibility branch |
| Master at full quality, deliver separately | `render` writes a master that never trades quality for size. Delivery files are made from the same frames (`--deliver`) or from it (`transcode`) |
| Reproducible from the resolved document | What can differ between machines is fixed into the resolved document. Recognised text, tracks, text layout, themes, presets and templates are written out as values, and the files the roles still open (media, mattes, LUTs, fonts) are pinned by hash. Rendering it again on the same decoder and renderer gives the same frames on any machine that has the same files |
| Sound is media | frames places sound files on the timeline. Speech synthesis, recording and transcription happen outside |

## 3. Shape of the system

```
theme.json, packs ──┐
presets/ ───────────┤
                    ▼
document.json ─▶ resolve ─▶ resolved document ─▶ evaluate ─┬─▶ display lists ─▶ renderer ─┐
                  ▲   ▲                                    └─▶ mix plan ──────▶ mixer ────┴─▶ encoder ─▶ PNG / MOV / MP4
      OCR, shaping and tracker providers

analysis: probe, ocr, track, extract, sheet, timeline, evaluate, locate          delivery: transcode (decoder, encoder)
every media file is read through the decoder
```

- **Document:** what the agent writes. There are three kinds: `image` (section 6), `layout` (section 7) and `sequence` (section 8). Any of them can be a template (section 10.2).
- **Resolve:** checks keys, merges the theme, reads presets and packs, fills template parameters, finds text areas, lays out text with real fonts, and plans time. Its output is the resolved document (section 11). It creates no media.
- **Evaluate:** turns a resolved document and a time into a display list (what to draw at that instant, with every keyframe, animation, transition and parent already applied), and a resolved sequence into one mix plan for its sound. It is deterministic, calls no provider, and is shared by every role. Both build on `geometry(clip, t)`, a clip's keyframed geometry at t with its tracked motion, without animation or labels. It takes a clip whose areas are found and whose theme lengths are scaled, and for a parented clip its picture's conformed crop at t, so resolve calls it before the resolved document exists to place label sides.
- **Decoder, renderer, mixer, encoder:** the four roles that read media and make pixels, sound and files (section 13).
- **Providers:** OCR, shaping and tracking, which resolve and the analysis tools call (section 13.1). They read media files (through the decoder) and fonts, never drawn pixels, so no resolved value depends on a renderer. A resolved document needs neither again.
- **Analysis:** commands that give the agent and extensions facts to write a document with, as versioned JSON (section 15.2). They take no part in rendering.
- **Transcode:** makes a delivery file from an image, audio or video file with the encoder role. It is not part of rendering.

## 4. Common values

### 4.1 Units (must)

| Value | Unit |
| --- | --- |
| Time | seconds, as a number. Which clock a time is on is section 8.3 |
| Area in media | media pixels: pixels of the media picture as it is displayed, origin at the top left, rotation metadata applied, pixels made square |
| Position and size on a sequence | pixels of the output, origin at the top left |
| Theme lengths (text size, stroke, padding, line width, filter radius) | points at the theme `baseWidth`, multiplied by the length scale of the place they are drawn (below). Area padding is the exception and is measured in its picture (section 4.2) |
| Animation offsets `x`, `y` | multiples of the animated thing's own size, its box before any scale (a label's own box for a label animation). In a transition, multiples of the content rect |

| Angles | degrees, clockwise positive |
| Colours | `#RRGGBB`, `#RRGGBBAA`, or the name of a theme colour |

A clip's own size is that of its box: a title's text box, a media clip's box, a shape's area (an arrow's from tail to head). A label is not part of it. Scale and rotation act around the clip's anchor point (section 4.5), and around the centre of the box for a clip placed by an area.

Media time, in media seconds, is a media file's presentation timeline after its edit list, with 0 at the first presented frame. The decoder converts pictures to sRGB and tone maps HDR sources. Everything that reads media reads it by these definitions.

The length scale is `width / baseWidth`, where width is the output width for a sequence, the width of the canvas at that operation for an image document, and the widest item for a layout.

### 4.2 Areas (must)

A place in a picture is given in one of these forms. Coordinates are media pixels.

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `"text"` | the whole recognised line that contains the text. A text area names a line by part of its text, and the area is the line |
| `{"text": "...", "nth": 1}` | the nth line (from 0) among the lines that contain the text, counted top to bottom by the top of each line, then left to right |
| `{"from": "...", "to": "...", "fromNth": 0, "toNth": 0}` | the rectangle around both lines and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |
| `{"band": <area>}` | the full width of the picture, between the top and bottom of the inner area, which is one of the forms above |

- Text is compared with whitespace removed. A line matches when it contains the text.
- A text form without `nth` that matches more than one line stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that matches no line stops, naming the media, the text and the nth.
- An area found by text grows outward by the theme `area.padding`, or by `area.cropPadding` when it is a crop. Padding is added once the area is found and before a band widens it. A tracker follows the area before padding (section 8.10). Both paddings are lengths in the picture the area is in: their points are multiplied by that picture's width over `baseWidth`, giving media pixels, so padding is fixed in the picture and grows with it under a zoom like the text it surrounds.
- On video, the text is searched in the frame at the instant where the area takes effect: a connected clip's start (its storyline clip's `in` when it has no `at`), a keyframe's time, or a storyline clip's `in` for a static crop. A clip's `track` finds its target at that instant too (section 8.10). The instant is turned into the media time of the clip that owns the area through that clip's time map (its `in` and `speed`), so a text area on a picture-in-picture clip's crop searches that clip's own frame. An image document's `time` picks its frame.
- Text is only recognised in media files. On an image document used as a source, a text area finds the text in that document's `source` and follows its operations to where that text ended up. A compound clip takes no text area from outside, since its picture is drawn, not read. Text inside it is pointed at from the nested document.

### 4.3 Media references (must)

| Form | Meaning |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` document, which stands as if written there |
| `"<pack>/<name.ext>"` | a file in a pack's `media/` (section 10.1), a `.json` document there included |
| `{"sequence": "/abs/dir", "fps": 30}` | a numbered image sequence (the directory may be `<pack>/<dir>`, a folder in a pack's `media/`): every PNG in the directory, in natural order (runs of digits compare as numbers), at that rate. It plays like a video: its media seconds are frame index / fps, and it takes `in`, `out` and `speed` |
| an image or layout document object | the picture that document draws (sections 6 and 7) |
| a sequence document object | a compound clip: the nested sequence plays as a video with sound, and its sequence time is its media time |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance (section 10.2). The template is `<pack>/<name>` or an absolute path |

- A document with `params` is a template and is used only as a template instance. Anywhere else it stops.
- Paths are absolute. Inside a pack, its own files are named by `<pack>/<name>` like any other pack's (section 10.1).
- A compound clip is evaluated at the media times the outer frames ask for, not at its own frame rate. Its `size`, `background`, `inset` and `conform` apply. Its `fps` applies only when it is rendered alone. It is part of the document that wrote it, so its theme is merged over the one in effect there. A template instance is not (section 10.2).
- Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha) and compound clips. This is how graphics made elsewhere come in.
- At media time s, a video or an image sequence shows the frame whose presentation interval holds s: its timestamp is at or before s, and the next one is after s. OCR, extraction and drawing all pick frames by this rule, and the resolved document pins each such file's frame timestamps, so evaluation picks the frame once and names it by index.
- A compound clip has no frames of its own. It is evaluated at whatever time is asked, clamped into `[0, duration)`.

### 4.4 Keyframes, easing and interpolation (must)

Any property marked keyframable takes a static value or a list of keyframes. A keyframe is an object with `at`, one or more properties, and an optional `ease`.

```json
"opacity": 1,
"keyframes": [ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ]
```

- Each property joins only the keyframes that name it. Before its first keyframe it holds the first value. After its last it holds the last value.
- A property that no keyframe names uses its static value, or its default. A property written both as a static value and in a keyframe stops (section 8.2).
- A keyframe's `ease` shapes the span leaving it, towards the next keyframe of each property it names, as in CSS and Lottie. The default is `linear`. An `ease` on a keyframe that no later keyframe follows for any of its properties stops.
- A keyframe's `at` is an instant on the clock of its clip (section 8.3).
- Numbers and points interpolate per component. An `area` interpolates per component. A `crop` interpolates its centre per component and its size geometrically (in log space), so a zoom keeps one speed. Crops are conformed to one aspect ratio first (section 8.5), so the ratio holds between keyframes.
- An area given by text resolves at its own keyframe's time before it interpolates (on a tracked clip it is then brought back through the motion, as every value is, section 8.10).

| ease | f(u), u from 0 to 1 |
| --- | --- |
| `linear` | u |
| `ease-in` | u³ |
| `ease-out` | 1 - (1-u)³ |
| `ease-in-out` | 4u³ when u < 0.5, otherwise 1 - (2 - 2u)³ / 2 |
| `back-out` | 1 + 2.70158(u-1)³ + 1.70158(u-1)² |
| `bounce-out` | standard bounce-out with n = 7.5625, d = 2.75 |
| `step` | 0 when u < 1, otherwise 1 |
| `[x1, y1, x2, y2]` | cubic Bézier, as CSS `cubic-bezier()` |

### 4.5 Placement (must)

A clip on a sequence that is not placed by an area is placed by `placement` or by `position`, never both. A clip with both stops.

- `placement` is a name: `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right`. The clip sits inside the output frame, inset by the theme `placement.padding` on every side. A text style's `offset` replaces that inset on the top or bottom edge, when the name has one (a subtitle sits `offset` above the bottom of the output).
- `position` is `[x, y]`, where the clip's anchor point goes, in output pixels, or in the media pixels of its picture for a parented clip (section 8.7). On a parented clip it may also be `{area, point}`: the point (a placement name) of an area found as section 4.2 says, padding included, so a title sits beside a button by its text: `{"area": "Send", "point": "left"}` with `anchor: "right"`. It is keyframable.
- `anchor` names the clip's anchor point, as in an NLE: one of the placement names, a point of the clip's box (`top-left` is its top left corner). The default is `center`, or the point the placement names for a clip placed by `placement` (a `bottom` subtitle grows from its bottom edge). Keyframed and animated scale and rotation both act around it, as in an NLE. Under a parent's zoom or a track's scale the anchor point stays on its place in the picture and the clip keeps its size, so a clip next to something stays on it when it is anchored on the side that faces it: a title left of a button is anchored `right`.

Placement is measured on the output frame, not the content rect, so a title can sit in the band an inset leaves. The default is the text style's placement for titles and `center` for media. A parented title or media clip has no default and needs `position`.

### 4.6 Text layout (must)

Text is laid out by resolve, with real fonts, so line breaks, sizes and label sides are part of the resolved document and are the same on every renderer.

- A style's font is the first family in the theme `font` list that its pack carries (section 10.1) or the machine has installed, in the style's weight. Characters that face lacks fall back to the platform's fallback fonts. A list with no family on the machine stops, naming the families.
- Lines break by Unicode line breaking (UAX #14) at the wrapping width, and at `\n`.
- Resolve shapes each run of text with the shaping provider, which gives glyph ids and advances. frames breaks, wraps and places the lines. The resolved document carries glyph runs (font file, face, size, colour, glyph ids and positions) and the box they fill. A renderer draws the glyphs where they are written and shapes nothing.
- `**text**` takes the style's `emphasis` colour.
- A style with `lines: 1` never wraps. Text wider than its room stops, since a cut label would say something else.

---

## 5. Documents

Every document is a JSON object with a `kind` of `image`, `layout` or `sequence`. A document may carry a `theme` (a theme object, or a theme file, `<pack>/<name>` or an absolute path), which is merged over the theme in effect (section 14), and `params`, which make it a template (section 10.2).

## 6. image document

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
- `crop`, `resize`, `pad` and `banner` change the canvas. `shape`, `adjust`, `title` and `border` draw on it. Operations run in order, as layers.
- A drawing is made on the canvas as it is at its operation, with theme lengths scaled by the canvas width at that point, and is clipped to that canvas. Later canvas operations move and scale it with the picture. Later pads and banners add room around it but never reveal what was clipped.
- A drawing wholly outside the canvas at its operation stops. A label's room is measured on the canvas at its shape's operation.
- Coordinates outside the source picture reach into pads and banners only for drawings after those operations, so a title at `y: -20` after a top pad sits in that pad.
- `adjust` is an adjustment layer: it changes everything drawn before it, inside its area or over the whole canvas, so a box drawn before a pixelate is pixelated and a box drawn after it is not.
- Any op may carry an `id` (section 8.2).
- Wherever a picture is taken (a layout item, a storyline clip, a connected clip), an image document can stand in for a path.

| op | Keys | What it does |
| --- | --- | --- |
| `crop` | area | Keeps the area, clipped to the picture |
| `resize` | `{scale}`, `{width}` or `{height}` | Resizes and keeps the aspect ratio |
| `pad` | `n`, `[vertical, horizontal]` or `[top, right, bottom, left]`, `color` optional | Adds a margin. The default colour is the theme `background` |
| `shape` | `box`, `fill`, `dim` or `arrow`, with `id`, `area`, `label`, `side`, `color` | Draws a shape (section 8.9) |
| `adjust` | filter preset, `area` optional | Applies a filter preset to everything drawn before it, inside the area when one is given |
| `title` | text, `position` (media `[x, y]` or a point of an area), `anchor`, `style` | Places a title (section 8.8), its anchor point at `position` as on a sequence (section 4.5) |
| `banner` | lines, `edge` (`top` or `bottom`) | Extends the picture with a band as tall as its text. A line is a string, in the `banner` style, or `{text, style}` |
| `border` | `true` (the `border` colour) or a colour | Draws a border around the picture with the theme `shapes.border.width` |

## 7. layout document

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

- Without `columns`, every item goes on one row.
- Every column is as wide as the widest item, and every row is as tall as the tallest item in it. An item is centred in its cell.
- `border` is `true` (the `border` colour), a colour, or `false`, and draws a border around every cell with `shapes.border.width`. The default is `true`.
- `heading` sits above its cell in the `heading` style.
- `banner` is a band above the grid, styled as in the image `banner` operation.

## 8. sequence document

### 8.1 Shape

```json
{
  "kind": "sequence",
  "format": { "size": [1080, 1920], "fps": 30, "background": "#000000", "inset": [420, 40, 120, 40], "conform": "fit" },
  "theme": { "defaults": { "transition": "push-up", "filter": "vivid", "animation": { "title": { "subtitle": "pop" }, "shape": "draw" } } },
  "storyline": [
    { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "volume": 0,
      "keyframes": [ { "at": 2, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ],
      "connected": [ { "at": [2, 8], "title": "**Emphasis** subtitle", "style": "subtitle" } ] },
    { "media": "/abs/run.mp4", "in": 17.5, "out": 23, "transition": "flash", "volume": 0,
      "keyframes": [ { "at": 18, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 19, "crop": { "from": "Enter your password", "to": "3" } } ],
      "connected": [ { "at": [19, 22], "shape": "box", "area": "Sent", "label": "done", "animation": "stamp" },
                     { "shape": "box", "area": "Account 110-", "track": true, "label": "this account" } ] },
    { "media": { "kind": "image", "source": "/abs/card.png" }, "duration": 2.5,
      "transition": { "preset": "wipe-right", "seconds": 0.5 },
      "connected": [ { "shape": "box",
                       "keyframes": [ { "at": 1.2, "area": "First line" }, { "at": 1.65, "area": "Second line" } ] } ] }
  ],
  "clips": [
    { "at": [0, 30], "title": "Top title\n**emphasis**", "style": "headline", "lane": 2 },
    { "at": [1, 6], "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
      "animation": { "entrance": "pop", "exit": "fade" }, "lane": 5,
      "keyframes": [ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ] },
    { "at": [0, 4], "media": "/abs/light-leak.mov", "blend": "screen", "lane": 3 },
    { "media": "/abs/bgm.m4a", "volume": 0.3, "loop": true, "fadeOut": 1 },
    { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 }
  ]
}
```

- `storyline` is the primary storyline. Its clips play one after another, and a transition plays across the edit point between two of them.
- `connected` clips belong to one storyline clip and live on its clip time. They move when that clip moves.
- `clips` are the sequence's clips on the sequence clock.
- A clip is a media clip (`media`), a title (`title`), a shape (`shape`), an adjustment clip (`adjust`) or a solid (`solid`, storyline only). Exactly one of these keys is present.

### 8.2 Keys (must: any other key stops)

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips` |
| format | `size, fps, background, inset, conform` |
| storyline clip, timed media (video, image sequence, compound) | `id, media, in, track, out, speed, crop, filter, transition, volume, fadeIn, fadeOut, keyframes, connected` |
| storyline clip, still (image, image or layout document) | `id, media, duration, crop, filter, transition, keyframes, connected` |
| storyline clip, solid | `id, solid, duration, transition, connected` |
| every connected and sequence clip | `id, at, lane, opacity, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip's, `track, anchor, media, in, out, speed, loop, volume, fadeIn, fadeOut, placement, position, parent, scale, rotation, crop, conform, filter, blend, width, height, radius, border, shadow` |
| still media clip (image, image or layout document) | every clip's, `track, anchor, media, placement, position, parent, scale, rotation, crop, conform, filter, blend, width, height, radius, border, shadow` |
| audio clip | `id, at, media, in, out, speed, loop, volume, fadeIn, fadeOut, keyframes` |
| title clip | every clip's, `track, anchor, title, style, width, placement, position, parent, scale, rotation, blend` |
| shape clip | every clip's, `shape, area, track, label, labelAnimation, color, blend`, and `side` for an arrow |
| adjustment clip | every clip's, `adjust, area, track` |
| keyframe | `at, ease`, and the keyframable properties of its clip |
| transition choice | a preset name, a `<pack>/<name>`, an absolute path, `"cut"`, or `{preset, seconds}` |
| animation choice | a preset name, a `<pack>/<name>`, an absolute path, `"none"`, or `{entrance, exit}` |
| filter choice | a preset name, a `<pack>/<name>`, an absolute path, a list of those, or `"none"` |
| image document | `kind, source, time, theme, params, ops`, and each op's keys from section 6 |
| layout document | `kind, theme, params, banner, columns, border, items`. An item takes `heading, image` |
| template instance | `template, args` |
| parameter | `type, default, description`, and `options` for a choice |

`id` names a clip or op for whatever reads or changes the document from outside (section 17.1), since a place like `storyline[1].connected[0]` moves when clips are added. It is a string, unique within its document (a nested document has its own), and a duplicate stops. Messages and machine output give it with the place.

Which media row applies depends on what the media holds, so those keys are checked once the media has been probed. Where the media is a template parameter, the parameter's type picks the row (section 10.2).

Keyframable properties:

| Clip | Properties |
| --- | --- |
| storyline clip | `crop`, and `volume` on timed media |
| media clip | `position, scale, rotation, opacity, crop`, and `volume` on timed media (audio clips: `volume` only) |
| title clip | `position, scale, rotation, opacity` |
| shape clip | `area, opacity` |
| adjustment clip | `area, opacity` |

Keys are checked over the whole JSON tree before any value is read, except the media rows, which follow the probe. A value of the wrong type also stops, with its place. A property written both as a static value and in a keyframe stops, since the static value would never show.

### 8.3 Time (must, the most important rule)

Three clocks meet on a sequence. **Clip time** is the time inside one storyline clip. **Sequence time** is the time of the output. **Media time** (section 4.1) is the clock of a media file itself.

**Instants are on the clock of their owner. Durations are sequence seconds.**

| Instant | Clock |
| --- | --- |
| a storyline clip's own `keyframes` | that clip's clip time |
| a connected clip's `at` and `keyframes` | its storyline clip's clip time |
| a sequence clip's `at` and `keyframes` | sequence time |
| `in` and `out` of any media clip | that media's media time |

Durations (a media clip's natural length, `duration`, transition and animation `seconds`, loop `period`, `fadeIn`, `fadeOut`) are always sequence seconds. A sound connected to a clip at speed 2 plays its full length at its own speed, and an entrance takes the same time on every clip.

Clip time is the media time of a video, image sequence or compound clip, and the seconds since the clip started for a still or solid clip. It lets an agent take times straight from frames it extracted from a recording. Trimming or speeding up an earlier clip does not move anything connected to a later one.

A storyline clip starts at `start` on the sequence clock and lasts `duration`:

```
timed media clip:       duration = (out - in) / speed
still or solid clip:    duration = duration key

clip time t to sequence time:
  timed media clip:       start + (t - in) / speed
  still or solid clip:    start + t
```

The map is the same line outside the clip, so a keyframe before `in` keeps its time and its ease, and the handles below play on it.

- `in` and `out` are edit points. The first storyline clip starts at 0, each next clip starts where the previous one ends, and the sequence ends where the last one ends. A transition does not change the length of the sequence.
- The first storyline clip has no transition: one written on it stops, and the default does not apply. To open from black or end on it, put a solid clip there and give the clip after it a transition.
- A transition belongs to the clip it brings in and is centred on their edit point. It lasts `min(transition seconds, previous duration, next duration)`. During it the outgoing clip plays on past its `out`, and the incoming clip starts before its `in`, on the media beyond them (the handles). Where the media runs out, its first or last frame holds, and a still or solid clip simply goes on. Evaluation clamps to the media's first and last frame before it writes a frame, so a decoder is only asked for frames that exist.
- A storyline clip has two ranges on the sequence clock. Its **edit range** is `[start, end)`, between its edit points. Its **drawn range** runs from the start of its incoming transition to the end of its outgoing one.
- Every range and window holds its start and not its end, so a frame at an edit point belongs to the clip that starts there.
- `at` is `[start, end]` or a single start. A window's start and end are both instants. A single start is an instant followed by a duration, the clip's natural length `(out - in) / speed` for video, audio, image sequence and compound media. Under a storyline clip whose speed is not 1 the two forms differ: `[2, 6]` ends at clip second 6, and `2` ends when the media does. When titles, shapes, adjustments and still images take `at`, it is `[start, end]`. A connected clip without `at` spans its storyline clip's drawn range when it is parented and its edit range otherwise, and a sequence clip without `at` spans the whole sequence. A parented clip whose window starts at the clip's `in` starts at the edit point, inside the transition, so one meant for the whole picture leaves out `at`. A parented clip without `at` takes no entrance and no exit, since it comes and goes with its picture.
- A media clip plays from `in` at its own `speed` (default 1), whatever the speed of its storyline clip. When its window is longer than the media, video holds its last frame and audio goes silent, unless `loop` is true, in which case it repeats from `in` to `out` to fill the window.
- An unparented connected clip is attached by its start, as in an NLE, and plays its whole window across edit points and transitions, over whatever is below it. Only the end of the sequence cuts it.
- A parented connected clip (section 8.7) is visible where its window meets its storyline clip's drawn range. It is composited with its picture, so a transition covers, wipes or moves it exactly as it does its picture.
- A connected clip with a picture whose window does not meet the range it is visible in stops ("never visible").
- A connected audio clip is only anchored by its start. It plays its window, or its natural length, across transitions. One whose start lies outside its storyline clip's drawn range stops.
- Sequence clips are cut at the end of the sequence. One that starts at or after the end stops.

### 8.4 Format (must)

- `size` defaults to the size of the first video clip on the storyline, or the first storyline clip when there is no video. Width and height round to even numbers.
- `fps` defaults to the nominal frame rate of the first video clip on the storyline, rounded to the nearest of 24, 25, 30, 50 and 60. It is 30 when that clip has no nominal rate (some variable-rate recordings) or there is no video.
- `background` defaults to the theme `background`. Transparent parts of storyline pictures show it.
- `inset` is `[top, right, bottom, left]` and shrinks the content rect, where storyline clips are drawn. An inset that leaves no content rect stops.
- `conform` is `fit` (show the whole crop, fill the rest with the background) or `fill` (fill the content rect and cut what overflows), as an NLE's spatial conform. The default is `fit`.
- Outside the content rect is always the background. A cropped, filled or moving storyline clip never shows outside it.

### 8.5 Storyline clips (must)

- `in` defaults to 0 and `out` to the end of the media, here and on media clips. A video, image sequence or compound clip needs `in < out` and `speed > 0`. An `out` past the end of the media is trimmed to the end.
- A still or solid clip needs `duration > 0`. `solid` is a colour, and fills the content rect.
- An empty storyline stops, and so does a storyline clip whose media holds only sound.
- `crop` is the region of the media shown in the content rect. It is an area, or `{scale: s}` for a centred region `1/s` the size of the picture (`s = 1` is the whole picture). It is keyframable, which gives a pan and zoom (Ken Burns).
- Resolve conforms every crop to the aspect ratio of the content rect around its centre. `fit` grows it until the written region fits inside, and what lies beyond the picture is transparent: lower lanes and the background show there, and during a transition the other unit does. `fill` shrinks it until it lies inside the written region. The conformed crop is exactly what fills the content rect, and keyframes between conformed crops keep their ratio.
- Each frame of a storyline clip is made in this order: take the conformed crop, scale it to the content rect, apply the filter at that size in output pixels, then apply the transition motion.
- `filter` and `transition` take preset choices. `"none"` turns off a default filter for one clip, and `"cut"` turns off a default transition.
- Every storyline kind with a picture takes crop, filter and transition the same way. A solid takes a transition only.

### 8.6 Lanes and stacking (must)

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

### 8.7 Parenting (must)

A connected clip can be parented to its storyline clip's picture. Shapes and adjustments placed by `area` always are. A title or media clip is when it has `parent: true`, and then its `position` is in the media pixels of that picture. `parent: true` with a `placement` stops, since placement names the output frame.

A parented clip is one compositing unit with its picture (section 8.6). It stays in the media coordinates of its picture and follows the crop, so a box, or a title beside a button, stays on what it points at while the picture zooms, and with `track` while it scrolls (section 8.10). A transition moves, fades, wipes and mattes the unit as one picture, so a parented clip goes with its picture and never floats over the next clip. Its blend, and an adjustment parented to the same picture, reach only that unit. A clip is parented only to its storyline clip's picture: a box on a picture in picture is made by putting both in a compound clip, where that picture is the storyline.

Parenting maps positions and areas. The lengths a clip draws with (stroke widths, text and label sizes, filter lengths) stay in output pixels and do not grow with a zoom.

A sequence clip has no parent, and its `area` takes only `[x, y, w, h]` in output pixels.

### 8.8 Titles (must)

- `title` is the text. `style` names a theme style (section 14.2) and is required, since which kind of text a title is belongs to the document.
- `width` is the wrapping width in output pixels. The default is the output width minus twice the placement padding.
- Layout follows section 4.6.

### 8.9 Shapes (must)

| shape | What it draws |
| --- | --- |
| `box` | a rounded border around the area |
| `fill` | the area filled with a colour |
| `dim` | darkens everything but the area: the content rect for a connected clip, the output frame for a sequence clip, the canvas in an image document |
| `arrow` | an arrow pointing at the area from the side named by `side` (`left`, `right`, `top`, `bottom`) |

- `label` adds a one-line label in the `label` style. It goes on the first side in the theme `shapes.label.sides` where it fits inside the content rect (the output frame for a sequence clip), measured at the shape's keyframed geometry without animation. When no side fits, it stops.
- The side is measured at the clip's first visible instant at which its storyline clip is out of every transition, or at the middle of its visible window when all of that window falls in transitions. A sequence clip's side is measured at its first visible instant. Resolve evaluates that instant and writes the side into the resolved document, so `timeline` stops on a label with no room. Motion after that instant (area keyframes, tracking, a zoom) may carry the label partly out of the content rect, and then it is clipped like the shape.
- A label is part of its shape. It follows the shape's geometry and animation, and its own label animation is combined on top: `labelAnimation` on the clip (an animation choice, where `"none"` turns it off), else the `label` entry of `defaults.animation.title`.
- `color` replaces the shape's theme colour.

### 8.10 Tracking (must)

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is an area in one of the finding forms of section 4.2, or `true` for the clip's own `area` (a shape or adjustment) or `crop` (a storyline clip). The area is found at the clip's instant (section 4.2), before padding, and the tracker provider (section 13.1) follows it backwards and forwards over every frame the picture draws, handles included, giving the target's rectangle on each.

- The track is a motion: on each frame, the similarity transform (a move, and one uniform scale about the target's centre) that takes the target's rectangle at the instant to its rectangle on that frame. The scale is the geometric mean of the width and height ratios, so a crop keeps its aspect ratio.
- The motion acts as a moving parent. Every value of the clip's geometry (its `area`, its `position`, a storyline clip's `crop`) is where it is at its own time, as a rectangle `ocr --json` gives for that time is: a keyframe's value at the keyframe's time, found by text or written as a rectangle, and a static value at the instant. Each is brought back through the inverse of the motion at its time, interpolated there, and carried by the motion on each frame. So a box stays on a scrolling line, a title beside a button stays beside it when the screen zooms (section 4.5), and a zoom keyframed on a crop goes on while the crop follows a card.
- A tracked clip's instant is the time of its first keyframe of the property it follows, when it has one, and otherwise its instant of section 4.2. `true` follows the clip's own area or crop at that instant. It is taken by a shape, an adjustment, and a storyline clip whose crop is an area. Elsewhere it stops: a title or media clip names its target. A media clip's own `crop` is in its own media and is not moved.
- A band keeps the full width of its picture and takes the vertical part of the motion.
- `track` is taken by a storyline clip of video or image sequence, which follows its own media, and by a parented connected clip on one, which follows that storyline clip's media. Anywhere else (a sequence clip, an unparented clip, a still or compound storyline clip) it stops, since there is nothing to follow.
- A connected clip is visible only on the frames followed: its window is narrowed to them, as section 8.3 narrows any window. A storyline clip whose target is lost inside its edit range stops, naming the time. In a handle its motion holds the nearest value followed, as a handle past the end of the media holds its edge frame.

### 8.11 Media clips (must)

- `width` and `height` size the clip's box in output pixels. Given one, the other follows the aspect ratio of the clip's first crop, or of the media when there is no crop, and every crop conforms to that box, so the box holds still while the crop moves. Given both, the crop conforms to the box by the clip's `conform` (default `fit`).
- `radius` rounds the corners, `border` (`true` for the `border` colour, or a colour) draws a border with `shapes.border.width`, and `shadow: true` draws the theme shadow.
- `crop` and `filter` work as on a storyline clip, with the clip's own box in place of the content rect.
- `blend` sets the clip's blend mode (section 8.14).
- A video media clip is picture in picture, and an image sequence with alpha is how a motion graphic made elsewhere comes in.

### 8.12 Adjustment clips (must)

An adjustment clip applies a filter preset (`adjust`) to everything below it, inside `area` or over the whole output when there is none, as an NLE's adjustment layer. Placed by an area on a connected clip, it is parented like a shape. Its `opacity` blends the filtered result with what is below.

### 8.13 Audio (must)

- A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept.
- `fadeIn` and `fadeOut` are seconds, and ramp the volume from and to 0 at the ends of the clip's window, or of a storyline clip's drawn range.
- `volume` is keyframable, for ducking and longer fades.
- During a storyline transition the outgoing clip's sound fades out and the incoming clip's sound fades in, linearly over the transition, from their handles. Where a handle runs out of media, that sound is silent.
- Gains multiply: volume, fades and the transition crossfade all apply.
- A compound clip's sounds join the outer mix, with their times mapped through the compound clip and their gains multiplied by its own.
- Sounds that overlap are mixed. Everything is cut at the end of the sequence.
- A sequence with no sound has no audio track.

### 8.14 Blend modes (must)

`blend` composites a media, title or shape clip with what is below it. The modes and their formulas are those of W3C Compositing and Blending Level 1: `normal` (default), `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`. Light leaks and film burns come in this way, as media with `screen` or `plus-lighter`.

---

## 9. Presets (must)

A preset is one JSON file at `presets/<transition|animation|filter>/<name>.json`. A bare name is a preset frames ships, `<pack>/<name>` is a preset in an installed pack (section 10.1), and an absolute path reads that file. Adding a preset needs no rebuild.

Every preset has a `description`: one line on how it looks and when to use it, which `presets` prints. Unknown keys and broken rules in a preset stop when it is read.

### 9.1 Motion properties

| Property | Default | Meaning |
| --- | --- | --- |
| `opacity` | 1 | opacity |
| `scale` | 1 | scale around the anchor point (section 4.5), or the centre of the box for a clip placed by an area |
| `x`, `y` | 0 | offset in multiples of the thing's own size, or of the content rect in a transition. Down is positive |
| `rotation` | 0 | degrees, clockwise positive, around the same point as `scale` |
| `reveal` | 1 | 0 shows nothing, 1 shows everything. How it reveals depends on what receives it (below) |
| `nudge` | 0 | moves an arrow towards what it points at by multiples of its length. Only arrows read it |

| Receiver of `reveal` | How it reveals |
| --- | --- |
| box | the border is drawn around |
| fill | painted from the `revealFrom` side |
| dim | closes in from all it darkens to the area |
| arrow | grows from its tail to its head |
| title, media, adjustment, storyline picture | wiped from the `revealFrom` side |

A span is:

```json
{ "seconds": 0.35, "ease": "back-out", "revealFrom": "left",
  "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "scale": 1 } ] }
```

- `t` is progress through the span, from 0 to 1.
- Each property joins only the keys that name it, in straight lines. Opacity can finish at 30% while scale runs to the end.
- A property the span does not name takes its default.
- `ease` bends the progress first, and the bent value drives every property.
- `revealFrom` is `left`, `right`, `top` or `bottom`. The default is `left`.

### 9.2 animation

```json
{ "description": "...",
  "entrance": { "seconds": 0.35, "ease": "back-out", "keys": [ ... ] },
  "loop":     { "period": 0.9, "keys": [ ... ] },
  "exit":     { "seconds": 0.15, "keys": [ ... ] } }
```

| Span | When it runs | Required | Default ease |
| --- | --- | --- | --- |
| `entrance` | for `seconds` from the start of the clip's visible window | `seconds` | `ease-out` |
| `loop` | every `period` seconds from the end of the entrance to the start of the exit | `period` | `ease-in-out` |
| `exit` | for the last `seconds` of the visible window | `seconds` | `ease-in` |

- Every span is optional. Without one the clip simply shows.
- On a short clip the entrance runs first and the exit takes what time is left.
- `{entrance, exit}` as a choice takes the entrance from one preset and the exit from another.
- An animation is applied over the clip's keyframes, about the same point: its scale and opacity multiply, and its x, y and rotation add. A preset's look is the same for every anchor point, made about that point.

### 9.3 transition

```json
{ "description": "...",
  "seconds": 0.45, "ease": "ease-in-out", "over": "incoming",
  "incoming": { "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
  "outgoing": { "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": -1 } ] },
  "cover":    { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

| Key | Meaning |
| --- | --- |
| `seconds` | default length. `{preset, seconds}` in a document overrides it |
| `ease` | default curve of incoming, outgoing, cover and matte |
| `over` | which unit is on top during the transition: `incoming` (default) or `outgoing` |
| `incoming` | motion of the incoming clip |
| `outgoing` | motion of the outgoing clip |
| `cover` | `{color, keys}` or `{media, keys}`: a colour (a dip to colour) or an image or video with alpha (a stinger) over both units, stretched over the content rect. Only opacity is read from its keys |
| `matte` | `{media, softness, invert}`: a luma wipe (below) |

- A storyline picture reads opacity, scale, x, y, rotation and reveal. Scale, x, y and rotation act around the centre of the content rect, and reveal shows the content rect from the `revealFrom` side.
- `seconds` or `period` inside a span stops. A transition's time is its length.
- To change scenes while the cover hides them, cut the incoming opacity from 0 to 1 at that point.
- `matte.media` is a greyscale image or video, stretched over the content rect. The incoming unit shows where the matte's luminance is below the transition progress, with an edge `softness` wide (0 to 1 of the luminance range). `invert` swaps dark and light. A still gradient gives the luma wipe (gradient wipe) of an NLE, and a black and white video gives a track-matte wipe that shows the incoming unit where it is black. Either gives any wipe shape without code. A matte reveals the incoming unit, so a transition with both `matte` and `"over": "outgoing"` stops.
- A video in `matte` or `cover` is stretched over the transition: at progress p it shows media time p × its duration, so the transition's seconds change its speed, not its shape.

### 9.4 filter

A filter preset is a chain of operations from this table, applied in order. The operations are frames vocabulary, so every renderer maps them to its own.

```json
{ "description": "...", "ops": [ { "op": "saturation", "amount": 0 }, { "op": "contrast", "amount": 1.3 } ] }
```

| op | Parameters | Meaning |
| --- | --- | --- |
| `exposure` | `ev` | multiplies linear light by 2^ev |
| `contrast` | `amount` (1 is none) | contrast around middle grey |
| `saturation` | `amount` (0 is grey, 1 is none) | colour saturation |
| `temperature` | `kelvin` (positive is warmer) | white balance shift |
| `hue` | `degrees` | rotates hue |
| `sepia` | `amount` (0 to 1) | sepia tone |
| `levels` | `input: [black, white]`, `output: [black, white]` (0 to 1) | maps input levels to output levels |
| `lut` | `file` (a `.cube` 3D LUT), `amount` (0 to 1) | maps colours through the LUT, applied to sRGB-encoded values with trilinear interpolation, and blends the result by `amount` |
| `blur` | `radius` (theme length) | Gaussian blur |
| `sharpen` | `amount`, `radius` | unsharp mask |
| `bloom` | `amount`, `radius`, `color` optional | bright areas glow, in that colour when one is given (halation) |
| `vignette` | `amount`, `radius` (fraction of half the diagonal) | darkens towards the edges |
| `pixelate` | `size` (theme length) | square blocks, each filled with the mean colour of the pixels it covers |
| `grain` | `amount` (0 to 1), `size` (theme length) | monochrome film grain, strongest in the midtones. Evaluation writes its `seed` (section 12), so a render made again has the same grain |

- An unknown op stops when the preset is read.
- Parameters are numbers, lists of numbers, colours, or for `lut` a file: `<pack>/<name>` for `luts/<name>.cube` in a pack, or an absolute path.
- The result has the size of the input. Operations that pull in pixels from beyond the edge (blur) are cropped back to the original size.
- Renderers keep the meaning of each operation, in the working space (section 13). Identical pixels across renderers are not part of the contract.

### 9.5 Presets to ship

The names, how each looks, and the preset files frames ships are the contract, so a template timed to `pop` keeps its timing. Changing a shipped preset's numbers raises the major version (section 10.1). Seconds are the default length.

**transition (14)**

| Name | Looks like | Seconds |
| --- | --- | --- |
| `fade` | cross dissolve, the next clip fades in | 0.4 |
| `dip-black` | fades to black, then the next clip comes up (a big scene change, black cover) | 0.7 |
| `flash` | a white flash (a result or a reveal, white cover) | 0.3 |
| `push-left` | the next clip pushes the previous one out to the left | 0.45 |
| `push-up` | the next clip pushes the previous one up (vertical video) | 0.45 |
| `slide-left` | the next clip slides in from the right and covers | 0.45 |
| `slide-right` | the next clip slides in from the left | 0.45 |
| `slide-up` | the next clip slides up from the bottom and covers | 0.45 |
| `uncover-left` | the previous clip leaves to the left and uncovers the next (`over: outgoing`) | 0.45 |
| `wipe-left` | the next clip is wiped in from the right | 0.5 |
| `wipe-right` | the next clip is wiped in from the left | 0.5 |
| `wipe-down` | the next clip is wiped in from the top | 0.5 |
| `zoom-in` | the next clip starts large and settles | 0.4 |
| `zoom-out` | the next clip starts small and grows | 0.4 |

**animation (14)**

| Name | Looks like |
| --- | --- |
| `none` | appears and disappears |
| `fade` | fades in and out |
| `pop` | starts small and pops to size |
| `stamp` | starts large and lands like a stamp |
| `zoom` | starts large and shrinks into place |
| `draw` | drawn in with reveal |
| `wipe` | wiped in from the left, as if written |
| `rise` | rises a little from below |
| `drop` | comes down from above |
| `slide-left` | slides in from the right and leaves to the left |
| `bounce` | bounces into place |
| `pulse` | pops, then pulses until it ends. An arrow jabs with nudge |
| `blink` | blinks |
| `shake` | lands large, shakes side to side, then trembles while it stays |

**filter (14)**

| Name | Looks like |
| --- | --- |
| `mono` | black and white |
| `noir` | high-contrast black and white |
| `sepia` | old brown photo |
| `warm` | warmer, towards yellow |
| `cool` | cooler, towards blue |
| `vivid` | stronger colour |
| `faded` | washed-out film |
| `bright` | one step brighter |
| `dark` | one step darker |
| `soft` | highlights glow softly |
| `sharpen` | crisper text edges |
| `blur` | blurred |
| `vignette` | darker edges that pull the eye to the centre |
| `pixelate` | square blocks, as a look |

---

## 10. Packs and templates (must)

### 10.1 Packs

A pack is a set of looks and edits that someone made to share or sell. It is an open-package directory: a `manifest.toml` with an `[open-package]` table that names the pack, its version and its licence, a `[frames]` table with the `engine` versions it is written for, and any of these folders.

| Folder | Holds | Named as |
| --- | --- | --- |
| `presets/<transition, animation or filter>/` | presets | `<pack>/<name>` in a preset choice |
| `themes/` | themes | `<pack>/<name>` in `--theme` or a document `theme` |
| `templates/` | templates (section 10.2) | `<pack>/<name>` in a template instance |
| `luts/` | `.cube` LUTs | `<pack>/<name>` in a `lut` op |
| `media/` | mattes, overlays, stingers and other media, with image sequences as folders and documents as `.json` files used by file (without `params`) | `<pack>/<name.ext>` for a file and `<pack>/<dir>` for a sequence, wherever media is taken |
| `fonts/` | font files | by family, in the `font` list of the pack's themes |
| `guide.md`, `examples/` | the guide and example documents of the form a pack is for (section 17) | read by people and agents, not by frames |

- Installed packs live at `$FRAMES_HOME/packs/<pack>/`, and `FRAMES_HOME` defaults to `~/.config/frames`. The packs that ship with frames (section 17) are found as if installed, and an installed pack of the same name stops. Installing a pack is copying its directory there. frames has no network command.
- A bare name is built in. An unknown pack, or a name a pack does not hold, stops.
- frames is versioned `major.minor.patch` (semantic versioning), and this specification, at 1.0.0, is what the version is about: document keys and values, presets, themes, templates, packs, commands, and the values of the base theme and of the presets frames ships. An addition (a key, an op, a preset, a form of a value, a command) raises the minor number. A removal, a renamed key, or a changed value of the base theme or a preset raises the major number. A fix that brings an implementation to this specification raises the patch number. A name never changes its meaning within a major version: a new meaning takes a new name.
- The resolved document, the display list, the mix plan and each machine output object carry their own schema version (sections 11, 15.2), which their readers (frames, the roles, extensions) check. A change to one raises that number, not the major version of frames, so a pack that never reads it keeps working.
- A pack names the versions of frames it is written for as a range in `[frames] engine`, where `"^1.2"` is 1.2.0 or later before 2.0.0. Outside it, the pack stops when it is used, naming both.
- A document names no version. It is resolved by the frames that reads it, and what it resolved to is kept in its resolved document (section 11), so a document that must be made again the same way keeps its resolved document. A pack is checked because it is made once and used by many frames.
- A theme written in a pack (a theme file, or a theme inside a pack's template) looks for its `font` families in the pack's `fonts/` before the machine's fonts, so a template that must keep its look carries its fonts.
- A pack's files name each other by `<pack>/<name>`, as anything outside does, so every name has one spelling and a pack works wherever `FRAMES_HOME` is. The pack's name is the one in its manifest, and a pack whose directory has another name stops.
- What resolve takes from a pack goes into the resolved document like anything else (section 11): presets, themes and templates as values, media and LUTs pinned by hash. A resolved document does not depend on what is installed later.
- `frames packs` lists the installed packs, and `frames packs <pack>` lists what one holds, with descriptions.

### 10.2 Templates

A template is a document with published parameters, as an NLE's motion graphics template exposes some of its values for editing (Premiere's MOGRT, Final Cut's published parameters). Any document kind can be one.

```json
{
  "kind": "sequence",
  "params": {
    "clip":  { "type": "video", "description": "the recording to show" },
    "title": { "type": "text", "default": "New feature", "description": "headline in the top band" },
    "tone":  { "type": "choice", "options": ["warm", "cool"], "default": "warm", "description": "colour of the whole clip" }
  },
  "storyline": [
    { "media": { "param": "clip" }, "in": 0, "out": 6, "filter": { "param": "tone" },
      "connected": [ { "title": { "param": "title" }, "style": "headline" } ] }
  ]
}
```

- `params` maps a name to `{type, default, description}`. `type` is `video` (a video or an image sequence), `sequence` (a compound clip: a sequence document, or a sequence template instance), `image` (an image, or an image or layout document), `audio`, `text`, `color`, `number` or `choice`, and a `choice` lists its `options`.
- `{"param": "<name>"}` stands for a value anywhere a value of that type is accepted. It never stands for a key. A choice stands where one of its options is accepted, such as a preset name. A `text` stands for text on screen (a title, a label, a banner line, a heading) or the text of an area. Names (presets, styles, themes, templates) are taken only by a choice.
- A template is used as media, `{"template": "<pack>/<name>", "args": {...}}`, where it plays as a compound clip, or draws as an image or a layout when it is one. It is also rendered on its own with `render <template> --args <args.json>`.
- A template resolves on the base theme and its own `theme`. The theme of the document it is used in and `--theme` do not reach it, so only its arguments change it. A template that wants a pack's look names that theme in `theme`. Keys it does not set come from the base theme of the frames it runs on. A document given as an argument keeps the look of the document that wrote it (section 14).
- A template is checked once against its parameter types, before any argument: each media parameter's type picks its media row, and a choice is checked with every option at every place it stands. A template that passes has its keys and types right for every argument of the right type. Values are checked for each instance, where they stand: a number its place does not take (an `in` past its `out`, a lane of 0), and what depends on an argument's content (the length of a text, what OCR finds in a media, how long a video is).
- An unknown arg, an arg of the wrong type (a media arg whose probed kind is not its type included), and a missing arg without a default stop. A declared parameter that nothing in the template refers to stops.
- Resolve then fills the arguments in, so the resolved document holds plain values.

---

## 11. Resolved document (must)

The resolved document is frames' own lockfile: what `resolve` writes, and what evaluation and `render` read. It is not an exchange format, and frames reads only what resolve wrote. It is JSON of the same kind as its document, with `"resolved": 1`, the version of its schema.

What resolve has already done:

- **Keys are checked.** A resolved document carries only the keys below.
- **No text areas.** Every area is `[x, y, w, h]`. A storyline crop and a parented area or position stay in the media pixels of their picture. Every other area on a sequence is in output pixels.
- **Files are pinned.** Every file a role opens (media, mattes, LUTs, fonts) is written as its absolute path and its SHA-256. An image sequence is pinned as its ordered list of files, each with its SHA-256, so a frame added, removed or changed is refused. `render` checks every hash before any role starts and refuses a file whose hash differs.
- **Decisions are written down.** Label sides, conformed crops and tracks (the target's rectangle on each frame followed) are values, not rules to apply again.
- **Anchor points are applied.** A `position` is written as the top left of the clip's box, and the anchor point that scale and rotation act around as `anchor`, a point in the box's own pixels.
- **Clips are named.** Every clip keeps its place in the document and its `id`, so `evaluate` and `locate` can name what made each thing drawn.
- **No names.** Theme colours, styles, presets and template arguments are written out as values. Theme lengths are already multiplied by their length scale. Colours are `#RRGGBBAA`.
- **Text is shaped.** Every title and label carries its glyph runs (font file, face, hash, size, colour, glyph ids and positions in its own box), its box size, stroke and background.
- **One clock.** Every instant on a sequence is sequence time, and keyframes keep their eases. Media keeps `in`, `out` and `speed` in media time.
- **Lanes kept.** Clips keep document order and carry their signed `lane`, so evaluation stacks them by section 8.6. The order of units during a transition (`over`) is applied at each time.

### 11.1 Resolved sequence

```json
{
  "kind": "sequence", "resolved": 1,
  "format": { "size": [1080, 1920], "fps": 30, "duration": 13.95, "background": "#000000FF",
              "content": [40, 420, 1000, 1380], "conform": "fit" },
  "storyline": [
    { "media": { "file": "/abs/run.mp4", "sha256": "9f2c41d07b3e", "frames": [0, 0.0333, 0.0667] }, "in": 2, "out": 8, "speed": 2, "start": 0, "end": 3,
      "crop": [ { "at": 0, "value": [0, 0, 1206, 2622] }, { "at": 3, "value": [45, 97, 1116, 2428], "ease": "linear" } ],
      "filter": [ { "op": "saturation", "amount": 1.25 } ],
      "transition": null }
  ],
  "clips": [
    { "title": { "size": [929.1, 68.2], "background": { "color": "#000000B8", "radius": 14.2 }, "stroke": null,
                 "runs": [
                   { "font": "/System/Library/Fonts/AppleSDGothicNeo.ttc", "sha256": "41aa0c9e5d17", "face": "AppleSDGothicNeo-Bold", "size": 51.4, "color": "#FFD43BFF",
                     "glyphs": [ [1043, 21.4, 52.0], [2210, 70.9, 52.0] ] },
                   { "font": "/System/Library/Fonts/AppleSDGothicNeo.ttc", "sha256": "41aa0c9e5d17", "face": "AppleSDGothicNeo-Bold", "size": 51.4, "color": "#FFFFFFFF",
                     "glyphs": [ [3, 288.1, 52.0] ] } ] },
      "start": 0, "end": 3, "position": [75.4, 1709.8], "blend": "normal",
      "animation": { "entrance": { "seconds": 0.35, "ease": "back-out", "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1, "opacity": 1 } ] } },
      "parent": null }
  ],
  "audio": [
    { "media": { "file": "/abs/bgm.m4a", "sha256": "c07d9a1e44f2" }, "in": 0, "out": 92.1, "speed": 1, "start": 0, "end": 13.95, "loop": true,
      "volume": [ { "at": 0, "value": 0.3 }, { "at": 12.95, "value": 0.3 }, { "at": 13.95, "value": 0 } ] }
  ]
}
```

- `format.content` is the content rect. `format.duration` is the sequence end.
- A storyline entry has `start`, `end`, its keyframable properties as sequence-time keyframe lists, its filter as an op list, and `transition` as `null` or `{start, end, over, incoming, outgoing, cover, matte}` with spans and files inline.
- Hashes in the example are cut short. A glyph is `[glyph id, x, y]`, its origin in the title's box, and the example's glyph lists are cut short too.
- A video or image sequence keeps its frame timestamps in `frames` (cut short in the example).
- A clips entry is a title, a shape, an adjustment or a media clip with its visible window `start` and `end` already narrowed by section 8.3, its properties as keyframe lists in sequence time, its animation spans inline, its `blend`, its `lane`, and `parent` (the index of the storyline entry it is composited with, or `null`).
- An audio entry is a source of sound, storyline clips included, with its volume keyframes in sequence time, its fades and its transitions. Evaluation multiplies them into the mix plan.
- A compound clip or a sequence template instance carries its nested resolved sequence in place of a media file.

### 11.2 Resolved image and layout

An image document and a layout resolve to their final size and one list of drawing steps: the source picture with its crop and scale, pads as fills, shapes, adjustments over what is below them inside their areas, shaped text and borders, each clipped to its canvas, in operation order and in output pixels. Evaluating them at any time gives the same display list.

### 11.3 Rules

- Resolve is deterministic for the same document, arguments, media, theme, presets, packs, fonts, recognised text and tracks.
- Evaluating and rendering a resolved document needs its pinned files and nothing else.
- Evaluation refuses a `resolved` version it does not know.
- Display lists and the mix plan have a JSON form too, with `"displayList": 1` and `"mixPlan": 1`, so what evaluation gives a role can be checked, recorded and replayed apart from it. A role refuses a version it does not know.
- Evaluation and `render` trust a resolved document as they trust resolve. They check its version, and `render` its hashes, not its rules again. Evaluation opens no file.

## 12. Evaluation, display lists and the mix plan (must)

`evaluate(resolved, t)` gives the display list at sequence time t: the frame size, its background, and drawing items bottom first, every value already sampled at t. Frame k of a sequence is `evaluate(resolved, k / fps)`, and an image or layout has one display list.

Every item has `transform` (an affine matrix `[a, b, c, d, tx, ty]` in output pixels), `opacity`, `blend` (section 8.14), `mask` (a rectangle in output pixels, or `null`) and `reveal` (a rectangle in the item's own coordinates before its transform, or `null`). `reveal` turns with the item, so a wipe on a rotated title follows the title. Inside a nested display list, output pixels are the pixels of that list's own frame.

| Item | Fields | Draws |
| --- | --- | --- |
| `picture` | `source` (a frame of a media file or image sequence, by index, or a nested display list), `rect` (the media region), `dest` (the output rectangle it fills), `filter` (op list, applied at `dest` size), `matte` (`{source, frame, progress, softness, invert}` or `null`), `radius`, `border` `{width, color}`, `shadow` `{radius, offset, color}` | a region of a media picture scaled into a rectangle, filtered, then masked by its matte |
| `fill` | `rect`, `radius`, `color`, `hole` (`{rect, radius}` or `null`) | a filled rounded rectangle, with an optional rounded hole |
| `stroke` | `rect`, `radius`, `width`, `color`, `trim` (0 to 1, from the top left clockwise) | the outline of a rounded rectangle, drawn as far as `trim` |
| `arrow` | `tail`, `head` (points), `width`, `headSize`, `color` | a straight arrow |
| `glyphs` | `runs` (font file, face, size, colour, glyph ids and positions), `stroke` `{width, color}`, `box` `{rect, radius, color}` | glyphs, with their outline and background box |
| `adjust` | `rect` (or `null` for the whole frame), `filter` | the filter applied to everything drawn below it, inside the rect |

- Evaluation picks a media source's frame by section 4.3 from the pinned timestamps, and the renderer draws that frame.
- Evaluation writes `seed` into every `grain` op: the number of the output frame being drawn, k for frame k of the outermost sequence (evaluated at k / fps), the frame whose interval holds t for `still` and `evaluate`, and 0 for a picture. Nested lists take the outer frame's seed, so grain belongs to the output frame and two units in a transition share it.
- A nested display list stands for an image or layout document, a compound clip at its mapped time, or a storyline unit. It is drawn at its own size, and the picture's `rect`, `dest`, `filter`, `radius`, `border` and `shadow` apply to it as to any source.
- A matte is stretched over `dest`. The picture shows where the matte's luminance in `frame` (picked from its media time, section 9.3) is below `progress`, with an edge `softness` wide, inverted when `invert` is true.
- A storyline unit (section 8.6) is one `picture` whose source is the unit's nested display list, the size of the content rect: its parented clips and its media picture (the conformed crop as `rect`, with its filter), in unit order and in content rect coordinates. The outer picture takes the transition's transform, opacity, reveal and matte, with the content rect as its mask, so they act on the unit as one picture, and a blend or an adjustment inside the unit reaches only the unit.
- Evaluation has done everything above pixels: keyframes and eases, animation spans and how they combine, transition motion, cover and matte progress, reveal (as the item's `reveal` rectangle, a `trim`, a shorter arrow or a moving hole), compositing units, parent transforms and masks, tracked motion, label sides, and the visible windows.

The mix plan is the sound of a whole sequence: a list of segments, each with a media file, its media start and speed, the sequence times it starts and ends, and a gain envelope of points `[t, gain]` joined in straight lines. The envelope already holds volume keyframes and their eases (sampled at the frame rate), fades and crossfades. A loop is one segment per repeat, and a compound clip's sounds are segments of their own.

## 13. Roles (must)

Rendering is four roles. The renderer and the mixer take the two outputs of evaluation, the decoder reads media files for all of frames, and the encoder writes files.

| Role | Takes | Gives | Also |
| --- | --- | --- | --- |
| decoder | a media file and a frame index, or for sound a media time range | a picture in the working space (RGBA with premultiplied alpha, at the media's bit depth or more), or sound | the providers, the analysis commands and `transcode` read through it too |
| renderer | display lists | frames, as pixels | reads pictures through the decoder, applies filter ops, LUTs, blend modes and mattes, draws glyphs |
| mixer | the mix plan | audio, as samples | reads sound through the decoder, stretches time with the pitch kept |
| encoder | frames and audio | a file | `transcode` uses it with the decoder |

- Each role supports everything its input names (items, filter ops, blend modes, LUTs, mattes, media formats, codecs) or refuses before it starts, naming the first thing it lacks and its place. It never drops one silently.
- A renderer draws glyphs from the font files and faces named, at the positions written, and shapes no text. It draws each frame's items as written: rounded rectangles, holes, trimmed strokes, arrows and glyphs. An engine that only runs a filter graph over time fills the decoder, the mixer or the encoder, not the renderer.
- Every decoder keeps sections 4.1 and 4.3, and frames are named by index. Frame i is the frame at `frames[i]`: a decoder checks a file's timestamps against the pinned ones and refuses before it starts when it counts them differently. So the text resolve recognised and the pixels a renderer draws come from the same frame, whichever decoder renders.
- A sequence output lasts `duration` to within one frame.
- Every file is tagged with the working space's encoding: BT.709 primaries and the sRGB transfer (IEC 61966-2-1) in a video, an sRGB chunk in a PNG, so every encoder's output looks the same in a player.
- `render` writes a master: a `.mov` (ProRes 422 HQ, or ProRes 4444 when the frames carry alpha, with 24-bit PCM sound), or a PNG for images, layouts and stills. `--deliver` also writes a delivery file from the same frames in the same step: H.264 at the encoder's highest quality with AAC at 256 kbps or more.
- The working space is sRGB. Decoded pictures are converted to it (section 4.1), and every renderer composites, blends, filters and measures matte luminance on sRGB-encoded values, the values W3C Compositing writes its formulas for. `exposure` alone works in linear light: it decodes to linear, multiplies, and encodes back. Luminance is the Rec. 709 luma of the encoded values.
- No role leaves temporary files.
- The same display lists on the same decoder and renderer give the same frames before encoding, on any machine with the same files. File bytes are not promised, since hardware encoders differ. Two renderers give the same geometry, text, timing and operations in the same working space, not the same pixels. The same mix plan on the same decoder and mixer gives the same samples.

`--decoder`, `--renderer`, `--mixer` and `--encoder` pick each role. Each defaults to `swift`.

### 13.1 Providers

| Provider | Takes | Gives |
| --- | --- | --- |
| OCR | a picture from the decoder | recognised lines: each a text and a rectangle in media pixels |
| shaping | a run of text, a font file, a face and a size | glyph ids and advances |
| tracker | pictures from the decoder around one frame, and a rectangle on that frame | a rectangle in media pixels on each frame before and after it, out to where it reports the target lost in each direction |

- What makes one line is the OCR provider's. A document can resolve on one provider and stop on another, where a line is split or joined differently, and the resolved document keeps what was found. The same holds for what a tracker followed.
- `--ocr`, `--shaper` and `--tracker` pick each provider. Each defaults to `swift` (Vision and Core Text).

## 14. Theme (must)

`theme` prints the base theme, and that output is also the list of every key a theme can hold. Its values are part of this contract, like the presets of section 9.5, so a template that leaves a key unset gets the same value on every frames of the same major version. `colors`, `styles` and `defaults.animation.title` (keyed by style name) are open maps: any name may be added. A name that is referred to must exist: a style, a colour, or a `title` key that names no style stops. A theme file and a document's `theme` hold only the keys they change, and an unknown key stops. `--theme` and a document's `theme` take `<pack>/<name>` or an absolute path, and a document's `theme` also takes a theme object.

Merging goes key by key through the theme's own structure: the top-level groups, each colour, each style and its properties, each shape and its properties, each entry of `defaults`, each entry of `defaults.animation`, and each style in its `title` map. Below that every value replaces the one under it whole: a `background`, a `stroke`, a transition choice like `{preset, seconds}`, a list.

Precedence, from weakest:

```
base theme < --theme file < document theme < keys on the clip or op
```

A document inside another starts from the theme in effect where it is written: a compound clip from its document's, and a document given as a template argument from the caller's, not the template's. A template starts from the base theme (section 10.2).

### 14.1 Base theme

The base theme is the floor every theme merges over, not the look of a form. Its open maps carry common text roles (`subtitle`, `headline`, `bannerHead`), as a browser's default style sheet carries headings, and a form's pack changes what it needs.

```json
{
  "baseWidth": 1206,
  "font": ["Apple SD Gothic Neo"],
  "colors": {
    "accent": "#ED2929", "onAccent": "#FFFFFF",
    "background": "#FFFFFF", "text": "#000000", "border": "#D9D9D9",
    "emphasis": "#FFD43B", "shadow": "#00000059"
  },
  "styles": {
    "subtitle":   { "size": 58, "weight": "bold", "color": "#FFFFFF", "emphasis": "emphasis",
                    "background": { "color": "#000000B8", "padding": [12, 24], "radius": 16 },
                    "placement": "bottom", "offset": 160, "align": "center" },
    "headline":   { "size": 72, "weight": "bold", "color": "#FFFFFF", "emphasis": "emphasis",
                    "stroke": { "width": 6, "color": "#000000" },
                    "placement": "top", "offset": 220, "align": "center" },
    "label":      { "size": 36, "weight": "bold", "color": "onAccent",
                    "background": { "color": "accent", "padding": [8, 16], "radius": 12 }, "lines": 1 },
    "banner":     { "size": 38, "weight": "regular", "color": "text", "lineHeight": 64 },
    "bannerHead": { "size": 44, "weight": "bold", "color": "text", "lineHeight": 64 },
    "heading":    { "size": 44, "weight": "bold", "color": "accent", "lineHeight": 80 }
  },
  "shapes": {
    "box":       { "width": 8, "radius": 18, "color": "accent" },
    "fill":      { "color": "#FFD43B80" },
    "dim":       { "color": "#0000008C" },
    "arrow":     { "width": 10, "length": 160, "color": "accent" },
    "border":    { "width": 3 },
    "shadow":    { "radius": 24, "offset": [0, 8], "color": "shadow" },
    "label":     { "sides": ["right", "bottom", "left", "top"] }
  },
  "area":      { "padding": 14, "cropPadding": 40 },
  "placement": { "padding": 40 },
  "image":     { "bannerPadding": 40 },
  "layout":    { "gap": 40, "padding": 40 },
  "defaults":  { "transition": "cut", "filter": "none",
                 "animation": { "title": { "label": "pop" }, "shape": "none", "media": "none", "adjust": "none" } }
}
```

### 14.2 Styles

A style is a named set of text properties. Any name is allowed, and frames reads three names itself, the default style of each text part it draws: `label` (shape labels), `banner` (banner lines) and `heading` (layout headings).

| Property | Meaning |
| --- | --- |
| `size` | font size |
| `weight` | `regular` or `bold` |
| `color`, `emphasis` | text colour, and the colour of `**text**` |
| `lineHeight` | distance between baselines. The default is 1.25 × size |
| `stroke` | `{width, color}`: an outline with round joins, where strokes never show overlapping. Absent means none |
| `background` | `{color, padding, radius}`: a box behind the text, or `false` |
| `placement`, `offset` | default placement (section 4.5) |
| `align` | `left`, `center` or `right` |
| `lines` | `1` keeps the text on one line |

### 14.3 Defaults

`defaults` holds the presets a form uses when a clip names none. They are part of a form's look, which is why they live in the theme: shorts pop their subtitles, evidence does not. `animation` holds `title` (keyed by style name, which covers labels through the `label` style), `shape`, `media` and `adjust`. Anything not listed is `none`, the transition default is `cut`, and the filter default is `none`. A clip whose media is a compound clip or a template instance takes no default filter, since the clips inside it already took theirs.

### 14.4 A form's theme

A form's theme lives in its pack (section 17) and holds only the keys it changes. The `shorts` pack's theme, `shorts/shorts`:

```json
{ "baseWidth": 1080,
  "colors": { "accent": "#FF3B30", "emphasis": "#FFE14D" },
  "styles": {
    "subtitle": { "size": 66, "background": false, "stroke": { "width": 7, "color": "#000000" }, "offset": 330 },
    "headline": { "size": 84, "offset": 110 },
    "label":    { "size": 40 } },
  "shapes": { "box": { "width": 10 } },
  "defaults": { "transition": { "preset": "push-up", "seconds": 0.3 },
                "animation": { "title": { "subtitle": "pop", "headline": "none", "label": "pop" }, "shape": "draw", "media": "pop" } } }
```

---

## 15. Command line (must)

```
frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>] [--encoder <name>] [--ocr <name>] [--shaper <name>] [--tracker <name>] <command> ...

render    <document.json> -o <out.mov | out.png> [--deliver <out.mp4>] [--args <args.json>]
still     <document.json> --at <t>[,<t>...] -o <out.png> [--args <args.json>]
resolve   <document.json> -o <resolved.json> [--args <args.json>]
timeline  <document.json> [--args <args.json>] [--json]
evaluate  <document.json> --at <t> [--args <args.json>]
locate    <document.json> --at <t> --point <x,y> [--args <args.json>]
probe     <media> [--json]
ocr       <image | video> [--at <t> | --from <t> --to <t> --step <s>] [--json]
track     <video> --at <t> --area <area> [--to <t>]
extract   <video | document.json> <outdir> [--from <t>] [--to <t>] [--step 1]
sheet     <video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]
transcode <in> -o <out> [--quality high|medium|low] [--max <px>] [--codec h264|hevc]
presets   [<kind>] [<name>]
packs     [<pack>]
theme
```

- Every command that takes a document (`render`, `still`, `timeline`, `evaluate`, `locate`, `extract`, `sheet`) also takes a resolved document, which it uses as it is. `render` takes a document, a template with `--args`, or a resolved document. A resolved document with `--theme` or `--args` stops, since both are already written in. A template renders with its defaults when every parameter has one. A template with `--theme` stops, since only its arguments change it.
- `still` draws sequence frames at the given sequence times without encoding a video. Several times go side by side, each labelled with its time in the `label` style, laid out by resolve like any title. It is the cheap check while a sequence is being written.
- `timeline` resolves without rendering and prints, for every storyline clip, its edit range, drawn range, clip range (`[in, out)` on its clip time), speed, and incoming transition with its length, and for every other clip, its visible range, kind, animation and place (`storyline[1].connected[0]`). Everything resolve stops on (an unknown preset, a clip that is never visible, a label with no room, a bad argument) stops here too. It writes no file.
- `evaluate` prints what is drawn at sequence time t, clip by clip. `locate` maps a point of the output at t back to the document (section 15.2).
- `probe` prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in media pixels. Over a range it does this for each frame, under a line with its media time.
- `track` follows an area (section 4.2) found at media time `--at`, backwards and forwards with the tracker provider, as `track` on a clip does.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each labelled with its time. Given a document they take composite frames at sequence times, as `still` draws them.
- `presets` lists presets with their descriptions, or prints one preset's JSON. `packs` lists installed packs, or what one pack holds.
- The analysis commands (`probe`, `ocr`, `track`, `extract`, `sheet`) use the providers, and `transcode` writes with the encoder role. All of them read media through the decoder role.
- Paths are absolute. A document argument may also name a pack template, `<pack>/<name>`, or be `-`, read from standard input.
- A command frames does not have, `frames <name> ...`, runs `frames-<name>` from `PATH` with the global options before the name and the arguments after it, unchanged, and with standard input and output passed through (section 17.1).
- `frames --version` prints the version (section 10.1). An extension checks it against the versions it is written for, as a pack does with `[frames] engine`.
- On success, stdout gets one line with the output path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints usage and exits with 64.
- Messages name the place, for example `storyline[2].connected[0] (arrow): unknown key "anim". Allowed: at, lane, opacity, animation, keyframes, shape, area, label, labelAnimation, color, blend, side`.

### 15.1 transcode

| Input (judged by contents) | Output extension | How it shrinks |
| --- | --- | --- |
| image | `.jpg`, `.heic`, `.png` | JPEG or HEIC quality. PNG only shrinks through `--max` |
| audio | `.m4a` | AAC, up to 2 channels and 48 kHz |
| video | `.mp4`, `.mov`, `.m4v` | H.264 (default) or HEVC, with AAC sound |
| video | `.m4a` | the sound only |

| Quality | Image (0 to 1) | Video | Audio (per channel) |
| --- | --- | --- | --- |
| `high` | 0.9 | high | 96 kbps |
| `medium` (default) | 0.75 | medium | 64 kbps |
| `low` | 0.55 | low | 32 kbps |

- `--max` caps the longer side. A smaller source is never enlarged. Video sizes round to even numbers.
- Metadata (EXIF, location) is not copied. Rotation is applied to the pixels. A JPEG gets transparent parts on white.
- The output line gives size, format and the ratio to the source, and says so when the output is not smaller.
- The same file as input and output stops, and so does an extension that does not fit the input. An existing output file is removed only after every check passes.

### 15.2 Machine output

What frames reports about a document or a medium is a contract, so programs outside frames can build on it. With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name with the version of its schema. The text output is for people and is not part of the contract.

| Command | Object |
| --- | --- |
| `probe` | `{"probe": 1, kind, size, duration, fps, alpha, audio}`, `audio` as `{channels, sampleRate}` or `null` |
| `ocr` | `{"ocr": 1, size, frames}`, each frame `{time, lines}` and each line `{text, rect}`. An image has one frame at time 0 |
| `track` | `{"track": 1, frames}`, each frame followed as `{time, rect}`, in time order |
| `timeline` | `{"timeline": 1, duration, storyline, clips}`. A storyline entry has `place, id, media` (the file, or `null`), `edit`, `drawn`, `clip` (each `[start, end)`), `speed` and `transition` (`{preset, seconds}` or `null`). A clips entry has `place, id, kind, visible, lane, parent` (the place of its storyline clip, or `null`) and `animation`. An entry whose media is a compound clip or a template instance also has `nested`, the timeline object of the document inside, with places continued from the entry's. Section 8.3 maps sequence time to clip time and media time from these values |
| `evaluate` | `{"evaluate": 1, time, size, items}`, bottom first, each `{place, id, kind, bounds, opacity}`: the clip or op that drew it (`null` for the background, a transition cover and the fill outside the content rect), and the output rectangle it covers after its transform and mask. Inside a nested document a place continues the place of the clip that holds it (`storyline[0].media.storyline[2]`) |
| `locate` | `{"locate": 1, hits}`, topmost first: every item under the point, each `{place, id, kind}`, and for a picture of a media file also `{media, mediaTime, point}`, the point in that media's pixels |

- A change to an object raises its version, and the old form is no longer printed (section 2, no legacy keys).
- Places are those of section 15 messages.
- The display list and the mix plan are the roles' wire forms (section 11.3), not part of this output.

---

## 16. What a correct result keeps (must)

These are the acceptance tests.

- The first frame is not black or empty unless the storyline opens with a solid. A clip visible from 0 shows on the first frame.
- Nothing of a cropped, filled or moving storyline clip shows outside the content rect.
- During a transition both units show, stacked as section 8.6 says.
- An unparented connected clip plays its whole window, across edit points.
- A parented clip goes with its picture: a transition covers, wipes or moves it exactly as it does its picture.
- A connected shape follows the crop and stays on the text it points at.
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A label sits on the first side in `shapes.label.sides` where it fits.
- A tracked clip stays on its target on every frame the tracker followed, at every zoom.
- The master is ProRes and PCM at full quality. Only `--deliver` and `transcode` trade quality for size.
- A storyline image is resampled once, from its source straight to its size on the output.
- Evaluating a resolved document at the same time always gives the same display list, and rendering it twice on the same decoder and renderer gives the same frames before encoding.
- A resolved document whose files changed is refused.
- A role that lacks a feature refuses before it starts.
- No temporary files are left.

## 17. Guides, how-tos and extensions

Guides, how-tos and extensions sit outside the engine. They only use what frames already has.

A form is a kind of result (a PR screenshot, a vertical short, a demo) and is a pack (section 10.1): its guide (`guide.md`), a theme when its look differs from the base theme (`themes/`, only the keys it changes), its examples (`examples/`, each runs once its paths are changed), and any presets and templates of its own. Adding a form is adding a pack, and frames does not change. A form's edits differ in how many clips, boxes and lines they hold, so a form is taught, not templated. A guide holds:

- what the form is for: who watches it, and where
- its theme
- its format: size, inset, conform, and how the top band or banner is built from titles
- its rules for text, emphasis, cuts and length, each with a one-line reason
- which presets to use and which not to, with the reason
- an example

A how-to (`howto/<name>.md`) teaches a technique that belongs to no form, so it has no theme and no example of its own. Making material outside frames is a how-to.

A missing look becomes a preset or a pack. A missing capability goes into this specification and the model first, and into the roles only when it needs a new kind of pixel, sound or file work. A form-only feature, or one that serves a purpose rather than editing, is never hidden in either.

How to make anything:

1. Pick the form and read its guide.
2. Look at the material. `probe` it, lay video out with `sheet` every 1 to 2 seconds, then again every 0.5 seconds over the chosen range. Check the text to point at with `ocr`.
3. Write the document, with templates from packs as media where they fit. Point at places by their text, and write connected instants in clip seconds. Check times with `timeline` and pictures with `still`.
4. Render the master.
5. Lay the result out with `sheet` and check it against section 16.
6. `transcode` for where it goes.

### 17.1 Extensions

Three kinds of thing are added to frames without changing this specification.

| Kind | What is added | Section |
| --- | --- | --- |
| data | presets, themes, templates, LUTs, mattes and media, in packs | 9, 10 |
| implementations | a decoder, renderer, mixer or encoder, an OCR, shaping or tracker provider, built into frames under the name `--decoder` and the other options pick | 13 |
| extensions | programs that take a document and give a document | here |

An extension reads what frames reports (section 15.2) and writes or changes documents. It finds personal data and covers it, cuts silence, places captions from a transcript, cuts to a beat, translates titles, or bakes an effect frames has no op for. Its interface is documents and the machine output, so frames has no extension API.

- It finds clips by `id` and `timeline`, where things are by `evaluate` and `locate`, and pictures by `still`, `extract` and `sheet`, which take the document itself, so what it sees is what frames draws from the same resolve. An extension that must be sure of what is drawn, such as one that covers personal data, resolves the document once, checks that resolved document with `evaluate`, `still` and `extract`, and has the same resolved document rendered. It passes the resolved document on and does not read it, since its form is frames' own (section 11). An extension that gives a resolved document ends the chain: only frames commands take it after that, so such an extension runs last, and a chain has one.
- It gives a document on standard output, and `timeline` checks it like any other. Extensions chain: `frames autocut doc.json | frames privacy - | frames render - -o out.mov`.
- `frames <name>` runs `frames-<name>` from `PATH`, so an extension is installed by putting it there.
- An extension that splits a clip keeps the clip's `id` on the first part and gives every other part a new one. An unparented connected clip goes with the part that holds its start and plays on as before. A parented clip is part of its picture, so one whose window crosses the cut is copied onto each part it crosses, the first copy keeping its `id` and the others taking new ones. Clip time is media time, so the copies keep their `at`.
- An extension acts before resolve. What must act while frames renders is a role or a provider, so a resolved document stays enough to make the result again, and a pack stays data that every role can draw.

Forms that ship with frames, as packs:

- **pr-evidence:** its theme `pr-evidence/pr-evidence` changes only `shapes.label.sides`. The conclusion and the reason go in the banner, the conclusion first in `bannerHead`. Crops are bands (`{"band": ...}`), since evidence keeps whole lines. Labels never go above a box, where they would cover the line above, which is why its theme takes `top` out of `shapes.label.sides`. Only the reason lines get a box. Personal data is covered with an opaque `fill` at opacity 1 with no animation, on every clip and every frame that shows it: on video with `track`, or area keyframes from `ocr --json` where it leaves the screen and comes back. A template is a closed box, so a recording given to one is covered first: render it with its covers to a master and pass that file. The finished file is checked with `ocr`. No filters and no music. Transitions are `fade` at 0.3 to 0.5.
- **shorts:** Korean vertical short-form, 9:16, with the theme `shorts/shorts` (section 14.4). A headline in the top band, outlined subtitles with `pop`, `push-up` between scenes.
- **demo:** a feature demo on the base theme.

First how-tos:

- **motion-graphics:** making graphics outside frames. Write HTML, render it to a PNG sequence with alpha in a headless browser, and bring it in as `{"sequence": ...}` media.
- **effects:** an effect beyond the filter ops (particles, a glitch, a shader of one's own) is made outside. Render it as a video with alpha and lay it over with a `blend`, or `extract` the frames of the clip's media file over its range, process them, and point the clip's `media` at the result.

## 18. Out of scope

- Effects as code run by a renderer: shaders and scripts. Packs carry data only, so every role can draw them. Filters, LUTs, matte transitions and blend modes cover most of what such effects are bought for, and the rest is made outside and arrives as media (the effects how-to). A per-pixel kernel carried as data in a portable shading language is where a later contract would add them.
- Stabilisation, audio filters beyond volume, per-character text animation.
- GIF and WebM output. Rendering makes MOV, MP4 and PNG.
- Speech synthesis, recording and transcription. Sound arrives as files.
- Generating graphics. They arrive as media.
- Fetching packs over the network. Installing is copying.

Adding any of these later raises the minor version (section 10.1). Whoever adds one updates the key tables, the README and this document together.

---

## 19. Recommended structure

### 19.1 Stages

```
1. check      walk the JSON tree against the key tables
2. read       theme, presets, packs, media facts (probe), then check the media rows
3. resolve    template arguments, text areas (OCR provider), text layout (text provider), scale, styles,
              the time plan (durations, edit points, transitions, ranges), tracks (tracker provider), visible windows,
              label sides, units and lanes.
              timeline stops here, resolve writes it out
4. evaluate   the display list at a time, the mix plan
5. roles      decoder, renderer (filter, draw), mixer, encoder
```

### 19.2 Drawing a frame

```
evaluate(resolved, t):
  items = [fill background]
  items += unparented clips on negative lanes visible at t
  for each storyline unit visible at t, bottom first:
      media time = inverse of the clip's time map at t
      unit = its parented clips on negative lanes
           + picture(source frame at that media time, rect = conformed crop at t, dest = the whole unit, filter)
           + its parented clips on positive lanes, all in content rect coordinates
      items += picture(unit, dest = the content rect, mask = the content rect,
                       transform, opacity, reveal and matte of the transition at t)
  items += transition cover, a fill or a picture
  items += fill of everything outside the content rect, with the content rect as a hole
  for each unparented clip on a positive lane visible at t, in order:
      values = keyframes at t, combined with the animation at t
      items += its picture, glyphs, fill, stroke, arrow or adjust
  return items
```

- A renderer may draw a glyphs item once and reuse it while only its transform changes.
- Decoded media frames are cached.

### 19.3 Modules

| Module | Owns |
| --- | --- |
| model | document types and the key tables |
| theme | the base theme, merging, scale |
| preset | reading presets, spans, easing |
| pack | finding packs, templates and their arguments |
| area | areas, the OCR provider and the tracker provider |
| text | text layout and the shaping provider |
| resolve | the time plan, timeline, the resolved document |
| evaluate | display lists at a time, the mix plan |
| decoder, renderer, mixer, encoder | one module per backend for each role |
| analysis | probe, ocr, track, extract, sheet, evaluate, locate, and the machine output |
| transcode | image, audio and video delivery files |
| cli | commands, arguments, error output |

### 19.4 Package

```
frames/
  manifest.toml
  README.md                commands and the document reference
  document/
    SPEC.md                this document
    GUIDE.md               how to make anything, how to write a guide or a how-to
    PRESET.md              how to write a preset
    PACK.md                how to make a pack, a form and a template
    howto/<name>.md
  presets/                 built in, laid out as in a pack
    transition/*.json
    animation/*.json
    filter/*.json
  packs/                   the forms that ship with frames
    pr-evidence/  shorts/  demo/
  source/                  the sources and the built tool
```

### 19.5 Order of work

1. The contract as data: key tables, the base theme, presets, spans and easing. Pure data with easy unit tests.
2. Resolve and `timeline`: templates, packs, text areas, text layout and the time plan without rendering, tested against section 8.3.
3. Evaluate: display lists at a time and the mix plan, tested as data without drawing.
4. The Swift roles: the decoder, the renderer (pictures, fills, strokes, arrows, glyphs, adjustments, filters, LUTs, blend modes, mattes), the mixer, and the encoder for ProRes and H.264. Checked against section 16 with `still` and `sheet`.
5. `transcode`, `probe`, `extract`, `sheet`, `ocr`, `track`, `evaluate`, `locate`, `packs`, and the machine output of section 15.2.
6. The 42 presets, the base theme, the form packs (themes, guides, examples) and the first how-tos.

---

## 20. Practical notes

These are not contract, but help whoever writes documents.

- OCR confuses similar characters (`0` and `O`). Read the `ocr` output before pointing, and point with a part of the text that is less confusable, plus `nth`.
- On a 1206-wide vertical video a subtitle line holds about 21 Korean characters. Longer subtitles wrap, and more than two lines are hard to read.
- Starting a connected shape while the screen is still moving puts it where the text was at that frame. Start after the screen settles, or follow it with area keyframes.
- PNG is lossless and does not shrink when written again. Use JPEG or HEIC for smaller files.
- `transcode` target: a 1080×1920, 35-second short (11.7 MB) comes to about 3.4 MB at PSNR around 44 dB at `medium`, about 5.5 MB (50 dB) at `high`, and about 2.2 MB (38 dB) at `low`. Text on screen stays sharp at every level.
- HEVC looks slightly better than H.264 at the same level, at about the same size, and some browsers cannot play it. H.264 is the default for delivery.
