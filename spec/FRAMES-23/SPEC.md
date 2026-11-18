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
ocr       <image | video> [--at <t> | --from <t> --to <t> --step <s>] [--languages <tag>[,<tag>...]] [--json]
track     <video> --at <t> --area <area> [--to <t>]
extract   <video | document.json> <outdir> [--from <t>] [--to <t>] [--step 1]
sheet     <video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]
transcode <in> -o <out> [--quality high|medium|low] [--max <px>] [--codec h264|hevc]
presets   [<kind>] [<name>]
packs     [<pack>]
theme
```

- Every command that takes a document (`render`, `still`, `timeline`, `evaluate`, `locate`, `extract`, `sheet`) also takes a resolved document, which it uses as it is. `render` takes a document, a template with `--args`, or a resolved document. A resolved document with `--theme` or `--args` stops, since both are already written in. A template renders with its defaults when every parameter has one. A template with `--theme` stops, since only its arguments change it, and `--args` with a document that is not a template stops, since it has no parameters to take them.
- `render` writes a sequence to a `.mov`, or one frame of it to a `.png`: the frame at sequence time `--at`, 0 when it is left out, at the frame's size and without a time label. `--at` lies in `[0, duration)`. `--at` with a `.mov` stops, since a master holds every frame, and so does `--deliver` with a `.png`, which has no frames to deliver. `--deliver` names an `.mp4`. Any other extension stops. `resolve` writes to a `.json` file, compared ignoring case, and any other extension stops before the document is read.
- `still` draws sequence frames at the given sequence times without encoding a video. It is the cheap check while a document is being edited. Several times go side by side, left to right in the order given, each with its time label ([Time labels](#time-labels)).
- `timeline` resolves without rendering and prints, for every storyline clip, its edit range, drawn range, clip range (`[in, out)` on its clip time), its speed or that it is time-remapped, and its incoming transition with its length, and for every other clip its visible range, kind, lane, animation, place (`storyline[1].connected[0]`) and parent. Everything resolve stops on while it plans (an unknown preset, a clip that is never visible, a parent chain with a cycle, a bad argument) stops here too. It reads media for its facts, but not a LUT, which resolve reads only when it pins the file and which has no say in time. It writes no file.
- `evaluate` prints the display list at sequence time t as machine output, item by item, with the clip or op that drew each. `locate` maps a point of the output at t back to the document ([Machine output](#machine-output)). Both stop on `--at` outside `[0, duration)`, as `still` does.
- `probe` prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate. The kind is `image`, `video`, `audio` or `imageSequence`, which a directory probes as, and the frame rate is the nominal one. A fact the medium does not have is `null`: the size of sound, and the duration and frame rate of an image and of an image sequence, whose rate is the document's `fps`. `alpha` says whether the picture carries an alpha channel.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in media pixels. Over a range it does this for each frame, under a line with its media time. Lines come in the order a text area's `nth` counts them ([FRAMES-2](../FRAMES-2/SPEC.md)). Without `--at` or a range a video is read at time 0. `--at` and `--from` lie in `[0, duration)`, `--to` at most at the duration, after `--from`, and `--step` is at least a microsecond. An image takes neither `--at` nor a range. A range is any of `--from`, `--to` and `--step`, and it needs `--step`, and `--at` with any of them stops. A frame's `time` is the media time asked, and the frame read is the one shown at it. `--languages` gives the recognition languages for this command in place of the global `--ocr-languages` ([FRAMES-21](../FRAMES-21/SPEC.md)).
- `track` follows an area found at media time `--at`, backwards and forwards with the tracker provider, as `track` on a clip does ([FRAMES-12](../FRAMES-12/SPEC.md)). `--area` is the JSON text of any area form of [FRAMES-2](../FRAMES-2/SPEC.md), `[x, y, w, h]` or a text form found in the frame at `--at`, and its messages name `--area`. The tracker follows the area as found, before its padding. It follows over the whole video, or with `--to` over the frames shown between `--at` and `--to`, which may lie on either side.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each with its time label. Given a document they take composite frames at sequence times, as `still` draws them, and given a video the frames shown at media times. `sheet` scales each frame so its longer side is at most 480 pixels, never enlarging it, and lays the frames out left to right in `--cols` columns, or one column per frame when there are fewer frames, then top to bottom. `extract` writes each frame at full size and unlabelled, named by its index in time order with at least four digits (`0000.png`, `0001.png`), into the directory, which it makes when it is missing. A `.json` file, a pack template or `-` is a document to them, and any other path a video.
- `still`, `extract` and `sheet` stop on a time outside the video or sequence, on `--to` past its end, on `--from` not before `--to` and on a `--step` under a microsecond, before they write anything.
- `presets` lists presets by kind: a line with the kind, then a line for each of its presets, indented, with the name a document gives it and its description. With a name it prints that preset's JSON, its `params` included. `packs` lists the packs, the one that ships with frames and the installed ones, or what one pack holds. Under a preset or a template that publishes parameters, `packs <pack>` prints one line for each, indented, in the order they are declared: its name, its type, its default as JSON on one line (`-` when it has none) and its description. A template's lines come from its `params` alone, checked as they are where it is used, so a template whose media is not there still lists them, and a broken declaration stops the listing, naming its place.
- The analysis commands (`probe`, `ocr`, `track`, `extract`, `sheet`, `timeline`, `evaluate`, `locate`) report facts to write a document with. `ocr` and `track` use the providers, and `transcode` writes with the encoder role. All of them read media through the decoder role.
- Paths are absolute. A document argument may also name a pack template, `<pack>/<name>`, or be `-`, read from standard input.
- Times are seconds written as decimals, several separated by commas, a point is `x,y`, `--cols` and `--max` are whole numbers, and languages are BCP 47 tags separated by commas. A value that is not one, or is not finite, stops naming its option.
- A command frames does not have, `frames <name> ...`, runs `frames-<name>` from `PATH` with the global options before the name and the arguments after it, unchanged, and with standard input and output passed through ([FRAMES-25](../FRAMES-25/SPEC.md)).
- `frames --version` prints the version ([FRAMES-18](../FRAMES-18/SPEC.md)). An extension checks it against the versions it is written for, as a pack does with `engine` in its `pack.json`.
- On success, stdout gets one line for each file written, with its path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints usage and exits with 64, and so it does with global options and no command.
- The global options are checked before any command or extension runs, so an unknown role or provider name stops the same way for every command.
- Messages name the place, for example `format: unknown key "inset". Allowed: size, fps, background, conform`. A place is a path of keys and indexes from the document, and the document itself is `top level`. A clip or op with an `id` is named with it after its index: `clips[1]#logo`.
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
| image | `.jpg`, `.heic`, `.png` | JPEG or HEIC at the quality level. PNG is lossless, and only `--max` changes it |
| audio | `.m4a` | AAC, up to 2 channels and 48 kHz |
| video | `.mp4`, `.mov`, `.m4v` | H.264 (default) or HEVC, with AAC sound |
| video | `.m4a` | the sound only |

