# Guide

How an edit is made with frames, how to write a guide, a how-to and an extension, and how to change a document without changing what it shows. The rules are in the [specification](../spec/README.md), packs and templates in [PACK.md](PACK.md), presets in [PRESET.md](PRESET.md), and the commands and keys in the [README](../README.md).

## How an edit is made

An edit is made the way it is made in any NLE: look at the material, cut it, check it, and go round until it holds ([FRAMES-25](../spec/FRAMES-25/SPEC.md)). frames keeps no state between commands, so the document is the project and every command reads it again.

Run `frames` without arguments for the list of commands. Every path given to frames is absolute.

### 1. Look at the material

Know what you have before you write a time or a place.

```sh
frames probe /path/to/recording.mov
frames sheet /path/to/recording.mov -o /path/to/out/overview.png --step 1
frames sheet /path/to/recording.mov -o /path/to/out/close.png --from 1 --to 2.5 --step 0.5
```

```
kind video
size 1280x720
duration 4
fps 30
alpha no
audio 2 channels, 48000 Hz
```

- `probe` gives the size, length, frame rate, alpha and sound. Write the document's `format` from it, or decide how the material is conformed when it differs.
- Lay the whole video out with `sheet` every 1 to 2 seconds to find the parts that matter, then again every 0.5 seconds over the part you chose. Each frame is labelled with its media time. On a storyline clip without `timeRemap`, clip time is media time ([FRAMES-8](../spec/FRAMES-8/SPEC.md)), so a time read from a sheet goes straight into `in`, `out`, a connected clip's `at` and the clip's keyframes.
- Listen to the sound in a player: where speech starts and ends, where the beat falls, where a noise has to be cut around. A picture cut against the sound is decided here.
- Where a place has to be found or followed, `track` it. Where it is found by its text on screen, `ocr` the frame first. A plane seen in perspective, a screen or a sign a `cornerPin` is laid on, is followed with `--tracker planar`.

```sh
frames ocr /path/to/recording.mov --at 1
frames track /path/to/recording.mov --at 1 --area '{"text": "Total"}' --to 2
```

```
size 1280x720
[160, 185, 227, 26]  Subtotal $42.00
[160, 285, 217, 29]  Shipping $5.00
[158, 385, 180, 26]  Total $47.00
```

`ocr` prints each recognised line with its rectangle in media pixels. An area written as `{"text": "Total"}` names the whole line that contains the text, and a text that matches several lines stops and lists them, so add `nth` or a longer part of the line ([FRAMES-2](../spec/FRAMES-2/SPEC.md)). `ocr --from --to --step` reads a range and shows when a line appears, moves or leaves. `track` prints the target's quadrilateral and its motion on every frame it followed, which is what a `track` on a clip uses ([FRAMES-12](../spec/FRAMES-12/SPEC.md)).

### 2. Edit the document

Write the storyline, connected clips, titles, shapes, masks and sound. The keys of every object are in [FRAMES-7](../spec/FRAMES-7/SPEC.md).

