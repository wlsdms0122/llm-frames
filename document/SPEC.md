# frames specification

frames is an image and video editing tool that an agent drives. The agent writes a document in JSON, frames resolves it, and an engine renders it to a PNG or an MP4.

This document is the contract. It says what frames takes, what it gives back, and how it behaves, and leaves out how any implementation is built.

- **Must:** behaviour an implementation keeps. Document shapes, time and coordinate rules, the resolved document, the engine contract and error behaviour are here.
- **Recommended:** structure that makes the contract easier to keep. An implementation may ignore it.

---

## 1. What frames is

frames is built like a non-linear editor (NLE) such as Final Cut Pro or Premiere Pro, with a sequence, a primary storyline of clips, clips connected to them, lanes, transitions, keyframes, filters and masks. The same model makes three kinds of output: evidence for a pull request (a screenshot with boxes, redactions and a caption), vertical short-form video, and feature demo video.

- A document and its media are enough to make the result again.
- Places in a picture are named by the text on screen, found by text recognition (OCR), instead of measured by hand.
- frames composites media and does not generate it. Motion graphics, illustrations and diagrams are made with other tools (HTML in a headless browser, an image model, a design tool) and arrive as media: a PNG, a PNG sequence, or a video with alpha. Titles and shapes are built in, as in any NLE, because they point at places in the picture that frames finds itself.

## 2. Principles

| Principle | Meaning |
| --- | --- |
| The editing model is the product | Documents, time, anchors, presets and themes are defined once, here. An engine only draws what the model resolved |
| Engines are replaceable | Rendering takes a resolved document (section 10) and nothing else. A Swift engine comes first, and an engine built on ffmpeg or anything else takes the same input |
| Standard vocabulary | Names come from NLEs and compositing tools: storyline, connected clip, in and out points, lane, keyframe, transition, crop, title, parenting |
| Composite, do not generate | Anything beyond titles and shapes arrives as media |
| Look is theme, combination is guide, effect is data | Sizes, colours, text styles and default presets live in a theme. Which pieces a form combines lives in a guide. Transitions, animations and filters are preset files, and adding one needs no rebuild |
| Unknown keys stop | Every object has a fixed set of keys. A typo stops with the place it was found instead of rendering as "no effect" |
| Ambiguity stops | A text anchor that matches more than one line stops and lists the matches |
| No legacy keys | When a key changes, old documents stop. There is no compatibility branch |
| Render at full quality, deliver separately | Rendering never trades quality for size. `transcode` does that |
| Reproducible from the resolved document | What can differ between machines (text recognition, themes, presets) is fixed into the resolved document. Rendering it again on the same engine gives the same result |
| Sound is media | frames places sound files on the timeline. Speech synthesis, recording and transcription happen outside |

## 3. Shape of the system

```
theme.json ──────┐
presets/ ────────┤
                 ▼
document.json ─▶ resolve ─▶ resolved document ─▶ engine ─▶ PNG / MP4 ─▶ transcode ─▶ delivery file
                   ▲                               swift, ...
       probe, ocr, extract, sheet (analysis)
```

- **Document:** what the agent writes. There are three kinds: `image` (section 6), `layout` (section 7) and `sequence` (section 8).
- **Resolve:** checks keys, merges the theme, reads presets, finds text anchors, and puts every time on the sequence clock. Its output is the resolved document. It creates no media.
- **Engine:** draws a resolved document. It owns text layout and pixels, and nothing above them (section 11).
- **Analysis:** tools that give the agent facts to write a document with. They take no part in rendering.
- **Transcode:** makes a delivery file from an image, audio or video file. It is not part of rendering.

## 4. Common values

### 4.1 Units (must)

| Value | Unit |
| --- | --- |
| Time | seconds, as a number. Which clock a time is on is section 8.3 |
| Area in source media | pixels of the source picture, origin at the top left |
| Position and size on a sequence | pixels of the output, origin at the top left |
| Theme lengths (text size, stroke, padding, line width) | points at the theme `baseWidth`, multiplied by the scale of the place they are drawn (below) |
| Animation offsets `x`, `y` | multiples of the animated thing's own size. In a transition, multiples of the content rect |
| Angles | degrees, clockwise positive |
| Colours | `#RRGGBB`, `#RRGGBBAA`, or the name of a theme colour |

Scale is `width / baseWidth`, where width is the output width for a sequence, the width of the picture at that operation for an image document, and the widest item for a layout.

### 4.2 Areas (must)

A place in a picture is given in one of four forms. Coordinates are source pixels.