| Quality | Image (0 to 1) | Video | Audio (per channel) |
| --- | --- | --- | --- |
| `high` | 0.9 | high | 96 kbps |
| `medium` (default) | 0.75 | medium | 64 kbps |
| `low` | 0.55 | low | 32 kbps |

- `--max` caps the longer side. A smaller source is never enlarged. Video sizes round down to even numbers, so neither the source nor `--max` is exceeded. A video whose side would round below 2 pixels, from its source or under `--max`, stops before anything is written, naming the size it would give, and `--max` when it is what shrank it.
- Metadata (EXIF, location) is not copied. Rotation is applied to the pixels. A JPEG gets transparent parts on white.
- A video is written at its frame rate: frame k is the source frame shown at k / fps, for every k whose time is before the video's duration and frame 0 always, as a sequence's frames are, so a variable frame rate source keeps its length.
- The video levels are the encoder's: with `avfoundation` they are `AVVideoQualityKey` 0.7, 0.5 and 0.3, for H.264 and HEVC alike.
- Sound with more than 2 channels is downmixed to stereo by ITU-R BS.775, as the mixer downmixes it, and a rate above 48 kHz is converted to 48 kHz. A bit rate too high or low for the sample rate moves to the nearest one the AAC encoder takes.
- The output line gives size, format and the ratio to the source: `<path>  <size>  <format>  <percent> of <source size>`, the percent with one decimal.
- The same file as input and output stops, compared with symbolic links resolved and then as the file system names it, so a hard link stops too. An extension that does not fit the input stops, compared ignoring case, and so do `--codec` for an output that is not a video and an output that is a directory. An existing output file is removed only after every check passes.

### Machine output

What frames reports about a document or a medium is a contract, so programs outside frames can build on it. With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name, set to the version of the frames that printed it. The text output is for people and is not part of the contract.

