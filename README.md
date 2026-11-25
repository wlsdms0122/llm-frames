# frames

frames is a non-linear video editor driven by JSON documents and a command line, in the class of Final Cut Pro, Premiere Pro and After Effects compositions. A person, an agent or a program writes a sequence: a primary storyline of clips, clips connected to them, clips on the sequence's own clock, lanes, transitions, keyframes, filters, titles, shapes, masks, track mattes, parenting and time remapping. frames checks it, resolves it and renders a PNG, a master `.mov` or a delivery `.mp4`.

The same model edits a still and a video, since a still is a sequence rendered as one frame. Work goes as it does in any editor: write the document, look at it with `timeline`, `still` and `sheet`, change it, render, and use what was rendered as media in the next document.

At its centre frames is an engine: it turns an edit written out in values, with the media it names, into a result, and decides no value by reading content. What a purpose needs (a lower third for a lecture, an annotation look, a vertical short with subtitles) is made above the engine, in vocabulary and tools, and a pack is the one unit both are installed in. Vocabulary is the themes, presets, LUTs, fonts, media and templates with published parameters that a document names and resolve replaces by their values, and a tool is a program that reads media and what frames reports and writes values into a document before it is resolved. [FRAMES-25](spec/FRAMES-25/SPEC.md#layers) defines the layers. frames composites media and does not generate it. Titles and shapes are built in, and motion graphics, illustrations and diagrams are made in other software and come in as PNGs, PNG sequences, video with alpha, or pages of a PDF for vector artwork.

A few rules hold everywhere:

- Every object has a fixed set of keys. A misspelt key stops with its place, so a typo never renders as no effect.
- A reference that matches more than one thing stops and lists what it matched.
- A value that still does its job is clamped (a transition longer than its clips, an `out` past the end of the media), and one that cannot stops (a clip that is never visible, a one-line title wider than its room).
- The resolved document is a lockfile: tracks, text layout, themes, presets and templates are written into it as values, and the files it still needs are pinned by hash, so it makes the same result again.
- `render` writes a master at full quality. Delivery files are made from the same frames (`--deliver`) or from the master (`transcode`), and a render made only to look at or hand over writes the delivery file alone (`-o` an `.mp4`).

The specification in [`spec/`](spec/README.md) is the contract for every rule, and this page is the way in for someone who uses frames. Each section below links to the spec that holds the full rules.

- [Build](#build)
- [A first edit](#a-first-edit)
- [Commands](#commands)
- [Document reference](#document-reference)
- [More](#more)

## Build

frames is a Swift package for macOS 14 or later. It renders with Apple's frameworks: AVFoundation, Core Graphics and Core Image, Vision and Core Text.

```sh
swift build -c release --package-path source/frames
source/frames/.build/release/frames --version
```

The executable is `source/frames/.build/release/frames`, with `Frames_FramesCommand.bundle` beside it. The bundle holds `frames`, the pack of presets and tools that ships with frames, and the executable reads it from its own directory, so the two are copied together wherever the executable is put. `open-package build` runs the same build.

`FRAMES_HOME` is where frames looks for installed packs, in `$FRAMES_HOME/packs/`. It defaults to `~/.config/frames`, and setting it keeps a machine's packs wherever that machine keeps its work.

A pack is installed by copying its directory into `$FRAMES_HOME/packs/`, its tools with it, and installing a pack runs nothing:

```sh
mkdir -p ~/.config/frames/packs
cp -R packs/shorts ~/.config/frames/packs/
frames packs
```

## A first edit

An interview shot with a lower third and a logo, a still of a menu board that zooms slowly, and a B-roll shot that pushes in, over music:

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080], "fps": 25, "conform": "fill" },
  "theme": {
    "styles": {
      "name": { "size": 64, "weight": "bold", "placement": "bottom-left", "offset": 140 },
      "role": { "size": 40, "color": "#F2B33D" }
    }
  },
  "storyline": [
    { "id": "interview", "kind": "media", "media": "/path/to/interview.mov", "in": 2, "out": 8,
      "connected": [
        { "at": [3, 7.5], "kind": "title", "text": [ { "text": "Mina Park\n" }, { "text": "Head baker", "style": "role" } ],
          "style": "name", "animation": "frames/fade" },
        { "kind": "media", "media": "/path/to/logo.png", "width": 160, "placement": "top-right", "opacity": 0.9 } ] },
    { "kind": "media", "media": "/path/to/board.png", "duration": 4,
      "transition": { "preset": "frames/fade", "seconds": 0.8 },
      "keyframes": [ { "at": 0, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 4, "crop": { "scale": 1.3 } } ] },
    { "kind": "media", "media": "/path/to/broll.mov", "in": 0, "out": 4, "transition": "frames/push-left" }
  ],
  "clips": [
    { "kind": "media", "media": "/path/to/music.m4a", "volume": 0.4, "fadeOut": 1.5 }
  ]
}
```

- The storyline plays the interview from its second 2 to 8, the board for 4 seconds, then the B-roll from 0 to 4. Each transition is centred on its edit point and does not change the length of the sequence.
- The title and the logo are connected to the interview. Their `at` is on the interview's clip time, which is its media time, so `[3, 7.5]` is the stretch a `sheet` of the recording labels 3s to 7.5s. The logo has no `at`, so it spans the interview's edit range.
- The title is a list of runs: the name in the clip's style `name`, the role in `role`. `name` places the paragraph at the bottom left, 140 above the bottom edge.
- The board is a 1600 by 1000 picture. `conform: fill` fills the 16:9 frame with it and cuts what overflows at the top and bottom. Its `crop` keyframes are on its own clip time, seconds since it started, and push in slowly to the middle of the picture at 1.3 times.
- The music is a sequence clip: without `at` it starts at 0, and the sequence cuts it at its end, after a fade of 1.5 seconds.

Check it before rendering. `timeline` resolves without drawing and prints every clip's ranges, `still` draws frames side by side with their times, and `sheet` lays frames out in a grid:

```sh
frames timeline /path/to/edit.json
frames still /path/to/edit.json --at 4,6.5,9 -o /path/to/out/check.png
frames sheet /path/to/edit.json -o /path/to/out/sheet.png --step 1 --cols 7
```

```
duration 14
storyline[0]#interview  /path/to/interview.mov  edit [0, 6)  drawn [0, 6.4)  clip [2, 8)  speed 1  transition none
storyline[1]  /path/to/board.png  edit [6, 10)  drawn [5.6, 10.225)  clip [0, 4)  speed 1  transition frames/fade 0.8
storyline[2]  /path/to/broll.mov  edit [10, 14)  drawn [9.775, 14)  clip [0, 4)  speed 1  transition frames/push-left 0.45
storyline[0]#interview.connected[0]  title  visible [1, 5.5)  animation frames/fade / - / frames/fade
storyline[0]#interview.connected[1]  image  visible [0, 6)  animation none
clips[0]  audio  visible [0, 14)  animation none
```

The board's fade lasts 0.8 seconds, as its choice says, and the push takes the preset's own length. A clip's edit range lies between its edit points and its drawn range adds its transitions. The title's window is its `at` carried to sequence time: clip second 3 of the interview is sequence second 1.

Then render the master, with a delivery file from the same frames:

```sh
frames render /path/to/edit.json -o /path/to/out/edit.mov --deliver /path/to/out/edit.mp4
```

The master is what is kept and delivered from. A render made only to look at or hand over writes the delivery file alone:

```sh
frames render /path/to/edit.json -o /path/to/out/edit.mp4
```

[document/GUIDE.md](document/GUIDE.md) walks through the whole loop: picking a form, looking at the material, writing, checking, rendering and delivering.

## Commands

```
frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>]
       [--encoder <name>] [--shaper <name>] [--tracker <name>] [--ocr <name>]
       <command> ...
```

Global options go before the command. `--theme` merges a theme under every document's own theme. The role and provider options pick an implementation by name: the decoder, the mixer and the encoder are `avfoundation`, the renderer `quartz`, the OCR provider `vision`, the shaper `coretext` and the tracker `point`, which are also the defaults. `--tracker planar` picks the tracker that follows a plane in perspective, the one a tracked `cornerPin` rides on a screen or a sign.

Paths are absolute. Where a command takes a document, it also takes a resolved document, a pack template (`<pack>/<name>`), or `-` for standard input. On success a command that writes a file prints one line with its path and size. On failure it prints `frames: <reason>` to standard error and exits with 1, and without a command it prints its usage to standard error and exits with 64. `frames --help` prints the usage and what each global option takes, and `frames <command> --help` prints what that command does and each of its arguments and options with its default, both to standard output with exit 0. A message names the place in the document, a path of keys and indexes with a clip's `id` after its index. With `opacity` misspelt on the logo of the first edit:

```
frames: storyline[0]#interview.connected[1] (image): unknown key "opactiy". Allowed: id, metadata, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes, media, colorSpace, toneMap, placement, position, anchor, scale, rotation, cornerPin, crop, conform, filter, width, height, radius, border, shadow
```

### Making results

| Command | What it does |
| --- | --- |
| `render <document> -o <out.mov \| out.mp4 \| out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>] [--report <report.json>] [--progress text\|json\|none]` | Renders the sequence. A `.mov` is the master of every frame: ProRes 422 HQ, or ProRes 4444 when the background is not opaque, with 24-bit PCM sound. An `.mp4` is the delivery file alone: H.264 for an SDR colour space, HEVC Main 10 for an HDR one, with AAC sound and transparent parts over black. A `.png` is the frame at `--at` (0 when left out), without a time label, at 16 bits per channel. All are in the sequence's colour space ([Colour](#colour)). `--deliver`, with a `.mov` only, also writes the same `.mp4` from the same frames. While it draws it writes `frame <k>/<n>` on standard error at most once a second and for the last frame, a JSON object a line with `--progress json` and nothing with `--progress none`. `--report` also writes the run's report to a `.json` file when the last file is closed: its time by stage, how each medium was read and how each file was encoded |
| `still <document> --at <t>[,<t>...] -o <out.png> [--args <args.json>]` | Draws frames at those sequence times side by side, each with its time label, without encoding a video, as an SDR sRGB preview. The cheap check while you edit |
| `resolve <document> -o <resolved.json> [--args <args.json>]` | Writes the resolved document: everything found, laid out and planned, with the files it uses pinned by hash |
| `transcode <in> [--page <n>] -o <out> [--quality high\|medium\|low] [--max <px> \| --scale <s>] [--codec h264\|hevc] [--color-space <name>]` | Writes a delivery file from a still (`.jpg`, `.heic`, `.png`), audio (`.m4a`) or video (`.mp4`, `.mov`, `.m4v`, or `.m4a` for its sound) at a quality level. `--max` caps the longer side, and `--color-space` names the output's colour space ([Colour](#colour)). A page of a PDF, which has no pixels of its own, is drawn at `--scale` pixels per point, fractions allowed, by default 4, or the largest at which the decoder holds the page where that is less, and takes no `--max` |

`--args` gives a template its arguments ([Templates](#templates)). A resolved document has its theme and arguments written in, so `--theme` or `--args` with one stops.

```sh
frames render /path/to/edit.json -o /path/to/out/edit.png --at 7
frames resolve /path/to/edit.json -o /path/to/out/edit.resolved.json
frames render /path/to/out/edit.resolved.json -o /path/to/out/edit.mov
frames render mine/intro --args /path/to/intro-args.json -o /path/to/out/intro.mov
frames transcode /path/to/out/edit.mov -o /path/to/out/edit-small.mp4 --quality medium --max 1280
```

### Looking at material and results

| Command | What it reports |
| --- | --- |
| `probe <media> [--page <n>] [--json]` | the kind (`image`, `page`, `video`, `audio`, `imageSequence`), size, duration, frame rate, alpha, colour space and audio of a file or a directory of PNGs, and the page count of a PDF (without `--page`, a PDF of more pages gives only its page count) |
| `loudness <media \| document> [--from <t>] [--to <t>] [--args <args.json>] [--json]` | the integrated loudness, loudness range, largest momentary and short-term loudness, true peak and sample peak of a document's mix, after the sequence's `audioFilter`, or of the mix of one clip of a medium, without rendering pictures. `--from` and `--to` measure part of it, read as part of the whole sound. `--args` with a medium stops, since a medium has no parameters to take them |
| `ocr <still \| video \| image sequence> [--fps <rate>] [--page <n>] [--at <t> \| --from <t> --to <t> --step <s>] [--languages <tag>[,<tag>...]] [--color-space <name>] [--json]` | the recognised lines, `[x, y, w, h]  text` in media pixels, for a page of a PDF in points, top to bottom by row and left to right within a row. `--languages` gives the recognition languages, and `--fps` the rate an image sequence is read at, which its files do not give |
| `track <video \| image sequence> [--fps <rate>] --at <t> (--area <area> \| --quad <quad>) [--to <t>] [--color-space <name>]` | the target's four corners on every frame the tracker follows, as the track data a clip's `track` takes, as JSON. `--quad` gives the target as four points in a corner pin's order, and `--fps` the rate an image sequence is read at |
| `extract <video \| image sequence \| document> <outdir> [--fps <rate>] [--from <t>] [--to <t>] [--step 1]` | frames as full-size PNGs, `0000.png`, `0001.png`, ... |
| `sheet <video \| image sequence \| document> -o <out.png> [--fps <rate>] [--from <t>] [--to <t>] [--step 1] [--cols 6]` | frames laid out in one picture, each at most 480 pixels on its longer side and labelled with its time |
| `timeline <document> [--at <t>] [--args <args.json>] [--json]` | the plan of time without rendering: every storyline clip's edit, drawn and clip ranges, speed and transition, and every other clip's visible range, kind and animation, each by its place. `--json` also gives each clip's lane, parent, media, instant, the map of the times it writes to sequence time, and the pixels its coordinates are written in. `--at` adds what each clip's time map gives at a sequence time, inside the sequence or outside it: its clip time and the media time of the frame it shows, drawn or not |
| `evaluate <document> --at <t> [--args <args.json>]` | the display list at a time: what is drawn, by which clip, where, and where each title's lines, words and characters lie, as JSON |
| `locate <document> --at <t> --point <x,y> [--args <args.json>]` | the clips under a point of the output at a time, and for media the frame and pixel it shows, for a page of a PDF its page and the point in points |

Given a video, `extract` and `sheet` take the frames shown at media times. Given a document they draw it at sequence times as `still` does, so what you check is what `render` makes, as an SDR sRGB preview. `ocr` and `track` read the media in the colour space `--color-space` names, as a clip's `colorSpace` corrects it. `ocr --languages` takes the recognition languages as BCP 47 tags in order of preference (`ko-KR,en-US`); without it the provider detects the language of each picture, which reads text in one language, accents and Chinese and Japanese included. Give it for lines that mix scripts, such as Korean with English words and numbers, with the non-Latin language first: `vision` reads only what the listed languages cover, led by the first, so `ko-KR,en-US` reads `Total 12,000원` and `en-US,ko-KR` misses the Korean. `--area` takes a rectangle as JSON text, `'[10, 20, 300, 40]'`, and `--quad` four points, `'[[412, 204], [731, 252], [702, 518], [379, 461]]'`.

```sh
frames probe /path/to/interview.mov
frames loudness /path/to/edit.json --json
frames ocr /path/to/board.png
frames sheet /path/to/interview.mov -o /path/to/out/interview.png --step 1 --cols 6
frames track /path/to/broll.mov --at 1 --area '[780, 360, 360, 360]' --to 3
frames evaluate /path/to/edit.json --at 7
frames locate /path/to/edit.json --at 1 --point 1760,120
```

### Presets, packs and the theme

| Command | What it prints |
| --- | --- |
| `presets [<kind>] [<name>]` | the presets of every pack by kind (`transition`, `animation`, `filter`), each with the name a document gives it and how it looks, or one preset's JSON with its parameters |
| `packs [<pack>]` | the packs, the one that ships with frames and the installed ones, or what one pack holds, with the parameters each preset and template publishes and the tools it holds |
| `theme` | the base theme, which is also the list of every group a theme holds |
| `--version` | the version of frames |
| `--help`, `<command> --help` | the usage and the global options, or one command's help |

```sh
frames presets transition
frames presets transition frames/push-left
frames packs frames
frames theme
```

### Tools

A tool is a program a pack carries that takes a document and gives a document ([FRAMES-25](spec/FRAMES-25/SPEC.md#tools)). `frames <pack>/<name> [arguments]` runs the tool `<name>` of the pack `<pack>`, with the global options written before the name and the arguments after it passed through unchanged, standard input and output included, so `frames studio/autocut --help` is the tool's own help. A command word with a `/` names a tool, and any other word a command of frames. A tool reads documents and machine output and writes a document to standard output, so tools chain into `render -`:

```sh
frames studio/autocut /path/to/raw.json | frames studio/captions - | frames render - -o /path/to/out/cut.mov
```

A tool is installed with its pack, and `frames packs <pack>` lists the tools a pack holds. frames checks the pack's `engine` against its own version before it runs the tool, and runs a tool only when a command names it: resolve and render run nothing from a pack. [document/PACK.md](document/PACK.md#a-tool) shows how a pack carries a tool, and [document/GUIDE.md](document/GUIDE.md#writing-a-tool) how to write one.

frames ships two tools in the pack `frames`, with nothing to install, and each fills requests. A request is an object with the key `tool` that stands where a value is still to be found, and names its tool as `<pack>/<name>`. A tool fills the requests that name it and leaves every other as written ([FRAMES-25](spec/FRAMES-25/SPEC.md#requests)), and frames itself takes no request and stops on one, naming its tool. `frames/find-text` fills each area written as `{"tool": "frames/find-text", "text": "Total", "padding": 8}` with the rectangle `frames ocr` finds for that text, so `frames frames/find-text /path/to/edit.json | frames render - -o /path/to/out/edit.mp4` renders it. A request's `"aspectRatio": [w, h]` makes its rectangle that ratio inside the picture, for a crop that fills its box, and `--report <report.json>` writes the text each rectangle came from ([frames/find-text](source/frames/Sources/FramesCommand/Resources/packs/frames/tools/find-text/README.md)). `frames/track-motion` fills each `track` written as `{"tool": "frames/track-motion", "target": "area"}` with the track data `frames track` prints for the target, one of the clip's own keys or an area, followed from the frame the clip's instant shows, so `frames frames/find-text /path/to/edit.json | frames frames/track-motion - | frames render - -o /path/to/out/edit.mp4` renders a document whose track targets are areas `frames/find-text` fills ([frames/track-motion](source/frames/Sources/FramesCommand/Resources/packs/frames/tools/track-motion/README.md)).

## Document reference

A document is a JSON object whose `kind` is `"sequence"`. Its keys are checked over the whole tree before any value is read, a value of the wrong type stops with its place, and a leaf written as a static value and given a value in every keyframe that writes it stops, since the static value would never show. The full key table is [FRAMES-7](spec/FRAMES-7/SPEC.md).

### Values

| Value | Written as | Spec |
| --- | --- | --- |
| time | seconds, as a number | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| colour | `#RRGGBB` or `#RRGGBBAA` (sRGB), `color(<space> r g b)` or `color(<space> r g b / a)` with `srgb`, `srgb-linear`, `display-p3` or `rec2020` and components of any real number, or the name of a theme colour (`accent`) | [FRAMES-26](spec/FRAMES-26/SPEC.md#colour-values) |
| a clip's coordinates (`position`, `area`, path points, mask geometry) | output pixels, origin top left, for an unparented clip, and the space its parent gives for a parented one | [FRAMES-1](spec/FRAMES-1/SPEC.md), [FRAMES-10](spec/FRAMES-10/SPEC.md) |
| `crop` | media pixels of the clip's own media | [FRAMES-9](spec/FRAMES-9/SPEC.md) |
| theme length (text size, `lineHeight`, stroke width, `dash`, `radius`, `outset`, `feather`, border, shadow, filter radius, `displace` `amount`) | points at the theme `baseWidth`, scaled by the width of the frame the clip is drawn on over it: the output frame, or a compound clip's own frame for a clip inside it | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| angle | degrees, clockwise positive | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| placement name | `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right` | [FRAMES-1](spec/FRAMES-1/SPEC.md) |

### The sequence

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips, audioFilter, keyframes`. `kind` is required and is `"sequence"` |
| format | `size, fps, background, conform, colorSpace, peak, compositing, motionBlur` |
| content fit (a `size` written as an object) | `fit, margin` |

- `size` is `[w, h]`, `{"fit": "content", "margin": m}` ([Stills and content fit](#stills-and-content-fit)), or left out for the size of the first video clip on the storyline (of the first storyline clip when there is no video). Sizes round to even numbers.
- `fps` defaults to the first video's nominal rate rounded to 24, 25, 30, 50 or 60, and to 30 without video.
- `background` defaults to the theme `background` colour, black in the base theme. A background that is not opaque gives a master with alpha.
- `conform` is how a storyline crop fills the frame: `fit` (the default) shows the whole crop and leaves the rest transparent, `fill` fills the frame and cuts what overflows.
- `colorSpace` is the colour space the sequence is output in, `srgb` by default, `peak` the mastering peak of a `rec2100-pq` sequence, and `compositing` the form it composites in, `encoded` by default or `linear` ([Colour](#colour)).
- `motionBlur` is the shutter of every frame, `{shutterAngle, shutterPhase, samplesPerFrame}` ([Motion blur](#motion-blur)).
- `theme` is a theme object, `<pack>/<name>` or an absolute path ([Theme](#theme)). `params` makes the document a template ([Templates](#templates)).
- `audioFilter` is the chain of the sequence's bus, run over the sum of its sounds wherever the sequence plays, so the outermost sequence's chain is the master bus ([Audio filters](#audio-filters)). The sequence's own `keyframes` time it on sequence time, and it is the only thing they take.

[FRAMES-6](spec/FRAMES-6/SPEC.md), [FRAMES-7](spec/FRAMES-7/SPEC.md), [FRAMES-9](spec/FRAMES-9/SPEC.md), [FRAMES-26](spec/FRAMES-26/SPEC.md), [FRAMES-28](spec/FRAMES-28/SPEC.md)

### Clips

- `storyline` is the primary storyline: its clips play one after another, and a transition plays across the edit point between two of them.
- `connected` clips belong to one storyline clip, live on its clip time and move when it moves, as connected clips do in an NLE.
- `clips` are sequence clips, on the sequence clock.

A clip is a media clip (`media`), a title (`title`), a shape (`shape`), an adjustment clip (`adjust`) or, on the storyline only, a solid (`solid`, a colour that fills the frame). Exactly one of these keys is present. An audio clip is a media clip that takes no picture, because its media holds only sound or because it is written with `"picture": false`, and a clip with a picture is every other clip. Which media row applies is decided once the media is probed.

| Clip | Keys |
| --- | --- |
| storyline clip, timed media (video, image sequence, compound) | `id, metadata, media, colorSpace, toneMap, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, split, keyframes, connected`, and `audioFilter` on a video or a compound clip |
| storyline clip, still (image or page, a page without `toneMap`) | `id, metadata, media, colorSpace, toneMap, duration, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, radius, border, shadow, keyframes, connected` |
| storyline clip, solid | `id, metadata, solid, duration, transition, motionBlur, keyframes, connected` |
| every clip with a picture (connected and sequence) | `id, metadata, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip with a picture's, `audioFilter` on a video or a compound clip and `split`, `media, picture, colorSpace, toneMap, in, out, speed, loop, volume, pan, fadeIn, fadeOut, placement, position, anchor, scale, rotation, cornerPin, crop, conform, filter, width, height, radius, border, shadow` |
| still media clip (image or page, a page without `toneMap`) | every clip with a picture's, `media, colorSpace, toneMap, placement, position, anchor, scale, rotation, cornerPin, crop, conform, filter, width, height, radius, border, shadow` |
| audio clip | `id, metadata, at, media, in, out, speed, loop, volume, pan, fadeIn, fadeOut, audioFilter, keyframes` |
| audio clip of a video's, a compound clip's or a template instance's sound (`"picture": false`) | every audio clip's, `picture` |
| title clip | every clip with a picture's, `title, style, character, paragraph, width, placement, position, anchor, scale, rotation, cornerPin` |
| shape clip | every clip with a picture's, `shape, style, area, width, height, placement, position, anchor, points, closed, radius, outset, fill, stroke, trim, shadow, scale, rotation`, and `cornerPin` on a rect or ellipse given by `width` and `height` |
| adjustment clip | every clip with a picture's, `adjust` |

- `id` names a clip for `parent`, a track matte's `clip`, messages, machine output and the programs that change a document. It is unique within its document, and a duplicate stops.
- `metadata` is an object frames does not read: what a program that changes the document keeps on a clip, as an NLE keeps keywords and notes.
- `lane` is a non-zero integer, 1 by default. Negative lanes are below the storyline (lane 0) and positive lanes above it ([Lanes and stacking](#lanes-and-stacking)).
- A storyline clip is placed by `position` (default the centre of the frame) or by `cornerPin` and takes no `placement` and no `parent`. Its box is the frame, which its conformed crop fills, so a storyline clip that writes no transform fills the frame. `radius`, `border` and `shadow` show where its transform leaves the box smaller than the frame.
- `colorSpace` on a media clip names the colour space its media are in, over what the file says, and `toneMap` (`true` by default) whether an HDR picture of it is tone mapped to the sequence's peak ([Colour](#colour)). A clip whose media is a compound clip or a template instance takes neither.
- `filter` and `transition` take preset choices ([Presets and choices](#presets-and-choices)). `"none"` turns off the theme's default filter for one clip, and `"cut"` its default transition. The first storyline clip takes no transition. To open from black, put a solid there and give the clip after it a transition.
- `"picture": false` on a connected or sequence clip of a video, a compound clip or a template instance takes only its sound, and `split` moves the edges of a clip's sound for a J or an L cut ([Sound](#sound)).

[FRAMES-7](spec/FRAMES-7/SPEC.md), [FRAMES-9](spec/FRAMES-9/SPEC.md), [FRAMES-11](spec/FRAMES-11/SPEC.md), [FRAMES-13](spec/FRAMES-13/SPEC.md)

### Media

| Form | Means |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` sequence document, which stands as if written there |
| `"<pack>/<name.ext>"` | a file in a pack's `media/` |
| `{"file": "/abs/deck.pdf", "page": 3}` | a page of a PDF, from 1 (the file may be `<pack>/<name.pdf>`). A PDF of one page may be named as a file, the same page, and one of more pages named as a file stops |
| `{"imageSequence": "/abs/dir", "fps": 30}` | every PNG in the directory, in natural order, played like a video (the directory may be `<pack>/<dir>`) |
| a sequence document object | a compound clip: the nested sequence plays as a video with sound, at its own frame size and with its own background |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance ([Templates](#templates)) |

Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha), pages of a PDF and compound clips. That is how graphics made elsewhere come in. A page of a PDF is a still with no pixels of its own, taken wherever a still (an image or a page) is: its media pixels are its points, and it is drawn at the size it is shown at, so a logo scaled up or a map zoomed into stays sharp. What it paints nothing over is transparent in an edit, and white where it is read for its values (OCR, a matte's luma, a JPEG). frames fixes its boxes, that its content streams are drawn and not its annotations, its pixel grid and the colour space of its untagged colour (DeviceRGB and DeviceGray), and the rest of how it is drawn (the colour spaces it tags colour with, optional content, anti-aliasing, transparency, the resampling of an image inside it) is the decoder's PDF renderer. The decoder refuses a PDF that needs a password and a page that sets drawn text in a font its file does not embed, since that font would come from the machine. It refuses before it starts, in `probe` as in a render, and `transcode` turns a page refused for its fonts into a PNG. SVG is converted to PDF first, with `rsvg-convert -f pdf` or Inkscape. A compound clip is also how a group of clips acts as one: a picture-in-picture window with its own edit inside, a group that should leave together in a wipe, or an adjustment that should reach only some clips. [FRAMES-3](spec/FRAMES-3/SPEC.md), [FRAMES-9](spec/FRAMES-9/SPEC.md)

### Time

Three clocks meet on a sequence: **clip time**, a storyline clip's own timeline; **sequence time**, the time of the output; and **media time**, the clock of a media file. Instants are on the clock of what they belong to, and durations are sequence seconds.

| Instant | Clock |
| --- | --- |
| a storyline clip's `keyframes`, `in` and `out` | its clip time: media seconds for video, image sequences and compound clips, seconds since it started for a still or a solid |
| a connected clip's `at` and `keyframes` | its storyline clip's clip time |
| a sequence clip's `at` and `keyframes` | sequence time |
| `in` and `out` of a connected or sequence media clip | its media time |

- A storyline clip of timed media lasts `(out - in) / speed`, and a still or a solid lasts `duration`. `in` defaults to 0 and `out` to the end of the media. An `out` past the end is trimmed to it.
- Durations (`duration`, transition and animation `seconds`, `fadeIn`, `fadeOut`) are sequence seconds, so an entrance takes the same time on every clip.
- A transition is centred on its edit point and lasts at most the shorter of its two clips. During it the outgoing clip plays on past its `out` and the incoming clip starts before its `in`, on their handles. A storyline clip's **edit range** lies between its edit points, and its **drawn range** runs from the start of its incoming transition to the end of its outgoing one.
- `at` is `[start, end]`, or a start alone for video, audio, image sequence and compound media, which then play their natural length. A connected clip without `at` spans its storyline clip's edit range, and a sequence clip without `at` the whole sequence. A media clip plays from its `in` at its own `speed`, and `loop` repeats it to fill a longer window.
- `timeRemap` keyframes give the media time a clip shows at each instant, as After Effects' time remapping: two keys with the same value hold a frame, a lower next value plays backwards, and eased keys ramp the speed. It is written only in keyframes, takes no `speed`, and the clip plays no sound.
- Connected and sequence clips are cut to the sequence. A clip that is never visible stops.

```json
{
  "kind": "sequence",
  "storyline": [
    { "kind": "media", "media": "/path/to/interview.mov", "in": 0, "out": 4, "speed": 2 },
    { "kind": "media", "media": "/path/to/broll.mov", "in": 0, "out": 6,
      "keyframes": [ { "at": 0, "timeRemap": 4 }, { "at": 2, "timeRemap": 6 },
                     { "at": 3.5, "timeRemap": 6, "ease": "ease-in" }, { "at": 6, "timeRemap": 9 } ] }
  ],
  "clips": [
    { "at": 2, "kind": "media", "media": "/path/to/whoosh.wav", "pan": -0.5 },
    { "kind": "media", "media": "/path/to/music.m4a", "fadeIn": 1,
      "keyframes": [ { "at": 1, "volume": 0.6, "ease": "ease-in-out" }, { "at": 1.5, "volume": 0.15 } ] }
  ]
}
```

The interview plays 4 seconds of media in 2. The B-roll shows its media seconds 4 to 6, holds that frame for a second and a half, and ramps on to second 9, over 6 seconds of sequence time. The whoosh plays on the left at the cut, and the music fades in and ducks under the B-roll. `timeline` prints each storyline clip's ranges and says `timeRemap` for the remapped one. [FRAMES-8](spec/FRAMES-8/SPEC.md)

### Keyframes and eases

Any keyframable property takes a static value or keyframes. A keyframe is `{at, ease}` with one or more properties of its clip, and sets only the leaves it writes: each number, colour, point, area and crop in a value is a leaf, timed on its own. Each leaf joins only the keyframes that write it, holds its first value before them and its last after them, and an `ease` shapes the span leaving its keyframe, as in CSS and Lottie.

| Clip | Keyframable |
| --- | --- |
| sequence, by its own `keyframes` | `audioFilter` |
| storyline clip with media | `crop, position, scale, rotation, cornerPin, opacity, mask, filter, radius, border, shadow`, `volume`, `pan` and `timeRemap` on timed media, and `audioFilter` on a video or a compound clip with sound |
| storyline clip, solid | `solid` |
| media clip | `position, scale, rotation, cornerPin, opacity, crop, mask, filter, radius, border, shadow`, `volume`, `pan` and `timeRemap` on timed media, and `audioFilter` on a video or a compound clip with sound |
| audio clip | `volume, pan`, and `audioFilter` where it takes one |
| title clip | `position, scale, rotation, cornerPin, opacity, mask`, in `character` its `color`, `stroke`, `tracking`, `baselineShift`, `highlight` and `underline`, and in `paragraph` its `lineHeight` and `background` |
| shape clip | `area, width, height, points, position, scale, rotation, cornerPin, opacity, trim, radius, outset, fill, stroke, shadow, mask` |
| adjustment clip | `opacity, mask, adjust` |

| ease | Shape |
| --- | --- |
| `linear` (default), `ease-in`, `ease-out`, `ease-in-out` | cubic curves |
| `back-out`, `bounce-out` | overshoots, bounces |
| `step` | holds, then jumps at the end |
| `[x1, y1, x2, y2]` | a cubic Bezier, as CSS `cubic-bezier()` |
| `{"spring": {"bounce": b}}` | a damped spring, b between -1 and 1: 0 settles without overshoot, higher swings past and back |

A `crop` keyframes its size in log space, so a zoom keeps one speed. In `mask`, `filter`, `adjust`, `fill`, `stroke`, `shadow`, `border`, `character`, `paragraph` and `audioFilter` a keyframe writes the numbers and colours that move, over the clip's static value merged over its style. Names, booleans, files and the form of a value (a mask's `shape`, `invert` and `mode`, a filter's presets and ops, a gradient's kind and number of stops, a stroke's or a border's `align`, a stroke's `join` and `cap`) are static on the clip, and a keyframe that writes one stops. A keyframe's `mask` is a list as long as the clip's, whose masks write only the geometry, `radius` and `feather` they move. A `radius` keyframe may write one number where the next writes four: the number is four equal radii, and each corner moves apart. A leaf written `null` in a keyframe is the merged value at that instant, so a keyframe can point back at the static value or the style's. A leaf whose keyframes all lie before or all after the range its clip is visible in (for the sequence's own keyframes, the sequence) stops, since only one value would ever show.

```json
{ "at": [0, 3], "kind": "media", "media": "/path/to/broll.mov", "width": 960, "position": [960, 540],
  "mask": { "shape": "ellipse", "position": [640, 360] },
  "filter": { "op": "blur", "radius": 12 },
  "keyframes": [ { "at": 0, "mask": [ { "width": 0, "height": 0, "feather": 0 } ], "filter": { "radius": 0 }, "ease": "ease-out" },
                 { "at": 1, "mask": [ { "width": 1400, "height": 1400, "feather": 40 } ], "filter": { "radius": null } } ] }
```

The picture opens in a circle from its centre as its edge softens, and its blur eases in to the clip's own 12. The mask's `shape` and `position` are written once on the clip, and `"invert": true` in a keyframe would stop. [FRAMES-4](spec/FRAMES-4/SPEC.md), [FRAMES-7](spec/FRAMES-7/SPEC.md)

### Placement and transform

A clip with a box of its own (a title, a media clip, a rect or ellipse given by `width` and `height`) is placed by `placement` or by `position`, never both.

- `placement` is a placement name: the box sits there inside the frame, kept in from every edge by the theme `placement.padding`, the title safe margin. A text style's `offset` replaces that margin on the top or bottom edge.
- `position` is where the clip's anchor point goes, a point ([Areas and points](#areas-and-points)). `anchor` names that point of the clip's box, `center` by default, or for a placed clip the point its placement names, so a `bottom` subtitle grows upwards.
- `cornerPin` places a clip by the four points its box's corners go to, top left, top right, bottom right and bottom left, so a picture lies on a plane seen in perspective: `"cornerPin": [[400, 300], [1500, 360], [1460, 760], [440, 700]]`. Written with any of `placement`, `position`, `anchor`, `scale` and `rotation`, on the clip or in a keyframe, it stops. It is keyframable point by point, and on a shape given by `area` or `points` it stops. The clip is drawn flat in its box with everything it does, its animation included, and carried onto the four points by one homography, so an entrance slides and scales on the plane. A child of a clip with a corner pin follows its tracked motion, not the plane, and what should lie on the plane goes inside it as a compound clip.
- `scale` and `rotation` act around the anchor point. `opacity` runs from 0 to 1, and `blend` composites the clip onto what is below ([Blend modes and adjustment clips](#blend-modes-and-adjustment-clips)).
- A media clip's `width` and `height` size its box. Given one, the other follows the aspect ratio of its first crop. Given both, the crop conforms to the box by `conform`. Given neither, the box is the picture fitted to the frame. `radius` rounds its corners, one length or four as a rect's ([Shapes](#shapes)), `border` (`true`, `false`, a colour, or `{width, color, align}` whose missing keys come from the theme border) draws a border along its edge, inside it by the theme border's `align`, and `shadow` (`true`, `false` or `{radius, offset, color}`) drops the theme shadow below it.
- A media clip with video or an image sequence is picture in picture. One with alpha is how a motion graphic made elsewhere comes in.

[FRAMES-1](spec/FRAMES-1/SPEC.md), [FRAMES-11](spec/FRAMES-11/SPEC.md), [FRAMES-27](spec/FRAMES-27/SPEC.md)

### Areas and points

An area is a rectangle in the coordinate space of the clip that writes it. A point is `[x, y]`, or `{"area": <area>, "point": <placement name>}` for that point of an area.

| Form | Means |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `{"clip": "<id>", "padding": p}` | the box of that clip at the same instant, grown by `padding`, a theme length: a connected or sequence media clip, title or shape with the same parent or none, or the parent of the clip that writes it |

An area keeps what is written, also past the picture's edges, and the part of a crop beyond the media is transparent. A place found in a picture is written as the rectangle it was found at. `frames ocr` prints every line of text it recognises in a medium with its rectangle in media pixels, which are the coordinates of a storyline or media clip's own `crop`, `mask` and `track` target and of a clip parented to it, and the tool `frames/find-text` fills a document's requests that name lines by their text with those rectangles ([Tools](#tools)). A clip area makes a bar fit a title whatever its text, and a label sit at a point of the box it names. [FRAMES-2](spec/FRAMES-2/SPEC.md)

### Titles and runs

A title clip's `title` is a string or a list of runs `{text, style}`, and its `style` names a theme text style and is required.

- A run's `style` gives that run its character attributes (`font`, `size`, `weight`, `italic`, `tracking`, `kerning`, `features`, `baselineShift`, `color`, `stroke`, `highlight`, `underline`, `textOrientation`, `textCombineUpright`). The clip's style gives the paragraph its attributes (`placement`, `offset`, `writingMode`, `direction`, `align`, `lineHeight`, `lines`, `background`). A run without `style` is in the clip's style.
- `character` on a title merges character attributes over every run's style, leaf by leaf, as After Effects' Character panel sets a text layer, so `"character": {"color": "accent"}` colours every run and keeps each run's size. `paragraph` merges `writingMode`, `direction`, `align`, `lineHeight` and `background` over the clip style's. Their lengths are theme lengths. What decides faces, shaping and line breaks (`font`, `size`, `weight`, `italic`, `kerning`, `features`, `textOrientation`, `textCombineUpright`, `writingMode`, `direction`, `align`) is static, and the rest takes keyframes ([Keyframes and eases](#keyframes-and-eases)). A title changes size through its `scale`.
- Without `width` a title is point text: it does not wrap, its lines break only at `\n`, and its box is as wide as its widest line, so a background hugs the text.
- With `width` (output pixels) a title is paragraph text: it wraps at that width, its box is `width` wide, each line sits in it by the style's `align`, and a background fills it. Lines break by Unicode line breaking and keep words whole, so Korean breaks at spaces.
- Text that needs more lines than its style's `lines` stops, with `width` or without, so a `lines: 1` title wider than its `width` stops rather than shrink or cut.
- Right-to-left and mixed-direction text is laid out by the Unicode Bidirectional Algorithm. A style's `direction` is `auto` (from the text's first strong character, the default), `ltr` or `rtl`, and `align` names a side of the box, `left` by default for left-to-right text and `right` for right-to-left. Characters, words, lines and units stay in the order they are read, so a reveal by character starts an Arabic word at its first letter. Write the text as it is read: `{"kind": "title", "text": "שלום עולם", "style": "title"}` is set right to left with no key, and a style with `"direction": "rtl"` sets a line that starts with a Latin name, such as `Frames 2.0 יצאה היום`, from the right.
- Vertical text: a style's or a title's `paragraph` `writingMode` is `horizontal-tb` (the default), `vertical-rl` (vertical lines stacked right to left, for Chinese, Japanese and Korean) or `vertical-lr` (stacked left to right, for Mongolian). Ideographs, kana and Hangul stand upright in their vertical forms and Latin words and digits lie on their sides, as Unicode's Vertical_Orientation gives. A run's style sets `textOrientation` to `upright` to stand every character of the run, `NHK` letter under letter, or to `sideways` to lay every one on its side (`mixed`, the default, follows Vertical_Orientation), and `textCombineUpright: all` to set the run's text side by side in one square of the column, narrowed to 1 em where it is wider, as tate-chu-yoko sets the digits of a date, here with a `combined` style that sets it: `[{"text": "令和", "style": "title"}, {"text": "12", "style": "combined"}, {"text": "年", "style": "title"}]`. Every other key keeps its meaning on the line's axes: `width` is the length the columns wrap at, `align` `left` and `right` are the top and the bottom, `lineHeight` is the distance between columns and `baselineShift` moves to the right.
- A style's or a `character`'s `font` is a list of families in the order they are tried, the theme `font` by default, and the first family the pack or the machine has is used. Text is laid out by resolve, so line breaks and boxes are the same on every renderer.
- An animation choice on a title takes `by` (`character`, `word` or `line`), `stagger`, the seconds between one unit's start and the next, and `order`, in both object forms: `{"preset": "frames/rise", "by": "word"}` and `{"entrance": "frames/pop", "exit": "frames/fade", "by": "character", "stagger": 0.03, "order": "center"}`. Each unit plays the entrance and the exit about its own box, and the default `stagger` is 0.04 by character, 0.12 by word and 0.3 by line ([Presets and choices](#presets-and-choices)).
- `order` is the order the units start in: `forward` (reading order, the default), `backward`, `center` (the middle unit first, then each pair out from it together), `edges` (the first and the last unit first, then each pair in towards the middle) or `random` (a shuffle that depends only on the unit count, so every render gives the same one). The units leave in the order they came, and the last one ends with the clip.

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080] },
  "theme": { "styles": { "mark": { "size": 96, "weight": "bold", "color": "#101418",
                                   "highlight": { "color": "#F2B33D", "padding": [4, 16], "radius": 8 } } } },
  "storyline": [ { "kind": "solid", "color": "#101418", "duration": 4 } ],
  "clips": [
    { "kind": "title", "text": [ { "text": "Baked " }, { "text": "this morning", "style": "mark" } ], "style": "title",
      "width": 900, "character": { "font": ["Avenir Next"], "tracking": 20 }, "paragraph": { "align": "left", "lineHeight": 110 },
      "animation": { "preset": "frames/rise", "by": "word", "stagger": 0.1 } }
  ]
}
```

The title wraps at 900 pixels, its lines 110 apart from baseline to baseline, all of it in Avenir Next with a little more tracking, and the words `this morning` are dark on a rounded yellow highlight. Its three words rise in one after another, a tenth of a second apart.

[FRAMES-5](spec/FRAMES-5/SPEC.md), [FRAMES-11](spec/FRAMES-11/SPEC.md), [FRAMES-14](spec/FRAMES-14/SPEC.md)

### Shapes

`shape` is `rect`, `ellipse` or `path`.

| shape | Geometry | Keys of its own |
| --- | --- | --- |
| `rect` | `area`, or `width` and `height` placed as a box | `radius`, `outset` |
| `ellipse` | as a rect: the ellipse inscribed in its box | `outset` |
| `path` | `points`, at least two vertices, each a point or `{vertex, inTangent, outTangent}`, joined by cubic Bézier segments, straight where both tangents are 0 | `closed` |

| Key | Form |
| --- | --- |
| `fill` | a colour, a gradient, or `false`. A path fills as if closed |
| `stroke` | `{color, gradient, width, align, join, cap, start, end, dash, dashOffset}`, or `false`. `width` is required, the stroke is painted by at most one of `color` and `gradient`, the theme `accent` without either, `align` is `inside`, `center` (default) or `outside`, the side of the outline the stroke lies on, `join` is `miter`, `round` (default) or `bevel`, `cap` is `butt` (default), `round` or `square`, and `start` and `end` are each `none` (default), the name of a head preset such as `frames/arrow`, or `{preset, scale}`, `scale` (default 1) multiplying the head's size |
| `dash`, `dashOffset` | a list of theme lengths, dashes and gaps in turn, not all 0, as SVG `stroke-dasharray`, and how far into that pattern the stroke starts. Each dash takes `cap`, and keyframing `dashOffset` moves the dashes along the outline |
| `trim` | `[a, b]` from 0 to 1: the part of the outline the stroke draws, as Trim Paths. Keyframed, it draws a stroke on |
| `radius` | a rect's rounded corners: a theme length for every corner, or a list of four, `[topLeft, topRight, bottomRight, bottomLeft]` as CSS `border-radius` writes them. Where a side's two corners add up to more than the side, every radius is scaled by one factor, as CSS does, so one radius is cut to half the shorter side |
| `outset` | how far a rect or an ellipse's outline grows beyond its box, a theme length |
| `shadow` | `true`, `false` or `{radius, offset, color}` |
| `style` | a shape style of the theme, which gives defaults for `fill`, `stroke`, `radius`, `outset` and `shadow`. A key on the clip merges over the style's leaf by leaf, so `"stroke": {"color": "#FF0000"}` keeps the style's width, `join` and `cap`, a value of another form (a colour fill over a gradient) replaces it, and `false` turns it off |

A path's vertex `{vertex, inTangent, outTangent}` carries its tangents as offsets from its point, as After Effects and Lottie write a path: the segment from A to B is the cubic Bézier whose control points are A plus A's `outTangent` and B plus B's `inTangent`, so a path of plain points is straight and a quadratic curve or an arc is written as tangents. A gradient is `{"linear": {"from": p, "to": p, "stops": [...]}}` or `{"radial": {"center": p, "radius": r, "stops": [...]}}`, its points fractions of the shape's box (`[0, 0]` its top left, `[1, 1]` its bottom right) and a radial `radius` a fraction of the distance from the centre to the farthest corner, 1 by default. `stops` are at least two `[offset, colour]` pairs, offsets from 0 to 1 in order. A gradient paints a `fill` or a stroke's `gradient` and nothing else, and its points, offsets and colours take keyframes while its kind and number of stops stay.

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080] },
  "theme": { "colors": { "accent": "#F2B33D" } },
  "storyline": [ { "kind": "solid", "color": "#101418", "duration": 4 } ],
  "clips": [
    { "kind": "rect", "width": 800, "height": 200, "position": [960, 300], "radius": 24,
      "fill": { "linear": { "from": [0, 0], "to": [1, 0], "stops": [ [0, "accent"], [1, "#F2B33D00"] ] } } },
    { "kind": "ellipse", "width": 300, "height": 300, "position": [1600, 300],
      "fill": { "radial": { "center": [0.5, 0.5], "radius": 1, "stops": [ [0, "#FFFFFF"], [1, "#FFFFFF00"] ] } } },
    { "kind": "path", "points": [ [400, 800], { "vertex": [1520, 800], "inTangent": [-300, -400] } ],
      "stroke": { "width": 6, "dash": [24, 12], "cap": "round", "end": "frames/arrow" },
      "keyframes": [ { "at": 0, "stroke": { "dashOffset": 0 } }, { "at": 4, "stroke": { "dashOffset": 144 } } ] }
  ]
}
```

The bar fades from the accent colour to clear across its width, the disc glows from a white centre, and a dashed arrow arcs up and over to the right, its dashes marching along the curve.

A stroke's `align` places its width as a design tool's stroke position does: `center` straddles the outline, `inside` lies within it, and `outside` around it, covering nothing of the fill, so a ring drawn `outside` an area leaves what it marks clear. An `inside` or `outside` stroke is the centred stroke of twice the width cut to that side, so its round joins round an outside corner by the width and its miter joins keep it square, and it needs a closed outline (a rect, an ellipse or a `closed` path) and no arrowhead. A shape given by `area` or `points` sits where its geometry is written, and `position` moves its anchor point. A shape that has neither a fill nor a stroke after its style stops. To darken everything but a region, fill a rect over the picture and give it an inverted mask of the region. To point at something, draw a path with `"end": "frames/arrow"`. A head is a preset of the kind `head`, named `<pack>/<name>` or by an absolute path as every preset is, and the pack `frames` ships six: `frames/arrow` a filled triangle 4 units long and wide, `frames/line-arrow` its two sides as open bands, `frames/circle`, `frames/square` and `frames/diamond` 4 units across, and `frames/bar` a bar 4 units across the end and 1 thick. A pack adds its own as a file in `presets/head/` ([document/PRESET.md](document/PRESET.md#a-head)). A head is drawn in units of the stroke's width times its `scale`, its tip at the end of the stroke as drawn, so nothing of it reaches past the point it marks, and on a curved end it keeps its shape, smaller by the chord from its base to its tip over its length. The line stops inside the head, with its cap there. Heads longer together than a short stroke shrink by one factor to share it. A name names the preset alone, so `"end": "frames/circle"` over a style whose end is `{"preset": "frames/arrow", "scale": 1.5}` keeps the 1.5. `preset` is static and `scale` keyframes as `width` does, from 0 where two keyframes write it, so a head grows in. Text beside a shape is a title parented to it. [FRAMES-11](spec/FRAMES-11/SPEC.md)

`radius` rounds corners as CSS `border-radius` does: one length rounds every corner, and `[topLeft, topRight, bottomRight, bottomLeft]` rounds each by its own, so `[24, 24, 0, 0]` is a tab square at the bottom. The corners are the box's own, before any scale or rotation, and where a side's two corners add up to more than the side every radius shrinks by one factor, keeping their proportions. The same `radius` rounds a media clip's and a storyline clip's box, a rect mask, a shape style's rect and a text background and highlight. [FRAMES-11](spec/FRAMES-11/SPEC.md#shapes)

### Masks and track mattes

`mask` cuts any clip with a picture. It is a mask or a list of masks, combined in order as After Effects combines a layer's masks.

| Mask key | Form |
| --- | --- |
| `shape` | `rect`, `ellipse` or `path`, required |
| `area`, or `width`, `height` and `position` | a rect's or an ellipse's box, the second form centred on `position` |
| `points` | a path's vertices, at least two, each a point or `{vertex, inTangent, outTangent}` as a path shape's, always closed |
| `radius` | a rect mask's corner radius, a number or a list of four as a rect shape's, in the mask's space |
| `feather` | a theme length, the blur of the mask's edge, 0 by default |
| `invert` | `true` to cover everything outside the geometry |
| `mode` | `add` (default), `subtract` or `intersect` |

A mask is in the clip's own space: its media's pixels for a storyline or media clip, its text box for a title, its box for a shape given by `width` and `height`, and the space its geometry is written in for a shape given by `area` or `points`. It moves with the clip, and on a storyline clip it cuts the picture before a transition moves it. Its `shape`, `invert` and `mode` are static, and keyframes move its geometry, `radius` and `feather` ([Keyframes and eases](#keyframes-and-eases)).

`trackMatte` is `{clip, mode, invert}`: `clip` names by `id` a connected or sequence media clip, title or shape in the same document, `mode` is `alpha` or `luma`, and `invert` defaults to `false`. The named clip is not drawn, and the clip shows only where the matte's alpha or luma is.

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080], "background": "#101418" },
  "theme": { "styles": { "big": { "size": 360, "weight": "bold" } } },
  "storyline": [ { "kind": "solid", "color": "#101418", "duration": 4 } ],
  "clips": [
    { "id": "word", "kind": "title", "text": "BAKE", "style": "big", "placement": "center" },
    { "kind": "media", "media": "/path/to/broll.mov", "trackMatte": { "clip": "word", "mode": "alpha" } },
    { "kind": "media", "media": "/path/to/logo.png", "width": 200, "position": [1700, 900],
      "mask": { "shape": "ellipse", "width": 400, "height": 400, "position": [256, 256] }, "blend": "screen" }
  ]
}
```

The B-roll plays inside the letters of the word, and the logo, cut to a circle in its own 512 pixel picture, is screened over the corner. [FRAMES-11](spec/FRAMES-11/SPEC.md)

### Parenting

`"parent": "<id>"` makes a connected or sequence clip follow another clip with a picture in the same document, as parenting does in After Effects. The child's coordinates are in its parent's space: a storyline or media clip's media pixels, a title's text box, a box shape's box, or the space a shape's geometry is written in. A child's points follow its parent whole, so a rect given by `area` turns and zooms with the picture it was drawn on. A clip with a box of its own keeps its size, and lengths a clip draws with (strokes, text sizes, feather) do not grow with a parent's scale. A parented clip with a box of its own needs `position`, since a `placement` names the frame. A parent's opacity, mask and window do not reach its children; a group that should fade or wipe together is a compound clip. [FRAMES-10](spec/FRAMES-10/SPEC.md)

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080] },
  "theme": {
    "colors": { "accent": "#F2B33D" },
    "styles": { "note": { "size": 44, "weight": "bold", "color": "accent" } },
    "shapes": { "outline": { "stroke": { "width": 6 }, "radius": 12, "outset": 10 } }
  },
  "storyline": [
    { "id": "menu", "kind": "media", "media": "/path/to/board.png", "duration": 4,
      "connected": [
        { "parent": "menu", "kind": "rect", "area": [0, 0, 1600, 1000], "fill": "#000000A0",
          "mask": { "shape": "rect", "area": [212, 548, 486, 64], "invert": true, "feather": 4 } },
        { "id": "box", "parent": "menu", "kind": "rect", "area": [212, 548, 486, 64], "style": "outline",
          "keyframes": [ { "at": 0.5, "trim": [0, 0], "ease": "ease-out" }, { "at": 1.2, "trim": [0, 1] } ] },
        { "at": [1.2, 4], "parent": "box", "kind": "title", "text": "New this week", "style": "note",
          "anchor": "left", "position": { "area": { "clip": "box", "padding": 28 }, "point": "right" },
          "animation": "frames/fade" } ] }
  ]
}
```

The board is fitted to the 1920 by 1080 frame, and every clip on it is written in the board's own pixels. A dark rect covers the board except the line `Cinnamon bun 3.80`, at the rectangle `frames ocr /path/to/board.png` reports for it. An outline traces itself around that line with `trim` keyframes, and a note fades in 28 to the right of the outline's box, its parent.

### Blend modes and adjustment clips

`blend` takes the W3C compositing modes: `normal` (default), `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`, and the non-separable `hue`, `saturation`, `color`, `luminosity`, and `add` (Linear Dodge). Light leaks and film burns come in as media with `screen`, `plus-lighter` or `add`. `add` adds light without bound, so it keeps an HDR highlight under a leak, which `screen` darkens and `plus-lighter` clips at 1, and a wide gamut leak's colour ([Colour](#colour)).

An adjustment clip applies a filter choice (`adjust`) to everything below it in its frame, as an adjustment layer: over the whole frame, or inside its `mask`. Its `opacity` mixes the filtered picture with what is below. Inside a compound clip it reaches only that compound clip's clips. [FRAMES-11](spec/FRAMES-11/SPEC.md), [FRAMES-15](spec/FRAMES-15/SPEC.md)

### Motion blur

A clip with `"motionBlur": true` shows the motion frames gives it during each frame's exposure, as After Effects' Motion Blur switch does: its keyframes, animation, the transitions it brings in, and the motion it gives the clips that follow it. Every clip with a picture takes it, storyline clips, titles, shapes, media clips and adjustment clips. The sequence's `format.motionBlur` is the shutter of every frame:

| Key | Value | Default |
| --- | --- | --- |
| `shutterAngle` | how long the shutter is open, in degrees of a frame, above 0 and at most 720 | 180 |
| `shutterPhase` | when it opens, in degrees before the frame's instant, from minus the angle to 0, so the exposure always holds the instant | 0, so the shutter opens at the frame's start and the exposure stays inside the frame |
| `samplesPerFrame` | how many pictures of the frame its exposure is the mean of, a whole number from 2 to 256 | 16 |

- The frame is the mean of `samplesPerFrame` pictures of the whole frame, each at one of the midpoints of equal parts of the exposure, the same for every clip. In each, the values of clips with motion blur are read at that instant and every other value at the frame's instant. Which clips show, the media frame of footage and tracked motion are those of the frame's instant in every picture, so a cut stays a cut, footage is never exposed twice and motion inside footage is not blurred.
- A value is moved by the switch of the clip it belongs to, wherever it is read: a bar without the switch, parented to a title with it or placed by the title's box, moves with the title, and the two blur as one picture. A transition belongs to the clip it brings in, so that clip's switch blurs both sides of a push, which meet at the seam on every frame, and the outgoing clip's switch does not blur it.
- A jump stays a jump: where a keyframe or an animation jumps inside the exposure, at a `step` end or between two keys at one `t`, every picture shows it on the side of the frame's instant, and the other terms of the value keep moving. A loop seam is not a jump, so a loop that meets itself blurs through it. A clip that ends inside the exposure stands at its last pose after it ends.
- A compound clip's own shutter applies only when it is rendered alone. Inside another sequence its time is carried to each instant through its speed and `timeRemap`, whatever its own switch, so a held frame shows no blur, its clips with the switch blur by their own motion, and a clip moving inside it against its motion stays sharp when both have the switch.
- A fast move shows steps where the samples are far apart: raise `samplesPerFrame`. Each sample is a full drawing of the frame, so a frame with motion blur costs up to that many times as much to render.

```json
{ "at": [1, 3], "kind": "title", "text": "Fast", "style": "title", "motionBlur": true,
  "keyframes": [ { "at": 1, "position": [-400, 540], "ease": "ease-out" }, { "at": 1.5, "position": [960, 540] } ] }