- Cut the storyline with `in` and `out` from the sheets, and put transitions where the picture changes place or time.
- Connect titles, shapes and B-roll to the storyline clip they belong to, so they move when it moves. Put what belongs to the whole sequence (music, a logo) in `clips`.
- Give a shape or a title that sits on something in the picture `parent` set to that clip's `id`, and write its area in the clip's media pixels or by the text on screen. It then moves, scales and turns with the picture ([FRAMES-10](../spec/FRAMES-10/SPEC.md)).
- Write right-to-left text in the order it is read, as it is typed. A title takes its direction from its first strong letter, so Hebrew or Arabic needs no key, and a title that reads right to left but starts with a Latin word or a number takes `"direction": "rtl"` in its style. `evaluate` reports each title's `direction` and each character's `level`, odd where it reads right to left ([FRAMES-5](../spec/FRAMES-5/SPEC.md#direction)).
- Set Japanese, Chinese or Korean in columns with `"writingMode": "vertical-rl"` in the title's style. Ideographs and kana stand and Latin words and digits lie on their sides. Give a run a style with `"textOrientation": "upright"` to stand an acronym letter under letter, and `"textCombineUpright": "all"` to set the digits of a date side by side in one square of the column (tate-chu-yoko), as `[{"text": "令和6年"}, {"text": "12", "style": "date"}, {"text": "月"}]` with a `date` style that sets it. A composition wider than 1 em is narrowed to fit its square; a face's half-width forms, `"features": {"hwid": 1}` in the same style, fit two digits without narrowing. `evaluate` gives a composition's characters one shared `rect`, the square ([FRAMES-5](../spec/FRAMES-5/SPEC.md#horizontal-in-vertical-composition)).
- Give clips an `id` wherever a parent, a track matte, a program or a later edit will name them.
- Bring in templates from packs as media where they fit (a lower third, an end card), and graphics and effects made elsewhere as media too ([motion graphics](howto/motion-graphics.md), [effects](howto/effects.md)).
- When the edit is a kind of result that a form teaches, start from its guide and examples. `frames packs` lists the installed packs, and the forms in this repository's `packs/` are `demo`, `pr-evidence` and `shorts`. A form is a starting point, and an edit may take it, change it or leave it.

### 3. Check

Checking a document draws only what you ask for and encodes nothing.

```sh
frames timeline /path/to/work/edit.json
frames still /path/to/work/edit.json --at 1.75,2.3,3 -o /path/to/out/check.png
frames sheet /path/to/work/edit.json -o /path/to/out/range.png --from 1 --to 3 --step 0.25
```

```
duration 4
storyline[0]#intro  -  edit [0, 1)  drawn [0, 1.2)  clip [0, 1)  speed 1  transition none
storyline[1]#demo  /path/to/recording.mov  edit [1, 4)  drawn [0.8, 4)  clip [0, 3)  speed 1  transition frames/fade 0.4
storyline[1]#demo.connected[0]#ring  rect  visible [1.5, 2.4)  animation frames/fade / - / frames/fade
storyline[1]#demo.connected[1]#note  title  visible [2.2, 3.4)  animation none
storyline[1]#demo.connected[2]#badge  title  visible [1, 4)  animation none
```

- `timeline` gives every storyline clip's edit range, drawn range and clip range, and every other clip's visible range on the sequence clock. It stops on what resolve stops on: an unknown preset, a clip that is never visible, a text area that matches nothing or several lines, a parent chain with a cycle. Fix those first.
- `still` draws frames at the instants you name, side by side with their times. Put one at each entrance, each edit point, the middle of each transition and the last frame.
- `sheet` given a document lays out a range of composite frames, as `still` draws them.
- Where a check needs numbers, `evaluate --at` prints every item drawn at that instant with its bounds and opacity, and `locate --at --point` says which clip drew a point of the output and which media pixel it shows.

Go back to step 2 until it holds.

### 4. Render the master and check it

```sh
frames render /path/to/work/edit.json -o /path/to/out/edit.mov
frames sheet /path/to/out/edit.mov -o /path/to/out/edit-sheet.png --step 0.5
```

The master is ProRes with PCM sound at full quality, in the sequence's colour space. Keep it, and make delivery files from it. Lay it out with `sheet` and check it against [FRAMES-24](../spec/FRAMES-24/SPEC.md). A sheet is an SDR sRGB preview, so check the colours of a `display-p3`, `rec2020` or HDR master on a frame from `render --at`, which is written in the sequence's colour space ([FRAMES-26](../spec/FRAMES-26/SPEC.md#providers-and-analysis-pictures)):

- the first frame is not black or empty, unless the storyline opens on a solid or on black media
- during a transition both pictures show, with the transition's motion
- an unparented connected clip plays its whole window across edit points
- a parented clip moves, scales and turns with its parent through its keyframes, tracked motion and transitions, and a tracked clip stays on its target
- a time-remapped clip holds, reverses and ramps where its keys say
- a mask cuts and feathers where it names, and a track matte shows its clip only where the matte is
- keyframed values arrive at their keyframe times with their eases
- outlined text has round corners and no overlapping strokes
- the length matches the `timeline` duration to within one frame

Play it and listen as well: overlapping sounds mixed at their volumes, crossfades at transitions without a dip, fades where they are written. Then check what the form's guide asks, when the edit follows one.

### 5. Deliver

```sh
frames render /path/to/work/edit.json -o /path/to/out/edit.mov --deliver /path/to/out/edit.mp4
frames transcode /path/to/out/edit.mov -o /path/to/out/edit-small.mp4 --quality low --max 1280
frames transcode /path/to/out/edit.mov -o /path/to/out/edit.m4a
```

`--deliver` writes an `.mp4` from the same frames in the same step as the master: H.264 for an SDR colour space and HEVC Main 10 for an HDR one. `transcode` writes a delivery file from a master, an image or a sound: H.264 or HEVC (`--codec hevc`) for video, the sound alone as `.m4a`, and JPEG, HEIC or PNG for an image, at `--quality high`, `medium` (the default) or `low`, with `--max` capping the longer side. It prints the ratio to the source. HEVC looks slightly better than H.264 at the same level, and some browsers cannot play it, so H.264 is the default in an SDR colour space. An HDR file is HEVC Main 10, since H.264 holds 8 bits. The output keeps the source's colour space, and `--color-space` names another.

### 6. Reuse a render as media

A rendered master is media like any other file ([FRAMES-3](../spec/FRAMES-3/SPEC.md)). A piece rendered once (an intro, a background plate, an effect baked by an extension) comes into the next edit as a file, and is not drawn again:

```json
{ "id": "intro", "media": "/path/to/out/intro.mov" }
```

`render --at` writes one frame as a PNG, for a poster frame or a still to use elsewhere. A sequence document may also be named as media directly, where it plays as a compound clip and is drawn again with the edit.

## Writing a guide

A guide is a form's `guide.md`, read by people and agents, not by frames. A form's edits differ in how many clips, titles and shapes they hold, so a form is taught, not templated, and the guide is where its judgement is written down ([FRAMES-25](../spec/FRAMES-25/SPEC.md)). It holds:

| Section | What it says |
| --- | --- |
| What it is for | who watches the result, and where (a phone held upright, a conference screen, a product page) |
| Theme | the form's theme, what it changes from the base theme, and why |
| Format | size, frame rate, conform, and how its recurring pieces (a title card, a lower third, an end card) are built from titles, shapes and templates |
| Rules | for text, cuts, sound and length, each with a one-line reason |
| Presets | which to use and which not to, with the reason |
| Example | a document that runs once its paths are changed, and which files the paths stand for |

Write each rule so a reader can check it on the result and knows why it holds:

- Checkable: "A subtitle line holds at most 21 Korean characters, since a phone held upright shows no more at the subtitle size."
- Not checkable: "Keep subtitles short."

A rule without a reason gets broken the first time it is in the way, and a reason without a rule cannot be checked. Give both.

Keep the guide to what the form decides. How a key works belongs in the specification, and a technique that serves any form belongs in a how-to. What a guide says binds only edits made from that form.

The example is a document in `examples/`. It names its media by absolute placeholders under `/path/to/`, and the guide says which files they stand for ("`/path/to/interview.mov` is one camera on the speaker, at least 30 seconds"). Check it with `timeline` and `still` whenever frames or the pack changes. How a form is laid out as a pack is in [PACK.md](PACK.md#a-form).

## Writing a how-to

A how-to is `document/howto/<name>.md`, or `howto/<name>.md` in a pack. It teaches a technique that belongs to no form: a motion graphic, an effect beyond the filter ops, a caption track from a transcript. It has no theme and no example of its own, since the form that uses it brings both. Making material outside frames is a how-to.

A how-to shows the steps with real commands, says what frames expects of the material (size, frame rate, alpha, how files are named), and shows the document fragment that brings it in. See [motion graphics](howto/motion-graphics.md) and [effects](howto/effects.md).

## Writing an extension

An extension is a program that takes a document and gives a document. It cuts silence out of an interview, cuts B-roll to the beats of a track, places captions from a transcript, translates titles, or bakes an effect frames has no op for. frames has no extension API: an extension reads what frames reports ([FRAMES-23](../spec/FRAMES-23/SPEC.md)) and writes JSON.

- `frames <name>` runs `frames-<name>` from `PATH`, with the global options frames was given first and then the arguments written after the name, unchanged. Standard input and output pass through. Installing an extension is putting it on `PATH`.
- It finds clips by `id` and with `timeline --json`, where things are with `evaluate` and `locate`, and what is drawn with `still`, `extract` and `sheet`. All of these take the document itself, so what it sees is what frames draws from the same resolve.
- It writes its document to standard output, and `timeline` checks the result like any other document. Extensions chain: `frames autocut /path/to/interview.json | frames captions - | frames render - -o /path/to/out/interview.mov`.
- It keeps what it knows about a clip in the clip's `metadata`, which frames does not read: which extension added the clip and why.
- It checks `frames --version` against the versions it is written for, as a pack does with `engine`.
- It acts before resolve. What must act while frames renders is a role or a provider, so a resolved document stays enough to make the result again.
- An extension that must be sure of what is drawn (one that keeps captions clear of other text on screen, or one that covers a region) resolves the document once with `frames resolve`, checks that resolved document with `evaluate`, `still` and `extract`, and passes it on to be rendered. It does not read or change the resolved document, whose form is frames' own. Only frames commands take a resolved document, so such an extension runs last in a chain, and a chain has one.

### A minimal extension

`frames-number` puts `1/3`, `2/3`, ... in the top right corner over each storyline clip. It reads the edit ranges from `timeline --json` and adds one title per storyline clip to `clips`. It needs `jq`.

```sh
#!/bin/bash
# frames-number: puts "1/3", "2/3", ... in the top right corner over each storyline clip of a sequence.
# Usage: frames [global options] number <document.json | ->
set -eo pipefail

# frames passes its global options first, then the arguments written after the name.
document=${!#}
options=("${@:1:$#-1}")

# The document is read twice, by frames and by jq, so keep it in a file.
input=$(mktemp)
trap 'rm -f "$input"' EXIT
if [ "$document" = "-" ]; then cat > "$input"; else cat "$document" > "$input"; fi

frames "${options[@]}" timeline - --json < "$input" |
jq --slurpfile document "$input" '
    (.storyline | length) as $count
    | $document[0] + { clips: (($document[0].clips // []) + [
        .storyline | to_entries[] | {
            at: .value.edit,
            title: "\(.key + 1)/\($count)",
            style: "subtitle",
            placement: "top-right",
            animation: "none",
            lane: 9,
            metadata: { by: "frames-number", clip: (.value.id // .value.place) }
        } ]) }'
```

```sh
install -m 755 /path/to/frames-number /usr/local/bin/
frames number /path/to/work/edit.json > /path/to/work/numbered.json
frames timeline /path/to/work/numbered.json
frames number /path/to/work/edit.json | frames still - --at 0.5,1.5,3 -o /path/to/out/numbered.png
```

```
duration 4
storyline[0]#intro  -  edit [0, 1)  drawn [0, 1.2)  clip [0, 1)  speed 1  transition none
...
clips[0]  title  visible [0, 1)  animation none
clips[1]  title  visible [1, 2)  animation none
clips[2]  title  visible [2, 4)  animation none
```

What it relies on:

- `timeline --json` gives each storyline clip's `edit` range as `[start, end)` in sequence seconds, which is the clock of a sequence clip's `at`, so the range goes straight into the title.
- The global options are passed on to the `frames` it calls, so `frames --theme <pack>/<name> number /path/to/work/edit.json` reads the timeline under that theme.
- Each added title says in `metadata` which extension added it and for which clip, so a later run, or another extension, can find and replace them.

## Editing without changing what is shown

An edit (a blade, a trim, a ripple delete, a move) is a document in and a document out, since frames keeps no state between commands for an edit to act on. You or an extension write it, and `timeline` checks the result like any other document. An edit that only restructures, such as a blade, leaves every frame as it was when it keeps these rules ([FRAMES-25](../spec/FRAMES-25/SPEC.md)).

A blade through a storyline clip:

- **Ids.** The first part keeps the clip's `id`, and the others take new ones.
- **Keyframes.** Every part keeps all the clip's keyframes, its `timeRemap` included. They are on its clip time, which a blade does not change.
- **Transitions and fades.** The incoming `transition` and `fadeIn` stay on the first part, and the `fadeOut` goes to the last.
- **The cut.** Every later part takes `"transition": "cut"`, so a theme's default transition does not play at the edit point.
- **Connected clips** go with the part that holds their start. On a video or other timed media their `at` and keyframes do not change. One without `at` first takes its storyline clip's edit range in clip time as `at` (`[in, out]` of the clip before the blade), since it would otherwise span only the part it goes with.
- **`parent` and `trackMatte`.** A `parent` or a track matte's `clip` that named the bladed clip names the part its own clip goes with.
- **Parented connected clips across the cut.** A connected clip parented to the bladed clip whose window crosses the cut is copied onto each part. Each copy is parented to its part, its window is cut at the edit point, and its exit is turned off before the cut and its entrance after it: `{ "entrance": "frames/fade", "exit": "none" }` and `{ "entrance": "none", "exit": "frames/fade" }`. A parent outside its window holds the transform it has at the window's edge ([FRAMES-10](../spec/FRAMES-10/SPEC.md)), so a copy left on one part would freeze there instead of following the picture.
- **Still and solid clips.** Their clip time counts from their own start, so every part after the first moves its own keyframes, and the `at` and keyframes of its connected clips, back by where that part starts.
- **Ripple.** After a trim or delete that closes the gap, later storyline clips and what is connected to them move by themselves. Every later sequence clip in `clips`, which is on the sequence clock, moves its `at` and its keyframes by the same amount.

### A blade, worked

Before: a recording after a title card. It comes in with a dissolve, pushes in slowly, and fades out. A rect parented to it rings `Total` and fades in and out, a note parented to it points at the line, and a `DEMO` tag spans the whole clip.

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "id": "intro", "solid": "#111827", "duration": 1 },
    { "id": "demo", "media": "/path/to/recording.mov", "in": 0, "out": 3,
      "transition": "frames/fade", "fadeOut": 0.5,
      "keyframes": [ { "at": 0, "scale": 1, "ease": "ease-in-out" }, { "at": 3, "scale": 1.1 } ],
      "connected": [
        { "id": "ring", "at": [0.5, 1.4], "parent": "demo", "shape": "rect", "area": { "text": "Total", "padding": 8 },
          "stroke": { "color": "#F59E0B", "width": 4 }, "radius": 6, "animation": "frames/fade" },
        { "id": "note", "at": [1.2, 2.4], "parent": "demo", "title": "Shipping is added here", "style": "subtitle",
          "anchor": "top-left", "position": [420, 380] },
        { "id": "badge", "title": "DEMO", "style": "subtitle", "placement": "top-right" } ] }
  ] }
```

After a blade at clip second 1 of `demo`, which is sequence second 2:

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "id": "intro", "solid": "#111827", "duration": 1 },
    { "id": "demo", "media": "/path/to/recording.mov", "in": 0, "out": 1,
      "transition": "frames/fade",
      "keyframes": [ { "at": 0, "scale": 1, "ease": "ease-in-out" }, { "at": 3, "scale": 1.1 } ],
      "connected": [
        { "id": "ring", "at": [0.5, 1], "parent": "demo", "shape": "rect", "area": { "text": "Total", "padding": 8 },
          "stroke": { "color": "#F59E0B", "width": 4 }, "radius": 6,
          "animation": { "entrance": "frames/fade", "exit": "none" } },
        { "id": "badge", "at": [0, 3], "title": "DEMO", "style": "subtitle", "placement": "top-right" } ] },
    { "id": "demo-2", "media": "/path/to/recording.mov", "in": 1, "out": 3,
      "transition": "cut", "fadeOut": 0.5,
      "keyframes": [ { "at": 0, "scale": 1, "ease": "ease-in-out" }, { "at": 3, "scale": 1.1 } ],
      "connected": [
        { "id": "ring-2", "at": [1, 1.4], "parent": "demo-2", "shape": "rect", "area": { "text": "Total", "padding": 8 },
          "stroke": { "color": "#F59E0B", "width": 4 }, "radius": 6,
          "animation": { "entrance": "none", "exit": "frames/fade" } },
        { "id": "note", "at": [1.2, 2.4], "parent": "demo-2", "title": "Shipping is added here", "style": "subtitle",
          "anchor": "top-left", "position": [420, 380] } ] }
  ] }
```

- `demo` keeps its id, the dissolve in and the start of the media. `demo-2` takes the rest, the `fadeOut`, and a `cut` in. Both keep the push in, whose keyframes are on clip time, so the scale runs on across the edit point without a jump.
- The ring is parented to `demo` and crosses the cut, so each part gets a copy parented to it, with its window cut at clip second 1: `ring` from sequence second 1.5 to 2, `ring-2` from 2 to 2.4. Its fade in stays on the first and its fade out on the second.
- The note starts at clip second 1.2, inside `demo-2`, so it goes there with the same `at`, and its parent becomes `demo-2`.
- The tag had no `at`, so it first takes `demo`'s edit range in clip time, `[0, 3]`, and stays on `demo`. Unparented, it plays its whole window across the edit point.
- `ring-2` starts at the edit point, so its text area is searched in the frame there and not at clip second 0.5. On a screen that moves, write the rectangle `ocr` reports at the original start instead of the text.

Check that nothing moved: `timeline` gives the same duration and the same visible ranges, and `still` at the same instants draws the same frames.

```sh
frames timeline /path/to/work/after.json
for t in 0.9 1.5 1.75 1.99 2 2.1 2.3 2.39 3 3.7 3.99; do
  frames still /path/to/work/before.json --at $t -o /path/to/work/before.png > /dev/null
  frames still /path/to/work/after.json --at $t -o /path/to/work/after.png > /dev/null
  cmp -s /path/to/work/before.png /path/to/work/after.png && echo "$t same" || echo "$t differs"
done
```

The instants cover the dissolve, the ring's entrance, the frames on each side of the edit point, the ring's exit, the note and the fade out. Every one should print `same`.

A blade through a solid works the same way, except that every later part moves its own keyframes, and the `at` and keyframes of its connected clips, back by where it starts. A 2 second title card bladed at 0.5, with a subtitle connected at `[1, 1.8]` that slides down:

```json
{ "id": "card", "solid": "#111827", "duration": 0.5,
  "connected": [ { "id": "head", "at": [0.2, 1.8], "title": "Checkout", "style": "title" } ] },
{ "id": "card-2", "solid": "#111827", "duration": 1.5, "transition": "cut",
  "connected": [
    { "id": "sub", "at": [0.5, 1.3], "title": "now with shipping", "style": "subtitle",
      "keyframes": [ { "at": 0.5, "position": [640, 420] }, { "at": 1.3, "position": [640, 520] } ] } ] }
```

The heading starts on `card` and stays there with its window unchanged. The subtitle starts on `card-2`, so its `at` and keyframes move back by 0.5, where `card-2` starts.

## Practical notes

These are not contract, but help whoever writes documents.

- OCR confuses similar characters (`0` and `O`). Read the `ocr` output before pointing, and point with a part of the line that is less confusable, plus `nth`.
- A shape placed by text while the screen is still moving lands where the text was at its start. Start it after the screen settles, or follow the text with `track`.
- A shape found on one screen stays where that text was. When the recording changes screens, end the shape at the change, or start another on the new screen.
- PNG is lossless and does not shrink when written again. Use JPEG or HEIC for smaller stills.