| Form | Meaning |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `"text"` | the one recognised line that contains the text |
| `{"text": "...", "nth": 1}` | the nth line (from 0) among the lines that contain the text |
| `{"from": "...", "to": "...", "from_nth": 0, "to_nth": 0}` | the rectangle around both lines and every line between them |

- Text is compared with whitespace removed. A line matches when it contains the text.
- A text form without `nth` that matches more than one line stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that matches no line stops, naming the media, the text and the nth.
- An area found by text grows outward by the theme `anchor.padding`.
- On video, the text is searched in the frame at the source time where the area is used: a connected clip's start, or the keyframe's time.

### 4.3 Media references (must)

| Form | Meaning |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents |
| `{"sequence": "/abs/dir", "fps": 30}` | a numbered image sequence: every PNG in the directory, in name order, at that rate |
| an image document object | the picture that document renders (section 6) |

- Paths are absolute.
- Alpha is kept for PNG, PNG sequences and video codecs that carry it (ProRes 4444, HEVC with alpha). This is how graphics made elsewhere come in.

### 4.4 Keyframes and easing (must)

Any property marked keyframable takes a static value, a list of keyframes, or both. A keyframe is an object with `at`, one or more properties, and an optional `ease`.

```json
"opacity": 1,
"keyframes": [ { "at": 3, "position": [600, 500] }, { "at": 4, "position": [330, 900], "scale": 1.5, "ease": "ease-in-out" } ]
```

- Each property joins only the keyframes that name it. Before its first keyframe it holds the first value. After its last it holds the last value.
- A property that no keyframe names uses its static value, or its default.
- A keyframe's `ease` shapes the span coming into that keyframe. The default is `linear`.
- `at` of a keyframe is on the same clock as the `at` of the clip it belongs to (section 8.3).

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

- `placement` is a name: `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right`. The clip sits inside the content rect, inset by the theme `placement.padding`. A text style's `offset` replaces that inset on the edge the name points to (a subtitle sits `offset` above the bottom).
- `position` is `[x, y]`, the top left of the clip in output pixels. It is keyframable, and once set it replaces `placement`.

The default is the text style's placement for titles and `center` for media.

---

## 5. Documents