```

[FRAMES-29](spec/FRAMES-29/SPEC.md)

### Colour

frames holds every colour from the decoder to the encoder as a working value: red, green and blue on the sRGB primaries, each any real number, with 1 as reference white. A value above 1 is light brighter than reference white (HDR) or a colour outside the sRGB gamut, and one below 0 is outside the gamut. One working space serves every sequence, so every formula gives the same result whatever the output, and nothing clips a value until the output.

`format.colorSpace` is the colour space the sequence is output in:

| `colorSpace` | Primaries, transfer | Range |
| --- | --- | --- |
| `srgb` (default) | BT.709, sRGB | SDR |
| `display-p3` | P3 D65, sRGB | SDR |
| `rec2020` | BT.2020, BT.1886 | SDR |
| `rec709` | BT.709, BT.1886 | SDR |
| `rec2100-pq` | BT.2020, PQ | HDR, its peak `format.peak` (400 to 10000 cd/m², 1000 by default) |
| `rec2100-hlg` | BT.2020, HLG | HDR, its peak 1000 cd/m² |

- The master `.mov` and a `render` `.png` (16 bits per channel) are written and tagged in that space, with each channel clipped to its gamut and peak and no gamut mapping. A delivery file, from `--deliver` or `render` to an `.mp4`, is H.264 for an SDR space and HEVC Main 10 for an HDR one, since H.264 holds 8 bits. On an HDR output reference white is 203 cd/m², as BT.2408 gives it, so a white title stays well below the peak.
- `format.compositing` is the form the sequence composites in. Under `encoded` (the default) source-over, blends such as `multiply`, `screen` and `add`, dissolves, blurs and `mix` weigh code values, as browsers and After Effects do by default. Under `linear` they mix light, as Premiere Pro's Composite in Linear Color does, so a dissolve or a blur of HDR and wide gamut pictures mixes their light. A formula written for one form keeps it under either: `contrast`, `levels`, `overlay`, `soft-light` and luma read encoded values, `exposure` and `temperature` read light, and a `lut` reads its `space`. Keyframed colours and gradient stops interpolate on encoded values.
- A picture is read in the colour space its tags name, an untagged one as `srgb`. A `colorSpace` written where the media is named (on a media clip, or on a transition's cover or matte) replaces what the file says, as Premiere Pro's Override Media Color Space does, and every place that names the same file names the same space. A picture tagged outside the table is converted by fixed formulas, and one with a LUT-based ICC profile stops, naming `transcode`. Log footage is not a colour space: a `lut` filter takes it to a display space.
- HDR media (PQ or HLG) of a clip with `toneMap` true, the default, are tone mapped by the BT.2390 EETF to the sequence's peak where their own peak is above it, so an HDR shot in an SDR sequence comes in with its highlights fitted under white. With `toneMap` false they come in as their display light, values above 1 that filters see, to be graded into the sequence by hand.
- `color()` writes a colour beyond `#RRGGBB`: `color(display-p3 1 0 0)` is the red of P3 and `color(srgb-linear 2 2 2)` twice reference white. The resolved document writes every colour as `color(srgb r g b / a)`.
- `still`, `sheet` and `extract` write SDR previews: PNGs in sRGB at 8 bits per channel, with HDR tone mapped to 203 cd/m² and wide gamut clipped, the same pictures OCR and the tracker read. They are not the master: check the master of a `display-p3`, `rec2020` or HDR sequence with `render --at`, which writes the frame in its colour space.
- `transcode` writes in the source's colour space where a sequence can be output in it, and in `srgb` otherwise. `--color-space` names another, and an HDR source is tone mapped to the output space's peak where its own is above it. `--codec h264` and a `.jpg` in an HDR space stop.
- `probe` reports the colour space a picture is read in (none when it is tagged outside the table), its H.273 primaries, transfer and matrix, its bits per channel, whether it is HDR and the conversion that takes it to working values.

