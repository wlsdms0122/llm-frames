# frames

frames is a non-linear video editor driven by JSON documents and a command line, in the class of Final Cut Pro, Premiere Pro and After Effects compositions. A person, an agent or a program writes a sequence: a primary storyline of clips, clips connected to them, clips on the sequence's own clock, lanes, transitions, keyframes, filters, titles, shapes, masks, track mattes, parenting and time remapping. frames checks it, resolves it and renders a PNG, a master `.mov` or a delivery `.mp4`.

The same model edits a still and a video, since a still is a sequence rendered as one frame. Work goes as it does in any editor: write the document, look at it with `timeline`, `still` and `sheet`, change it, render, and use what was rendered as media in the next document.

frames holds the editing tools that any result uses. What a purpose needs (a lower third for a lecture, an annotation look, a vertical short with subtitles) is made with those tools by packs and extensions, installed beside frames: a pack carries themes, presets, LUTs, media and templates with published parameters, and an extension is a program that reads what frames reports and writes documents. frames composites media and does not generate it. Titles and shapes are built in, and motion graphics, illustrations and diagrams are made with other tools and come in as PNGs, PNG sequences or video with alpha.

A few rules hold everywhere:

- Every object has a fixed set of keys. A misspelt key stops with its place, so a typo never renders as no effect.
- A reference that matches more than one thing stops and lists what it matched.
- A value that still does its job is clamped (a transition longer than its clips, an `out` past the end of the media), and one that cannot stops (a clip that is never visible, a one-line title wider than its room).
- The resolved document is a lockfile: recognised text, tracks, text layout, themes, presets and templates are written into it as values, and the files it still needs are pinned by hash, so it makes the same result again.
- `render` writes a master at full quality. Delivery files are made from the same frames (`--deliver`) or from the master (`transcode`).

The specification in [`spec/`](spec/README.md) is the contract for every rule, and this page is the way in for someone who uses the tool. Each section below links to the spec that holds the full rules.