Every document is a JSON object with a `kind` of `image`, `layout` or `sequence`. A document may carry a `theme` object, which is merged over the theme in effect (section 12).

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
    { "filter": "pixelate", "area": "issuerDn:" },
    { "shape": "arrow", "area": "serialNumber", "from": "right", "label": "here" },
    { "text": "Note", "at": [40, 40], "style": "label" },
    { "resize": { "width": 800 } },
    { "pad": [20, 40], "color": "#FFFFFF" },
    { "caption": ["Bold first line", "Regular line"], "edge": "top" },
    { "border": true }
  ]
}
```

- `source` is any media reference that gives a picture. For a video, `at` picks the frame by source time.
- **Every area and point is written in source coordinates.** Operations run in order, and frames maps source coordinates through the crops, resizes, pads and captions before it.
- An area that falls wholly outside the picture at its operation stops. One that falls partly outside is clipped.
- Theme lengths scale by the width of the picture at that operation.
- Wherever a picture is taken (a layout item, a storyline clip, a connected clip), an image document can stand in for a path.

| op | Keys | What it does |
| --- | --- | --- |
| `crop` | area | Keeps the area. A text area crops a full-width band, with `anchor.cropPadding` above and below, clipped to the picture |
| `resize` | `{scale}`, `{width}` or `{height}` | Resizes and keeps the aspect ratio |
| `pad` | `n`, `[vertical, horizontal]` or `[top, right, bottom, left]`, `color` optional | Adds a margin. The default colour is the theme `background` |
| `shape` | `box`, `highlight`, `dim` or `arrow`, with `area`, `label`, `from`, `color` | Draws a shape (section 8.9) |
| `filter` | preset, `area` optional | Applies a filter preset, inside the area when one is given |
| `text` | text, `at` (source `[x, y]`), `style` | Places a title (section 8.8) |
| `caption` | lines, `edge` (`top` or `bottom`) | Extends the picture with a band of text. The first line takes the `captionHead` style and the rest take `caption` |
| `border` | `true` | Draws a thin border around the picture with the theme `image.borderWidth` and the `border` colour |

## 7. layout document

A layout places pictures on a grid.

```json
{
  "kind": "layout",
  "caption": ["Bold first line", "Regular line"],
  "columns": 2,
  "borders": true,
  "items": [
    { "title": "Before", "image": { "kind": "image", "source": "/abs/before.png", "ops": [ { "shape": "box", "area": "9190799" } ] } },
    { "title": "After", "image": "/abs/after.png" }
  ]
}
```

- Without `columns`, every item goes on one row.
- Every column is as wide as the widest item, and every row is as tall as the tallest item in it. An item is centred in its cell.
- `borders` draws a border around every cell with `layout.borderWidth` and the `border` colour. The default is `true`.
- `title` sits above its cell in the `cellTitle` style.
- `caption` is a band above the grid, styled as in the image `caption` operation.

## 8. sequence document

### 8.1 Shape

```json
{
  "kind": "sequence",
  "format": { "size": [1080, 1920], "fps": 30, "background": "#000000", "inset": [420, 40, 120, 40], "fit": "contain" },
  "theme": { "defaults": { "transition": "push-up", "filter": "vivid", "animation": { "subtitle": "pop", "shape": "draw" } } },
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
    { "at": [0, 30], "title": "Top title\n**emphasis**", "style": "title", "lane": 2 },
    { "at": [1, 6], "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
      "placement": "top-right", "animation": { "in": "pop", "out": "fade" }, "lane": 5,
      "keyframes": [ { "at": 3, "position": [600, 500] }, { "at": 4, "position": [330, 900], "scale": 1.5, "ease": "ease-in-out" } ] },
    { "media": "/abs/bgm.m4a", "volume": 0.3, "loop": true, "fade": [0, 1] },
    { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 }
  ]
}
```

- `storyline` is the primary storyline. Its clips play one after another, and transitions overlap them.
- `connected` clips belong to one storyline clip and live on its source clock. They move when that clip moves.
- `clips` are placed on the sequence clock.
- A clip is a media clip (`media`), a title (`title`), a shape (`shape`) or a solid (`solid`, storyline only). Exactly one of these keys is present.

### 8.2 Keys (must: any other key stops)

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, storyline, clips` |
| format | `size, fps, background, inset, fit` |
| storyline clip | `media` or `solid`, `in, out, speed, duration, crop, filter, transition, volume, fade, keyframes, connected` |
| connected clip and sequence clip, common | `at, lane, placement, position, scale, rotation, opacity, animation, keyframes` |
| media clip | common, `media, in, out, speed, loop, volume, fade, width, height, radius, border, shadow` |
| title clip | common, `title, style, width` |
| shape clip | common, `shape, area, label, from, color` |
| keyframe | `at, ease`, and the keyframable properties of its clip |
| transition choice | a preset name, an absolute path, `"cut"`, or `{preset, seconds}` |
| animation choice | a preset name, an absolute path, or `{in, out}` |
| filter choice | a preset name, an absolute path, a list of those, or `"none"` |
| image document | `kind, source, at, theme, ops`, and each op's keys from section 6 |
| layout document | `kind, theme, caption, columns, borders, items`. An item takes `title, image` |

Keyframable properties:

| Clip | Properties |
| --- | --- |
| storyline clip | `crop, volume` |
| media clip | `position, scale, rotation, opacity, volume` |
| title clip | `position, scale, rotation, opacity` |
| shape clip | `area, opacity` |

Keys are checked over the whole JSON tree before any value is read. A value of the wrong type also stops, with its place.

### 8.3 Time (must, the most important rule)

A sequence has two clocks. **Source time** is the time inside one storyline clip. **Sequence time** is the time of the output.

| Where it is written | Clock of `at` |
| --- | --- |
| a storyline clip's own `keyframes` | that clip's source time |
| a connected clip's `at` and `keyframes` | its storyline clip's source time |
| a sequence clip's `at` and `keyframes` | sequence time |
| `in` and `out` of any media clip | that media's own seconds |

Source time is the seconds of the source video for a video clip, and the seconds since the clip started for an image or solid clip. It lets an agent take times straight from frames it extracted from a recording. Trimming or speeding up an earlier clip does not move anything connected to a later one.

A storyline clip starts at `start` on the sequence clock and lasts `duration`:

```
video clip:        duration = (out - in) / speed
image, solid clip: duration = duration key

source time t to sequence time:
  video clip:        start + (clamp(t, in, out) - in) / speed
  image, solid clip: start + clamp(t, 0, duration)
```