```json
{
  "kind": "sequence",
  "format": { "size": [3840, 2160], "fps": 25, "colorSpace": "rec2100-pq", "compositing": "linear" },
  "storyline": [
    { "kind": "media", "media": "/path/to/drone-hlg.mov", "in": 0, "out": 6 },
    { "kind": "media", "media": "/path/to/phone.mov", "colorSpace": "rec709", "in": 0, "out": 4, "transition": "frames/fade" }
  ],
  "clips": [
    { "at": [1, 5], "kind": "title", "text": "Above the bay", "style": "title", "placement": "bottom" },
    { "at": [5, 7], "kind": "media", "media": "/path/to/light-leak.mov", "blend": "add", "lane": 2 }
  ]
}
```

The drone shot is HLG, whose peak of 1000 cd/m² is the sequence's, so it comes in as its display light without tone mapping. The phone video is untagged and was made for a BT.1886 display, so its clip names `rec709`. The fade mixes light, and the leak adds its light above the highlights under it. The master is ProRes in PQ, `--deliver` writes HEVC Main 10, `still` shows an SDR preview and `render --at` the PQ frame. [FRAMES-26](spec/FRAMES-26/SPEC.md)

### Lanes and stacking

From the bottom, a frame is the background, the clips on negative lanes, the storyline, then the clips on positive lanes, a higher lane above a lower one. During a transition the incoming storyline picture is above the outgoing one. Within a lane, clips stack in document order: each storyline clip's connected clips in storyline order, then the sequence clips. A parent moves a clip and does not change its lane or order, and a clip used as a track matte takes no place in the stack. [FRAMES-9](spec/FRAMES-9/SPEC.md)

