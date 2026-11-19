# FRAMES-23: Command line and machine output

Status: accepted

## Summary

The commands, their arguments and output, the fixed style of the time labels `still` and `sheet` draw, `transcode` for delivery files, and the machine output that programs outside frames build on.

## Motivation

An agent and the programs it runs drive frames only through commands. Editing is a loop: change the document, look at it with `still`, `sheet` and `timeline`, change it again, render, and use what was rendered as media in the next edit. So the commands that check must be cheap and must say exactly what they saw, and what each command prints and how it fails is the interface. Two implementations that differ in a flag, a label or a field would break every program written against one of them.

## Rules

```
frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>] [--encoder <name>]
       [--shaper <name>] [--tracker <name>] [--ocr <name>] [--ocr-languages <tag>[,<tag>...]] <command> ...

render    <document.json> -o <out.mov | out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>]
still     <document.json> --at <t>[,<t>...] -o <out.png> [--args <args.json>]
resolve   <document.json> -o <resolved.json> [--args <args.json>]
timeline  <document.json> [--args <args.json>] [--json]
evaluate  <document.json> --at <t> [--args <args.json>]
locate    <document.json> --at <t> --point <x,y> [--args <args.json>]
probe     <media> [--json]
ocr       <image | video> [--at <t> | --from <t> --to <t> --step <s>] [--languages <tag>[,<tag>...]] [--color-space <name>] [--json]
track     <video> --at <t> --area <area> [--to <t>] [--color-space <name>]
extract   <video | document.json> <outdir> [--from <t>] [--to <t>] [--step 1]
sheet     <video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]
transcode <in> -o <out> [--quality high|medium|low] [--max <px>] [--codec h264|hevc] [--color-space <name>]
presets   [<kind>] [<name>]
packs     [<pack>]
theme
```