- The first storyline clip starts at 0. Each next clip starts at the previous clip's end minus their overlap. The sequence ends where the last storyline clip ends.
- A transition belongs to the clip it brings in. The two clips overlap by `min(transition seconds, previous duration / 2, next duration / 2)`.
- A connected clip is visible where its `at` meets `[start + incoming overlap / 2, end - outgoing overlap / 2]` of its storyline clip. It disappears at the middle of a transition and never stays over the next clip.
- A connected clip whose window does not meet that range stops ("never visible"), since that is what writing a sequence time into a connected clip looks like.
- Sequence clips are cut at the end of the sequence.
- `at` is `[start, end]` or a single start. A single start lasts the clip's natural length: `(out - in) / speed` for video and audio. Titles, shapes and images need `[start, end]`. A sequence clip without `at` spans the whole sequence.
- A media clip plays from `in`. When its window is longer than the media, video holds its last frame and audio goes silent, unless `loop` is true, in which case it repeats from `in` to `out` to fill the window.

### 8.4 Format (must)

- `size` defaults to the size of the first video clip on the storyline, or the first storyline clip when there is no video. Width and height round to even numbers.
- `fps` defaults to 30.
- `background` defaults to the theme `background`. Transparent parts of storyline images show it.
- `inset` is `[top, right, bottom, left]` and shrinks the content rect, where storyline clips are drawn. An inset that leaves no content rect stops.
- `fit` is `contain` (show everything, fill the rest with the background) or `cover` (fill the rect and cut what overflows). The default is `contain`.
- Outside the content rect is always the background. A cropped, covered or moving storyline clip never shows outside it.

### 8.5 Storyline clips (must)

- A video clip needs `in < out` and `speed > 0`. An `out` past the end of the media is cut to the end.
- An image or solid clip needs `duration > 0`.
- An empty storyline stops.
- `crop` is the region of the source shown in the content rect, fitted by `fit`. It is an area, or `{scale: s}` for a centred region `1/s` the size of the picture (`s = 1` is the whole picture). It is keyframable, which gives a pan and zoom (Ken Burns).
- `filter` and `transition` take preset choices. `"none"` turns off a default filter for one clip, and `"cut"` turns off a default transition.
- Every storyline kind takes crop, filter and transition the same way, and keeps the same order during a transition.

### 8.6 Lanes and stacking (must)

The storyline is lane 0. Connected and sequence clips are on lane 1 unless `lane` says otherwise, and `lane` is 1 or more. From the bottom:

```
background < storyline < transition cover colour < background outside the content rect < lane 1 < lane 2 < ...
```

- During a transition the incoming clip is above the outgoing one. A preset with `"over": "out"` puts the outgoing clip above.
- Within a lane, clips stack in document order: storyline clips in order, each with its connected clips in order, then the sequence clips in order.
- Audio-only clips have no lane.

### 8.7 Parenting (must)

A connected clip placed by `area` is parented to its storyline clip's picture. It follows the crop, the fit and the transition motion, so a box stays on the text it points at while the picture zooms. It is clipped to the content rect. A sequence clip's `area` takes only `[x, y, w, h]` in output pixels.

### 8.8 Titles (must)

- `**text**` takes the style's `emphasis` colour, and `\n` breaks the line.
- `style` names a theme style (section 12.2). The default style is `subtitle`.
- `width` is the wrapping width in output pixels. The default is the content rect width minus twice the placement padding. A style with `lines: 1` never wraps.

### 8.9 Shapes (must)

| shape | What it draws |
| --- | --- |
| `box` | a rounded border around the area |
| `highlight` | a marker colour over the area |
| `dim` | darkens everything but the area |
| `arrow` | an arrow pointing at the area from the side named by `from` (`left`, `right`, `top`, `bottom`) |

- `label` adds a one-line label in the `label` style. It goes to the right of the shape, and to below or above when there is no room on the right. It never sits on the top edge of a box, where it would cover the line above.
- `color` replaces the shape's theme colour.
- A label moves with the shape, and animates with `defaults.animation.label`.

### 8.10 Media clips (must)

- `width` and `height` size the clip in output pixels. Given one, the other keeps the aspect ratio.
- `radius` rounds the corners, `border` draws a border in that colour, and `shadow: true` draws the theme shadow.
- A video media clip is picture in picture, and an image sequence with alpha is how a motion graphic made elsewhere comes in.

### 8.11 Audio (must)

- A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept.
- `fade` is `[in, out]` in seconds and ramps the volume from and to 0 at the ends of the clip's window.
- `volume` is keyframable, for ducking and longer fades.
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
| highlight | painted from one side |
| dim | closes in from the whole content rect to the area |
| arrow | flies in from behind |
| title, media, storyline picture | wiped from the `reveal_from` side |

A span is:

```json
{ "seconds": 0.35, "ease": "back-out", "reveal_from": "left",
  "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 0.3, "opacity": 1 }, { "t": 1, "scale": 1 } ] }
```

- `t` is progress through the span, from 0 to 1.
- Each property joins only the keys that name it, in straight lines. Opacity can finish at 30% while scale runs to the end.
- A property the span does not name takes its default.
- `ease` bends the progress first, and the bent value drives every property.
- `reveal_from` is `left`, `right`, `top` or `bottom`. The default is `left`.

### 9.2 animation

```json
{ "description": "...",
  "in":   { "seconds": 0.35, "ease": "back-out", "keys": [ ... ] },
  "loop": { "period": 0.9, "keys": [ ... ] },
  "out":  { "seconds": 0.15, "keys": [ ... ] } }
```

| Span | When it runs | Required | Default ease |
| --- | --- | --- | --- |
| `in` | for `seconds` from the clip's start | `seconds` | `ease-out` |
| `loop` | every `period` seconds while the clip stays | `period` | `ease-in-out` |
| `out` | for the last `seconds` of the clip | `seconds` | `ease-in` |

- Every span is optional. Without one the clip simply shows.
- On a short clip `in` runs first and `out` takes what time is left.
- `{in, out}` as a choice takes the in span from one preset and the out span from another.
- An animation is applied over the clip's keyframes: its scale and opacity multiply, and its x, y and rotate add.

### 9.3 transition

```json
{ "description": "...",
  "seconds": 0.45, "ease": "ease-in-out", "over": "in",
  "in":    { "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
  "out":   { "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": -1 } ] },
  "cover": { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
```

| Key | Meaning |
| --- | --- |
| `seconds` | default overlap. `{preset, seconds}` in a document overrides it |
| `ease` | default curve of in, out and cover |
| `over` | which clip is on top during the overlap: `in` (the incoming clip, default) or `out` |
| `in` | motion of the incoming clip |
| `out` | motion of the outgoing clip |
| `cover` | one colour over both clips. Only opacity is read |

- A storyline picture reads opacity, scale, x, y, rotate and reveal. Scale, x, y and rotate act around the centre of the content rect, and reveal shows the content rect from the `reveal_from` side.
- `seconds` or `period` inside a span stops. A transition's time is its overlap.
- To change scenes while the cover hides them, cut the incoming opacity from 0 to 1 at that point.
- Transitions are evaluated on every frame. Joining only the first and last frame in a straight line is wrong.

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
| `levels` | `in: [black, white]`, `out: [black, white]` (0 to 1) | maps input levels to output levels |
| `blur` | `radius` (theme length) | Gaussian blur |
| `sharpen` | `amount`, `radius` | unsharp mask |
| `bloom` | `amount`, `radius` | bright areas glow |
| `vignette` | `amount`, `radius` (fraction of half the diagonal) | darkens towards the edges |
| `pixelate` | `size` (theme length) | square blocks |

- An unknown op stops when the preset is read.
- Parameters are numbers, lists of numbers, or colours.
- The result has the size of the input. Operations that pull in pixels from beyond the edge (blur) are cut back to the original size.
- Storyline video and storyline image clips take filters the same way.
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
| `uncover-left` | the previous clip leaves to the left and uncovers the next (`over: out`) | 0.45 |
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
| `pixelate` | square blocks, for hiding personal data |

---

## 10. Resolved document (must)

The resolved document is the engine's only input. `resolve` writes it, and `render` takes it as well as a document. It is JSON of the same kind as its document, with `"resolved": 1`, the version of this schema.

What resolve has already done:

- **Keys are checked.** A resolved document carries only the keys below.
- **No anchors.** Every area is `[x, y, w, h]` in source pixels for image documents and storyline crops, and in output pixels everywhere else.
- **No names.** Theme colours, styles and presets are written out as values. Theme lengths are already multiplied by their scale.
- **One clock.** Every time on a sequence is sequence time. Media keeps `in`, `out` and `speed` in its own seconds.
- **One order.** Lanes are flattened into a single draw list, bottom first.

What the engine still does: text layout (fonts, line breaking, measuring, label placement), sampling keyframes, animations and transitions at each frame, decoding, compositing, filtering and encoding.

### 10.1 Resolved sequence