### Tracking

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is track data, `{"time": t, "frames": [...]}`: each frame `{time, quad}` gives a media time of the tracked media and the target's four corners on that frame in its media pixels, top left, top right, bottom right and bottom left, in time order, and `time` names the frame the clip's values are written on, whose quad is the target. So a trim of the clip's head moves nothing. What `track` follows is how the clip is placed: a clip placed by points in its parent's space (an area, points, a corner pin) follows its parent's media, and the motion carries those points as a moving parent would; a clip placed by its box follows inside its own media, and the motion moves its crop and mask; a title, still or compound clip, with no frames of its own, follows its parent's media by its position. A clip with a corner pin follows its parent's media, and its crop and mask ride its plane. Only a video or an image sequence has frames to follow, and `timeline --json` gives each clip's tracked media and the first and last frame of it the clip shows as `tracked`. A similarity motion (a move, a uniform scale and a rotation) is fitted to each frame's quad, and evaluation computes the homography the quads give. A clip with a corner pin rides the homography, so its corners stay on a screen's corners. The clip is visible only over the frames the data names.

`frames track` follows a target in a video or an image sequence and prints its track data. The tracker is picked for each run by `--tracker`: `point` (the default) reports a move, scale and rotation of the target, and `planar` follows a quadrilateral in perspective, which a tracked corner pin needs. Resolve calls no tracker, so track data from any tracker, run by frames or outside it, drives a clip the same way. A `track` written as a request, `{"tool": "frames/track-motion", "target": "area"}` for the clip's own area or an area `[x, y, w, h]` as its target, is filled with track data by the tool `frames/track-motion` ([Tools](#tools)).

