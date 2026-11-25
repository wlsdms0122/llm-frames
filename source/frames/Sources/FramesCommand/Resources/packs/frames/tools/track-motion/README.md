# frames/track-motion

`frames/track-motion` is a tool of the pack `frames`, which ships with frames ([FRAMES-25](../../../../../../../../../spec/FRAMES-25/SPEC.md#tools)): it takes a document whose clips' `track` may hold a request for it, a target to be followed through their media, and gives the same document with each of those requests filled with the track data `frames track` prints for it, so once every request in it is filled the result is a plain frames document that any frames command takes.

```sh
frames frames/track-motion /path/to/edit.json | frames render - -o /path/to/out/edit.mp4
```

frames takes a clip's `track` as track data `{"time": t, "frames": [...]}` alone ([FRAMES-12](../../../../../../../../../spec/FRAMES-12/SPEC.md#track-data)), and `frames track` follows a rectangle or a quadrilateral in a video or an image sequence and prints that data. This tool joins the two: it reads only frames' machine output (`timeline --json`, `timeline --at <t> --json` and `track`), never a resolved document, and links no frames code. A target named by its text on screen is the clip's own `area` holding a request for [`frames/find-text`](../find-text/README.md), which runs first:

```sh
frames frames/find-text /path/to/edit.json | frames frames/track-motion - | frames render - -o /path/to/out/edit.mp4
```

## Running it

It is one Python 3 script that uses the standard library alone, in the tool's directory of the pack `frames`, `packs/frames/tools/track-motion/` in `Frames_FramesCommand.bundle` beside the frames executable, so it is there wherever frames is. `frames frames/track-motion` runs it, with the global options written before `frames/track-motion` (`--tracker` and the other role options) passed to every frames command it runs, so `frames --tracker planar frames/track-motion /path/to/edit.json` follows every target with the `planar` tracker, and with `FRAMES_EXECUTABLE` set to the frames that runs it, which it runs for every frames command it needs. The pack's `engine` is the frames it is written for, which frames checks before it runs the tool. Run by anything but frames, a document that holds a request for it stops, since `FRAMES_EXECUTABLE` is not set.

```
frames frames/track-motion <document.json | ->
```

`<document.json>` is an absolute path, or `-` for standard input. The document is printed to standard output, and a stop prints `frames/track-motion: <reason>` to standard error and exits with 1. Where a frames command it runs fails, the reason is the command line it ran, with the global options it passed, and what frames printed.

## The requests

A request is a hole a tool fills ([FRAMES-25](../../../../../../../../../spec/FRAMES-25/SPEC.md#requests)): an object with the key `tool`, which names the tool, and that tool's arguments beside it. This tool fills the requests whose `tool` is `frames/track-motion`, standing as a clip's `track`:

```json
"track": { "tool": "frames/track-motion", "target": "area" }
"track": { "tool": "frames/track-motion", "target": [150, 194, 132, 92] }
```

A track says how a clip moves with something in its media. It is followed from one frame, the **frame the target is written on**, where the clip stands as written, and on every other frame the clip moves as that thing moved from there. That frame is the one the clip's instant shows (where the clip starts, or a storyline clip's `in`), and where the named key is keyframed, the one its first keyframe shows, as `frames timeline` reports them. The target and the clip's values are written on it. So a request says one thing:

- `target`, required: **what is followed**, a box around the thing on that frame. It is the name of one of the clip's own keys, `area`, `cornerPin`, `crop` or `mask`, whose value is that box, or an area `[x, y, w, h]` written in the request. Either is in the media pixels the track follows, the pixels of the video the clip is parented to, or of the clip's own video for a storyline clip's `crop` and `mask`.

**A worked example.** A shot shows a card that slides right, and a green box is to stay on the card from 0.4 seconds.

1. Find the frame: the box starts at 0.4 seconds, so the frame the shot shows there is the one it is written on. `frames extract /path/to/shot.mp4 /path/to/out/frames --from 0.4 --to 0.44` writes that frame, the one frame from 0.4 seconds up to the next, as a PNG, in the shot's pixels.
2. Write the box over the card on that frame, in that frame's pixels: the card's top left corner is at 150, 194 and it is 132 by 92, so the box's `area` is `[150, 194, 132, 92]`.
3. Name the box as the target: `"track": { "tool": "frames/track-motion", "target": "area" }`.

The tool follows the card from that frame backwards and forwards, and writes what it found as the box's `track`. On the frame at 0.4 seconds the box is where it is written, and on every other frame it is where the card went.

- A target written beside the clip's own keys, `"target": [x, y, w, h]`, follows a thing other than the box, as a title written beside the card that moves with it. It is written on the same frame, the one the clip's instant shows.
- A target key filled by `frames/find-text` is found on the frame the clip's instant shows, and a keyframe's on the frame that keyframe shows, so the track starts from the rectangle found on its own frame. A track followed from any other frame is track data written by `frames track` or another tool.
- A key the clip does not write stops, and so does one that is not in the media pixels the track follows (a title's own box, output pixels). A crop written as `{"scale": s}` is no area and stops.
- A key named as the target that still holds a request stops, naming that request, since the target is the value it finds: run that tool first. A target that is itself a request stops, since a request's arguments are values: write the request in the clip's own key and name the key.
- A target that names `mask` stops, since no report gives the bounds of a clip's masks: write the area to follow.
- A keyframed target key is the value of its first keyframe, the one at the earliest `at` and, of those written at that `at`, the one written last, which the key takes there.
- A corner pin is followed from its quadrilateral, its four points in their order, with `frames track --quad`, so with `--tracker planar` it is followed in perspective. A corner pin with a point that names a clip area stops.
- A clip area `{"clip": ...}` as the target stops, since no report gives another clip's box in the media pixels followed.
- A request holds `tool` and `target` alone, and any other key stops. A request for this tool anywhere but a clip's `track` stops.
- Track data, and a request for any other tool, are left as written, so this tool and another chain in either order where neither needs a value the other finds.

## Where it works

Every fact the tool acts on is in a report of a copy of the document with a value in the place of every request, its own and every other tool's, since frames takes none: no `track` where a track request stands, and a placeholder rectangle where an area stands, since a clip's times, spaces and tracked frames do not depend on them. A request of another tool anywhere else has no such value, and stops, naming the tool that fills it first.

- `tracked` of the clip's `timeline --json` entry ([FRAMES-23](../../../../../../../../../spec/FRAMES-23/SPEC.md#a-clips-times-and-spaces)): `clip`, the place of the clip whose video or image sequence the track follows, and `first` and `last`, the first and the last frame of that media the clip is followed over. A clip whose `tracked` is `null` stops, since there is no video or image sequence to follow.
- `media` and `fps` of the entry at `tracked.clip`: the file or image sequence directory given to `frames track`, with `fps` as `--fps` for an image sequence.
- `space` and `ownSpace` of the clip's entry: whether the key a request names lies in the media pixels its track follows.
- `instant` of the clip's entry, and the `mediaTime` of the entry at `tracked.clip` in `timeline --at <instant> --json`: the frame the clip's instant shows, `speed`, `in`, `loop`, `timeRemap` and a parent's time map applied by frames.
- `clock` of the clip's entry, `{clip, origin, speed}`, the map frames reports from the times the clip writes to sequence time: a keyframed target's first keyframe lies at sequence time `origin + at / speed`, and the `mediaTime` of the entry at `tracked.clip` in `timeline --at` at that time is the frame it shows. The tool applies the map as reported and derives no rule of its own.

The target is followed with `frames track` from the track's frame to `first`, and from it to `last`, as `--to`, and the frames of both are joined in time order, so it is followed over every frame the clip can show and no further. The tracked clip's `colorSpace`, as the document writes it, is given as `--color-space`. A `track` that stops (a target lost on its own frame, a time past the media) stops the tool with the command line it ran and frames' message.

## What it does not cover

Where a fact is in no report, the tool stops and names it:

- The bounds of a clip's masks, which a target `mask` would follow: `evaluate` reports no masks, and a path mask, a mask placed by its size or a keyframed one has no rectangle written in the document. Write the area to follow.
- Requests inside a compound clip or template instance, or inside a sequence document named as media by its file: `timeline --at` gives a nested document's clips only at the outer sequence's times. Run the tool on the nested document first.

## Example

The box of the worked example, kept on the moving card:

```json
{
  "kind": "sequence",
  "format": { "size": [640, 360], "fps": 25 },
  "storyline": [
    { "id": "shot", "kind": "media", "media": "/path/to/shot.mp4",
      "connected": [
        { "at": [0.4, 2.6], "parent": "shot", "kind": "rect", "area": [150, 194, 132, 92],
          "stroke": { "width": 4, "paint": "#3DDC84" }, "track": { "tool": "frames/track-motion", "target": "area" } } ] }
  ]
}
```

```sh
frames frames/track-motion /path/to/box.json > /path/to/out/box.frames.json
frames render /path/to/out/box.frames.json --at 2 -o /path/to/out/check.png
```

The box's `track` is filled with the track data of its area followed through the shot from the frame at 0.4 seconds to the frames the box shows.

## Check

The check runs without frames, on frames output recorded in `source/frames/Tests/tools/track-motion/fixtures/`, from the repository root:

```sh
python3 -m unittest discover -s source/frames/Tests/tools/track-motion
```