```json
{
  "kind": "sequence", "resolved": 1,
  "format": { "size": [1080, 1920], "fps": 30, "duration": 13.95, "background": "#000000FF",
              "content": [40, 420, 1000, 1380], "fit": "contain" },
  "storyline": [
    { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "start": 0, "end": 3,
      "crop": [ { "at": 0, "rect": [0, 0, 1206, 2622] }, { "at": 3, "rect": [45, 97, 1116, 2428] } ],
      "filter": [ { "op": "saturation", "amount": 1.25 } ],
      "transition": null }
  ],
  "draw": [
    { "title": "Emphasis subtitle", "spans": [ { "text": "Emphasis", "color": "#FFD43BFF" }, { "text": " subtitle" } ],
      "start": 0, "end": 3, "style": { "font": ["Apple SD Gothic Neo"], "size": 51.4, "weight": "bold", "color": "#FFFFFFFF",
                 "lineHeight": 64.2, "stroke": null, "align": "center", "lines": null,
                 "background": { "color": "#000000B8", "padding": [10.6, 21.4], "radius": 14.2 } },
      "placement": { "edge": "bottom", "offset": 142.3, "width": 929.1 },
      "animation": { "in": { "seconds": 0.35, "ease": "back-out", "keys": [] } },
      "parent": null, "clip": false }
  ],
  "audio": [
    { "media": "/abs/bgm.m4a", "in": 0, "out": 92.1, "speed": 1, "start": 0, "end": 13.95, "loop": true,
      "volume": [ { "at": 0, "value": 0.3 }, { "at": 12.95, "value": 0.3 }, { "at": 13.95, "value": 0 } ] }
  ]
}
```

- `format.content` is the content rect. `format.duration` is the sequence end.
- A storyline entry has `start`, `end`, its keyframes as sequence-time lists of values, its filter as an op list, and `transition` as `null` or `{start, end, over, in, out, cover}` with spans inline.
- A draw entry is a title, a shape or a media clip with its visible window `start` and `end` already cut by section 8.3, its keyframes in sequence time, its animation spans inline, `parent` (the index of the storyline entry it follows, or `null`) and `clip` (whether it is clipped to the content rect).
- An audio entry is every source of sound, storyline clips included, with its volume as a sequence-time list.

### 10.2 Resolved image and layout

- An image document keeps its op list, with every area as a source rectangle and every style and colour written out.
- A layout keeps its items as resolved image documents, with the grid, caption and borders written out.

### 10.3 Rules

- Resolve is deterministic for the same document, media, theme, presets and recognised text.
- Rendering a resolved document needs its media files and nothing else.
- An engine refuses a `resolved` version it does not know.

## 11. Engine contract (must)

- An engine takes a resolved document and an output path.
- Frame k of a sequence shows sequence time `k / fps`, and the output lasts `duration` to within one frame. A clip that ends near the end of its media never stalls the export.
- Keyframes, animations and transitions are evaluated at every frame.
- An engine supports every feature of the resolved schema or refuses before it draws, naming the first feature it lacks and its place. It never drops a feature silently.
- An engine owns fonts and line breaking, inside the rules of sections 8.8 and 8.9.
- Output is PNG for images, layouts and stills, and MP4 with H.264 at the engine's highest quality, with AAC at 256 kbps or more, for sequences.
- Colour is sRGB.
- An engine leaves no temporary files.
- The same resolved document on the same engine gives the same result. Two engines give the same look, not the same pixels.

`--engine` picks the engine. The default is `swift`.

## 12. Theme (must)

`theme` prints the built-in theme, and that output is also the list of every key a theme can hold. A theme file and a document's `theme` hold only the keys they change, and an unknown key stops.

Precedence, from weakest:

```
built-in theme < --theme file < document theme < keys on the clip or op
```