```json
{
  "kind": "sequence",
  "storyline": [
    { "id": "phone", "kind": "media", "media": "/path/to/phone.mov", "in": 0, "out": 3,
      "connected": [
        { "id": "screen", "parent": "phone", "kind": "media", "media": "/path/to/app.png",
          "cornerPin": [ [412, 204], [731, 252], [702, 518], [379, 461] ],
          "track": { "time": 0,
                     "frames": [ { "time": 0, "quad": [ [412, 204], [731, 252], [702, 518], [379, 461] ] },
                                 { "time": 0.033333, "quad": [ [414, 203], [733, 252], [704, 519], [381, 461] ] } ] } } ] }
  ]
}
```

A picture of an app is pinned to a phone's screen, its corner pin written on the shot's first frame in the shot's media pixels, and the track data of a planar tracker keeps it there. The data is cut short here to two frames, and the clip is visible only over the frames the data names. `frames --tracker planar track /path/to/phone.mov --at 0 --quad '[[412, 204], [731, 252], [702, 518], [379, 461]]' --to 3` prints the whole of it. [FRAMES-12](spec/FRAMES-12/SPEC.md), [FRAMES-21](spec/FRAMES-21/SPEC.md), [FRAMES-27](spec/FRAMES-27/SPEC.md)

### Sound

