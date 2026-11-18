# frames

frames edits images and video from a JSON document. You (or an agent) write what the result holds: a screenshot with boxes and a banner, a vertical short with subtitles, a demo with titles and transitions. frames finds the text you point at, lays out titles with real fonts, plans the time, and draws a PNG, a master `.mov` or a delivery file.

It is built like a non-linear editor: a sequence, a primary storyline of clips, connected clips, lanes, transitions, keyframes, filters and templates. The same model edits a still and a video. frames composites media and does not generate it: graphics made elsewhere come in as PNGs, PNG sequences or video with alpha.

The specification in [`spec/`](spec/README.md) is the authority on every rule. This page shows how to use frames and points there for the details.

- [Build](#build)
- [A first edit](#a-first-edit)
- [Commands](#commands)
- [Documents](#documents)
- [Document reference](#document-reference)
- [More](#more)

## Build

frames is a Swift package for macOS. It renders with Apple's frameworks (AVFoundation, Core Graphics, Core Image, Vision, Core Text).

```sh
sh source/install.sh
frames --version
```

It builds a release, then installs `frames` and `Frames_FramesCommand.bundle`, which holds the `frames` pack of presets, side by side in `/usr/local/bin`. `--prefix <dir>` (or `FRAMES_PREFIX`) installs them elsewhere, and `open-package install` runs the same script.

The tool is `frames`. Packs (looks, forms and templates others made) are installed by copying a directory into `$FRAMES_HOME/packs/`, and `FRAMES_HOME` defaults to `~/.config/frames`:

```sh
mkdir -p ~/.config/frames/packs
cp -R packs/shorts ~/.config/frames/packs/
frames packs
```

## A first edit

A screenshot of a checkout page, with the total boxed, everything else dimmed, and a banner that says what changed. Every place is named by the text on screen, so the document survives a new screenshot.

```json
{ "kind": "image",
  "source": "/path/to/shot.png",
  "ops": [
    { "shape": "dim", "area": { "from": "Item total", "to": "Total" } },
    { "shape": "box", "area": "Total", "label": "includes shipping" },
    { "banner": [ { "text": "Total now includes shipping", "style": "bannerHead" }, "Checkout summary, PR #123" ], "edge": "top" }
  ] }
```

```sh
frames ocr /path/to/shot.png                 # what text is there to point at
frames render /path/to/total.json -o /path/to/out/total.png
```

`"Total"` names the whole recognised line that contains it, `Total 42,000`, and the box goes around that line. Text is compared as written apart from whitespace, so `Item total` is not a match. On a screen where two lines contain the text, frames stops rather than guess:

```
frames: ops[0].area (box): "Total" matches 2 lines: [25.77, 34, 302.49, 26] "Total includes shipping", [47.70, 467, 248.45, 41] "(Total 42,000 fixed". Give nth to pick one
```

Then write `{ "text": "Total", "nth": 1 }` for the second, or a longer part of the line, such as `"Total 42"`.

## Commands

```
frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>]
       [--encoder <name>] [--ocr <name>] [--shaper <name>] [--tracker <name>] <command> ...
```

Global options go before the command. `--theme` merges a theme under every document's own theme. The role and provider options pick an implementation by name: the renderer is `quartz`, the OCR provider `vision`, the shaper `coretext`, the tracker `point`, and the decoder, mixer and encoder `avfoundation`.

Paths are absolute. Where a command takes a document, it also takes a resolved document, a pack template (`<pack>/<name>`), or `-` for standard input. On success a command that writes a file prints one line with its path and size. On failure it prints `frames: <reason>` to standard error and exits with 1. Messages name the place in the document: `storyline[1].connected[0] (box): ...`.

In the examples below, `total.json` is the [first edit](#a-first-edit) above and `short.json` is the [sequence example](#sequence) under Documents.

### Making results

| Command | What it does |
| --- | --- |
| `render <document> -o <out.mov \| out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>]` | Draws the result. A `.mov` is the master of every frame (ProRes and PCM at full quality), and a `.png` the frame at `--at` (0 when left out). `--deliver` writes an H.264 `.mp4` from the same frames as the master |
| `still <document> --at <t>[,<t>...] -o <out.png> [--args <args.json>]` | Draws sequence frames at those times, side by side and labelled, without encoding a video. The cheap check while you write |
| `resolve <document> -o <resolved.json> [--args <args.json>]` | Writes the resolved document: everything found, laid out and planned, with files pinned by hash |
| `transcode <in> -o <out> [--quality high\|medium\|low] [--max <px>] [--codec h264\|hevc]` | Makes a smaller delivery file from an image, audio or video |

```sh
frames render /path/to/total.json -o /path/to/out/total.png
frames render /path/to/short.json -o /path/to/out/short.mov --deliver /path/to/out/short.mp4
frames still /path/to/short.json --at 0.5,1.3,3 -o /path/to/out/check.png
frames resolve /path/to/short.json -o /path/to/out/short.resolved.json
frames render /path/to/out/short.resolved.json -o /path/to/out/short.mov
frames transcode /path/to/out/total.png -o /path/to/out/total.jpg --quality high --max 1600
frames transcode /path/to/out/short.mov -o /path/to/out/short.mp4 --quality medium
```

A template renders on its own with its arguments: `frames render mine/intro --args /path/to/args.json -o /path/to/out/intro.mov`. A resolved document already has its theme and arguments written in, so `--theme` or `--args` with one stops.

### Looking at material and results

| Command | What it reports |
| --- | --- |
| `probe <media> [--json]` | kind (`image`, `video`, `audio`, `imageSequence`), size, duration, frame rate, alpha, audio |
| `ocr <image \| video> [--at <t> \| --from <t> --to <t> --step <s>] [--json]` | the recognised lines, `[x, y, w, h]  text` in media pixels, in the order `nth` counts them |
| `track <video> --at <t> --area <area> [--to <t>]` | the rectangle of an area on every frame the tracker follows, as JSON |
| `extract <video \| document> <outdir> [--from <t>] [--to <t>] [--step 1]` | frames as full-size PNGs, `0000.png`, `0001.png`, ... |
| `sheet <video \| document> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]` | frames laid out in one picture, each labelled with its time |
| `timeline <document> [--args <args.json>] [--json]` | every clip's ranges, speed, transition, animation and place, after resolve, without rendering |
| `evaluate <document> --at <t> [--args <args.json>]` | the display list at a time: what is drawn, by which clip, where, as JSON |
| `locate <document> --at <t> --point <x,y> [--args <args.json>]` | which clips are under a point of the output, and for media the frame and pixel it shows |

```sh
frames probe /path/to/recording.mp4
frames ocr /path/to/recording.mp4 --from 0 --to 3 --step 0.5 --json
frames track /path/to/recording.mp4 --at 1 --area '{"text": "Total"}' --to 2.5
frames extract /path/to/recording.mp4 /path/to/out/frames --from 1 --to 3 --step 0.5
frames sheet /path/to/recording.mp4 -o /path/to/out/sheet.png --step 1 --cols 6
frames timeline /path/to/short.json
frames evaluate /path/to/short.json --at 1
frames locate /path/to/short.json --at 1 --point 540,960
```

`--area` takes an area as JSON text: `'[10, 20, 300, 40]'` or `'{"text": "Total", "nth": 1}'`. `extract` and `sheet` take a document too, and then draw it as `still` does, so what you check is what `render` makes.

With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name set to the version of frames: `{"probe": "1.0.0", "kind": "video", ...}`. That output is a contract that extensions build on ([FRAMES-23](spec/FRAMES-23/SPEC.md)). The text output is for people.

### Presets, packs and the theme

| Command | What it prints |
| --- | --- |
| `presets [<kind>] [<name>]` | the presets of every pack by kind, with their descriptions, or one preset's JSON |
| `packs [<pack>]` | the packs, the one that ships with frames and the installed ones, or what one pack holds, each thing by the name a document gives it |
| `theme` | the base theme, which is also the list of every key a theme can hold |
| `--version` | the version of frames |

```sh
frames presets animation
frames presets transition push-up
frames packs
frames packs shorts
frames theme
```

### Extensions

A command frames does not have runs a program from `PATH`: `frames autocut ...` runs `frames-autocut ...`, with the global options before the name and everything after it passed through unchanged, standard input and output included. An extension reads documents and machine output and writes a document to standard output, so extensions chain:

```sh
frames autocut /path/to/raw.json | frames privacy - | frames render - -o /path/to/out/clean.mov
```

[document/GUIDE.md](document/GUIDE.md) shows how to write one.

## Documents

Every document is a JSON object with a `kind`: `image`, `layout` or `sequence`. Any of them may carry a `theme` (an object, `<pack>/<name>` or an absolute path) and `params`, which make it a template.

### image

An image document edits one picture with operations in order. Every area and point is written in the pixels of `source`, and frames maps them through the crops, resizes and pads before them, so you point at what `ocr` reported without doing any arithmetic.

```json
{ "kind": "image",
  "source": "/path/to/shot.png",
  "ops": [
    { "crop": { "band": { "from": "Order summary", "to": "Total" } } },
    { "shape": "box", "area": "Item total", "label": "before discount" },
    { "shape": "arrow", "area": "Total", "side": "right", "label": "charged" },
    { "resize": { "width": 800 } },
    { "pad": 20 },
    { "banner": [ { "text": "The total is charged as shown", "style": "bannerHead" }, "Item total is before the discount" ], "edge": "top" },
    { "border": true }
  ] }
```

### layout

A layout puts pictures on a grid, with a heading over each and an optional banner. An item is a path or an image document.

```json
{ "kind": "layout",
  "banner": [ { "text": "The total is fixed", "style": "bannerHead" }, "Before and after the change" ],
  "columns": 2,
  "items": [
    { "heading": "Before", "image": "/path/to/shot.png" },
    { "heading": "After",  "image": { "kind": "image", "source": "/path/to/pr.png",
                                      "ops": [ { "shape": "box", "area": { "text": "Total", "nth": 1 } } ] } }
  ] }
```

### sequence

A sequence plays clips over time. The storyline plays one clip after another, connected clips ride on a storyline clip and use its clock, and `clips` sit on the sequence clock.

```json
{ "kind": "sequence",
  "format": { "size": [1080, 1920], "fps": 30, "inset": [420, 0, 120, 0] },
  "storyline": [
    { "media": "/path/to/recording.mp4", "in": 0.2, "out": 1.5,
      "connected": [
        { "at": [0.4, 1.5], "title": "The total **includes shipping**", "style": "subtitle" },
        { "at": [0.6, 1.5], "shape": "box", "area": "Total", "label": "fixed" } ] },
    { "media": "/path/to/shot.png", "duration": 2.5, "transition": "frames/fade",
      "keyframes": [ { "at": 0, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 2.5, "crop": { "scale": 1.2 } } ] }
  ],
  "clips": [
    { "title": "Checkout, fixed", "style": "headline", "lane": 2 }
  ] }
```

- The recording plays from media second 0.2 to 1.5. The subtitle and box use the recording's own seconds, so `"at": [0.6, 1.5]` starts at the frame a `sheet` of the recording labels 0.6.
- The box finds `Total` in the frame at 0.6 seconds and stays on it as part of the picture, fitted into the content rect with it. It ends where the screen changes, since a box found on one screen does not follow the text to the next.
- The screenshot comes in with a `frames/fade` and zooms slowly with crop keyframes on its own clock (seconds since it started).
- The headline is a sequence clip without `at`, so it spans the whole sequence, in the band the inset leaves at the top.

### Templates

A template is a document with published parameters, used as media or rendered with `--args`:

```json
{ "kind": "sequence",
  "format": { "size": [1080, 1920] },
  "params": {
    "title": { "type": "text", "default": "New feature", "description": "headline at the top" },
    "color": { "type": "color", "default": "#111827", "description": "background" }
  },
  "storyline": [ { "solid": { "param": "color" }, "duration": 2,
                   "connected": [ { "title": { "param": "title" }, "style": "headline" } ] } ] }
```

```json
{ "media": { "template": "mine/intro", "args": { "title": "Checkout, fixed" } } }
```

[document/PACK.md](document/PACK.md) covers templates and packs.

## Document reference

The tables below are short forms. Each links to the spec that holds the full rules. Every object has a fixed set of keys, and an unknown key stops with its place, so a typo never renders as nothing.

### Values

| Value | Written as | Spec |
| --- | --- | --- |
| time | seconds as a number | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| colour | `#RRGGBB`, `#RRGGBBAA` or a theme colour name (`accent`) | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| position on a sequence | output pixels `[x, y]`, origin top left | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| area | media pixels of its picture | [FRAMES-2](spec/FRAMES-2/SPEC.md) |
| theme length (text size, stroke, padding, blur radius) | points at the theme `baseWidth`, scaled to the output | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| placement | `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right` | [FRAMES-1](spec/FRAMES-1/SPEC.md) |

### Areas

| Form | Means |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `"Total"` | the whole recognised line that contains the text (whitespace ignored). More than one match stops and lists them |
| `{"text": "Total", "nth": 1}` | the nth match from 0, top to bottom, then left to right |
| `{"from": "Item total", "to": "Total", "fromNth": 0, "toNth": 0}` | around both lines and every line between them |
| `{"band": <area>}` | the full width of the picture, as tall as the inner area |

A text area grows by the theme `area.padding` (`area.cropPadding` for a crop). On video it is found in the frame at the moment it takes effect: a connected clip's start, a keyframe's time. [FRAMES-2](spec/FRAMES-2/SPEC.md)

### Media

| Form | Means |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` document |
| `"<pack>/<file.ext>"` | a file in a pack's `media/` |
| `{"imageSequence": "/abs/dir", "fps": 30}` | every PNG in the folder, in natural order, played like a video |
| an image or layout document | the picture it draws |
| a sequence document | a compound clip |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance |

[FRAMES-3](spec/FRAMES-3/SPEC.md)

### image document

| op | Keys | Does |
| --- | --- | --- |
| `crop` | an area | keeps the area |
| `resize` | `{scale}`, `{width}` or `{height}` | resizes, keeping the aspect ratio |
| `pad` | `n`, `[vertical, horizontal]` or `[top, right, bottom, left]`, `color` | adds a margin |
| `shape` | `box`, `fill`, `dim` or `arrow`, `area`, `side` (arrow), `label`, `color` | draws a shape |
| `adjust` | a filter choice, `area` | filters everything drawn before it |
| `title` | text, `position`, `style`, `anchor`, `width` | places a title |
| `banner` | lines, `edge` (`top` or `bottom`) | extends the picture with a band of text |
| `border` | `true` or a colour | draws a border around the picture |

Document keys: `kind, source, time, theme, params, ops`. Every op also takes `id` and `metadata`. A banner line is a string (the `banner` style) or `{text, style}`. [FRAMES-6](spec/FRAMES-6/SPEC.md)

### layout document

Keys: `kind, theme, params, banner, columns, border, items`, and an item takes `heading, image`. Without `columns` every item is on one row. `border` defaults to `true`. [FRAMES-6](spec/FRAMES-6/SPEC.md)

### sequence document

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips` |
| format | `size, fps, background, inset, conform` |
| storyline clip, video or compound | `id, metadata, media, in, out, speed, track, crop, filter, transition, volume, fadeIn, fadeOut, keyframes, connected` |
| storyline clip, still | `id, metadata, media, duration, crop, filter, transition, keyframes, connected` |
| storyline clip, solid | `id, metadata, solid, duration, transition, connected` |
| every other clip | `id, metadata, at, lane, opacity, animation, keyframes`, and its kind's keys |
| media clip | `media, in, out, speed, loop, volume, fadeIn, fadeOut, track, anchor, placement, position, parent, scale, rotation, crop, conform, filter, blend, width, height, radius, border, shadow` (a still takes no time or sound keys) |
| audio clip | `id, metadata, at, media, in, out, speed, loop, volume, fadeIn, fadeOut, keyframes` |
| title clip | `title, style, width, track, anchor, placement, position, parent, scale, rotation, blend` |
| shape clip | `shape, area, track, label, labelAnimation, color, blend`, and `side` for an arrow |
| adjustment clip | `adjust, area, track` |
| keyframe | `at, ease`, and the clip's keyframable properties |

The full table is [FRAMES-7](spec/FRAMES-7/SPEC.md). What each key does: format and lanes [FRAMES-9](spec/FRAMES-9/SPEC.md), parenting [FRAMES-10](spec/FRAMES-10/SPEC.md), clip kinds [FRAMES-11](spec/FRAMES-11/SPEC.md), tracking [FRAMES-12](spec/FRAMES-12/SPEC.md), sound [FRAMES-13](spec/FRAMES-13/SPEC.md).

| Clip | Keyframable |
| --- | --- |
| storyline clip | `crop`, `volume`, and `timeRemap` on video, image sequence or compound media |
| media clip | `position, scale, rotation, opacity, crop, volume`, and `timeRemap` on timed media |
| title clip | `position, scale, rotation, opacity` |
| shape or adjustment clip | `area, opacity` |

| Choice | Takes |
| --- | --- |
| transition | a preset name, `<pack>/<name>`, an absolute path, `"cut"`, or `{preset, seconds}` |
| animation | a preset name, `<pack>/<name>`, an absolute path, `"none"`, or `{entrance, exit}` |
| filter | a preset name, `<pack>/<name>`, an absolute path, a list of those, or `"none"` |

### Time

| Instant | Clock |
| --- | --- |
| a storyline clip's `keyframes` | its clip time: media seconds for video, seconds since it started for a still or solid |
| a connected clip's `at` and `keyframes` | its storyline clip's clip time |
| a sequence clip's `at` and `keyframes` | sequence time |
| `in` and `out` | the media's own seconds |

Durations (`duration`, transition and animation seconds, fades) are sequence seconds. `at` is `[start, end]` or a start alone (then the media's natural length). A transition is centred on the edit point and does not change the sequence's length. `timeRemap` keyframes give the media seconds a clip shows at each instant, for holds, reverse and ramps; it is written only in keyframes, takes no `speed`, and the clip plays no sound. Check every time with `timeline`. [FRAMES-8](spec/FRAMES-8/SPEC.md)

| ease | Shape |
| --- | --- |
| `linear`, `ease-in`, `ease-out`, `ease-in-out` | the usual curves |
| `back-out`, `bounce-out` | overshoots, bounces |
| `step` | holds, then jumps at the end |
| `[x1, y1, x2, y2]` | cubic Bezier |

[FRAMES-4](spec/FRAMES-4/SPEC.md)

### Shapes, titles and blend modes

| shape | Draws |
| --- | --- |
| `box` | a rounded border around the area |
| `fill` | the area filled with a colour |
| `dim` | darkens everything but the area |
| `arrow` | points at the area from `side` (`left`, `right`, `top`, `bottom`) |

A `label` goes on the first side in the theme `shapes.label.sides` where it fits, and stops when none does. A title needs a `style`. `blend` takes the W3C modes: `normal, multiply, screen, overlay, darken, lighten, color-dodge, color-burn, hard-light, soft-light, difference, exclusion, plus-lighter`. [FRAMES-11](spec/FRAMES-11/SPEC.md)

### Theme

`frames theme` prints the base theme, and that is the list of every key. A theme file or a document `theme` holds only the keys it changes.

| Group | Holds |
| --- | --- |
| `baseWidth`, `font` | the width theme lengths are written for, and the font families in order |
| `colors` | named colours (`accent`, `background`, `text`, ...), an open map |
| `styles` | text styles by name: `size, weight, color, emphasis, lineHeight, stroke, background, placement, offset, align, lines`, an open map |
| `shapes` | `box, fill, dim, arrow, border, shadow, label` |
| `area`, `placement`, `image`, `layout` | paddings and gaps |
| `defaults` | the transition, filter and animations a clip takes when it names none |

Precedence, weakest first: base theme, `--theme`, the document's `theme`, keys on the clip. [FRAMES-22](spec/FRAMES-22/SPEC.md)

### Presets

frames ships 42 presets as the pack `frames`: 14 transitions, 14 animations and 14 filters. A document names them like any pack's presets, `frames/fade`. `frames presets` lists them and says how each looks. [FRAMES-16](spec/FRAMES-16/SPEC.md), and the format [FRAMES-14](spec/FRAMES-14/SPEC.md) and [FRAMES-15](spec/FRAMES-15/SPEC.md). How to write one: [PRESET.md](document/PRESET.md).

### Packs and templates

What a pack holds and how its things are named: [PACK.md](document/PACK.md).

A parameter is `{type, default, description}`, with `options` for a `choice`. Types: `video, sequence, image, audio, text, color, number, choice`. `{"param": "<name>"}` stands for a value of that type. [FRAMES-17](spec/FRAMES-17/SPEC.md)

### Machine output

| Command | Object |
| --- | --- |
| `probe` | `{"probe", kind, size, duration, fps, alpha, audio}` |
| `ocr` | `{"ocr", size, frames: [{time, lines: [{text, rect}]}]}` |
| `track` | `{"track", frames: [{time, rect}]}` |
| `timeline` | `{"timeline", duration, storyline, clips}` |
| `evaluate` | `{"evaluate", time, size, items: [{place, id, kind, bounds, opacity}]}` |
| `locate` | `{"locate", hits: [{place, id, kind}, ...]}` |

The first key holds the version. Times are rounded to the microsecond and positions to the millionth. [FRAMES-23](spec/FRAMES-23/SPEC.md)

## More

- [document/GUIDE.md](document/GUIDE.md): how to make anything, write a guide, a how-to or an extension, and edit a document without changing what it shows.
- [document/PRESET.md](document/PRESET.md): how to write a transition, an animation and a filter.
- [document/PACK.md](document/PACK.md): how to make a pack, a form and a template.
- [document/howto/](document/howto/): techniques that belong to no form, such as [motion graphics](document/howto/motion-graphics.md) and [effects](document/howto/effects.md).
- [packs/](packs/): the first forms, `pr-evidence`, `shorts` and `demo`, each with its guide and examples, and `film`, five film looks made of LUTs with grain, halation and vignettes.
- [document/ARCHITECTURE.md](document/ARCHITECTURE.md): how the code is laid out.