### 12.1 Built-in theme

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
    "subtitle":    { "size": 58, "weight": "bold", "color": "#FFFFFF", "emphasis": "emphasis",
                     "background": { "color": "#000000B8", "padding": [12, 24], "radius": 16 },
                     "placement": "bottom", "offset": 160, "align": "center" },
    "title":       { "size": 72, "weight": "bold", "color": "#FFFFFF", "emphasis": "emphasis",
                     "stroke": { "width": 6, "color": "#000000" },
                     "placement": "top", "offset": 220, "align": "center" },
    "label":       { "size": 36, "weight": "bold", "color": "onAccent",
                     "background": { "color": "accent", "padding": [8, 16], "radius": 12 }, "lines": 1 },
    "caption":     { "size": 38, "weight": "regular", "color": "text", "lineHeight": 64 },
    "captionHead": { "size": 44, "weight": "bold", "color": "text", "lineHeight": 64 },
    "cellTitle":   { "size": 44, "weight": "bold", "color": "accent", "lineHeight": 80 }
  },
  "shapes": {
    "box":       { "width": 8, "radius": 18, "color": "accent" },
    "highlight": { "color": "#FFD43B80" },
    "dim":       { "color": "#0000008C" },
    "arrow":     { "width": 10, "length": 160, "color": "accent" },
    "shadow":    { "radius": 24, "offset": [0, 8], "color": "shadow" }
  },
  "anchor":    { "padding": 14, "cropPadding": 40 },
  "placement": { "padding": 40 },
  "image":     { "borderWidth": 3, "captionPadding": 40 },
  "layout":    { "gap": 40, "padding": 40, "borderWidth": 3 },
  "defaults":  { "transition": "cut", "filter": "none",
                 "animation": { "label": "pop" } }
}
```

### 12.2 Styles

A style is a named set of text properties. Any name is allowed, and the engine reads four names itself: `label` (shape labels), `caption` and `captionHead` (caption bands), and `cellTitle` (layout titles).

| Property | Meaning |
| --- | --- |
| `size` | font size |
| `weight` | `regular` or `bold` |
| `color`, `emphasis` | text colour, and the colour of `**text**` |
| `lineHeight` | distance between baselines. The default is 1.25 × size |
| `stroke` | `{width, color}`: an outline with round joins, where strokes never show overlapping. Width 0 or absent means none |
| `background` | `{color, padding, radius}`: a box behind the text, or `false` |
| `placement`, `offset` | default placement (section 4.5) |
| `align` | `left`, `center` or `right` |
| `lines` | `1` keeps the text on one line |

### 12.3 Defaults

`defaults` holds the presets used when a clip names none. `animation` is keyed by style name for titles, and by `shape` and `media` for those clips. Anything not listed is `none`, the transition default is `cut`, and the filter default is `none`.

### 12.4 Example: shorts theme

```json
{ "baseWidth": 1080,
  "colors": { "accent": "#FF3B30", "emphasis": "#FFE14D" },
  "styles": {
    "subtitle": { "size": 66, "background": false, "stroke": { "width": 7, "color": "#000000" }, "offset": 330 },
    "title":    { "size": 84, "offset": 110 },
    "label":    { "size": 40 } },
  "shapes": { "box": { "width": 10 } },
  "defaults": { "transition": { "preset": "push-up", "seconds": 0.3 },
                "animation": { "subtitle": "pop", "title": "none", "label": "pop", "shape": "draw", "media": "pop" } } }
```

---

## 13. Command line (must)

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
- `timeline` resolves without rendering and prints, for every storyline clip, its sequence range, source range, speed, and incoming transition with its overlap, and for every other clip, its visible range, kind, animation and place (`storyline[1].connected[0]`). Errors a render would hit (an unknown preset, a clip that is never visible) stop here too. It writes no file.
- `probe` prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in source pixels.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each labelled with its source time.
- `presets` lists presets with their descriptions, or prints one preset's JSON.
- Paths are absolute.
- On success, stdout gets one line with the output path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints usage and exits with 64.
- Messages name the place, for example `storyline[2].connected[0]: unknown key "anim". Allowed: at, lane, placement, position, scale, rotation, opacity, animation, keyframes, shape, area, label, from, color`.

### 13.1 transcode

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

## 14. What a correct result keeps (must)

These are the acceptance tests.

- The first frame is not black or empty. A clip visible from 0 shows on the first frame.
- Nothing of a cropped, covered or moving storyline clip shows outside the content rect.
- During a transition both clips show, stacked as section 8.6 says.
- A connected clip disappears at the middle of a transition and does not stay over the next clip.
- A connected shape follows the crop and stays on the text it points at.
- The output length matches the `timeline` duration to within one frame.
- Outlined text has round corners and no overlapping strokes.
- A label never covers the line above its box.
- Rendering is lossless or at the highest quality. Only `transcode` makes things smaller.
- Text in storyline images stays crisp.
- Rendering a resolved document twice on the same engine gives the same output.
- An engine that lacks a feature refuses before drawing.
- No temporary files are left.

## 15. Guides

Guides sit outside the engine. Each form has a guide (`guide/<form>.md`), a theme (`theme/<form>.json`, only the keys it changes) and an example (`example/<form>.json`, runs once its paths are changed).

A guide holds:

- what the form is for: who watches it, and where
- its theme
- its format: size, inset, fit, and how the top band or caption is built from titles
- its rules for text, emphasis, cuts and length, each with a one-line reason
- which presets to use and which not to, with the reason
- an example

Guides only combine. A missing look becomes a preset. A missing capability goes into the engine and the README, never into a form-only feature hidden in the engine.

How to make anything:

1. Pick the guide.
2. Look at the material. `probe` it, lay video out with `sheet` every 1 to 2 seconds, then again every 0.5 seconds over the chosen range. Check the text to point at with `ocr`.
3. Write the document. Point at places by their text, and write connected times in source seconds. Check times with `timeline` and pictures with `still`.
4. Render.
5. Lay the result out with `sheet` and check it against section 14.
6. `transcode` for where it goes.

First guides:

- **pr-evidence:** the built-in theme. The conclusion and the reason go in the caption. Only the reason lines get a box. No filters and no music. Transitions are `fade` at 0.3 to 0.5.
- **shorts:** Korean vertical short-form, 9:16. A top title, outlined subtitles with `pop`, `push-up` between scenes.
- **demo:** a feature demo on the built-in theme.
- **motion-graphics:** making graphics outside frames. Write HTML, render it to a PNG sequence with alpha in a headless browser, and bring it in as `{"sequence": ...}` media.

## 16. Out of scope

- Stabilisation, audio filters beyond volume, per-character typing.
- GIF and WebM output. Rendering makes MP4 and PNG.
- Speech synthesis, recording and transcription. Sound arrives as files.
- Generating graphics. They arrive as media.

Adding any of these later does not break the contract. Whoever adds one updates the key tables, the README and this document together.

---

## 17. Recommended structure

### 17.1 Stages

```
1. check     walk the JSON tree against the key tables
2. read      theme, presets and media facts as values
3. resolve   anchors, scale, styles, the time plan (durations, overlaps, starts, visible windows),
             lanes into one draw list. timeline stops here, resolve writes it out