| Command | Object |
| --- | --- |
| `probe` | `{"probe": "1.0.0", kind, size, duration, fps, alpha, audio}`, `size` as `[w, h]` in pixels or `null` for sound, `audio` as `{channels, sampleRate}` or `null` |
| `ocr` | `{"ocr": "1.0.0", size, languages, frames}`, `languages` the tags asked for or `null` where the provider detected them, each frame `{time, lines}` and each line `{text, rect}`. An image has one frame at time 0 |
| `track` | `{"track": "1.0.0", time, target, frames}`: the media time of `--at`, the target's quadrilateral there as found, and each frame followed as `{time, quad, motion}` in time order, a quadrilateral and a motion as the resolved document writes them ([FRAMES-19](../FRAMES-19/SPEC.md)) |
| `timeline` | `{"timeline": "1.0.0", duration, storyline, clips}`. A storyline entry has `place, id, media` (the file as the document wrote it, such as `broll/surf.mov`, the same on every machine, or `null` for a solid, a document written in place and a template instance), `edit`, `drawn`, `clip` (each `[start, end)`), `speed`, `timeRemap` (whether the clip is time-remapped, when `speed` is 1) and `transition` (`{preset, seconds}` or `null`). A clips entry has `place, id, kind, visible, lane, storyline` (the place of the storyline clip it is connected to, or `null`), `parent` (the place of its parent clip, or `null`) and `animation` (`{entrance, loop, exit}` or `null`, each `{preset, seconds}` for the entrance and exit and `{preset, period}` for the loop, or `null`, with the lengths that apply after theme defaults). An entry whose media is a compound clip or a template instance also has `nested`, the timeline object of the document inside, with places continued from the entry's. [FRAMES-8](../FRAMES-8/SPEC.md) maps sequence time to clip time and media time from these values. A resolved document keeps no names ([FRAMES-19](../FRAMES-19/SPEC.md)), so its timeline gives each `preset` as `null`, `media` as the pinned file (an image sequence as the directory of its frames), and no audio clips, which it holds only as sound |
| `evaluate` | `{"evaluate": "1.0.0", time, size, items}`, bottom first, each `{place, id, kind, item, bounds, opacity}`: the clip or op that drew it (`null` for the background and a transition cover; inside a nested list an item with none takes the place of the clip that holds the list), the item kind of [FRAMES-20](../FRAMES-20/SPEC.md) (`picture`, `path`, `glyphs` or `adjust`, and `background` for the background), and the output rectangle it covers after its transform, reveal and masks, `null` when it covers nothing. The background is an item only when it is not fully transparent. A clip used as a track matte draws no item of its own. Inside a nested document a place continues the place of the clip that holds it (`storyline[0].media.storyline[2]`) |
| `locate` | `{"locate": "1.0.0", hits}`, topmost first: every item under the point, each `{place, id, kind, item}`, and for a picture of a media file also `{media, mediaTime, point}`: the pinned absolute path of the file the frame is read from (an image sequence's frame file), since a resolved document keeps no written spelling, the frame's pinned media time, and the point in that frame's pixels, `null` for a picture that shows its whole frame (a transition cover), whose pixel size evaluation does not know since it opens no file. An item is under the point when its shape holds it: a picture's `dest`, a path's fill (its geometry, closed) or the band of its stroke as drawn with its arrowheads, a glyphs item's text box, an adjustment's whole frame, carried by its transforms and cut by its reveal, its masks (their geometry without feather, inverted and combined by their modes) and the pictures that hold it. Rounded corners, joins, caps, feather, transition mattes, track mattes and transparent pixels are not told apart |

- Fields follow [FRAMES-17](../FRAMES-17/SPEC.md): a new field is an addition, and a removed or changed one a major change. The old form is no longer printed ([the principles](../README.md#principles), no legacy keys).
- Places are those of the messages above.
- The `kind` of a clip in `timeline`, `evaluate` and `locate` is the clip's kind: `video` (an image sequence included), `image`, `audio`, `compound` (a sequence as media, a template instance included), `title`, `rect`, `ellipse`, `path`, `adjustment` or `solid`. It names what the document wrote, and `item` names what the clip drew ([FRAMES-20](../FRAMES-20/SPEC.md)), so a `title` draws `glyphs`, a `rect` a `path` and an `adjustment` an `adjust` item.
- Times and lengths are written rounded to the nearest microsecond, in their shortest form (`2.85`, not `2.850000`), so floating point noise is not reported as a fact. A microsecond is far below a frame at any rate, so no frame changes.
- Positions, sizes and opacities are written rounded to the nearest millionth, for the same reason.
- The display list and the mix plan are the roles' wire forms ([FRAMES-19](../FRAMES-19/SPEC.md)), not part of this output.

## Interactions

Machine output follows [FRAMES-18](../FRAMES-18/SPEC.md). Extensions are [FRAMES-25](../FRAMES-25/SPEC.md). The display list `evaluate` and `locate` report is [FRAMES-20](../FRAMES-20/SPEC.md), the providers `ocr` and `track` call and the master `render` writes are [FRAMES-21](../FRAMES-21/SPEC.md), and the checks made with `still` and `sheet` are [FRAMES-24](../FRAMES-24/SPEC.md).

## Alternatives considered

A separate command or document kind for stills: a still is a frame of a sequence, so `render` writes it with `--at` and there is one way to draw a picture.

Time labels in the theme's text styles: a check would look different under every look, and a theme without such a style could not be checked at all. A fixed tool style keeps the check apart from the result.

Time labels under each frame on a band of their own: a label burnt into the corner, as NLEs overlay timecode, keeps a sheet as tight as its frames and reads the same at any size.

An API or a server in place of commands: commands with JSON output are what any agent, shell and language already drive, and frames keeps no state between them for a session to hold.

`transcode` defined as making a file smaller: a delivery file is written for where it goes at a quality level, and whether it is smaller depends on how its source was written.

## Notes