- Every command that takes a document (`render`, `still`, `timeline`, `evaluate`, `locate`, `extract`, `sheet`) also takes a resolved document, which it uses as it is. `render` takes a document, a template with `--args`, or a resolved document. A resolved document with `--theme` or `--args` stops, since both are already written in. A template renders with its defaults when every parameter has one. A template with `--theme` stops, since only its arguments change it, and `--args` with a document that is not a template stops, since it has no parameters to take them.
- `render` writes a sequence to a `.mov`, or one frame of it to a `.png`: the frame at sequence time `--at`, 0 when it is left out, at the frame's size and without a time label, in the sequence's colour space at 16 bits per channel ([FRAMES-21](../FRAMES-21/SPEC.md)). `--at` lies in `[0, duration)`. `--at` with a `.mov` stops, since a master holds every frame, and so does `--deliver` with a `.png`, which has no frames to deliver. `--deliver` names an `.mp4`. Any other extension stops. `resolve` writes to a `.json` file, compared ignoring case, and any other extension stops before the document is read.
- `still` draws sequence frames at the given sequence times without encoding a video. It is the cheap check while a document is being edited. Several times go side by side, left to right in the order given, each with its time label ([Time labels](#time-labels)).
- `timeline` resolves without rendering and prints, for every storyline clip, its edit range, drawn range, clip range (`[in, out)` on its clip time), its speed or that it is time-remapped, its incoming transition with its length, and its sound range, the range its sound plays over with its `split` applied, or that it plays no sound ([FRAMES-13](../FRAMES-13/SPEC.md)), and for every other clip its visible range, kind, lane, animation, place (`storyline[1].connected[0]`) and parent, and for a visual media clip its sound range as well. Everything resolve stops on while it plans (an unknown preset, a clip that is never visible, a parent chain with a cycle, a bad argument) stops here too. It reads media for its facts, but not a LUT, which resolve reads only when it pins the file and which has no say in time. It writes no file.
- `evaluate` prints the display list at sequence time t as machine output, item by item, with the clip or op that drew each. `locate` maps a point of the output at t back to the document ([Machine output](#machine-output)). Both stop on `--at` outside `[0, duration)`, as `still` does.
- `probe` prints the kind, size, duration, frame rate, alpha, colour space, and audio channels and sample rate. The kind is `image`, `video`, `audio` or `imageSequence`, which a directory probes as, and the frame rate is the nominal one. A fact the medium does not have is `null`: the size of sound, and the duration and frame rate of an image and of an image sequence, whose rate is the document's `fps`. `alpha` says whether the picture carries an alpha channel. The colour space is the one the decoder takes the picture in ([FRAMES-26](../FRAMES-26/SPEC.md#colour-spaces)): the name of the table row its tags match, `srgb` when it is untagged, and none when it is tagged outside the table. With it come the H.273 primaries, transfer and matrix the picture is tagged with, the bits per channel the file stores, and whether it is HDR, which a transfer of PQ or HLG (16 or 18) makes it. An image sequence reports its first frame's.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in media pixels. Over a range it does this for each frame, under a line with its media time. Lines come in the order a text area's `nth` counts them ([FRAMES-2](../FRAMES-2/SPEC.md)). Without `--at` or a range a video is read at time 0. `--at` and `--from` lie in `[0, duration)`, `--to` at most at the duration, after `--from`, and `--step` is at least a microsecond. An image takes neither `--at` nor a range. A range is any of `--from`, `--to` and `--step`, and it needs `--step`, and `--at` with any of them stops. A frame's `time` is the media time asked, and the frame read is the one shown at it. `--languages` gives the recognition languages for this command in place of the global `--ocr-languages` ([FRAMES-21](../FRAMES-21/SPEC.md)).
- `track` follows an area found at media time `--at`, backwards and forwards with the tracker provider, as `track` on a clip does ([FRAMES-12](../FRAMES-12/SPEC.md)). `--area` is the JSON text of any area form of [FRAMES-2](../FRAMES-2/SPEC.md), `[x, y, w, h]` or a text form found in the frame at `--at`, and its messages name `--area`. The tracker follows the area as found, before its padding. It follows over the whole video, or with `--to` over the frames shown between `--at` and `--to`, which may lie on either side.
- `ocr` and `track` read the media in the colour space `--color-space` names, over what the file says, as a media clip's `colorSpace` corrects it ([FRAMES-26](../FRAMES-26/SPEC.md#media)), so they see the picture resolve's providers see for a clip that writes that `colorSpace`. The name is one whose Media column says yes, and any other name stops. Without it the file's tags apply.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each with its time label. Given a document they take composite frames at sequence times, as `still` draws them, and given a video the frames shown at media times. `sheet` scales each frame so its longer side is at most 480 pixels, never enlarging it, and lays the frames out left to right in `--cols` columns, or one column per frame when there are fewer frames, then top to bottom. `extract` writes each frame at full size and unlabelled, named by its index in time order with at least four digits (`0000.png`, `0001.png`), into the directory, which it makes when it is missing. A `.json` file, a pack template or `-` is a document to them, and any other path a video.
- `still`, `sheet` and `extract` write analysis pictures ([FRAMES-26](../FRAMES-26/SPEC.md#providers-and-analysis-pictures)), SDR previews for looking at and the same normalised picture the providers read: PNGs in sRGB at 8 bits per channel, with HDR tone mapped and wide gamut clipped as it gives, whatever the sequence's or the video's colour space. They are not the master: the master of a `display-p3`, `rec2020` or HDR sequence is checked with `render --at`, which writes the frame in the sequence's colour space.
- `still`, `extract` and `sheet` stop on a time outside the video or sequence, on `--to` past its end, on `--from` not before `--to` and on a `--step` under a microsecond, before they write anything.
- `presets` lists presets by kind: a line with the kind, then a line for each of its presets, indented, with the name a document gives it and its description. With a name it prints that preset's JSON, its `params` included. `packs` lists the packs, the one that ships with frames and the installed ones, or what one pack holds. Under a preset or a template that publishes parameters, `packs <pack>` prints one line for each, indented, in the order they are declared: its name, its type, its default as JSON on one line (`-` when it has none) and its description. A template's lines come from its `params` alone, checked as they are where it is used, so a template whose media is not there still lists them, and a broken declaration stops the listing, naming its place.
- The analysis commands (`probe`, `ocr`, `track`, `extract`, `sheet`, `timeline`, `evaluate`, `locate`) report facts to write a document with. `ocr` and `track` use the providers, and `transcode` writes with the encoder role. All of them read media through the decoder role.
- Paths are absolute. A document argument may also name a pack template, `<pack>/<name>`, or be `-`, read from standard input.
- Times are seconds written as decimals, several separated by commas, a point is `x,y`, `--cols` and `--max` are whole numbers, and languages are BCP 47 tags separated by commas. A value that is not one, or is not finite, stops naming its option.
- A command frames does not have, `frames <name> ...`, runs `frames-<name>` from `PATH` with the global options before the name and the arguments after it, unchanged, and with standard input and output passed through ([FRAMES-25](../FRAMES-25/SPEC.md)).
- `frames --version` prints the version ([FRAMES-18](../FRAMES-18/SPEC.md)). An extension checks it against the versions it is written for, as a pack does with `engine` in its `pack.json`.
- `frames --help` prints the usage, then each global option with what it takes and its default, to standard output and exits with 0. `frames <command> --help` prints that command's help to standard output and exits with 0, running nothing: its line of the usage, what it does, and each argument and option with what it takes and its default. An argument `--help` anywhere among a built-in command's arguments does this. An extension's arguments pass through unchanged, `--help` among them, so `frames <extension> --help` is the extension's own help.
- The global options before `--help` are checked as for any command, so `frames --renderer metal --help` stops. `--version` and `--help` stand alone after the global options, and an argument after either stops: `frames --version --help` and `frames --help render` stop, and a command's help is `frames <command> --help`.
- On success, stdout gets one line for each file written, with its path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints the usage to standard error and exits with 64, and so it does with global options and no command, since the command line is incomplete.
- The global options are checked before any command or extension runs, so an unknown role or provider name stops the same way for every command.
- Messages name the place, for example `format: unknown key "inset". Allowed: size, fps, background, conform, colorSpace, compositing`. A place is a path of keys and indexes from the document, and the document itself is `top level`. A clip or op with an `id` is named with it after its index: `clips[1]#logo`.
- A message about a file other than the document (a theme, a preset, a template, a document named as media, an args file, a pack's `pack.json`) puts that file first, as it was referred to, then the place in that file: `looks/warm: defaults.transition (defaults): unknown transition preset "dissolve"`. A pack's `pack.json` is named by its path. What resolve finds inside a nested document or a template instance, once each is read and checked, is named by the place of the clip that holds it, continued as `timeline` continues it (`storyline[0].media.storyline[1]`).

### Time labels

`still` and `sheet` label each frame with its time in one fixed tool style. No theme changes it, so a check looks the same whatever the document's look, and it is laid out by frames itself, not by a document.

| Part | Value |
| --- | --- |
| text | the time in seconds, rounded to the microsecond in its shortest form, followed by `s`: `0s`, `2.5s`, `12.04s`. A video's frames are labelled with their media time, a document's with sequence time |
| size | S = max(14, round(L / 40)) pixels, where L is the longer side of the frame as it is drawn in the picture (48 for a 1920 by 1080 frame, 14 on a sheet frame 480 wide) |
| font | Helvetica Neue Medium (`HelveticaNeue-Medium` in `/System/Library/Fonts/HelveticaNeue.ttc`) at size S, shaped by the shaping provider ([FRAMES-21](../FRAMES-21/SPEC.md)) |
| colour | `#FFFFFFFF` text, no stroke |
| background | `#000000B3`, a rectangle around the text's line box (the font's ascent and descent at S), 0.25 S above and below it and 0.5 S left and right of it, with corners of radius 0.3 S |
| place | on the frame, the background's top left corner 0.5 S from the frame's top left corner, as an NLE burns a time into the picture |

- Frames lie S apart, with S around them, on an opaque `#202020FF` background, which their transparent parts show. A `still` of one time is that frame with its label and the same margin.

### transcode

`transcode` writes a delivery file from an image, audio or video file: a format and a quality level for where the file goes. Whether it is smaller than its source depends on the source.

| Input (judged by contents) | Output extension | Written as |
| --- | --- | --- |
| image | `.jpg`, `.heic`, `.png` | JPEG or HEIC at the quality level, HEIC at 10 bits per channel in an HDR colour space. PNG is lossless, and only `--max` changes it, at the source's bit depth, and 16 bits per channel in an HDR colour space |
| audio | `.m4a` | AAC, up to 2 channels and 48 kHz |
| video | `.mp4`, `.mov`, `.m4v` | H.264 (the default in an SDR colour space) or HEVC (Main 10, the default in an HDR colour space), with AAC sound |
| video | `.m4a` | the sound only |

| Quality | Image (0 to 1) | Video | Audio (per channel) |
| --- | --- | --- | --- |
| `high` | 0.9 | high | 96 kbps |
| `medium` (default) | 0.75 | medium | 64 kbps |
| `low` | 0.55 | low | 32 kbps |

- `--max` caps the longer side. A smaller source is never enlarged. Video sizes round down to even numbers, so neither the source nor `--max` is exceeded. A video whose side would round below 2 pixels, from its source or under `--max`, stops before anything is written, naming the size it would give, and `--max` when it is what shrank it.
- The output is in the source's colour space when a sequence can be output in it ([FRAMES-26](../FRAMES-26/SPEC.md#colour-spaces), the Sequence column), and in `srgb` otherwise, so a source tagged outside the table is written as `srgb`. `--color-space` names the output's colour space instead, a name a sequence takes, and any other name stops. The source is read as a sequence of the output's colour space reads a media clip's with `toneMap` true ([FRAMES-26](../FRAMES-26/SPEC.md#media)), so an HDR source is tone mapped to the output space's peak when its source peak is above it, and written as that sequence's output is encoded and tagged ([FRAMES-26](../FRAMES-26/SPEC.md#output)). A source the decoder stops on for its colour, an image whose ICC profile is LUT-based or a video whose code points no formula defines ([FRAMES-26](../FRAMES-26/SPEC.md#media)), is read by the platform's own colour management at relative intent instead: the one reading of frames that no fixed formula gives, made once, so the file it writes is read by the fixed formulas from then on.
- `--codec h264` with an HDR colour space stops, naming HEVC, since H.264 at 8 bits cannot carry HDR. A `.jpg` output in an HDR colour space stops, naming `.png` and `.heic`, since JPEG holds 8 bits.
- Metadata (EXIF, location) is not copied. Rotation is applied to the pixels. A JPEG gets transparent parts on white.
- A video is written at its frame rate: frame k is the source frame shown at k / fps, for every k whose time is before the video's duration and frame 0 always, as a sequence's frames are, so a variable frame rate source keeps its length.
- The video levels are the encoder's: with `avfoundation` they are `AVVideoQualityKey` 0.7, 0.5 and 0.3, for H.264 and HEVC alike.
- Sound with more than 2 channels is downmixed to stereo by ITU-R BS.775, as the mixer downmixes it, and a rate above 48 kHz is converted to 48 kHz. A bit rate too high or low for the sample rate moves to the nearest one the AAC encoder takes.
- The output line gives size, format and the ratio to the source: `<path>  <size>  <format>  <percent> of <source size>`, the percent with one decimal.
- The same file as input and output stops, compared with symbolic links resolved and then as the file system names it, so a hard link stops too. An extension that does not fit the input stops, compared ignoring case, and so do `--codec` for an output that is not a video, `--color-space` for an output of sound only and an output that is a directory. An existing output file is removed only after every check passes.

### Machine output

What frames reports about a document or a medium is a contract, so programs outside frames can build on it. With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name, set to the version of the frames that printed it. The text output is for people and is not part of the contract.

| Command | Object |
| --- | --- |
| `probe` | `{"probe": "1.0.0", kind, size, duration, fps, alpha, colorSpace, audio}`, `size` as `[w, h]` in pixels or `null` for sound, `colorSpace` as `{name, primaries, transfer, matrix, bitDepth, hdr}` or `null` for sound, `audio` as `{channels, sampleRate}` or `null`. In `colorSpace`, `name` is the table name or `null` outside the table, `primaries`, `transfer` and `matrix` are H.273 code points as the file is tagged, `null` for one it leaves out (an image tagged by an ICC profile gives those of the table row the profile describes, `null` outside the table, and a `matrix` of `null`), `bitDepth` is a whole number and `hdr` a boolean |
| `ocr` | `{"ocr": "1.0.0", size, languages, frames}`, `languages` the tags asked for or `null` where the provider detected them, each frame `{time, lines}` and each line `{text, rect}`. An image has one frame at time 0 |
| `track` | `{"track": "1.0.0", time, target, frames}`: the media time of `--at`, the target's quadrilateral there as found, and each frame followed as `{time, quad, motion}` in time order, a quadrilateral and a motion as the resolved document writes them ([FRAMES-19](../FRAMES-19/SPEC.md)) |
| `timeline` | `{"timeline": "1.0.0", duration, storyline, clips}`. A storyline entry has `place, id, media` (the file as the document wrote it, such as `broll/surf.mov`, the same on every machine, or `null` for a solid, a document written in place and a template instance), `edit`, `drawn`, `clip` (each `[start, end)`), `sound` (`[start, end)`, the range its sound plays over, or `null` for a clip that plays no sound), `speed`, `timeRemap` (whether the clip is time-remapped, when `speed` is 1) and `transition` (`{preset, seconds}` or `null`). A clips entry has `place, id, kind, visible, sound` (for a visual media clip the range its sound plays over, its `split` applied, `null` for every other clip and for one that plays no sound), `lane, storyline` (the place of the storyline clip it is connected to, or `null`), `parent` (the place of its parent clip, or `null`) and `animation` (`{entrance, loop, exit, by, stagger}` or `null`: each span `{preset, seconds}` for the entrance and exit and `{preset, period}` for the loop, or `null`, with the lengths that apply after theme defaults, and `by` and `stagger` the unit and the seconds between units of a title animated by unit, with its default `stagger` applied, both `null` otherwise). An entry whose media is a compound clip or a template instance also has `nested`, the timeline object of the document inside, with places continued from the entry's. [FRAMES-8](../FRAMES-8/SPEC.md) maps sequence time to clip time and media time from these values. A resolved document keeps no names ([FRAMES-19](../FRAMES-19/SPEC.md)), so its timeline gives each `preset` as `null`, `media` as the pinned file (an image sequence as the directory of its frames), and no audio clips, which it holds only as sound |
| `evaluate` | `{"evaluate": "1.0.0", time, size, items}`, bottom first, each `{place, id, kind, item, bounds, opacity}`: the clip or op that drew it (`null` for the background and a transition cover; inside a nested list an item with none takes the place of the clip that holds the list), the item kind of [FRAMES-20](../FRAMES-20/SPEC.md) (`picture`, `path`, `glyphs` or `adjust`, and `background` for the background), and the output rectangle it covers after its transform, reveal and masks, `null` when it covers nothing. The background is an item only when it is not fully transparent. A clip used as a track matte draws no item of its own. Inside a nested document a place continues the place of the clip that holds it (`storyline[0].media.storyline[2]`) |
| `locate` | `{"locate": "1.0.0", hits}`, topmost first: every item under the point, each `{place, id, kind, item}`, and for a picture of a media file also `{media, mediaTime, point}`: the pinned absolute path of the file the frame is read from (an image sequence's frame file), since a resolved document keeps no written spelling, the frame's pinned media time, and the point in that frame's pixels, `null` for a picture that shows its whole frame (a transition cover), whose pixel size evaluation does not know since it opens no file. An item is under the point when its shape holds it: a picture's `dest`, a path's fill (its geometry, closed) or the band of its stroke as drawn with its arrowheads, a glyphs item's text box (the unit's box for the item of one unit of a title animated by unit, and nothing for its item of the background when the title has none), an adjustment's whole frame, carried by its transforms and cut by its reveal, its masks (their geometry without feather, inverted and combined by their modes) and the pictures that hold it. Rounded corners, joins, caps, feather, transition mattes, track mattes and transparent pixels are not told apart |

- Fields follow [FRAMES-17](../FRAMES-17/SPEC.md): a new field is an addition, and a removed or changed one a major change. The old form is no longer printed ([the principles](../README.md#principles), no legacy keys).
- Places are those of the messages above.
- The `kind` of a clip in `timeline`, `evaluate` and `locate` is the clip's kind: `video` (an image sequence included), `image`, `audio` (a clip written with `"picture": false` included), `compound` (a sequence as media, a template instance included), `title`, `rect`, `ellipse`, `path`, `adjustment` or `solid`. It names what the document wrote, and `item` names what the clip drew ([FRAMES-20](../FRAMES-20/SPEC.md)), so a `title` draws `glyphs`, a `rect` a `path` and an `adjustment` an `adjust` item.
- Times and lengths are written rounded to the nearest microsecond, in their shortest form (`2.85`, not `2.850000`), so floating point noise is not reported as a fact. A microsecond is far below a frame at any rate, so no frame changes.
- Positions, sizes and opacities are written rounded to the nearest millionth, for the same reason.
- The display list and the mix plan are the roles' wire forms ([FRAMES-19](../FRAMES-19/SPEC.md)), not part of this output.

## Interactions

Machine output follows [FRAMES-18](../FRAMES-18/SPEC.md). Extensions are [FRAMES-25](../FRAMES-25/SPEC.md). The display list `evaluate` and `locate` report is [FRAMES-20](../FRAMES-20/SPEC.md), the providers `ocr` and `track` call and the master `render` writes are [FRAMES-21](../FRAMES-21/SPEC.md), and the checks made with `still` and `sheet` are [FRAMES-24](../FRAMES-24/SPEC.md). The colour spaces `probe` reports and `transcode` writes, tone mapping and analysis pictures are [FRAMES-26](../FRAMES-26/SPEC.md).

## Alternatives considered

A separate command or document kind for stills: a still is a frame of a sequence, so `render` writes it with `--at` and there is one way to draw a picture.

Time labels in the theme's text styles: a check would look different under every look, and a theme without such a style could not be checked at all. A fixed tool style keeps the check apart from the result.

Time labels under each frame on a band of their own: a label burnt into the corner, as NLEs overlay timecode, keeps a sheet as tight as its frames and reads the same at any size.

An API or a server in place of commands: commands with JSON output are what any agent, shell and language already drive, and frames keeps no state between them for a session to hold.

`transcode` defined as making a file smaller: a delivery file is written for where it goes at a quality level, and whether it is smaller depends on how its source was written.

`transcode` refusing a source no fixed formula reads, as the decoder does: such a file could not enter an edit at all without another tool. Read once by the platform's colour management, it becomes a file of the table that every later reading converts by formula, and the resolved document pins that file.

## Notes
