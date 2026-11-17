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
- `still` draws sequence frames at the given sequence times without encoding a video. Several times go side by side, each labelled with its time in the base theme's `label` style, laid out by resolve like any title, so a form's theme does not change how a check looks. It is the cheap check while a sequence is being written.
- `timeline` resolves without rendering and prints, for every storyline clip, its edit range, drawn range, clip range (`[in, out)` on its clip time), speed, and incoming transition with its length, and for every other clip, its visible range, kind, animation and place (`storyline[1].connected[0]`). Everything resolve stops on (an unknown preset, a clip that is never visible, a label with no room, a bad argument) stops here too. It writes no file.
- `evaluate` prints the display list at sequence time t as machine output, item by item, with the clip or op that drew each. `locate` maps a point of the output at t back to the document ([Machine output](#machine-output)).
- `probe` prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate. The kind is `image`, `video`, `audio` or `imageSequence`, which a directory probes as, and the frame rate is the nominal one. A fact the medium does not have is `null`: the size of sound, and the duration and frame rate of an image and of an image sequence, whose rate is the document's `fps`. `alpha` says whether the picture carries an alpha channel.
- `ocr` prints `size WxH` on the first line, then one line per recognised line, `[x, y, w, h]  text`, in media pixels. Over a range it does this for each frame, under a line with its media time. Lines come in the order a text area's `nth` counts them ([FRAMES-2](../FRAMES-2/SPEC.md)). Without `--at` or a range a video is read at time 0. `--at` and `--from` lie in `[0, duration)`, `--to` at most at the duration, after `--from`, and `--step` is at least a microsecond. An image takes neither `--at` nor a range. A frame's `time` is the media time asked, and the frame read is the one shown at it.
- `track` follows an area ([FRAMES-2](../FRAMES-2/SPEC.md)) found at media time `--at`, backwards and forwards with the tracker provider, as `track` on a clip does. `--area` is the area's JSON text, and its messages name `--area`. A tracker follows the area before padding, so the rectangles are the area as found and followed, and a band's are those of the area inside it. It follows over the whole video, or with `--to` over the frames shown between `--at` and `--to`, which may lie on either side.
- `extract` writes frames as PNG files. `sheet` lays frames out in one picture, each labelled with its time as `still` labels it. Given a document they take composite frames at sequence times, as `still` draws them.
- `presets` lists presets with their descriptions, or prints one preset's JSON. `packs` lists installed packs, or what one pack holds.
- The analysis commands (`probe`, `ocr`, `track`, `extract`, `sheet`, `timeline`, `evaluate`, `locate`) report facts to write a document with. `ocr` and `track` use the providers, and `transcode` writes with the encoder role. All of them read media through the decoder role.
- Paths are absolute. A document argument may also name a pack template, `<pack>/<name>`, or be `-`, read from standard input.
- A command frames does not have, `frames <name> ...`, runs `frames-<name>` from `PATH` with the global options before the name and the arguments after it, unchanged, and with standard input and output passed through ([FRAMES-25](../FRAMES-25/SPEC.md)).
- `frames --version` prints the version ([FRAMES-18](../FRAMES-18/SPEC.md)). An extension checks it against the versions it is written for, as a pack does with `engine` in its `pack.json`.
- On success, stdout gets one line with the output path and size.
- On failure, stderr gets `frames: <reason>` and the exit code is 1. Without arguments, frames prints usage and exits with 64.
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

- `--max` caps the longer side. A smaller source is never enlarged. Video sizes round to even numbers.
- Metadata (EXIF, location) is not copied. Rotation is applied to the pixels. A JPEG gets transparent parts on white.
- The output line gives size, format and the ratio to the source, and says so when the output is not smaller.
- The same file as input and output stops, and so does an extension that does not fit the input. An existing output file is removed only after every check passes.

### Machine output

What frames reports about a document or a medium is a contract, so programs outside frames can build on it. With `--json`, and always for `evaluate`, `locate` and `track`, a command prints one JSON object whose first key is the command's name, set to the version of the frames that printed it. The text output is for people and is not part of the contract.

| Command | Object |
| --- | --- |
| `probe` | `{"probe": "1.0.0", kind, size, duration, fps, alpha, audio}`, `audio` as `{channels, sampleRate}` or `null` |
| `ocr` | `{"ocr": "1.0.0", size, frames}`, each frame `{time, lines}` and each line `{text, rect}`. An image has one frame at time 0 |
| `track` | `{"track": "1.0.0", frames}`, each frame followed as `{time, rect}`, in time order |
| `timeline` | `{"timeline": "1.0.0", duration, storyline, clips}`. A storyline entry has `place, id, media` (the file as the document wrote it, such as `shorts/leak.mov`, the same on every machine, or `null` for a solid, a document written in place and a template instance), `edit`, `drawn`, `clip` (each `[start, end)`), `speed` and `transition` (`{preset, seconds}` or `null`). A clips entry has `place, id, kind, visible, lane, parent` (the place of its storyline clip, or `null`) and `animation` (`{entrance, loop, exit}` or `null`, each `{preset, seconds}` for the entrance and exit and `{preset, period}` for the loop, or `null`, with the lengths that apply after theme defaults). An entry whose media is a compound clip or a template instance also has `nested`, the timeline object of the document inside, with places continued from the entry's. [FRAMES-8](../FRAMES-8/SPEC.md) maps sequence time to clip time and media time from these values |
| `evaluate` | `{"evaluate": "1.0.0", time, size, items}`, bottom first, each `{place, id, kind, bounds, opacity}`: the clip or op that drew it (`null` for the background, a transition cover and the fill outside the content rect), and the output rectangle it covers after its transform and mask. Inside a nested document a place continues the place of the clip that holds it (`storyline[0].media.storyline[2]`) |
| `locate` | `{"locate": "1.0.0", hits}`, topmost first: every item under the point, each `{place, id, kind}`, and for a picture of a media file also `{media, mediaTime, point}`, the point in that media's pixels |

- Fields follow [FRAMES-17](../FRAMES-17/SPEC.md): a new field is an addition, and a removed or changed one a major change. The old form is no longer printed ([the principles](../README.md#principles), no legacy keys).
- Places are those of the messages above.
- Times and lengths are written rounded to the nearest microsecond, in their shortest form (`2.85`, not `2.850000`), so floating point noise is not reported as a fact. A microsecond is far below a frame at any rate, so no frame changes.
- The display list and the mix plan are the roles' wire forms ([FRAMES-19](../FRAMES-19/SPEC.md)), not part of this output.

## Interactions

Machine output follows [FRAMES-18](../FRAMES-18/SPEC.md). Extensions are [FRAMES-25](../FRAMES-25/SPEC.md).

## Alternatives considered


## Notes
