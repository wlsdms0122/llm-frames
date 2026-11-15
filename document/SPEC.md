# frames specification

frames is an image and video editing tool that an agent drives. The agent writes a document in JSON, frames resolves and evaluates it, and an engine draws the result to a PNG or an MP4.

This document is the contract. It says what frames takes, what it gives back, and how it behaves, and leaves out how any implementation is built.

- **Must:** behaviour an implementation keeps. Document shapes, time and coordinate rules, the resolved document, the display list, the engine contract and error behaviour are here.
- **Recommended:** structure that makes the contract easier to keep. An implementation may ignore it.

---

## 1. What frames is

frames is built like a non-linear editor (NLE) such as Final Cut Pro or Premiere Pro, with a sequence, a primary storyline of clips, clips connected to them, lanes, transitions, keyframes and filters. The same model makes three kinds of output: evidence for a pull request (a screenshot with boxes, redactions and a banner of text), vertical short-form video, and feature demo video.

- A document and its media are enough to make the result again.
- Places in a picture are named by the text on screen, found by text recognition (OCR), instead of measured by hand.
- frames composites media and does not generate it. Motion graphics, illustrations and diagrams are made with other tools (HTML in a headless browser, an image model, a design tool) and arrive as media: a PNG, a PNG sequence, or a video with alpha.
- Titles and shapes are built in, as the basics of any NLE. A shape points at an area: its geometry is part of frames, and how it moves is a preset.

## 2. Principles

| Principle | Meaning |
| --- | --- |
| The editing model is the product | Documents, time, anchors, presets, themes, text layout and evaluation at a time are defined once, here, and implemented once |
| Engines are replaceable | An engine draws display lists, mixes a mix plan (section 11) and encodes them. It knows nothing of clips, keyframes or presets. A Swift engine comes first, and an engine built on ffmpeg or anything else draws the same display lists |
| Standard vocabulary | Names come from NLEs and compositing tools: storyline, connected clip, in and out points, lane, keyframe, transition, crop, title, parenting, compound clip, display list |
| Composite, do not generate | Anything beyond titles and shapes arrives as media |
| Look is theme, combination is guide, effect is data | Sizes, colours, text styles and default presets live in a theme. Which pieces a form combines lives in a guide. Transitions, animations and filters are preset files, and adding one needs no rebuild |
| Unknown keys stop | Every object has a fixed set of keys. A typo stops with the place it was found instead of rendering as "no effect" |
| Ambiguity stops | A text anchor that matches more than one line stops and lists the matches |
| A value that still does what it says is clamped, one that cannot stops | A transition longer than its clips, an out point past the end of the media, an area partly outside the picture: each is cut to what fits and still does its job. A clip that is never visible, an area wholly outside the picture, a one-line label that does not fit: each stops |
| No legacy keys | When a key changes, old documents stop. There is no compatibility branch |
| Render at full quality, deliver separately | Rendering never trades quality for size. `transcode` does that |
| Reproducible from the resolved document | What can differ between machines (recognised text, fonts, themes, presets) is fixed into the resolved document. Drawing it again on the same engine gives the same result on any machine that has the same media and font files |
| Sound is media | frames places sound files on the timeline. Speech synthesis, recording and transcription happen outside |

## 3. Shape of the system

```
theme.json ─────┐
presets/ ───────┤
                ▼
document.json ─▶ resolve ─▶ resolved document ─▶ evaluate ─▶ display lists, mix plan ─▶ engine ─▶ PNG / MP4
                  ▲   ▲                                                         swift, ...
            OCR provider, text layout provider

analysis: probe, ocr, extract, sheet          delivery: transcode
```

- **Document:** what the agent writes. There are three kinds: `image` (section 6), `layout` (section 7) and `sequence` (section 8).
- **Resolve:** checks keys, merges the theme, reads presets, finds text anchors, lays out text with real fonts, and plans time. Its output is the resolved document (section 10). It creates no media.
- **Evaluate:** turns a resolved document and a time into a display list (what to draw at that instant, with every keyframe, animation, transition and parent already applied), and a resolved sequence into one mix plan for its sound. It is deterministic, calls no provider, and is shared by every engine. Resolve and `timeline` may call it for geometry.
- **Engine:** decodes media, applies filter operations, draws display lists and encodes the output (section 12).
- **Providers:** OCR and text layout depend on the platform, and only resolve calls them. They read media files and fonts, never drawn pixels, so no resolved value depends on an engine. A resolved document needs neither again.
- **Analysis:** tools that give the agent facts to write a document with. They take no part in rendering.
- **Transcode:** makes a delivery file from an image, audio or video file. It is not part of rendering.

## 4. Common values

### 4.1 Units (must)

| Value | Unit |
| --- | --- |
| Time | seconds, as a number. Which clock a time is on is section 8.3 |
| Area in source media | pixels of the source picture as it is displayed, origin at the top left: rotation metadata applied, pixels made square |
| Position and size on a sequence | pixels of the output, origin at the top left |
| Theme lengths (text size, stroke, padding, line width, filter radius) | points at the theme `baseWidth`, multiplied by the scale of the place they are drawn (below) |
| Animation offsets `x`, `y` | multiples of the animated thing's own size. In a transition, multiples of the content rect |
| Angles | degrees, clockwise positive |
| Colours | `#RRGGBB`, `#RRGGBBAA`, or the name of a theme colour |

Source seconds are the media's presentation timeline after its edit list, with 0 at the first presented frame. Decoded pictures are converted to sRGB, and HDR sources are tone mapped by the engine. Providers and engines read media by these definitions.

Scale is `width / baseWidth`, where width is the output width for a sequence, the width of the picture at that operation for an image document, and the widest item for a layout.

### 4.2 Areas (must)

A place in a picture is given in one of four forms. Coordinates are source pixels.

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `"text"` | the one recognised line that contains the text |
| `{"text": "...", "nth": 1}` | the nth line (from 0) among the lines that contain the text |
| `{"from": "...", "to": "...", "fromNth": 0, "toNth": 0}` | the rectangle around both lines and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |

- Text is compared with whitespace removed. A line matches when it contains the text.
- A text form without `nth` that matches more than one line stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that matches no line stops, naming the media, the text and the nth.
- An area found by text grows outward by the theme `anchor.padding`.
- On video, the text is searched in the frame at the source time where the area takes effect: a connected clip's start, a keyframe's time, or a storyline clip's `in` for a static crop. An image document's `time` picks its frame.
- Text is only recognised in media files. On an image document used as a source, a text anchor finds the text in that document's `source` and follows its operations to where that text ended up. A compound clip takes no text anchor from outside, since its picture is drawn, not read. Text inside it is pointed at from the nested document.

### 4.3 Media references (must)

| Form | Meaning |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents |
| `{"sequence": "/abs/dir", "fps": 30}` | a numbered image sequence: every PNG in the directory, in natural order (runs of digits compare as numbers), at that rate. It plays like a video: its seconds are frame index / fps, and it takes `in`, `out` and `speed` |
| an image or layout document object | the picture that document draws (sections 6 and 7) |
| a sequence document object | a compound clip: the nested sequence plays as a video with sound, its seconds are its media seconds, and its theme is merged over the one in effect |

- Paths are absolute.
- Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha) and compound clips. This is how graphics made elsewhere come in.
- At source time s, a video, an image sequence or a compound clip shows the frame whose presentation interval holds s: its timestamp is at or before s, and the next one is after s. OCR, extraction and drawing all pick frames by this rule.

### 4.4 Keyframes, easing and interpolation (must)

Any property marked keyframable takes a static value, a list of keyframes, or both. A keyframe is an object with `at`, one or more properties, and an optional `ease`.

```json
"opacity": 1,
"keyframes": [ { "at": 3, "position": [600, 500] }, { "at": 4, "position": [330, 900], "scale": 1.5, "ease": "ease-in-out" } ]
```

- Each property joins only the keyframes that name it. Before its first keyframe it holds the first value. After its last it holds the last value.
- A property that no keyframe names uses its static value, or its default.
- A keyframe's `ease` shapes the span coming into that keyframe. The default is `linear`.
- A keyframe's `at` is an instant on the clock of its clip (section 8.3).
- Numbers, points and colours interpolate per component, colours in linear light. An `area` interpolates per component. A `crop` interpolates its centre per component and its size geometrically (in log space), so a zoom keeps one speed. Crops are conformed to one aspect ratio first (section 8.5), so the ratio holds between keyframes.
- An area given by text resolves at its own keyframe's time before it interpolates.

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

A clip on a sequence that is not placed by an area is placed by `placement` or `position`:

- `placement` is a name: `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right`. The clip sits inside the output frame, inset by the theme `placement.padding` on every side. A text style's `offset` replaces that inset on the top or bottom edge, when the name has one (a subtitle sits `offset` above the bottom of the output).
- `position` is `[x, y]`, the top left of the clip in output pixels. It is keyframable, and once set it replaces `placement`.

Placement is measured on the output frame, not the content rect, so a title can sit in the band an inset leaves. The default is the text style's placement for titles and `center` for media.

### 4.6 Text layout (must)

Text is laid out by resolve, with real fonts, so line breaks, sizes and label sides are part of the resolved document and are the same on every engine.