A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept. `pan` runs from -1 (left) to 1 (right): a mono sound is panned with equal power, and a stereo sound is balanced. `fadeIn` and `fadeOut` ramp the volume over the range the sound plays: a storyline clip's drawn range, or another clip's visible window. `volume` and `pan` are keyframable, for ducking and longer fades. During a storyline transition the two clips' sounds crossfade by the preset's curve. An audio clip has no lane. A sequence with no sound mixes to silence, and its file still carries a silent track as long as its frames.

- `split: {"before": b, "after": a}` on a storyline clip or a visual media clip with sound is a J or an L cut: its sound starts `b` seconds before its picture and ends `a` seconds after, measured from a storyline clip's edit points, and plays its media beyond `in` and `out`. The media must hold sound over that range, and a split that reaches past it or outside the sequence stops. `timeline` prints the range each clip's sound plays over.
- `"picture": false` on a connected or sequence clip of a video, a compound clip or a template instance takes only its sound, as Final Cut Pro detaches a clip's audio, and the clip is then an audio clip. On a storyline clip, a still, an image sequence or an audio file it stops.

```json
{
  "kind": "sequence",
  "storyline": [
    { "kind": "media", "media": "/path/to/question.mov", "in": 0, "out": 2.5 },
    { "kind": "media", "media": "/path/to/answer.mov", "in": 1, "out": 3.5, "split": { "before": 1 } }
  ],
  "clips": [ { "at": [0, 5], "kind": "media", "media": "/path/to/music-video.mov", "picture": false, "volume": 0.3, "loop": true } ]
}
```

