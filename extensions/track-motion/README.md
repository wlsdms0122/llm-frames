# track-motion

`frames-track-motion` is an extension of frames: it takes a document whose clips may ask for a target to be followed through their media, and gives the same document with each request written as the track data `frames track` prints for it, so the result is a plain frames document that any frames command takes.

```sh
frames track-motion /path/to/edit.json | frames render - -o /path/to/out/edit.mp4
```

frames takes a clip's `track` as track data `{"time": t, "frames": [...]}` alone ([FRAMES-12](../../spec/FRAMES-12/SPEC.md#track-data)), and `frames track` follows a rectangle or a quadrilateral in a video or an image sequence and prints that data. This extension joins the two: it reads only frames' machine output (`timeline --json`, `timeline --at <t> --json` and `track`), never a resolved document, and links no frames code. A target named by its text on screen is written as a rectangle by [`frames find-text`](../find-text/README.md) first:

```sh
frames find-text /path/to/edit.json | frames track-motion - | frames render - -o /path/to/out/edit.mp4
```

## Install

It is one Python 3 script that uses the standard library alone. Copy or link it into a directory on `PATH`:

```sh
ln -s "$PWD/extensions/track-motion/frames-track-motion" /usr/local/bin/frames-track-motion
```

`frames track-motion` then runs it, with the global options written before `track-motion` (`--tracker` and the other role options) passed to every frames command it runs, so `frames --tracker planar track-motion edit.json` follows every target with the `planar` tracker. It runs the `frames` on `PATH`, or the executable the environment variable `FRAMES_EXECUTABLE` names. It is written for frames 0.x and stops on another major version.

```
frames track-motion <document.json | ->
```

`<document.json>` is an absolute path, or `-` for standard input. The document is printed to standard output, and a stop prints `frames-track-motion: <reason>` to standard error and exits with 1.

## The requests

A request is the value of a clip's `track`. It names a **target**, what is followed, and the **track's frame**, the frame of the tracked media on which the clip's values are written, where the track's motion is the identity:

| `track` | Target | Track's frame |
| --- | --- | --- |
| `true` | the clip's own geometry | the frame the clip's instant shows |
| an area `[x, y, w, h]` | that area | the frame the clip's instant shows |
| `{"time": t}` | the clip's own geometry | the frame media time t names |
| `{"time": t, "area": [x, y, w, h]}` | that area | the frame media time t names |

- Track data, an object with `frames`, is no request and is kept as written.
- A target area is a rectangle in the media pixels the track follows. A place named by its text stops, naming `frames find-text`, which writes it as a rectangle, and a clip area `{"clip": ...}` stops, since no report gives another clip's box in those pixels.
- A request object holds `time` and `area` alone, and any other key stops.
- The clip's own geometry is the one of its `area` (a rect or ellipse placed by area), its `cornerPin`, its `crop` written as an area and its `mask` that lies in the media pixels its track follows. A clip with more than one of these there, or none, stops, since it must name its target. A crop written as `{"scale": s}` is no area.
- A corner pin is followed from its quadrilateral, its four points in their order, with `frames track --quad`, so with `--tracker planar` it is followed in perspective. A corner pin with a point that names a clip area stops.
## Where it works

Every fact the extension acts on is in a report of the document without its requests (it removes every `track`, since a request is no value frames takes):

- `tracked` of the clip's `timeline --json` entry ([FRAMES-23](../../spec/FRAMES-23/SPEC.md#a-clips-times-and-spaces)): `clip`, the place of the clip whose video or image sequence the track follows, and `first` and `last`, the first and the last frame of that media the clip is followed over. A clip whose `tracked` is `null` stops, since there is no video or image sequence to follow.
- `media` and `fps` of the entry at `tracked.clip`: the file or image sequence directory given to `frames track`, with `fps` as `--fps` for an image sequence.
- `space` and `ownSpace` of the clip's entry: which of its own keys lie in the media pixels its track follows.
- `instant` of the clip's entry, and the `mediaTime` of the entry at `tracked.clip` in `timeline --at <instant> --json`: the frame the clip's instant shows, `speed`, `in`, `loop`, `timeRemap` and a parent's time map applied by frames.

The target is followed with `frames track` from the track's frame to `first`, and from it to `last`, as `--to`, and the frames of both are joined in time order, so it is followed over every frame the clip can show and no further. The tracked clip's `colorSpace`, as the document writes it, is given as `--color-space`. A `track` that stops (a target lost on its own frame, a time past the media) stops the extension with frames' message.

## What it does not cover

Where a fact is in no report, the extension stops and names it:

- The bounds of a clip's masks, which `true` would follow on a clip whose target is its `mask`: `evaluate` reports no masks, and a path mask, a mask placed by its size or a keyframed one has no rectangle written in the document. Name the area to follow.
- A keyframed target of `true`: its track's frame is the one its first keyframe's time shows, and no report gives a keyframe's sequence time. Name the area and the frame with `{"time": t, "area": a}`. With `{"time": t}` a keyframed target stops as well, since a keyframe's value is where it is at its own time and none is written on the frame t names.
- Requests inside a compound clip or template instance, or inside a sequence document named as media by its file: `timeline --at` gives a nested document's clips only at the outer sequence's times. Run the extension on the nested document first.

## Example

A box kept on a moving card in a shot, written by eye on the frame the box's instant shows:

```json
{
  "kind": "sequence",
  "format": { "size": [640, 360], "fps": 25 },
  "storyline": [
    { "id": "shot", "media": "/path/to/shot.mp4",
      "connected": [
        { "at": [0.4, 2.6], "parent": "shot", "shape": "rect", "area": [150, 194, 132, 92],
          "stroke": { "width": 4, "color": "#3DDC84" }, "track": true } ] }
  ]
}
```

```sh
frames track-motion /path/to/box.json > /path/to/out/box.frames.json
frames render /path/to/out/box.frames.json --at 2 -o /path/to/out/check.png
```

The box's `track` is written as the track data of the area followed through the shot from the frame at 0.4 seconds to the frames the box shows.

## Check

The check runs without frames, on frames output recorded in `fixtures/`:

```sh
python3 -m unittest discover -s extensions/track-motion
```