- A style's font is the first family in the theme `font` list installed on the machine, in the style's weight. Characters that face lacks fall back to the platform's fallback fonts.
- Lines break by Unicode line breaking (UAX #14) at the wrapping width, and at `\n`.
- Resolve shapes the text. The resolved document carries glyph runs (font file, face, size, colour, glyph ids and positions) and the box they fill. An engine draws the glyphs where they are written and shapes nothing.
- `**text**` takes the style's `emphasis` colour.
- A style with `lines: 1` never wraps. Text wider than its room stops, since a cut label would say something else.

---

## 5. Documents

Every document is a JSON object with a `kind` of `image`, `layout` or `sequence`. A document may carry a `theme` object, which is merged over the theme in effect (section 13).

## 6. image document

An image document edits one picture with an ordered list of operations.

```json
{
  "kind": "image",
  "source": "/abs/shot.png",
  "ops": [
    { "crop": { "from": "Certificate", "to": "Last line" } },
    { "shape": "box", "area": "serialNumber: 9190809", "label": "matches the server" },
    { "shape": "dim", "area": { "from": "LV2", "to": "Cert,O=" } },
    { "shape": "redact", "area": "issuerDn:" },
    { "shape": "arrow", "area": "serialNumber", "side": "right", "label": "here" },
    { "title": "Note", "position": [40, 40], "style": "label" },
    { "resize": { "width": 800 } },
    { "pad": [20, 40], "color": "#FFFFFF" },
    { "banner": ["Bold first line", "Regular line"], "edge": "top" },
    { "border": true }
  ]
}
```

- `source` is any media reference that gives a picture. For a video, `time` picks the frame in source seconds.
- **Every area and point is written in source coordinates.** frames maps source coordinates through the crops, resizes, pads and banners before them. Coordinates outside the source picture reach into pads and banners, so a title at `y: -20` sits in a top pad.
- `crop`, `resize`, `pad` and `banner` change the canvas. `shape`, `adjust`, `title` and `border` draw on it. Operations run in order, as layers: a drawing is made at its operation with theme lengths scaled by the width of the picture at that point, and later canvas operations move and scale it with the picture. `adjust` is an adjustment layer: it changes everything drawn before it, inside its area or over the whole picture, so a box drawn before a pixelate is pixelated and a box drawn after it is not.
- Wherever a picture is taken (a layout item, a storyline clip, a connected clip), an image document can stand in for a path.

| op | Keys | What it does |
| --- | --- | --- |
| `crop` | area | Keeps the area. A text area crops a full-width band with `anchor.cropPadding` above and below, since evidence keeps whole lines. The band is clipped to the picture |
| `resize` | `{scale}`, `{width}` or `{height}` | Resizes and keeps the aspect ratio |
| `pad` | `n`, `[vertical, horizontal]` or `[top, right, bottom, left]`, `color` optional | Adds a margin. The default colour is the theme `background` |
| `shape` | `box`, `highlight`, `dim`, `arrow` or `redact`, with `area`, `label`, `side`, `color` | Draws a shape (section 8.9), or hides the area (section 8.10) |
| `adjust` | filter preset, `area` optional | Applies a filter preset to everything drawn before it, inside the area when one is given |
| `title` | text, `position` (source `[x, y]`), `style` | Places a title (section 8.8) |
| `banner` | lines, `edge` (`top` or `bottom`) | Extends the picture with a band of text. The first line takes the `bannerHead` style and the rest take `banner` |
| `border` | `true` (the `border` colour) or a colour | Draws a border around the picture with the theme `shapes.border.width` |

## 7. layout document

A layout places pictures on a grid.

```json
{
  "kind": "layout",
  "banner": ["Bold first line", "Regular line"],
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
      "keyframes": [ { "at": 18, "crop": { "scale": 1 } }, { "at": 19, "crop": { "from": "Enter your password", "to": "3" }, "ease": "ease-in-out" } ],
      "connected": [ { "at": [19, 22], "shape": "box", "area": "Sent", "label": "done", "animation": "stamp" } ] },
    { "media": { "kind": "image", "source": "/abs/card.png" }, "duration": 2.5,
      "transition": { "preset": "wipe-right", "seconds": 0.5 },
      "connected": [ { "at": [0, 2.5], "shape": "box", "area": "First line",
                       "keyframes": [ { "at": 1.2, "area": "First line" }, { "at": 1.65, "area": "Second line" } ] } ] }
  ],
  "clips": [
    { "at": [0, 30], "title": "Top title\n**emphasis**", "style": "headline", "lane": 2 },
    { "at": [1, 6], "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
      "placement": "top-right", "animation": { "entrance": "pop", "exit": "fade" }, "lane": 5,
      "keyframes": [ { "at": 3, "position": [600, 500] }, { "at": 4, "position": [330, 900], "scale": 1.5, "ease": "ease-in-out" } ] },
    { "media": "/abs/bgm.m4a", "volume": 0.3, "loop": true, "fadeOut": 1 },
    { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 },
    { "at": [4, 9], "shape": "redact", "area": [80, 1500, 600, 90] }
  ]
}
```

- `storyline` is the primary storyline. Its clips play one after another, and transitions overlap them.
- `connected` clips belong to one storyline clip and live on its source clock. They move when that clip moves.
- `clips` are the sequence's clips on the sequence clock.
- A clip is a media clip (`media`), a title (`title`), a shape (`shape`), an adjustment clip (`adjust`) or a solid (`solid`, storyline only). Exactly one of these keys is present.

### 8.2 Keys (must: any other key stops)

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, storyline, clips` |
| format | `size, fps, background, inset, conform` |
| storyline clip, timed media (video, image sequence, compound) | `media, in, out, speed, crop, filter, transition, volume, fadeIn, fadeOut, keyframes, connected` |
| storyline clip, still (image, image or layout document) | `media, duration, crop, filter, transition, keyframes, connected` |
| storyline clip, solid | `solid, duration, transition, connected` |
| every connected and sequence clip | `at, lane, opacity, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip's, `media, in, out, speed, loop, volume, fadeIn, fadeOut, placement, position, parent, scale, rotation, crop, filter, width, height, radius, border, shadow` |
| still media clip (image, image or layout document) | every clip's, `media, placement, position, parent, scale, rotation, crop, filter, width, height, radius, border, shadow` |
| audio clip | `at, media, in, out, speed, loop, volume, fadeIn, fadeOut, keyframes` |
| title clip | every clip's, `title, style, width, placement, position, parent, scale, rotation` |
| shape clip | every clip's, `shape, area, label, color`, and `side` for an arrow |
| redaction | `at, lane, keyframes, shape, area, color` |
| adjustment clip | every clip's, `adjust, area` |
| keyframe | `at, ease`, and the keyframable properties of its clip |
| transition choice | a preset name, an absolute path, `"cut"`, or `{preset, seconds}` |
| animation choice | a preset name, an absolute path, or `{entrance, exit}` |
| filter choice | a preset name, an absolute path, a list of those, or `"none"` |
| image document | `kind, source, time, theme, ops`, and each op's keys from section 6 |
| layout document | `kind, theme, banner, columns, border, items`. An item takes `heading, image` |

Which media row applies depends on what the file holds, so those keys are checked once the media has been probed.

Keyframable properties:

| Clip | Properties |
| --- | --- |
| storyline clip | `crop, volume` |
| media clip | `position, scale, rotation, opacity, crop, volume` (audio clips: `volume`) |
| title clip | `position, scale, rotation, opacity` |
| shape clip | `area, opacity` (a redaction: `area`) |
| adjustment clip | `area, opacity` |

Keys are checked over the whole JSON tree before any value is read, except the media rows, which follow the probe. A value of the wrong type also stops, with its place. A property written both as a static value and in a keyframe stops, since the static value would never show.

### 8.3 Time (must, the most important rule)

A sequence has two clocks. **Source time** is the time inside one storyline clip. **Sequence time** is the time of the output.

**Instants are on the clock of their owner. Durations are sequence seconds.**

| Instant | Clock |
| --- | --- |
| a storyline clip's own `keyframes` | that clip's source time |
| a connected clip's `at` and `keyframes` | its storyline clip's source time |
| a sequence clip's `at` and `keyframes` | sequence time |
| `in` and `out` of any media clip | that media's own seconds |

Durations (a media clip's natural length, `duration`, transition and animation `seconds`, loop `period`, `fadeIn`, `fadeOut`) are always sequence seconds. A sound connected to a clip at speed 2 plays its full length at its own speed, and an entrance takes the same time on every clip.

Source time is the media's own seconds for a video, image sequence or compound clip, and the seconds since the clip started for a still or solid clip. It lets an agent take times straight from frames it extracted from a recording. Trimming or speeding up an earlier clip does not move anything connected to a later one.

A storyline clip starts at `start` on the sequence clock and lasts `duration`:

```
timed media clip:       duration = (out - in) / speed
still or solid clip:    duration = duration key

source time t to sequence time:
  timed media clip:       start + (clamp(t, in, out) - in) / speed
  still or solid clip:    start + clamp(t, 0, duration)
```

- The first storyline clip starts at 0. Each next clip starts at the previous clip's end minus their overlap. The sequence ends where the last storyline clip ends.
- The first storyline clip takes no default transition. A transition written on it brings it in over the background, with the first half of its overlap taken from its own start. To end on black, end the storyline with a solid clip and a transition.
- A transition belongs to the clip it brings in. The two clips overlap by `min(transition seconds, previous duration / 2, next duration / 2)`.
- `at` is `[start, end]` or a single start. A window's start and end are both instants. A single start is an instant followed by a duration, the clip's natural length `(out - in) / speed` for video, audio, image sequence and compound media. Under a storyline clip whose speed is not 1 the two forms differ: `[2, 6]` ends at source second 6, and `2` ends when the media does. Titles, shapes, adjustments and still images need `[start, end]`. A connected clip without `at` spans its storyline clip, and a sequence clip without `at` spans the whole sequence.
- A media clip plays from `in` at its own `speed` (default 1), whatever the speed of its storyline clip. When its window is longer than the media, video holds its last frame and audio goes silent, unless `loop` is true, in which case it repeats from `in` to `out` to fill the window.
- A connected clip is visible where its window meets `[start + incoming overlap / 2, end - outgoing overlap / 2]` of its storyline clip. It disappears at the middle of a transition and never stays over the next clip. A redaction is the exception (section 8.10).
- A connected clip whose window does not meet that range stops ("never visible").
- Sequence clips are cut at the end of the sequence. One that starts at or after the end stops.

### 8.4 Format (must)

- `size` defaults to the size of the first video clip on the storyline, or the first storyline clip when there is no video. Width and height round to even numbers.
- `fps` defaults to the frame rate of the first video clip on the storyline, and to 30 when there is none.
- `background` defaults to the theme `background`. Transparent parts of storyline pictures show it.
- `inset` is `[top, right, bottom, left]` and shrinks the content rect, where storyline clips are drawn. An inset that leaves no content rect stops.
- `conform` is `fit` (show the whole crop, fill the rest with the background) or `fill` (fill the content rect and cut what overflows), as an NLE's spatial conform. The default is `fit`.
- Outside the content rect is always the background. A cropped, filled or moving storyline clip never shows outside it.

### 8.5 Storyline clips (must)

- A video or compound clip needs `in < out` and `speed > 0`. An `out` past the end of the media is cut to the end.
- A still or solid clip needs `duration > 0`. `solid` is a colour, and fills the content rect.
- An empty storyline stops.
- `crop` is the region of the source shown in the content rect. It is an area, or `{scale: s}` for a centred region `1/s` the size of the picture (`s = 1` is the whole picture). It is keyframable, which gives a pan and zoom (Ken Burns).
- Resolve conforms every crop to the aspect ratio of the content rect around its centre. `fit` grows it until the written region fits inside, and what lies beyond the picture shows the background. `fill` shrinks it until it lies inside the written region. The conformed crop is exactly what fills the content rect, and keyframes between conformed crops keep their ratio.
- Each frame of a storyline clip is made in this order: take the conformed crop of the source frame, scale it to the content rect, apply the filter at that size in output pixels, then apply the transition motion.
- `filter` and `transition` take preset choices. `"none"` turns off a default filter for one clip, and `"cut"` turns off a default transition.
- Every storyline kind takes crop, filter and transition the same way.

### 8.6 Lanes and stacking (must)

The storyline is lane 0. Connected and sequence clips are on lane 1 unless `lane` says otherwise, and `lane` is 1 or more. From the bottom:

```
background < storyline < transition cover colour < background outside the content rect < lane 1 < lane 2 < ...
```

- During a transition the incoming clip is above the outgoing one. A preset with `"over": "outgoing"` puts the outgoing clip above.
- Within a lane, clips stack in document order: storyline clips in order, each with its connected clips in order, then the sequence clips in order.
- Audio-only clips have no lane.

### 8.7 Parenting (must)

A connected clip can be parented to its storyline clip's picture. Shapes and adjustments placed by `area` always are. A title or media clip is when it has `parent: true`, and then its `position` is in the source pixels of that picture. A parented clip stays in the source coordinates of its picture and follows the crop and the transition motion, so a box, or a title beside a button, stays on what it points at while the picture zooms. It takes its parent's clip as well, so it stays inside the content rect and is wiped away with its picture. A sequence clip has no parent, and its `area` takes only `[x, y, w, h]` in output pixels.

### 8.8 Titles (must)

- `title` is the text. `style` names a theme style (section 13.2), and the default is `subtitle`.
- `width` is the wrapping width in output pixels. The default is the output width minus twice the placement padding.
- Layout follows section 4.6.

### 8.9 Shapes (must)

| shape | What it draws |
| --- | --- |
| `box` | a rounded border around the area |
| `highlight` | a marker colour over the area |
| `dim` | darkens everything but the area |
| `arrow` | an arrow pointing at the area from the side named by `side` (`left`, `right`, `top`, `bottom`) |

- `label` adds a one-line label in the `label` style. It goes to the right of the shape, else below it, else to its left: the first side where it fits inside the content rect (the output frame for a sequence clip), measured at the shape's keyframed geometry without animation. A label never goes above a shape, where it would cover the line above. When no side fits, it stops.
- The side is measured at the clip's first visible instant at which its storyline clip is out of every transition, and kept for the clip's life. Resolve evaluates that instant and writes the side into the resolved document, so `timeline` stops on a label with no room. Motion the document asks for later (area keyframes, a zoom) may carry the label partly out of the content rect, and then it is clipped like the shape.
- `color` replaces the shape's theme colour.
- A label moves with its shape, and animates with the `label` entry of `defaults.animation.title`.

### 8.10 Redaction (must)

`shape: "redact"` hides what is in its area. Hiding is a guarantee, not a look, so it is built in rather than a preset, and nothing can weaken it.

- It covers the area with square blocks, each filled with the mean colour of the pixels it covers, or with `color` when one is given.
- A block's edge is the larger of the theme `shapes.redact.size` and the height of the tallest recognised line inside the area, so no glyph stays readable.
- It takes no `opacity`, `animation`, `label` or placement, and no default animation applies. It is fully drawn from the first frame of its window to the last.
- On a sequence it is parented like a shape, and it stays for as long as its storyline clip's picture is drawn inside its window, transitions included, since the content shows until its picture is gone.
- When its area is given by text, resolve looks for that text at the start and end of the window and at every keyframe, and stops if it finds the text outside the redacted area.
- In an image document it is a drawing operation like a shape.

### 8.11 Media clips (must)

- `width` and `height` size the clip in output pixels. Given one, the other keeps the aspect ratio.
- `radius` rounds the corners, `border` (`true` for the `border` colour, or a colour) draws a border with `shapes.border.width`, and `shadow: true` draws the theme shadow.
- `crop` and `filter` work as on a storyline clip, with the clip's own box in place of the content rect.
- A video media clip is picture in picture, and an image sequence with alpha is how a motion graphic made elsewhere comes in.

### 8.12 Adjustment clips (must)

An adjustment clip applies a filter preset (`adjust`) to everything below it, inside `area` or over the whole output when there is none, as an NLE's adjustment layer. Placed by an area on a connected clip, it is parented like a shape. Its filter lengths are output pixels and do not grow with a zoom. Its `opacity` blends the filtered result with what is below.

### 8.13 Audio (must)

- A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept.
- `fadeIn` and `fadeOut` are seconds, and ramp the volume from and to 0 at the ends of the clip's window.
- `volume` is keyframable, for ducking and longer fades.
- During a storyline transition the outgoing clip's sound fades out and the incoming clip's sound fades in, linearly over the overlap.
- Gains multiply: volume, fades and the transition crossfade all apply.
- A compound clip's sounds join the outer mix, with their times mapped through the compound clip and their gains multiplied by its own.
- Sounds that overlap are mixed. Everything is cut at the end of the sequence.
- A sequence with no sound has no audio track.

---

## 9. Presets (must)

A preset is one JSON file at `presets/<transition|animation|filter>/<name>.json`. frames ships its presets in the package's `presets` folder, and an absolute path in place of a name reads that file instead. Adding a preset needs no rebuild.

Every preset has a `description`: one line on how it looks and when to use it, which `presets` prints. Unknown keys and broken rules in a preset stop when it is read.

### 9.1 Motion properties

| Property | Default | Meaning |
| --- | --- | --- |
| `opacity` | 1 | opacity |
| `scale` | 1 | scale around the centre |
| `x`, `y` | 0 | offset in multiples of the thing's own size, or of the content rect in a transition. Down is positive |
| `rotate` | 0 | degrees, clockwise positive |
| `reveal` | 1 | 0 shows nothing, 1 shows everything. How it reveals depends on what receives it (below) |
| `nudge` | 0 | moves an arrow towards what it points at by multiples of its length. Only arrows read it |

| Receiver of `reveal` | How it reveals |
| --- | --- |
| box | the border is drawn around |
| highlight | painted from the `revealFrom` side |
| dim | closes in from the whole content rect to the area |
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
| `loop` | every `period` seconds while the clip stays | `period` | `ease-in-out` |
| `exit` | for the last `seconds` of the visible window | `seconds` | `ease-in` |

- Every span is optional. Without one the clip simply shows.
- On a short clip the entrance runs first and the exit takes what time is left.
- `{entrance, exit}` as a choice takes the entrance from one preset and the exit from another.
- An animation is applied over the clip's keyframes: its scale and opacity multiply, and its x, y and rotate add.

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
| `seconds` | default overlap. `{preset, seconds}` in a document overrides it |
| `ease` | default curve of incoming, outgoing and cover |
| `over` | which clip is on top during the overlap: `incoming` (default) or `outgoing` |
| `incoming` | motion of the incoming clip |
| `outgoing` | motion of the outgoing clip |
| `cover` | one colour over both clips. Only opacity is read |

- A storyline picture reads opacity, scale, x, y, rotate and reveal. Scale, x, y and rotate act around the centre of the content rect, and reveal shows the content rect from the `revealFrom` side.
- `seconds` or `period` inside a span stops. A transition's time is its overlap.
- To change scenes while the cover hides them, cut the incoming opacity from 0 to 1 at that point.

### 9.4 filter

A filter preset is a chain of operations from this table, applied in order. The operations are frames vocabulary, so every engine maps them to its own.

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
| `blur` | `radius` (theme length) | Gaussian blur |
| `sharpen` | `amount`, `radius` | unsharp mask |
| `bloom` | `amount`, `radius` | bright areas glow |
| `vignette` | `amount`, `radius` (fraction of half the diagonal) | darkens towards the edges |
| `pixelate` | `size` (theme length) | square blocks, each filled with the mean colour of the pixels it covers |

- An unknown op stops when the preset is read.
- Parameters are numbers, lists of numbers, or colours.
- The result has the size of the input. Operations that pull in pixels from beyond the edge (blur) are cut back to the original size.
- Engines keep the meaning of each operation. Identical pixels across engines are not part of the contract.

### 9.5 Presets to ship

The names and how each looks are the contract. The numbers are the implementation's. Seconds are the default overlap.

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
| `pixelate` | square blocks, as a look. Hiding personal data is `redact` |

---

## 10. Resolved document (must)

The resolved document is what `resolve` writes and what evaluation reads. `render` takes it as well as a document. It is JSON of the same kind as its document, with `"resolved": 1`, the version of this schema.

What resolve has already done:

- **Keys are checked.** A resolved document carries only the keys below.
- **No anchors.** Every area is `[x, y, w, h]`. A storyline crop and a parented area or position stay in the source pixels of their picture. Every other area on a sequence is in output pixels.
- **Fonts are pinned.** Every font is written as its file, face and the SHA-256 of the file. Evaluation and engines refuse a font file whose hash differs.
- **Decisions are written down.** Label sides and conformed crops are values, not rules to apply again.
- **No names.** Theme colours, styles and presets are written out as values. Theme lengths are already multiplied by their scale. Colours are `#RRGGBBAA`.
- **Text is shaped.** Every title and label carries its glyph runs (font file, face, hash, size, colour, glyph ids and positions in its own box), its box size, stroke and background.
- **One clock.** Every instant on a sequence is sequence time, and keyframes keep their eases. Media keeps `in`, `out` and `speed` in its own seconds.
- **One order.** Lanes are flattened into a single list, bottom first.

### 10.1 Resolved sequence

```json
{
  "kind": "sequence", "resolved": 1,
  "format": { "size": [1080, 1920], "fps": 30, "duration": 13.95, "background": "#000000FF",
              "content": [40, 420, 1000, 1380], "conform": "fit" },
  "storyline": [
    { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "start": 0, "end": 3,
      "crop": [ { "at": 0, "value": [0, 0, 1206, 2622] }, { "at": 3, "value": [45, 97, 1116, 2428], "ease": "linear" } ],
      "filter": [ { "op": "saturation", "amount": 1.25 } ],
      "transition": null }
  ],
  "clips": [
    { "title": { "size": [929.1, 68.2], "background": { "color": "#000000B8", "radius": 14.2 }, "stroke": null,
                 "runs": [
                   { "font": "/System/Library/Fonts/AppleSDGothicNeo.ttc", "face": "AppleSDGothicNeo-Bold", "size": 51.4, "color": "#FFD43BFF",
                     "glyphs": [ [1043, 21.4, 52.0], [2210, 70.9, 52.0] ] },
                   { "font": "/System/Library/Fonts/AppleSDGothicNeo.ttc", "face": "AppleSDGothicNeo-Bold", "size": 51.4, "color": "#FFFFFFFF",
                     "glyphs": [ [3, 288.1, 52.0] ] } ] },
      "start": 0, "end": 3, "position": [75.4, 1709.8],
      "animation": { "entrance": { "seconds": 0.35, "ease": "back-out", "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1, "opacity": 1 } ] } },
      "parent": null, "clip": false }
  ],
  "audio": [
    { "media": "/abs/bgm.m4a", "in": 0, "out": 92.1, "speed": 1, "start": 0, "end": 13.95, "loop": true,
      "volume": [ { "at": 0, "value": 0.3 }, { "at": 12.95, "value": 0.3 }, { "at": 13.95, "value": 0 } ] }
  ]
}
```

- `format.content` is the content rect. `format.duration` is the sequence end.
- A storyline entry has `start`, `end`, its keyframable properties as sequence-time keyframe lists, its filter as an op list, and `transition` as `null` or `{start, end, over, incoming, outgoing, cover}` with spans inline.
- A glyph is `[glyph id, x, y]`, its origin in the title's box. The example's glyph lists are cut short.
- A clips entry is a title, a shape, an adjustment or a media clip with its visible window `start` and `end` already cut by section 8.3, its properties as keyframe lists in sequence time, its animation spans inline, `parent` (the index of the storyline entry it follows, or `null`) and `clip` (whether it is clipped to the content rect).
- An audio entry is a source of sound, storyline clips included, with its volume keyframes in sequence time, its fades and the overlaps of its transitions. Evaluation multiplies them into the mix plan.
- A compound clip carries its nested resolved sequence in place of a media path.

### 10.2 Resolved image and layout

An image document and a layout resolve to their final size and one list of drawing steps: the source picture with its crop and scale, pads as fills, shapes, adjustments over what is below them inside their areas, shaped text and borders, in operation order and in output pixels. Evaluating them at any time gives the same display list.

### 10.3 Rules

- Resolve is deterministic for the same document, media, theme, presets, fonts and recognised text.
- Evaluating and drawing a resolved document needs its media and font files and nothing else.
- Evaluation refuses a `resolved` version it does not know.
- A resolved document is what resolve writes. Evaluation and `render` trust it as they trust resolve, and check its version and font hashes, not its rules again.

## 11. Evaluation, display lists and the mix plan (must)

`evaluate(resolved, t)` gives the display list at sequence time t: the frame size, its background, and drawing items bottom first, every value already sampled at t. Frame k of a sequence is `evaluate(resolved, k / fps)`, and an image or layout has one display list.

Every item has `transform` (an affine matrix `[a, b, c, d, tx, ty]` in output pixels), `opacity`, `clip` (a rectangle in output pixels, or `null`) and `reveal` (a rectangle in the item's own coordinates before its transform, or `null`). `reveal` turns with the item, so a wipe on a rotated title follows the title.

| Item | Fields | Draws |
| --- | --- | --- |
| `picture` | `source` (a media file or image sequence at a source time, or a nested display list), `rect` (the source region), `dest` (the output rectangle it fills), `filter` (op list, applied at `dest` size), `radius`, `border` `{width, color}`, `shadow` `{radius, offset, color}` | a region of a source picture scaled into a rectangle |
| `fill` | `rect`, `radius`, `color`, `hole` (`{rect, radius}` or `null`) | a filled rounded rectangle, with an optional rounded hole |
| `stroke` | `rect`, `radius`, `width`, `color`, `trim` (0 to 1, from the top left clockwise) | the outline of a rounded rectangle, drawn as far as `trim` |
| `arrow` | `tail`, `head` (points), `width`, `headSize`, `color` | a straight arrow |
| `glyphs` | `runs` (font file, face, size, colour, glyph ids and positions), `stroke` `{width, color}`, `box` `{rect, radius, color}` | glyphs, with their outline and background box |
| `adjust` | `rect` (or `null` for the whole frame), `filter` | the filter applied to everything drawn below it, inside the rect |

- A media source shows the frame that section 4.3 picks at its source time.
- A nested display list stands for an image document, or a compound clip at its mapped time. It is drawn at its own size, and the picture's `rect`, `dest`, `filter`, `radius`, `border` and `shadow` apply to it as to any source.
- Evaluation has done everything above pixels: keyframes and eases, animation spans and how they combine, transition motion and cover, reveal (as a smaller clip, a `trim`, a shorter arrow or a moving hole), parent transforms and clips, label sides, and the visible windows.

The mix plan is the sound of a whole sequence: a list of segments, each with a source file, its source start and speed, the sequence times it starts and ends, and a gain envelope of points `[t, gain]` joined in straight lines. The envelope already holds volume keyframes and their eases (sampled at the frame rate), fades and crossfades. A loop is one segment per repeat, and a compound clip's sounds are segments of their own.

## 12. Engine contract (must)

- An engine draws display lists, decodes the media they name, applies filter operations, mixes the mix plan, and encodes the output.
- An engine supports every display list item, every filter op and every media format named in it, or refuses before it draws, naming the first one it lacks and its place. It never drops one silently.
- A sequence output lasts `duration` to within one frame. A clip that ends near the end of its media never stalls the export.
- Glyphs are drawn from the font files and faces named, at the positions written. An engine shapes no text.
- Output is PNG for images, layouts and stills, and MP4 with H.264 at the engine's highest quality, with AAC at 256 kbps or more, for sequences.
- Colour is sRGB, as section 4.1 defines for sources.
- An engine leaves no temporary files.
- The same display lists on the same engine give the same output on any machine. Two engines give the same geometry, text and timing, not the same pixels.

`--engine` picks the engine. The default is `swift`.

## 13. Theme (must)

`theme` prints the built-in theme, and that output is also the list of every key a theme can hold. `colors` and `styles` are open maps: any name may be added. A theme file and a document's `theme` hold only the keys they change, and an unknown key stops.

Merging goes key by key through the theme's own structure: the top-level groups, each colour, each style and its properties, each shape and its properties, and each entry of `defaults`. Below that every value replaces the one under it whole: a `background`, a `stroke`, a transition choice like `{preset, seconds}`, a list.

Precedence, from weakest:

```
built-in theme < --theme file < document theme < keys on the clip or op
```

### 13.1 Built-in theme

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
    "highlight": { "color": "#FFD43B80" },
    "dim":       { "color": "#0000008C" },
    "redact":    { "size": 24 },
    "arrow":     { "width": 10, "length": 160, "color": "accent" },
    "border":    { "width": 3 },
    "shadow":    { "radius": 24, "offset": [0, 8], "color": "shadow" }
  },
  "anchor":    { "padding": 14, "cropPadding": 40 },
  "placement": { "padding": 40 },
  "image":     { "bannerPadding": 40 },
  "layout":    { "gap": 40, "padding": 40 },
  "defaults":  { "transition": "cut", "filter": "none",
                 "animation": { "title": { "label": "pop" }, "shape": "none", "media": "none", "adjust": "none" } }
}
```

### 13.2 Styles

A style is a named set of text properties. Any name is allowed, and frames reads four names itself: `label` (shape labels), `banner` and `bannerHead` (banners), and `heading` (layout headings).

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

### 13.3 Defaults

`defaults` holds the presets a form uses when a clip names none. They are part of a form's look, which is why they live in the theme: shorts pop their subtitles, evidence does not. `animation` holds `title` (keyed by style name, which covers labels through the `label` style), `shape`, `media` and `adjust`. Anything not listed is `none`, the transition default is `cut`, and the filter default is `none`.

### 13.4 Example: shorts theme

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

## 14. Command line (must)

```
frames [--theme <theme.json>] [--engine <name>] <command> ...

render    <document.json> -o <out.png | out.mp4>
still     <document.json> --at <t>[,<t>...] -o <out.png>
resolve   <document.json> -o <resolved.json>
timeline  <document.json>
probe     <media>
ocr       <image | video --at <t>>
extract   <video> <outdir> [--from <t>] [--to <t>] [--step 1]
sheet     <video> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]
transcode <in> -o <out> [--quality high|medium|low] [--max <px>] [--codec h264|hevc]
presets   [<kind>] [<name>]
theme
```

- `render` takes a document or a resolved document. A resolved document with `--theme` stops, since its theme is already written in.
- `still` draws sequence frames at the given sequence times without encoding a video. Several times go side by side, each labelled with its time. It is the cheap check while a sequence is being written.
- `timeline` resolves without rendering and prints, for every storyline clip, its sequence range, source range, speed, and incoming transition with its overlap, and for every other clip, its visible range, kind, animation and place (`storyline[1].connected[0]`). Everything resolve stops on (an unknown preset, a clip that is never visible, a label with no room) stops here too. It writes no file.
- `probe` prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in source pixels.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each labelled with its source time.
- `presets` lists presets with their descriptions, or prints one preset's JSON.
- Paths are absolute.
- On success, stdout gets one line with the output path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints usage and exits with 64.
- Messages name the place, for example `storyline[2].connected[0]: unknown key "anim". Allowed: at, lane, placement, position, scale, rotation, opacity, animation, keyframes, shape, area, label, side, color`.

### 14.1 transcode

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
- Video target: a 1080×1920, 35-second short (11.7 MB) comes to about 3.4 MB at PSNR around 44 dB at `medium`, about 5.5 MB (50 dB) at `high`, and about 2.2 MB (38 dB) at `low`. Text on screen stays sharp at every level.

---

## 15. What a correct result keeps (must)

These are the acceptance tests.

- The first frame is not black or empty. A clip visible from 0 shows on the first frame.
- Nothing of a cropped, filled or moving storyline clip shows outside the content rect.
- During a transition both clips show, stacked as section 8.6 says.
- A connected clip disappears at the middle of a transition and does not stay over the next clip.
- A connected shape follows the crop and stays on the text it points at.
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A label never covers the line above its box.
- A redaction hides its area on every frame its picture is drawn, from its window's first frame to its last.
- Rendering is lossless or at the highest quality. Only `transcode` makes things smaller.
- Text in storyline images stays crisp.
- Evaluating a resolved document at the same time always gives the same display list, and drawing it twice on the same engine gives the same output.
- An engine that lacks a feature refuses before drawing.
- No temporary files are left.

## 16. Guides

Guides sit outside the engine. Each form has a guide (`guide/<form>.md`), a theme (`theme/<form>.json`, only the keys it changes) and an example (`example/<form>.json`, runs once its paths are changed).

A guide holds:

- what the form is for: who watches it, and where
- its theme
- its format: size, inset, conform, and how the top band or banner is built from titles
- its rules for text, emphasis, cuts and length, each with a one-line reason
- which presets to use and which not to, with the reason
- an example

Guides only combine. A missing look becomes a preset. A missing capability goes into this specification and the model first, and into the engines only when it needs a new kind of pixel work. A form-only feature is never hidden in either.

How to make anything:

1. Pick the guide.
2. Look at the material. `probe` it, lay video out with `sheet` every 1 to 2 seconds, then again every 0.5 seconds over the chosen range. Check the text to point at with `ocr`.
3. Write the document. Point at places by their text, and write connected instants in source seconds. Check times with `timeline` and pictures with `still`.
4. Render.
5. Lay the result out with `sheet` and check it against section 15.
6. `transcode` for where it goes.

First guides:

- **pr-evidence:** the built-in theme. The conclusion and the reason go in the banner. Only the reason lines get a box, and personal data gets `redact`. No filters and no music. Transitions are `fade` at 0.3 to 0.5.
- **shorts:** Korean vertical short-form, 9:16. A headline in the top band, outlined subtitles with `pop`, `push-up` between scenes.
- **demo:** a feature demo on the built-in theme.
- **motion-graphics:** making graphics outside frames. Write HTML, render it to a PNG sequence with alpha in a headless browser, and bring it in as `{"sequence": ...}` media.

## 17. Out of scope

- Stabilisation, audio filters beyond volume, per-character typing.
- GIF and WebM output. Rendering makes MP4 and PNG.
- Speech synthesis, recording and transcription. Sound arrives as files.
- Generating graphics. They arrive as media.

Adding any of these later does not break the contract. Whoever adds one updates the key tables, the README and this document together.

---

## 18. Recommended structure

### 18.1 Stages

```
1. check      walk the JSON tree against the key tables
2. read       theme, presets, media facts (probe), then check the media rows
3. resolve    anchors (OCR provider), text layout (text provider), scale, styles,
              the time plan (durations, overlaps, starts, visible windows), one clip order.
              timeline stops here, resolve writes it out