The answer is heard a second before it is seen, over the end of the question, and the music video's sound plays under both with none of its picture. [FRAMES-13](spec/FRAMES-13/SPEC.md)

### Audio filters

`audioFilter` processes a sound with operations from a fixed table, as `filter` does a picture. It is taken by a clip whose media has sound (a storyline or media clip of a video with sound, a compound clip or a template instance, and an audio clip) and by the sequence. It is an audio preset (`<pack>/<name>` for `presets/audio/<name>.json`, or an absolute path), `{preset, args, mix}` with at least one of `args` and `mix`, an op written in place, or a list of those, the first applied first. An entry written as an object takes `mix`, the dry sound and its result mixed from 0 to 1. frames ships no audio preset.

| op | Parameters |
| --- | --- |
| `eq` | `bands`, each `{type, frequency, gain, q}`: `type` is `lowShelf`, `highShelf`, `peak`, `lowPass` or `highPass`, `gain` (dB) only for the shelves and `peak`, and `q` 0.7071 by default |
| `compressor` | `threshold` (dBFS), `ratio`, `knee`, `attack`, `release`, `makeup` |
| `gate` | `threshold` (dBFS), `range`, `attack`, `hold`, `release` |
| `limiter` | `gain` (dB), `ceiling` (dBTP, -1 by default), `lookahead`, `release`: holds the true peak at `ceiling` |
| `convolve` | `file`, an impulse response named as media is, and `gain` (dB): a room, a plate, a speaker or a telephone |

- A clip's chain acts on its sound after its `speed` and before its volume, fades, crossfades and pan, so a fade fades the processed sound.
- The sum of a sequence's sounds is its bus, and the sequence's `audioFilter` runs over it wherever the sequence plays, inside another sequence included. The outermost sequence's chain is the master bus, and a `limiter` last in it, at `mix` 1, holds the whole mix under its `ceiling`. `loudness` measures the mix after it.
- `audioFilter` is keyframable: a clip's keyframes on its clip time, and the sequence's in its own `keyframes` on sequence time. They write the numbers that move (a band's `frequency`, `gain` and `q`, an op's numbers other than a limiter's `lookahead`, an entry's `mix`), and a list in a keyframe is as long as the chain. A band's `frequency` and `q` move in log space.
- A `convolve` reverb ends with the range its clip's sound plays over, its tail cut there. An audio clip whose `at` window is longer than its sound plays silence after it, and the tail rings into that silence to the window's end. A tail that must ring past a clip goes on a longer bus: a compound clip that holds the clip and runs longer, or the sequence's `audioFilter`.

```json
{
  "kind": "sequence",
  "audioFilter": [ { "op": "eq", "bands": [ { "type": "lowPass", "frequency": 20000 } ] }, { "op": "limiter", "gain": 3, "ceiling": -1 } ],
  "keyframes": [ { "at": 0, "audioFilter": [ { "bands": [ { "frequency": 400 } ] }, {} ], "ease": "ease-in" },
                 { "at": 2, "audioFilter": [ { "bands": [ { "frequency": null } ] }, {} ] } ],
  "storyline": [
    { "kind": "media", "media": "/path/to/interview.mov", "in": 0, "out": 3.5,
      "audioFilter": [ { "op": "eq", "bands": [ { "type": "highPass", "frequency": 80 }, { "type": "peak", "frequency": 3000, "gain": 3, "q": 1 } ] },
                       { "op": "compressor", "threshold": -18, "ratio": 3, "knee": 6 },
                       { "op": "gate", "threshold": -50 } ] }
  ],
  "clips": [
    { "at": [0.5, 3.5], "kind": "media", "media": "/path/to/tick.wav", "audioFilter": { "op": "convolve", "file": "/path/to/hall.wav", "mix": 0.4 } }
  ]
}
```

The voice loses its rumble, gains presence, is evened out and gated between phrases. The tick is a short sound in a three second window, so the hall's reverb rings on after it. On the master bus the whole mix opens from a muffled 400 Hz to full over two seconds, and the limiter raises it by 3 dB under a ceiling of -1 dBTP. [FRAMES-13](spec/FRAMES-13/SPEC.md), [FRAMES-28](spec/FRAMES-28/SPEC.md)

### Stills and content fit

A still is a sequence rendered as one frame (`render -o out.png`, `still`). A still edit is usually one still storyline clip with clips connected to it: its `crop` crops, `format.size` resizes, a larger `format.size` with the clip's transform pads, `border` borders, and connected titles, shapes and adjustment clips draw on it.

`format.size` as `{"fit": "content", "margin": m}` measures the frame from what it holds, as a design tool's "fit to content". `margin` is `n`, `[v, h]` or `[t, r, b, l]` in whole pixels. A storyline picture is drawn at the pixel size of its crop, a clip sits where its `position` puts it (a box with neither a `position` nor a placement sits with its top left at the origin), and the frame is the bounding box of all of it plus the margin. A picture is measured by its box, so a border laid `outside` it and a shadow fall in the margin, while a shape is measured with its stroke as drawn. A clip placed by `placement`, its own or its text style's, is placed on that frame, margin included, as on any frame, with its style's `offset`. It and what is parented to it or takes its box through a clip area are not measured, since they depend on the frame. A content-fit sequence whose storyline has no picture stops.

```json
{
  "kind": "sequence",
  "format": { "size": { "fit": "content", "margin": [48, 64] }, "background": "#F4F1EA" },
  "storyline": [
    { "kind": "media", "media": "/path/to/board.png", "duration": 1, "crop": [0, 300, 1600, 660],
      "connected": [
        { "kind": "media", "media": "/path/to/logo.png", "width": 120, "anchor": "top-right", "position": [1560, 40] } ] }
  ]
}
```

The crop keeps the menu's items without its heading, 1600 by 660 pixels, the logo sits in its top right corner, and the margin makes the frame 1728 by 756. [FRAMES-6](spec/FRAMES-6/SPEC.md)

### Theme

A theme holds a look: sizes, colours, text styles, shape styles and default presets. `frames theme` prints the base theme, which is also the list of every group. A theme file or a document `theme` holds only the keys it changes, and an unknown key stops.