4. engine    decode, prepare (filtered copies, still clips as video), draw each frame, encode
```

Preparing in the engine uses values from resolve (the background colour, for one), so it runs after resolve has finished.

### 17.2 Drawing a frame

The simplest engine draws the frame at sequence time t and runs that at the frame rate.

```
frame(t):
  fill with the background
  for each storyline entry visible at t, bottom first:
      source time = inverse of the clip's time map at t
      transform  = fit and crop at t, then transition motion at t
      draw into the content rect, cut by opacity and reveal
  transition cover colour
  fill outside the content rect with the background
  for each draw entry visible at t, in order:
      keyframes at t combined with the animation at t, parent transform if any, then draw
```

- Titles and media can be drawn once to a bitmap and transformed each frame.
- Shapes whose area moves (keyframes, parenting) are measured again each frame.
- Decoded source frames are cached.

### 17.3 Modules

| Module | Owns |
| --- | --- |
| model | document types and the key tables |
| theme | the built-in theme, merging, scale |
| preset | reading presets, spans, easing |
| anchor | areas, the OCR provider |
| resolve | the time plan, timeline, the resolved document |
| engine | the resolved document as input, and one engine per backend |
| analysis | probe, ocr, extract, sheet |
| transcode | image, audio and video delivery files |
| cli | commands, arguments, error output |

The OCR provider belongs to resolve, not to the engine. A resolved document renders on a machine that cannot recognise text.

### 17.4 Package

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
  source/                  the engine sources and the built tool
```

### 17.5 Order of work

1. The contract as data: key tables, the built-in theme, presets, spans and easing. Pure data with easy unit tests.
2. Resolve and `timeline`: the time plan without rendering, tested against the formulas in section 8.3.
3. The Swift engine for images and layouts: anchors with OCR, 2D drawing, text layout.
4. The Swift engine for sequences: storyline, transitions, draw list, parenting. Checked against section 14 with `still` and `sheet`.
5. Audio, `transcode`, `probe`, `extract`, `sheet`, `ocr`.
6. The 42 presets, the built-in theme, the guides.

---

## 18. Practical notes

These are not engine contract, but help whoever writes documents.

- OCR confuses similar characters (`0` and `O`). Read the `ocr` output before pointing, and point with a part of the text that is less confusable, plus `nth`.
- On a 1206-wide vertical video a subtitle line holds about 21 Korean characters. The second caption line is cut past about 50 characters.
- Starting a connected shape while the screen is still moving puts it where the text was at that frame. Start after the screen settles, or follow it with area keyframes.
- PNG is lossless and does not shrink when written again. Use JPEG or HEIC for smaller files.
- HEVC looks slightly better than H.264 at the same level, at about the same size, and some browsers cannot play it. H.264 is the default.