4. evaluate   the display list at a time
5. engine     decode, filter, draw, mix, encode
```

### 18.2 Drawing a frame

```
evaluate(resolved, t):
  items = [fill background]
  for each storyline entry visible at t, bottom first:
      source time = inverse of the clip's time map at t
      rect = conformed crop at t; dest = the content rect
      transform, opacity, clip = transition motion and reveal at t
      items += picture(source, source time, rect, dest, filter)
  items += transition cover fill
  items += fill of everything outside the content rect, with the content rect as a hole
  for each clip visible at t, in order:
      values = keyframes at t, combined with the animation at t, then the parent's transform
      items += its picture, text, fill, stroke or arrow
  return items
```

- An engine can draw a title once to a bitmap and reuse it while only its transform changes.
- Decoded source frames are cached.

### 18.3 Modules

| Module | Owns |
| --- | --- |
| model | document types and the key tables |
| theme | the built-in theme, merging, scale |
| preset | reading presets, spans, easing |
| anchor | areas and the OCR provider |
| text | text layout and the font provider |
| resolve | the time plan, timeline, the resolved document |
| evaluate | display lists at a time, the mix plan |
| engine | one module per engine, drawing display lists |
| analysis | probe, ocr, extract, sheet |
| transcode | image, audio and video delivery files |
| cli | commands, arguments, error output |

### 18.4 Package

```
frames/
  manifest.toml
  README.md                commands and the document reference
  document/
    SPEC.md                this document
    GUIDE.md               how to make anything, how to write a guide
    PRESET.md              how to write a preset
    guide/<form>.md
    theme/<form>.json
    example/<form>.json
  presets/
    transition/*.json
    animation/*.json
    filter/*.json
  source/                  the sources and the built tool
```

### 18.5 Order of work

1. The contract as data: key tables, the built-in theme, presets, spans and easing. Pure data with easy unit tests.
2. Resolve and `timeline`: anchors, text layout and the time plan without rendering, tested against section 8.3.
3. Evaluate: display lists at a time and the mix plan, tested as data without drawing.
4. The Swift engine: pictures, fills, strokes, arrows, glyphs and adjustments, then filters, mixing and encoding. Checked against section 15 with `still` and `sheet`.
5. `transcode`, `probe`, `extract`, `sheet`, `ocr`.
6. The 42 presets, the built-in theme, the guides.

---

## 19. Practical notes

These are not contract, but help whoever writes documents.

- OCR confuses similar characters (`0` and `O`). Read the `ocr` output before pointing, and point with a part of the text that is less confusable, plus `nth`.
- On a 1206-wide vertical video a subtitle line holds about 21 Korean characters. Longer subtitles wrap, and more than two lines are hard to read.
- Starting a connected shape while the screen is still moving puts it where the text was at that frame. Start after the screen settles, or follow it with area keyframes.
- PNG is lossless and does not shrink when written again. Use JPEG or HEIC for smaller files.
- HEVC looks slightly better than H.264 at the same level, at about the same size, and some browsers cannot play it. H.264 is the default.
