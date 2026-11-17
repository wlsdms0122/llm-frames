# FRAMES-23: Command line and machine output

Status: accepted

## Summary

The commands, their arguments and output, transcode, and the machine output that programs outside frames build on.

## Motivation

An agent and its extensions drive frames only through commands, so what each prints and how it fails is the interface.

## Rules

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

- Every command that takes a document (`render`, `still`, `timeline`, `evaluate`, `locate`, `extract`, `sheet`) also takes a resolved document, which it uses as it is. `render` takes a document, a template with `--args`, or a resolved document. A resolved document with `--theme` or `--args` stops, since both are already written in. A template renders with its defaults when every parameter has one. A template with `--theme` stops, since only its arguments change it, and `--args` with a document that is not a template stops, since it has no parameters to take them.
- `render` writes a sequence to a `.mov` and an image or layout to a `.png`, and `--deliver` names an `.mp4`. Any other extension stops, and so does `--deliver` with an image or layout, which has no frames to deliver.
- `still` draws sequence frames at the given sequence times without encoding a video. Several times go side by side, each labelled with its time in the base theme's `label` style, laid out by resolve like any title, so a form's theme does not change how a check looks. It is the cheap check while a sequence is being written. Each label sits centred on a band under its frame, as tall as the label and one `layout.gap`, with `layout.gap` between frames and `layout.padding` around them, the base theme's lengths at the frame's width.
- `timeline` resolves without rendering and prints, for every storyline clip, its edit range, drawn range, clip range (`[in, out)` on its clip time), speed, and incoming transition with its length, and for every other clip, its visible range, kind, animation and place (`storyline[1].connected[0]`). Everything resolve stops on (an unknown preset, a clip that is never visible, a label with no room, a bad argument) stops here too. It writes no file.
- `evaluate` prints the display list at sequence time t as machine output, item by item, with the clip or op that drew each. `locate` maps a point of the output at t back to the document ([Machine output](#machine-output)).
- `probe` prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate. The kind is `image`, `video`, `audio` or `imageSequence`, which a directory probes as, and the frame rate is the nominal one. A fact the medium does not have is `null`: the size of sound, and the duration and frame rate of an image and of an image sequence, whose rate is the document's `fps`. `alpha` says whether the picture carries an alpha channel.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in media pixels. Over a range it does this for each frame, under a line with its media time. Lines come in the order a text area's `nth` counts them ([FRAMES-2](../FRAMES-2/SPEC.md)). Without `--at` or a range a video is read at time 0. `--at` and `--from` lie in `[0, duration)`, `--to` at most at the duration, after `--from`, and `--step` is at least a microsecond. An image takes neither `--at` nor a range. A frame's `time` is the media time asked, and the frame read is the one shown at it.
- `track` follows an area ([FRAMES-2](../FRAMES-2/SPEC.md)) found at media time `--at`, backwards and forwards with the tracker provider, as `track` on a clip does. `--area` is the area's JSON text, and its messages name `--area`. A tracker follows the area before padding, so the rectangles are the area as found and followed, and a band's are those of the area inside it. It follows over the whole video, or with `--to` over the frames shown between `--at` and `--to`, which may lie on either side.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each labelled with its time as `still` labels it. Given a document they take composite frames at sequence times, as `still` draws them, and given a video the frames shown at media times. `sheet` scales each frame so its longer side is at most 480 pixels, never enlarging it, and lays the frames out left to right in `--cols` columns. `extract` writes each frame at full size and unlabelled, named by its index in time order with at least four digits (`0000.png`, `0001.png`), into the directory, which it makes when it is missing.
- `still`, `extract` and `sheet` stop on an image or layout document, which has no times, on a time outside the video or sequence, on `--to` past its end, on `--from` not before `--to` and on a `--step` under a microsecond, before they write anything.
- `presets` lists presets with their descriptions, or prints one preset's JSON. `packs` lists installed packs, or what one pack holds.
- The analysis commands (`probe`, `ocr`, `track`, `extract`, `sheet`, `timeline`, `evaluate`, `locate`) report facts to write a document with. `ocr` and `track` use the providers, and `transcode` writes with the encoder role. All of them read media through the decoder role.
- Paths are absolute. A document argument may also name a pack template, `<pack>/<name>`, or be `-`, read from standard input.
- A command frames does not have, `frames <name> ...`, runs `frames-<name>` from `PATH` with the global options before the name and the arguments after it, unchanged, and with standard input and output passed through ([FRAMES-25](../FRAMES-25/SPEC.md)).
- `frames --version` prints the version ([FRAMES-18](../FRAMES-18/SPEC.md)). An extension checks it against the versions it is written for, as a pack does with `engine` in its `pack.json`.
- On success, stdout gets one line with the output path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints usage and exits with 64, and so it does with global options and no command.
- The global options are checked before any command or extension runs, so an unknown role or provider name stops the same way for every command.
- Messages name the place, for example `storyline[2].connected[0] (arrow): unknown key "anim". Allowed: id, metadata, at, lane, opacity, animation, keyframes, shape, area, track, label, labelAnimation, color, blend, side`. A place is a path of keys and indexes from the document, and the document itself is `top level`. A clip or op with an `id` is named with it after its index: `clips[1]#intro`.
- A message about a file other than the document (a theme, a preset, a template, a document named as media, an args file, a pack's `pack.json`) puts that file first, as it was referred to, then the place in that file: `shorts/shorts: defaults.transition (defaults): unknown transition preset "dissolve"`. A pack's `pack.json` is named by its path. What resolve finds inside a nested document or a template instance, once each is read and checked, is named by the place of the clip that holds it, continued as `timeline` continues it (`storyline[0].media.storyline[1]`).

### transcode

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

- `--max` caps the longer side. A smaller source is never enlarged. Video sizes round down to even numbers, so neither the source nor `--max` is exceeded.
- Metadata (EXIF, location) is not copied. Rotation is applied to the pixels. A JPEG gets transparent parts on white.
- A video is written at its frame rate: frame k is the source frame shown at k / fps, for every k whose time is before the video's duration and frame 0 always, as a sequence's frames are, so a variable rate recording keeps its length.
- The video levels are the encoder's: with `avfoundation` they are `AVVideoQualityKey` 0.7, 0.5 and 0.3, for H.264 and HEVC alike, which shrink a screen recording written at AVFoundation's default quality to about 90, 60 and 45 percent.
- Sound with more than 2 channels is downmixed to stereo by ITU-R BS.775, as the mixer downmixes it, and a rate above 48 kHz is converted to 48 kHz. A bit rate too high or low for the sample rate moves to the nearest one the AAC encoder takes.
- The output line gives size, format and the ratio to the source, and says so when the output is not smaller.
- The same file as input and output stops, compared with symbolic links resolved and then as the file system names it, so a hard link stops too. An extension that does not fit the input stops, compared ignoring case, and so do `--codec` for an output that is not a video and an output that is a directory. An existing output file is removed only after every check passes.

### Machine output

What frames reports about a document or a medium is a contract, so programs outside frames can build on it. With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name, set to the version of the frames that printed it. The text output is for people and is not part of the contract.

| Command | Object |
| --- | --- |
| `probe` | `{"probe": "1.0.0", kind, size, duration, fps, alpha, audio}`, `audio` as `{channels, sampleRate}` or `null` |
| `ocr` | `{"ocr": "1.0.0", size, frames}`, each frame `{time, lines}` and each line `{text, rect}`. An image has one frame at time 0 |
| `track` | `{"track": "1.0.0", frames}`, each frame followed as `{time, rect}`, in time order |
| `timeline` | `{"timeline": "1.0.0", duration, storyline, clips}`. A storyline entry has `place, id, media` (the file as the document wrote it, such as `shorts/leak.mov`, the same on every machine, or `null` for a solid, a document written in place and a template instance), `edit`, `drawn`, `clip` (each `[start, end)`), `speed` and `transition` (`{preset, seconds}` or `null`). A clips entry has `place, id, kind, visible, lane, parent` (the place of its storyline clip, or `null`) and `animation` (`{entrance, loop, exit}` or `null`, each `{preset, seconds}` for the entrance and exit and `{preset, period}` for the loop, or `null`, with the lengths that apply after theme defaults). An entry whose media is a compound clip or a template instance also has `nested`, the timeline object of the document inside, with places continued from the entry's. [FRAMES-8](../FRAMES-8/SPEC.md) maps sequence time to clip time and media time from these values. A resolved document keeps no names ([FRAMES-19](../FRAMES-19/SPEC.md)), so its timeline gives each `preset` as `null`, `media` as the pinned file (an image sequence as the directory of its frames), and no audio clips, which it holds only as sound |
| `evaluate` | `{"evaluate": "1.0.0", time, size, items}`, bottom first, each `{place, id, kind, bounds, opacity}`: the clip or op that drew it (`null` for the background, a transition cover, the fill outside the content rect and a step of an image or layout document, which the resolved document keeps no place for; inside a nested list an item with none takes the place of the clip that holds the list), and the output rectangle it covers after its transform and mask, `null` when it covers nothing. The background is an item only when it is not fully transparent. Inside a nested document a place continues the place of the clip that holds it (`storyline[0].media.storyline[2]`) |
| `locate` | `{"locate": "1.0.0", hits}`, topmost first: every item under the point, each `{place, id, kind}`, and for a picture of a media file also `{media, mediaTime, point}`: the pinned absolute path of the file the frame is read from (an image sequence's frame file), since a resolved document keeps no written spelling, the frame's pinned media time, and the point in that frame's pixels, `null` for a picture that shows its whole frame (a transition cover), whose pixel size evaluation does not know since it opens no file. An item is under the point when its shape holds it: a picture's `dest`, a fill less its hole, a stroke's band about its edge, an arrow's shaft and head, a glyphs item's text box, an adjustment's rect or its whole frame, carried by its transforms and cut by its masks, reveals and the pictures that hold it. Rounded corners, trims, mattes and transparent pixels are not told apart |

- Fields follow [FRAMES-17](../FRAMES-17/SPEC.md): a new field is an addition, and a removed or changed one a major change. The old form is no longer printed ([the principles](../README.md#principles), no legacy keys).
- Places are those of the messages above.
- Times and lengths are written rounded to the nearest microsecond, in their shortest form (`2.85`, not `2.850000`), so floating point noise is not reported as a fact. A microsecond is far below a frame at any rate, so no frame changes.
- Positions, sizes and opacities are written rounded to the nearest millionth, for the same reason.
- The display list and the mix plan are the roles' wire forms ([FRAMES-19](../FRAMES-19/SPEC.md)), not part of this output.

## Interactions

Machine output follows [FRAMES-18](../FRAMES-18/SPEC.md). Extensions are [FRAMES-25](../FRAMES-25/SPEC.md).

## Alternatives considered


## Notes