- [Build and install](#build-and-install)
- [A first edit](#a-first-edit)
- [Commands](#commands)
- [Document reference](#document-reference)
- [More](#more)

## Build and install

frames is a Swift package for macOS 14 or later. It renders with Apple's frameworks: AVFoundation, Core Graphics and Core Image, Vision and Core Text.

```sh
sh source/install.sh
frames --version
```

`install.sh` builds a release and installs `frames` and `Frames_FramesCommand.bundle` side by side in `/usr/local/bin`. The bundle holds `frames`, the pack of presets that ships with the tool, and the tool reads it from its own directory, so the two always go together. `--prefix <dir>` (or `FRAMES_PREFIX`) installs them elsewhere, for example `sh source/install.sh --prefix "$HOME/.local/bin"`. `open-package install` runs the same script.

Packs are installed by copying a pack's directory into `$FRAMES_HOME/packs/`. `FRAMES_HOME` defaults to `~/.config/frames`.

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
    { "id": "interview", "media": "/path/to/interview.mov", "in": 2, "out": 8,
      "connected": [
        { "at": [3, 7.5], "title": [ { "text": "Mina Park\n" }, { "text": "Head baker", "style": "role" } ],
          "style": "name", "animation": "frames/fade" },
        { "media": "/path/to/logo.png", "width": 160, "placement": "top-right", "opacity": 0.9 } ] },
    { "media": "/path/to/board.png", "duration": 4,
      "transition": { "preset": "frames/fade", "seconds": 0.8 },
      "keyframes": [ { "at": 0, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 4, "crop": { "scale": 1.3 } } ] },
    { "media": "/path/to/broll.mov", "in": 0, "out": 4, "transition": "frames/push-left" }
  ],
  "clips": [
    { "media": "/path/to/music.m4a", "volume": 0.4, "fadeOut": 1.5 }
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

[document/GUIDE.md](document/GUIDE.md) walks through the whole loop: picking a form, looking at the material, writing, checking, rendering and delivering.

## Commands

```
frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>]
       [--encoder <name>] [--shaper <name>] [--tracker <name>] [--ocr <name>] [--ocr-languages <tag>[,<tag>...]]
       <command> ...
```

Global options go before the command. `--theme` merges a theme under every document's own theme. The role and provider options pick an implementation by name: the decoder, the mixer and the encoder are `avfoundation`, the renderer `quartz`, the OCR provider `vision`, the shaper `coretext` and the tracker `point`, which are also the defaults. `--ocr-languages` gives the OCR provider the recognition languages as BCP 47 tags in order of preference (`ko-KR,en-US`); without it the provider detects the language of each picture, which reads text in one language, accents and Chinese and Japanese included. Give it for lines that mix scripts, such as Korean with English words and numbers, with the non-Latin language first: `vision` reads only what the listed languages cover, led by the first, so `ko-KR,en-US` reads `Total 12,000원` and `en-US,ko-KR` misses the Korean.

Paths are absolute. Where a command takes a document, it also takes a resolved document, a pack template (`<pack>/<name>`), or `-` for standard input. On success a command that writes a file prints one line with its path and size. On failure it prints `frames: <reason>` to standard error and exits with 1, and without a command it prints its usage to standard error and exits with 64. `frames --help` prints the usage and what each global option takes, and `frames <command> --help` prints what that command does and each of its arguments and options with its default, both to standard output with exit 0. A message names the place in the document, a path of keys and indexes with a clip's `id` after its index. With `opacity` misspelt on the logo of the first edit:

```
frames: storyline[0]#interview.connected[1] (image): unknown key "opactiy". Allowed: id, metadata, at, lane, parent, opacity, blend, mask, trackMatte, track, animation, keyframes, media, colorSpace, toneMap, placement, position, anchor, scale, rotation, crop, conform, filter, width, height, radius, border, shadow
```

### Making results

| Command | What it does |
| --- | --- |
| `render <document> -o <out.mov \| out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>]` | Renders the sequence. A `.mov` is the master of every frame: ProRes 422 HQ, or ProRes 4444 when the background is not opaque, with 24-bit PCM sound. A `.png` is the frame at `--at` (0 when left out), without a time label, at 16 bits per channel. Both are in the sequence's colour space ([Colour](#colour)). `--deliver` also writes an `.mp4` from the same frames: H.264 for an SDR colour space, HEVC Main 10 for an HDR one |
| `still <document> --at <t>[,<t>...] -o <out.png> [--args <args.json>]` | Draws frames at those sequence times side by side, each with its time label, without encoding a video, as an SDR sRGB preview. The cheap check while you edit |
| `resolve <document> -o <resolved.json> [--args <args.json>]` | Writes the resolved document: everything found, laid out and planned, with the files it uses pinned by hash |
| `transcode <in> -o <out> [--quality high\|medium\|low] [--max <px>] [--codec h264\|hevc] [--color-space <name>]` | Writes a delivery file from an image (`.jpg`, `.heic`, `.png`), audio (`.m4a`) or video (`.mp4`, `.mov`, `.m4v`, or `.m4a` for its sound) at a quality level. `--max` caps the longer side, and `--color-space` names the output's colour space ([Colour](#colour)) |

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
| `probe <media> [--json]` | the kind (`image`, `video`, `audio`, `imageSequence`), size, duration, frame rate, alpha, colour space and audio of a file or a directory of PNGs |
| `ocr <image \| video> [--at <t> \| --from <t> --to <t> --step <s>] [--languages <tag>[,<tag>...]] [--color-space <name>] [--json]` | the recognised lines, `[x, y, w, h]  text` in media pixels, in the order a text area's `nth` counts them |
| `track <video> --at <t> --area <area> [--to <t>] [--color-space <name>]` | the four corners of an area on every frame the tracker follows, and the motion fitted to them, as JSON |
| `extract <video \| document> <outdir> [--from <t>] [--to <t>] [--step 1]` | frames as full-size PNGs, `0000.png`, `0001.png`, ... |
| `sheet <video \| document> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]` | frames laid out in one picture, each at most 480 pixels on its longer side and labelled with its time |
| `timeline <document> [--args <args.json>] [--json]` | the plan of time without rendering: every storyline clip's edit, drawn and clip ranges, speed and transition, and every other clip's visible range, kind and animation, each by its place. `--json` also gives each clip's lane and parent |
| `evaluate <document> --at <t> [--args <args.json>]` | the display list at a time: what is drawn, by which clip, where, and where each title's lines, words and characters lie, as JSON |
| `locate <document> --at <t> --point <x,y> [--args <args.json>]` | the clips under a point of the output at a time, and for media the frame and pixel it shows |

Given a video, `extract` and `sheet` take the frames shown at media times. Given a document they draw it at sequence times as `still` does, so what you check is what `render` makes, as an SDR sRGB preview. `ocr` and `track` read the media in the colour space `--color-space` names, as a clip's `colorSpace` corrects it. `--area` takes an area as JSON text: `'[10, 20, 300, 40]'` or `'{"text": "Flat white"}'`.

```sh
frames probe /path/to/interview.mov
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
| `packs [<pack>]` | the packs, the one that ships with frames and the installed ones, or what one pack holds, with the parameters each preset and template publishes |
| `theme` | the base theme, which is also the list of every group a theme holds |
| `--version` | the version of frames |
| `--help`, `<command> --help` | the usage and the global options, or one command's help |

```sh
frames presets transition
frames presets transition frames/push-left
frames packs frames
frames theme
```

### Extensions

A command frames does not have runs a program from `PATH`: `frames autocut ...` runs `frames-autocut ...`, with the global options before the name and the arguments after it passed through unchanged, standard input and output included, so `frames autocut --help` is the extension's own help. An extension reads documents and machine output and writes a document to standard output, so extensions chain into `render -`:

```sh
frames autocut /path/to/raw.json | frames captions - | frames render - -o /path/to/out/cut.mov
```

An extension checks `frames --version` against the versions it is written for. [document/GUIDE.md](document/GUIDE.md) shows how to write one.

## Document reference

A document is a JSON object whose `kind` is `"sequence"`. Its keys are checked over the whole tree before any value is read, a value of the wrong type stops with its place, and a property written both as a static value and in a keyframe stops. The full key table is [FRAMES-7](spec/FRAMES-7/SPEC.md).

### Values

| Value | Written as | Spec |
| --- | --- | --- |
| time | seconds, as a number | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| colour | `#RRGGBB` or `#RRGGBBAA` (sRGB), `color(<space> r g b)` or `color(<space> r g b / a)` with `srgb`, `srgb-linear`, `display-p3` or `rec2020` and components of any real number, or the name of a theme colour (`accent`) | [FRAMES-26](spec/FRAMES-26/SPEC.md#colour-values) |
| a clip's coordinates (`position`, `area`, path points, mask geometry) | output pixels, origin top left, for an unparented clip, and the space its parent gives for a parented one | [FRAMES-1](spec/FRAMES-1/SPEC.md), [FRAMES-10](spec/FRAMES-10/SPEC.md) |
| `crop` | media pixels of the clip's own media | [FRAMES-9](spec/FRAMES-9/SPEC.md) |
| theme length (text size, stroke width, `radius`, `outset`, `feather`, border, shadow, filter radius) | points at the theme `baseWidth`, scaled by the frame's width over it | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| angle | degrees, clockwise positive | [FRAMES-1](spec/FRAMES-1/SPEC.md) |
| placement name | `top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right` | [FRAMES-1](spec/FRAMES-1/SPEC.md) |

### The sequence

| Object | Keys |
| --- | --- |
| sequence | `kind, format, theme, params, storyline, clips`. `kind` is required and is `"sequence"` |
| format | `size, fps, background, conform, colorSpace, peak, compositing` |
| content fit (a `size` written as an object) | `fit, margin` |

- `size` is `[w, h]`, `{"fit": "content", "margin": m}` ([Stills and content fit](#stills-and-content-fit)), or left out for the size of the first video clip on the storyline (of the first storyline clip when there is no video). Sizes round to even numbers.
- `fps` defaults to the first video's nominal rate rounded to 24, 25, 30, 50 or 60, and to 30 without video.
- `background` defaults to the theme `background` colour, black in the base theme. A background that is not opaque gives a master with alpha.
- `conform` is how a storyline crop fills the frame: `fit` (the default) shows the whole crop and leaves the rest transparent, `fill` fills the frame and cuts what overflows.
- `colorSpace` is the colour space the sequence is output in, `srgb` by default, `peak` the mastering peak of a `rec2100-pq` sequence, and `compositing` the form it composites in, `encoded` by default or `linear` ([Colour](#colour)).
- `theme` is a theme object, `<pack>/<name>` or an absolute path ([Theme](#theme)). `params` makes the document a template ([Templates](#templates)).

[FRAMES-6](spec/FRAMES-6/SPEC.md), [FRAMES-9](spec/FRAMES-9/SPEC.md), [FRAMES-26](spec/FRAMES-26/SPEC.md)

### Clips

- `storyline` is the primary storyline: its clips play one after another, and a transition plays across the edit point between two of them.
- `connected` clips belong to one storyline clip, live on its clip time and move when it moves, as connected clips do in an NLE.
- `clips` are sequence clips, on the sequence clock.

A clip is a media clip (`media`), a title (`title`), a shape (`shape`), an adjustment clip (`adjust`) or, on the storyline only, a solid (`solid`, a colour that fills the frame). Exactly one of these keys is present. A clip with a picture is every clip except an audio clip, a media clip whose media holds only sound. Which media row applies is decided once the media is probed.

| Clip | Keys |
| --- | --- |
| storyline clip, timed media (video, image sequence, compound) | `id, metadata, media, colorSpace, toneMap, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, keyframes, connected` |
| storyline clip, still (image) | `id, metadata, media, colorSpace, toneMap, duration, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, radius, border, shadow, keyframes, connected` |
| storyline clip, solid | `id, metadata, solid, duration, transition, connected` |
| every clip with a picture (connected and sequence) | `id, metadata, at, lane, parent, opacity, blend, mask, trackMatte, track, animation, keyframes` |
| visual media clip (video, image sequence, compound) | every clip with a picture's, `media, colorSpace, toneMap, in, out, speed, loop, volume, pan, fadeIn, fadeOut, placement, position, anchor, scale, rotation, crop, conform, filter, width, height, radius, border, shadow` |
| still media clip (image) | every clip with a picture's, `media, colorSpace, toneMap, placement, position, anchor, scale, rotation, crop, conform, filter, width, height, radius, border, shadow` |
| audio clip | `id, metadata, at, media, in, out, speed, loop, volume, pan, fadeIn, fadeOut, keyframes` |
| title clip | every clip with a picture's, `title, style, width, placement, position, anchor, scale, rotation` |
| shape clip | every clip with a picture's, `shape, style, area, width, height, placement, position, anchor, points, closed, radius, outset, fill, stroke, trim, shadow, scale, rotation` |
| adjustment clip | every clip with a picture's, `adjust` |

- `id` names a clip for `parent`, a track matte's `clip`, messages, machine output and the programs that change a document. It is unique within its document, and a duplicate stops.
- `metadata` is an object frames does not read: what a program that changes the document keeps on a clip, as an NLE keeps keywords and notes.
- `lane` is a non-zero integer, 1 by default. Negative lanes are below the storyline (lane 0) and positive lanes above it ([Lanes and stacking](#lanes-and-stacking)).
- A storyline clip is placed by `position` (default the centre of the frame) and takes no `placement` and no `parent`. Its box is the frame, which its conformed crop fills, so a storyline clip that writes no transform fills the frame. `radius`, `border` and `shadow` show where its transform leaves the box smaller than the frame.
- `colorSpace` on a media clip names the colour space its media are in, over what the file says, and `toneMap` (`true` by default) whether an HDR picture of it is tone mapped to the sequence's peak ([Colour](#colour)). A clip whose media is a compound clip or a template instance takes neither.
- `filter` and `transition` take preset choices ([Presets and choices](#presets-and-choices)). `"none"` turns off the theme's default filter for one clip, and `"cut"` its default transition. The first storyline clip takes no transition. To open from black, put a solid there and give the clip after it a transition.

[FRAMES-7](spec/FRAMES-7/SPEC.md), [FRAMES-9](spec/FRAMES-9/SPEC.md), [FRAMES-11](spec/FRAMES-11/SPEC.md)

### Media

| Form | Means |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` sequence document, which stands as if written there |
| `"<pack>/<name.ext>"` | a file in a pack's `media/` |
| `{"imageSequence": "/abs/dir", "fps": 30}` | every PNG in the directory, in natural order, played like a video (the directory may be `<pack>/<dir>`) |
| a sequence document object | a compound clip: the nested sequence plays as a video with sound, at its own frame size and with its own background |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance ([Templates](#templates)) |

Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha) and compound clips. That is how graphics made elsewhere come in. A compound clip is also how a group of clips acts as one: a picture-in-picture window with its own edit inside, a group that should leave together in a wipe, or an adjustment that should reach only some clips. [FRAMES-3](spec/FRAMES-3/SPEC.md), [FRAMES-9](spec/FRAMES-9/SPEC.md)

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
    { "media": "/path/to/interview.mov", "in": 0, "out": 4, "speed": 2 },
    { "media": "/path/to/broll.mov", "in": 0, "out": 6,
      "keyframes": [ { "at": 0, "timeRemap": 4 }, { "at": 2, "timeRemap": 6 },
                     { "at": 3.5, "timeRemap": 6, "ease": "ease-in" }, { "at": 6, "timeRemap": 9 } ] }
  ],
  "clips": [
    { "at": 2, "media": "/path/to/whoosh.wav", "pan": -0.5 },
    { "media": "/path/to/music.m4a", "fadeIn": 1,
      "keyframes": [ { "at": 1, "volume": 0.6, "ease": "ease-in-out" }, { "at": 1.5, "volume": 0.15 } ] }
  ]
}
```

The interview plays 4 seconds of media in 2. The B-roll shows its media seconds 4 to 6, holds that frame for a second and a half, and ramps on to second 9, over 6 seconds of sequence time. The whoosh plays on the left at the cut, and the music fades in and ducks under the B-roll. `timeline` prints each storyline clip's ranges and says `timeRemap` for the remapped one. [FRAMES-8](spec/FRAMES-8/SPEC.md)

### Keyframes and eases

Any keyframable property takes a static value or keyframes. A keyframe is `{at, ease}` with one or more properties of its clip. Each property joins only the keyframes that name it, holds its first value before them and its last after them, and an `ease` shapes the span leaving its keyframe, as in CSS and Lottie.

| Clip | Keyframable |
| --- | --- |
| storyline clip with media | `crop, position, scale, rotation, opacity, mask`, and `volume`, `pan` and `timeRemap` on timed media |
| media clip | `position, scale, rotation, opacity, crop, mask`, and `volume`, `pan` and `timeRemap` on timed media |
| audio clip | `volume, pan` |
| title clip | `position, scale, rotation, opacity, mask` |
| shape clip | `area, width, height, points, position, scale, rotation, opacity, trim, radius, mask` |
| adjustment clip | `opacity, mask` |

| ease | Shape |
| --- | --- |
| `linear` (default), `ease-in`, `ease-out`, `ease-in-out` | cubic curves |
| `back-out`, `bounce-out` | overshoots, bounces |
| `step` | holds, then jumps at the end |
| `[x1, y1, x2, y2]` | a cubic Bezier, as CSS `cubic-bezier()` |
| `{"spring": {"bounce": b}}` | a damped spring, b between -1 and 1: 0 settles without overshoot, higher swings past and back |

A `crop` keyframes its size in log space, so a zoom keeps one speed. `mask` in a keyframe is the clip's whole mask list at that instant. Keyframes that all lie before or all after the range a clip is visible in stop, since only one value would ever show. [FRAMES-4](spec/FRAMES-4/SPEC.md)

### Placement and transform

A clip with a box of its own (a title, a media clip, a rect or ellipse given by `width` and `height`) is placed by `placement` or by `position`, never both.

- `placement` is a placement name: the box sits there inside the frame, kept in from every edge by the theme `placement.padding`, the title safe margin. A text style's `offset` replaces that margin on the top or bottom edge.
- `position` is where the clip's anchor point goes, a point ([Areas and points](#areas-and-points)). `anchor` names that point of the clip's box, `center` by default, or for a placed clip the point its placement names, so a `bottom` subtitle grows upwards.
- `scale` and `rotation` act around the anchor point. `opacity` runs from 0 to 1, and `blend` composites the clip onto what is below ([Blend modes and adjustment clips](#blend-modes-and-adjustment-clips)).
- A media clip's `width` and `height` size its box. Given one, the other follows the aspect ratio of its first crop. Given both, the crop conforms to the box by `conform`. Given neither, the box is the picture fitted to the frame. `radius` rounds its corners, `border` (`true` or a colour) draws the theme border inside it, and `shadow` (`true`, `false` or `{radius, offset, color}`) drops the theme shadow below it.
- A media clip with video or an image sequence is picture in picture. One with alpha is how a motion graphic made elsewhere comes in.

[FRAMES-1](spec/FRAMES-1/SPEC.md), [FRAMES-11](spec/FRAMES-11/SPEC.md)

### Areas and points

An area is a rectangle in the coordinate space of the clip that writes it. A point is `[x, y]`, or `{"area": <area>, "point": <placement name>}` for that point of an area.

| Form | Means |
| --- | --- |
| `[x, y, w, h]` | that rectangle |
| `{"text": "Flat white", "nth": 0, "padding": 8}` | the recognised line that contains the text, compared without whitespace. More than one match stops and lists them, and `nth` picks one, counted from 0, top to bottom and left to right |
| `{"from": "Sourdough", "to": "Flat white", "fromNth": 0, "toNth": 0, "padding": 8}` | the rectangle around both lines and every line between them |

`padding` grows a found area on every side, in pixels of the picture searched, also past the picture's edges: an area keeps what is written or found, and the part of a crop beyond the media is transparent. A text form needs a picture to search, so it is allowed where the coordinates are a video's, an image's or an image sequence's media pixels: in a storyline or media clip's own `crop`, `mask` and `track`, and in the coordinates of a clip parented to such a clip. On video the text is searched in the frame at the instant the area takes effect: a keyframe's `at`, or the clip's start. `frames ocr` shows what can be pointed at, in the order `nth` counts. [FRAMES-2](spec/FRAMES-2/SPEC.md)

### Titles and runs

A title clip's `title` is a string or a list of runs `{text, style}`, and its `style` names a theme text style and is required.

- A run's `style` gives that run its character attributes (`size`, `weight`, `color`, `stroke`). The clip's style gives the paragraph its attributes (`placement`, `offset`, `align`, `lineHeight`, `lines`, `background`). A run without `style` is in the clip's style.
- Without `width` a title is point text: it does not wrap, its lines break only at `\n`, and its box is as wide as its widest line, so a background hugs the text.
- With `width` (output pixels) a title is paragraph text: it wraps at that width, its box is `width` wide, each line sits in it by the style's `align`, and a background fills it. Lines break by Unicode line breaking and keep words whole, so Korean breaks at spaces.
- Text that needs more lines than its style's `lines` stops, with `width` or without, so a `lines: 1` title wider than its `width` stops rather than shrink or cut.
- Fonts come from the theme `font` list, the first family the pack or the machine has. Text is laid out by resolve, so line breaks and boxes are the same on every renderer.

[FRAMES-5](spec/FRAMES-5/SPEC.md), [FRAMES-11](spec/FRAMES-11/SPEC.md)

### Shapes

`shape` is `rect`, `ellipse` or `path`.

| shape | Geometry | Keys of its own |
| --- | --- | --- |
| `rect` | `area`, or `width` and `height` placed as a box | `radius`, `outset` |
| `ellipse` | as a rect: the ellipse inscribed in its box | `outset` |
| `path` | `points`, at least two, joined by straight segments | `closed` |

| Key | Form |
| --- | --- |
| `fill` | a colour, or `false`. A path fills as if closed |
| `stroke` | `{color, width, join, cap, start, end}`, or `false`. `width` is required, `color` defaults to the theme `accent`, `join` is `miter`, `round` (default) or `bevel`, `cap` is `butt` (default), `round` or `square`, and `start` and `end` are `none` (default) or `arrow` |
| `trim` | `[a, b]` from 0 to 1: the part of the outline the stroke draws, as Trim Paths. Keyframed, it draws a stroke on |
| `radius`, `outset` | a rect's rounded corners, and how far a rect or an ellipse's outline grows beyond its box, both theme lengths |
| `shadow` | `true`, `false` or `{radius, offset, color}` |
| `style` | a shape style of the theme, which gives defaults for `fill`, `stroke`, `radius`, `outset` and `shadow`. A key on the clip replaces the style's whole |

A shape given by `area` or `points` sits where its geometry is written, and `position` moves its anchor point. A shape that has neither a fill nor a stroke after its style stops. To darken everything but a region, fill a rect over the picture and give it an inverted mask of the region. To point at something, draw a path with `"end": "arrow"`. Text beside a shape is a title parented to it. [FRAMES-11](spec/FRAMES-11/SPEC.md)

### Masks and track mattes

`mask` cuts any clip with a picture. It is a mask or a list of masks, combined in order as After Effects combines a layer's masks.

| Mask key | Form |
| --- | --- |
| `shape` | `rect`, `ellipse` or `path`, required |
| `area`, or `width`, `height` and `position` | a rect's or an ellipse's box, the second form centred on `position` |
| `points` | a path's points, at least three, always closed |
| `radius` | a rect mask's corner radius |
| `feather` | a theme length, the blur of the mask's edge |
| `invert` | `true` to cover everything outside the geometry |
| `mode` | `add` (default), `subtract` or `intersect` |

A mask is in the clip's own space: its media's pixels for a storyline or media clip, its text box for a title, its box for a shape given by `width` and `height`, and the space its geometry is written in for a shape given by `area` or `points`. It moves with the clip, and on a storyline clip it cuts the picture before a transition moves it.

`trackMatte` is `{clip, mode, invert}`: `clip` names by `id` a connected or sequence media clip, title or shape in the same document, `mode` is `alpha` or `luma`, and `invert` defaults to `false`. The named clip is not drawn, and the clip shows only where the matte's alpha or luma is.

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080], "background": "#101418" },
  "theme": { "styles": { "big": { "size": 360, "weight": "bold" } } },
  "storyline": [ { "solid": "#101418", "duration": 4 } ],
  "clips": [
    { "id": "word", "title": "BAKE", "style": "big", "placement": "center" },
    { "media": "/path/to/broll.mov", "trackMatte": { "clip": "word", "mode": "alpha" } },
    { "media": "/path/to/logo.png", "width": 200, "position": [1700, 900],
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
    { "id": "menu", "media": "/path/to/board.png", "duration": 4,
      "connected": [
        { "parent": "menu", "shape": "rect", "area": [0, 0, 1600, 1000], "fill": "#000000A0",
          "mask": { "shape": "rect", "area": { "text": "Cinnamon bun" }, "invert": true, "feather": 4 } },
        { "id": "box", "parent": "menu", "shape": "rect", "area": { "text": "Cinnamon bun" }, "style": "outline",
          "keyframes": [ { "at": 0.5, "trim": [0, 0], "ease": "ease-out" }, { "at": 1.2, "trim": [0, 1] } ] },
        { "at": [1.2, 4], "parent": "box", "title": "New this week", "style": "note",
          "anchor": "left", "position": { "area": { "text": "Cinnamon bun", "padding": 28 }, "point": "right" },
          "animation": "frames/fade" } ] }
  ]
}
```

The board is fitted to the 1920 by 1080 frame, and every clip on it is written in the board's own pixels. A dark rect covers the board except the line `Cinnamon bun 3.80`, found by its text. An outline traces itself around that line with `trim` keyframes, and a note fades in to its right.

### Blend modes and adjustment clips

`blend` takes the W3C compositing modes: `normal` (default), `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`, and the non-separable `hue`, `saturation`, `color`, `luminosity`, and `add` (Linear Dodge). Light leaks and film burns come in as media with `screen`, `plus-lighter` or `add`. `add` adds light without bound, so it keeps an HDR highlight under a leak, which `screen` darkens and `plus-lighter` clips at 1, and a wide gamut leak's colour ([Colour](#colour)).

An adjustment clip applies a filter choice (`adjust`) to everything below it in its frame, as an adjustment layer: over the whole frame, or inside its `mask`. Its `opacity` mixes the filtered picture with what is below. Inside a compound clip it reaches only that compound clip's clips. [FRAMES-11](spec/FRAMES-11/SPEC.md), [FRAMES-15](spec/FRAMES-15/SPEC.md)

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

- The master `.mov` and a `render` `.png` (16 bits per channel) are written and tagged in that space, with each channel clipped to its gamut and peak and no gamut mapping. `--deliver` writes H.264 for an SDR space and HEVC Main 10 for an HDR one, since H.264 holds 8 bits. On an HDR output reference white is 203 cd/m², as BT.2408 gives it, so a white title stays well below the peak.
- `format.compositing` is the form the sequence composites in. Under `encoded` (the default) source-over, blends such as `multiply`, `screen` and `add`, dissolves, blurs and `mix` weigh code values, as browsers and After Effects do by default. Under `linear` they mix light, as Premiere Pro's Composite in Linear Color does, so a dissolve or a blur of HDR and wide gamut pictures mixes their light. A formula written for one form keeps it under either: `contrast`, `levels`, `overlay`, `soft-light` and luma read encoded values, `exposure` and `temperature` read light, and a `lut` reads its `space`. Keyframed colours and gradient stops interpolate on encoded values.
- A picture is read in the colour space its tags name, an untagged one as `srgb`. A `colorSpace` written where the media is named (on a media clip, or on a transition's cover or matte) replaces what the file says, as Premiere Pro's Override Media Color Space does, and every place that names the same file names the same space. A picture tagged outside the table is converted by fixed formulas, and one with a LUT-based ICC profile stops, naming `transcode`. Log footage is not a colour space: a `lut` filter takes it to a display space.
- HDR media (PQ or HLG) of a clip with `toneMap` true, the default, are tone mapped by the BT.2390 EETF to the sequence's peak where their own peak is above it, so an HDR shot in an SDR sequence comes in with its highlights fitted under white. With `toneMap` false they come in as their display light, values above 1 that filters see, to be graded into the sequence by hand.
- `color()` writes a colour beyond `#RRGGBB`: `color(display-p3 1 0 0)` is the red of P3 and `color(srgb-linear 2 2 2)` twice reference white. The resolved document writes every colour as `color(srgb r g b / a)`.
- `still`, `sheet` and `extract` write SDR previews: PNGs in sRGB at 8 bits per channel, with HDR tone mapped to 203 cd/m² and wide gamut clipped, the same pictures OCR and the tracker read. They are not the master: check the master of a `display-p3`, `rec2020` or HDR sequence with `render --at`, which writes the frame in its colour space.
- `transcode` writes in the source's colour space where a sequence can be output in it, and in `srgb` otherwise. `--color-space` names another, and an HDR source is tone mapped to the output space's peak where its own is above it. `--codec h264` and a `.jpg` in an HDR space stop.
- `probe` reports the colour space a picture is read in (none when it is tagged outside the table), its H.273 primaries, transfer and matrix, its bits per channel and whether it is HDR.

```json
{
  "kind": "sequence",
  "format": { "size": [3840, 2160], "fps": 25, "colorSpace": "rec2100-pq", "compositing": "linear" },
  "storyline": [
    { "media": "/path/to/drone-hlg.mov", "in": 0, "out": 6 },
    { "media": "/path/to/phone.mov", "colorSpace": "rec709", "in": 0, "out": 4, "transition": "frames/fade" }
  ],
  "clips": [
    { "at": [1, 5], "title": "Above the bay", "style": "title", "placement": "bottom" },
    { "at": [5, 7], "media": "/path/to/light-leak.mov", "blend": "add", "lane": 2 }
  ]
}
```

The drone shot is HLG, whose peak of 1000 cd/m² is the sequence's, so it comes in as its display light without tone mapping. The phone video is untagged and was made for a BT.1886 display, so its clip names `rec709`. The fade mixes light, and the leak adds its light above the highlights under it. The master is ProRes in PQ, `--deliver` writes HEVC Main 10, `still` shows an SDR preview and `render --at` the PQ frame. [FRAMES-26](spec/FRAMES-26/SPEC.md)

### Lanes and stacking

From the bottom, a frame is the background, the clips on negative lanes, the storyline, then the clips on positive lanes, a higher lane above a lower one. During a transition the incoming storyline picture is above the outgoing one. Within a lane, clips stack in document order: each storyline clip's connected clips in storyline order, then the sequence clips. A parent moves a clip and does not change its lane or order, and a clip used as a track matte takes no place in the stack. [FRAMES-9](spec/FRAMES-9/SPEC.md)

### Tracking

`track` makes a clip follow something in a picture, as an NLE's tracker does. Its value is an area, or `true` for the clip's own `area`, `mask` or `crop`. A storyline or media clip of video or an image sequence follows its own media, and the motion moves its crop and mask. Any other clip follows its parent's media, and the motion carries it as a moving parent would. The tracker provider follows the target's four corners on each frame, and a similarity motion (a move, a uniform scale and a rotation) is fitted to them. `frames track` reports the same for a video. [FRAMES-12](spec/FRAMES-12/SPEC.md)

### Sound

A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept. `pan` runs from -1 (left) to 1 (right): a mono sound is panned with equal power, and a stereo sound is balanced. `fadeIn` and `fadeOut` ramp the volume over the range the sound plays: a storyline clip's drawn range, or another clip's visible window. `volume` and `pan` are keyframable, for ducking and longer fades. During a storyline transition the two clips' sounds crossfade by the preset's curve. An audio clip has no lane, and a sequence with no sound has no audio track. [FRAMES-13](spec/FRAMES-13/SPEC.md)

### Stills and content fit

A still is a sequence rendered as one frame (`render -o out.png`, `still`). A still edit is usually one still storyline clip with clips connected to it: its `crop` crops, `format.size` resizes, a larger `format.size` with the clip's transform pads, `border` borders, and connected titles, shapes and adjustment clips draw on it.

`format.size` as `{"fit": "content", "margin": m}` measures the frame from what it holds, as a design tool's "fit to content". `margin` is `n`, `[v, h]` or `[t, r, b, l]` in whole pixels. A storyline picture is drawn at the pixel size of its crop, clips sit where they are written with their top left at the origin by default, and the frame is the bounding box of everything plus the margin. A `placement` stops under content fit, since it depends on the frame.

```json
{
  "kind": "sequence",
  "format": { "size": { "fit": "content", "margin": [48, 64] }, "background": "#F4F1EA" },
  "storyline": [
    { "media": "/path/to/board.png", "duration": 1, "crop": [0, 300, 1600, 660],
      "connected": [
        { "media": "/path/to/logo.png", "width": 120, "anchor": "top-right", "position": [1560, 40] } ] }
  ]
}
```

The crop keeps the menu's items without its heading, 1600 by 660 pixels, the logo sits in its top right corner, and the margin makes the frame 1728 by 756. [FRAMES-6](spec/FRAMES-6/SPEC.md)

### Theme

A theme holds a look: sizes, colours, text styles, shape styles and default presets. `frames theme` prints the base theme, which is also the list of every group. A theme file or a document `theme` holds only the keys it changes, and an unknown key stops.

| Group | Holds |
| --- | --- |
| `baseWidth` | the frame width theme lengths are written for, 1920 |
| `font` | font families in the order they are tried |
| `colors` | named colours, an open map. `text` is the default text colour and `background` the default format background |
| `styles` | text styles by name, an open map: `size` (required), `weight` (`regular` or `bold`), `color`, `stroke` (`{width, color}`), `lineHeight`, `background` (`{color, padding, radius}`), `placement`, `offset`, `align` (`left`, `center`, `right`), `lines` |
| `shapes` | shape styles by name, an open map: `fill`, `stroke`, `radius`, `outset`, `shadow` |
| `placement` | `padding`, the title safe margin |
| `border`, `shadow` | `{width, color}` and `{radius, offset, color}`, drawn by `border: true` and `shadow: true` |
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

Transitions, animations and filters are presets: data files named `<pack>/<name>`, or by an absolute path. frames ships the pack `frames` (`frames/fade`, `frames/push-left`, `frames/rise`, `frames/warm`, ...). `frames presets` lists every installed preset with how it looks, and [document/PRESET.md](document/PRESET.md) shows how to write one.

| Choice | Takes |
| --- | --- |
| transition | a preset, `"cut"`, or `{preset, seconds, args}` with `seconds` and `args` optional |
| animation | a preset, `"none"`, `{preset, args}`, or `{entrance, exit}`, each side a preset, `"none"` or `{preset, args}` |
| filter | a preset, `{preset, args}`, a list of those applied in order, or `"none"` |

A preset may publish parameters, as an NLE effect publishes its controls. `args` gives them values: an unknown name or a value of the wrong type stops, and a missing one takes its default. `frames packs <pack>` and `frames presets <kind> <name>` print a preset's parameters.

```json
{ "transition": { "preset": "frames/dip-black", "seconds": 1 },
  "animation": { "entrance": "frames/pop", "exit": "frames/fade" },
  "filter": [ "frames/warm", "frames/vignette" ] }
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
    { "solid": { "param": "color" }, "duration": 3,
      "connected": [ { "title": { "param": "headline" }, "style": "title", "animation": { "param": "entrance" } } ] }
  ]
}
```

Saved as `templates/intro.json` in a pack `mine`, it is used as media with arguments, or rendered alone with `--args`:

```json
{
  "kind": "sequence",
  "storyline": [
    { "media": { "template": "mine/intro", "args": { "headline": "Morning bake", "entrance": "frames/pop" } } },
    { "media": "/path/to/interview.mov", "in": 2, "out": 6, "transition": "frames/dip-black" }
  ]
}
```

| Parameter key | Means |
| --- | --- |
| `type` | `number`, `color`, `choice`, `text`, `video` (a video or image sequence), `sequence`, `image` or `audio` |
| `default` | a value of the type. A template parameter without one must be given |
| `description` | one line on what it changes, required |
| `options` | for a `choice`: the values it may take. Names (presets, styles, themes) are given only through a choice |

A template instance is `{template, args}`. A template starts from the base theme and is closed: only its arguments change it. What a pack holds and how to make one: [document/PACK.md](document/PACK.md). [FRAMES-17](spec/FRAMES-17/SPEC.md)

### Machine output

With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name, set to the version of frames that printed it: `{"probe": "1.0.0", "kind": "video", ...}`. That output is the contract extensions build on. The text output is for people.

| Command | Object |
| --- | --- |
| `probe` | `{probe, kind, size, duration, fps, alpha, colorSpace, audio}`, `colorSpace` as `{name, primaries, transfer, matrix, bitDepth, hdr}` or `null` for sound, `audio` as `{channels, sampleRate}` or `null` |
| `ocr` | `{ocr, size, languages, frames}`, each frame `{time, lines}` and each line `{text, rect}` |
| `track` | `{track, time, target, frames}`, each frame `{time, quad, motion}` |
| `timeline` | `{timeline, duration, storyline, clips}`. A storyline entry has `place, id, media, edit, drawn, clip, speed, timeRemap, transition`, and a clips entry `place, id, kind, visible, lane, storyline, parent, animation`. A compound clip or template instance adds `nested` |
| `evaluate` | `{evaluate, time, size, items, texts}`, `items` bottom first, each `{place, id, kind, item, bounds, opacity, transform, rect, characters}`, each character `{text, range, rect, baseline}`, and `texts` one entry for each title drawn, `{place, id, text, size, box, transform, lines, words}`, each line `{text, range, baseline, ascent, descent}` and each word `{text, range}`, ranges in Unicode scalars and places in the title's text box |
| `locate` | `{locate, hits}`, topmost first, each `{place, id, kind, item}`, and for a picture of a media file `{media, mediaTime, point}` |

Times are rounded to the microsecond and positions, sizes, opacities and the numbers of a `transform` to the millionth. A new field is an addition within a version, and a removed or changed one a new major version ([FRAMES-18](spec/FRAMES-18/SPEC.md)). [FRAMES-23](spec/FRAMES-23/SPEC.md)

## More

- [document/GUIDE.md](document/GUIDE.md): the editing loop from material to delivery, writing a guide, a how-to or an extension, and editing a document without changing what it shows.
- [document/PRESET.md](document/PRESET.md): how to write a transition, an animation and a filter.
- [document/PACK.md](document/PACK.md): what a pack holds, how to make one, a form and a template.
- [document/howto/](document/howto/): techniques that belong to no form, such as [motion graphics](document/howto/motion-graphics.md) and [effects](document/howto/effects.md).
- [packs/](packs/): packs kept beside frames, each a directory to copy into `$FRAMES_HOME/packs/`. A form's guide is its `guide.md`, such as [packs/demo/guide.md](packs/demo/guide.md).
- [document/ARCHITECTURE.md](document/ARCHITECTURE.md): how an implementation is laid out.
- [spec/](spec/README.md): the specification.