| Group | Holds |
| --- | --- |
| `baseWidth` | the frame width theme lengths are written for, 1920 |
| `font` | a list of font families in the order they are tried, for every text style without a `font` of its own |
| `colors` | named colours, an open map. `text` is the default text colour and `background` the default format background |
| `styles` | text styles by name, an open map. Character attributes: `font` (a list of families), `size` (required), `weight` (100 to 900, or a name from `thin` to `black`, `regular` and `bold` among them), `italic`, `tracking` (thousandths of an em), `kerning`, `features`, `baselineShift`, `color`, `stroke` (`{width, color}`), `highlight` (`{color, padding, radius}`, a box behind the run's glyphs on each line, its `radius` one length or four as a rect's), `underline` (`true` or `{width, offset, color}`), `textOrientation` (`mixed`, `upright`, `sideways`), `textCombineUpright` (`none`, `all`). Paragraph attributes: `lineHeight` (a theme length, the distance between baselines, not a multiple of the size, 1.25 × size by default), `background` (`{color, padding, radius}`, its `radius` one length or four), `placement`, `offset`, `writingMode` (`horizontal-tb`, `vertical-rl`, `vertical-lr`), `direction` (`auto`, `ltr`, `rtl`), `align` (`left`, `center`, `right`), `lines` |
| `shapes` | shape styles by name, an open map: `fill`, `stroke`, `radius` (one length or four), `outset`, `shadow` |
| `placement` | `padding`, the title safe margin |
| `border`, `shadow` | `{width, color, align}` and `{radius, offset, color}`, drawn by `border: true` and `shadow: true`. `align` is `inside` (the base theme's), `center` or `outside`, the side of the box's edge the border lies on |
| `defaults` | the presets a clip takes when it names none: `transition`, `filter`, and `animation` by clip kind (`title` keyed by text style, `shape`, `media`, `adjust`) |

```json
{
  "font": ["Avenir Next", "Apple SD Gothic Neo"],
  "colors": { "accent": "#F2B33D", "ink": "#101418" },
  "styles": {
    "subtitle": { "size": 44, "stroke": false, "background": { "color": "#000000B3", "padding": [6, 16], "radius": 6 } },
    "name": { "size": 56, "weight": "bold", "placement": "bottom-left", "offset": 160 },
    "role": { "size": 36, "color": "accent" }
  },
  "shapes": { "bar": { "fill": "accent", "radius": 4 } },
  "defaults": {
    "transition": { "preset": "frames/fade", "seconds": 0.5 },
    "animation": { "title": { "subtitle": "frames/fade", "name": "frames/slide-left" } }
  }
}
```

The base theme holds two text styles, `title` and `subtitle`, white text on black, no shape styles, and no default motion or filter. Themes merge key by key, weakest first: the base theme, `--theme`, the document's `theme`, then the keys on the clip. A compound clip starts from the theme of the document that holds it, and a template from the base theme. A style, shape style or colour that is named and not there stops. [FRAMES-22](spec/FRAMES-22/SPEC.md)

### Presets and choices

Transitions, animations, filters and stroke heads are presets: data files named `<pack>/<name>`, or by an absolute path. frames ships the pack `frames` (`frames/fade`, `frames/push-left`, `frames/rise`, `frames/warm`, ...). `frames presets` lists every installed preset with how it looks, and [document/PRESET.md](document/PRESET.md) shows how to write one.

| Choice | Takes |
| --- | --- |
| transition | a preset, `"cut"`, or `{preset, seconds, args}` with at least one of `seconds` and `args` |
| animation | a preset, `"none"`, `{preset, args}`, or `{entrance, exit}`, each side a preset, `"none"` or `{preset, args}`. On a title both object forms also take `by`, `stagger` and `order` ([Titles and runs](#titles-and-runs)) |
| filter | a preset, `{preset, args, mix}` with at least one of `args` and `mix`, an op written in place, a list of those applied in order, or `"none"` |

An object choice needs a key besides `preset`: `{"preset": "frames/warm"}` alone stops, since the name alone is that choice. An object without `preset` merges over the theme's default choice, so `{"by": "word"}` plays the default title animation by word, `{"order": "backward"}` plays a default that has `by` from its last unit, and `{"mix": 0.5}` is the default filter at half strength.

A preset may publish parameters, as an NLE effect publishes its controls. `args` gives them values: an unknown name or a value of the wrong type stops, and a missing one takes its default. `frames packs <pack>` and `frames presets <kind> <name>` print a preset's parameters.

A filter op is `{"op": ..., ...}` with the parameters of its row in [FRAMES-15](spec/FRAMES-15/SPEC.md): `exposure`, `contrast`, `saturation`, `temperature`, `hue`, `sepia`, `levels`, `lut`, `blur`, `sharpen`, `bloom`, `vignette`, `displace`, `pixelate` and `grain`. Written in a `filter` list it stands beside presets. `displace` moves each pixel by a displacement map, a still whose red moves it along x and green along y, 0.5 moving nothing, by up to `amount` (a theme length), the map stretched over the clip's box and moved by `offset`: a ripple, a heat haze or a refraction as a file. An entry written as an object takes `mix`, from 0 to 1, which mixes its result with its input.

```json
{ "transition": { "preset": "frames/dip-black", "seconds": 1 },
  "animation": { "entrance": "frames/pop", "exit": "frames/fade" },
  "filter": [ "frames/warm", { "op": "displace", "file": "/path/to/ripple.png", "amount": 12 }, { "preset": "frames/vignette", "mix": 0.5 } ] }
```

An animation preset holds an entrance, played at the start of a clip's window, a loop that repeats until the exit, and an exit, played at its end. `{entrance, exit}` takes each side from its own preset, with no loop. A filter applies at the clip's own size, before its transform. [FRAMES-14](spec/FRAMES-14/SPEC.md), [FRAMES-15](spec/FRAMES-15/SPEC.md), [FRAMES-16](spec/FRAMES-16/SPEC.md)

### Templates

A template is a sequence document with `params`, published parameters as in a motion graphics template. Its media and text are parameters, and `{"param": "<name>"}` stands for a value of that parameter's type.

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080] },
  "params": {
    "headline": { "type": "text", "default": "Fresh today", "description": "the line in the middle" },
    "color": { "type": "color", "default": "#2B2420", "description": "background" },
    "entrance": { "type": "choice", "options": ["frames/rise", "frames/pop", "frames/fade"], "default": "frames/rise",
                  "description": "how the headline comes in and goes" }
  },
  "storyline": [
    { "kind": "solid", "color": { "param": "color" }, "duration": 3,
      "connected": [ { "kind": "title", "text": { "param": "headline" }, "style": "title", "animation": { "param": "entrance" } } ] }
  ]
}
```

Saved as `templates/intro.json` in a pack `mine`, it is used as media with arguments, or rendered alone with `--args`:

```json
{
  "kind": "sequence",
  "storyline": [
    { "kind": "media", "media": { "template": "mine/intro", "args": { "headline": "Morning bake", "entrance": "frames/pop" } } },
    { "kind": "media", "media": "/path/to/interview.mov", "in": 2, "out": 6, "transition": "frames/dip-black" }
  ]
}
```

| Parameter key | Means |
| --- | --- |
| `type` | `number`, `color`, `choice`, `text`, `video` (a video or image sequence), `sequence`, `image` (a still, an image or a page of a PDF) or `audio` |
| `default` | a value of the type. A template parameter without one must be given |
| `description` | one line on what it changes, required |
| `options` | for a `choice`: the values it may take. Names (presets, styles, themes) are given only through a choice |

A template instance is `{template, args}`. A template starts from the base theme and is closed: only its arguments change it. What a pack holds and how to make one: [document/PACK.md](document/PACK.md). [FRAMES-17](spec/FRAMES-17/SPEC.md)

### Machine output

With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name, set to the version of frames that printed it: `{"probe": "0.1.0", "kind": "video", ...}`. That output is the contract tools build on. The text output is for people.

| Command | Object |
| --- | --- |
| `probe` | `{probe, kind, size, duration, fps, alpha, colorSpace, audio, pages}`, `colorSpace` as `{name, primaries, transfer, matrix, bitDepth, hdr, conversion}` or `null` for sound, `conversion` how the decoder takes the picture to working values by its tags (`none`, `space`, `transfer`, `pq`, `hlg` or `profile`) or `null` for a picture only the platform's colour management reads, `audio` as `{channels, sampleRate}` or `null`, `pages` the page count of a PDF or `null`, and for a page `size` in points, which may be fractions, and `bitDepth` `null` |
| `render` | the report `--report` writes, `{render, frames, seconds, cpuSeconds, fps, cores, peakMemory, machine, roles, stages, readAhead, waiting, other, media, files}`: `machine` as `{chip, cores, os}`, `roles` the implementation of each role, `stages` the seconds of `resolve`, `check`, `evaluate`, `mix`, `decode`, `workingConversion`, `draw`, `outputConversion` and `encode`, `readAhead` as `{decode, workingConversion}` the part of those two the decoder spent reading a video's next frame ahead beside the render, `waiting` as `{encoder, decoder}` the render's time in the encoder and waiting on that reading ahead, and `other` the rest of `seconds`, each medium `{path, page, colorSpace, conversion, pixelFormat, framesRead, framesDecoded, reopened}` and each file `{path, codec, hardware}` |
| `progress` | one line of `render --progress json` on standard error, `{progress, frame, frames, seconds}` |
| `loudness` | `{loudness, integrated, range, momentaryMax, shortTermMax, truePeak, samplePeak}`, in LUFS, LU, dBTP and dBFS, each rounded to the nearest hundredth and `null` where the meter gives none |
| `ocr` | `{ocr, size, languages, frames}`, each frame `{time, lines}` and each line `{text, rect}` |
| `track` | `{track, time, frames}`, each frame `{time, quad}`: the track data a clip's `track` takes, after the version |
| `timeline` | `{timeline, duration, storyline, clips}`, and with `--at` `time`. Every entry has `place, id, kind, media, page, fps, instant, clock, space, ownSpace`: `media` the pinned path of its file (an image sequence's directory) or `null`, `page` the page of a PDF or `null`, `fps` an image sequence's rate or `null`, `instant` the sequence time its values without keyframes take effect at, `clock` as `{clip, origin, speed}`, a time c it writes lying at `origin + c / speed`, and `space` and `ownSpace` the pixels its `position`, `area`, `points` and `cornerPin`, and its `crop` and `mask`, are written in, each `{kind, clip}` with kind `output`, `media` or `box`. A storyline entry also has `edit, drawn, clip, sound, speed, timeRemap, transition`, and a clips entry `visible, sound, lane, storyline, parent, animation`. With `--at` a storyline entry adds `clipTime` and every entry `mediaTime`. A compound clip or template instance adds `nested` |
| `evaluate` | `{evaluate, time, size, items, texts}`, `items` bottom first, each `{place, id, kind, item, bounds, opacity, transform, rect, cornerPins, characters}`, `transform` and `rect` where an item lies with the corner pins that carry it left out and `cornerPins` those corner pins, innermost first, each `{dest, cornerPin}` as four points, or `null` where none carries it, each character `{text, range, level, rect, baseline}`, `level` its bidirectional embedding level, and `texts` one entry for each title drawn, `{place, id, text, writingMode, direction, size, box, transform, cornerPins, lines, words}`, each line `{text, range, baseline, ascent, descent}` and each word `{text, range}`, ranges in Unicode scalars and places in the title's text box |
| `locate` | `{locate, hits}`, topmost first, each `{place, id, kind, item}`, and for a picture of a media file `{media, mediaTime, point, page}`, `page` the page of a PDF or `null` |

Times are rounded to the microsecond and positions, sizes, opacities and the numbers of a `transform` to the millionth. A new field is an addition within a version, and a removed or changed one a new major version ([FRAMES-18](spec/FRAMES-18/SPEC.md)). [FRAMES-23](spec/FRAMES-23/SPEC.md)

## More

- [document/GUIDE.md](document/GUIDE.md): the editing loop from material to delivery, writing a guide, a how-to or a tool, and editing a document without changing what it shows.
- [document/PRESET.md](document/PRESET.md): how to write a transition, an animation and a filter.
- [document/PACK.md](document/PACK.md): what a pack holds, how to make one, a form, a template and a tool.
- [document/howto/](document/howto/): techniques that belong to no form, such as [motion graphics](document/howto/motion-graphics.md), [effects](document/howto/effects.md) and [text on a path](document/howto/text-on-a-path.md).
- [packs/](packs/): packs kept beside frames, each a directory to copy into `$FRAMES_HOME/packs/`. A form's guide is its `guide.md`, such as [packs/demo/guide.md](packs/demo/guide.md).
- [document/ARCHITECTURE.md](document/ARCHITECTURE.md): how an implementation is laid out.
- [spec/](spec/README.md): the specification.
