# Guide

How to work with frames: how to make anything, how to write a guide, a how-to and an extension, and how to change a document without changing what it shows. The rules themselves are in the [specification](../spec/README.md), and the commands and keys in the [README](../README.md).

## How to make anything

The same six steps make a PR screenshot, a short or a demo ([FRAMES-25](../spec/FRAMES-25/SPEC.md)).

### 1. Pick the form and read its guide

A form is a kind of result, kept as a pack. Its guide says who the result is for, its format, and the rules it keeps. Its examples are documents to start from.

```sh
frames packs                                   # installed packs
frames packs shorts                            # what one holds: theme, presets, templates, media
cat ~/.config/frames/packs/shorts/guide.md
cp ~/.config/frames/packs/shorts/examples/checkout.json /path/to/work/short.json
```

When no form fits, work on the base theme and keep the rules of the closest form that apply.

### 2. Look at the material

Know what you have before you write a time or an area.

```sh
frames probe /path/to/recording.mp4                                   # size, length, frame rate, sound
frames sheet /path/to/recording.mp4 -o /path/to/out/overview.png --step 1
frames sheet /path/to/recording.mp4 -o /path/to/out/close.png --from 0.5 --to 2 --step 0.5
frames ocr /path/to/recording.mp4 --at 1
```

- Lay the whole video out every 1 to 2 seconds to find the moments that matter, then again every 0.5 seconds over the range you chose. Each frame in a sheet is labelled with its media time, which is the time you write for anything connected to that clip.
- Read the text you will point at with `ocr` at the frame where the area takes effect. Pick a part of the line that is unique on that screen and that OCR reads reliably.
- `ocr --json` gives exact rectangles, and over a range (`--from --to --step`) it shows when a line appears, moves or leaves.

### 3. Write the document

Start from the form's example. Then:

- Point at places by their text (`"area": "Total"`), not by measured rectangles, so a new recording of the same screen still works.
- Write connected instants in clip seconds, which for a video are the media seconds the sheet showed.
- Use templates from packs as media where they fit (an intro, an end card), and keep everything else in the document.
- Give clips an `id` when a program or a later edit will need to find them.

Check it while you write, which is cheap and encodes nothing:

```sh
frames timeline /path/to/work/short.json                      # times, transitions, and every stop resolve would hit
frames still /path/to/work/short.json --at 0.5,2,4.2 -o /path/to/out/check.png
```

`timeline` stops on what render would stop on: an unknown preset, a clip that is never visible, a label with no room, an ambiguous text area. Fix those before anything else. Then put `still` frames at the moments that matter: each entrance, each edit point, the last frame.

### 4. Render the master

```sh
frames render /path/to/work/short.json -o /path/to/out/short.mov
```

The master is ProRes with PCM sound at full quality. Keep it, and make smaller files from it. `--deliver /path/to/out/short.mp4` writes an H.264 delivery file from the same frames in the same step.

### 5. Check the result

```sh
frames sheet /path/to/out/short.mov -o /path/to/out/result.png --step 0.5
```

Check the sheet against [FRAMES-24](../spec/FRAMES-24/SPEC.md):

- the first frame is not black or empty, unless the storyline opens on a solid
- nothing of a cropped or moving clip shows outside the content rect
- both clips show during a transition, and boxes on a picture leave with it
- boxes stay on the text they point at, through zooms and scrolls
- labels sit on the first side the theme allows that has room
- outlined text has round corners and no overlapping strokes
- the length matches the `timeline` duration

Then check what the form's guide asks, such as personal data covered on every frame.

### 6. Transcode for where it goes

```sh
frames transcode /path/to/out/short.mov -o /path/to/out/short.mp4 --quality medium
frames transcode /path/to/out/evidence.png -o /path/to/out/evidence.jpg --quality high --max 1600
```

## Writing a guide

A guide is a form's `guide.md`, read by people and agents, not by frames. A form's edits differ in how many clips, boxes and lines they hold, so a form is taught, not templated: the guide is where the judgement goes. It holds:

| Section | What it says |
| --- | --- |
| What it is for | who watches the result, and where (a PR review in a browser, a phone held upright, a product page) |
| Theme | the theme's name and what it changes from the base theme, and why |
| Format | size, inset, conform, and how the top band or banner is built from titles |
| Rules | for text, emphasis, cuts and length, each with a one-line reason |
| Presets | which to use and which not to, with the reason |
| Example | a document that runs once its paths are changed, and which files the paths stand for |

Write each rule so a reader can check it on the result and knows why it holds:

- Good: "One subtitle line holds at most 21 Korean characters, since a phone held upright shows no more at the subtitle size."
- Not useful: "Keep subtitles short."

A rule without a reason gets broken the first time it is in the way. A reason without a rule cannot be checked. Give both.

Keep the guide to what the form decides. How a key works belongs in the spec, and a technique that serves any form belongs in a how-to.

The example is a document in `examples/`. It names its media by absolute paths under `/path/to/`, and the guide's example section says at its top which files they stand for ("`/path/to/screen.mp4` is a screen recording of the change, at least 5 seconds"). An example has to run once those paths are changed, so check it with `timeline` and `still` whenever frames or the pack changes.

## Writing a how-to

A how-to is `document/howto/<name>.md`, or `howto/<name>.md` in a pack. It teaches a technique that belongs to no form: making a motion graphic, an effect beyond the filters, a caption track from a transcript. It has no theme and no example of its own, since whatever form uses it brings both. Making material outside frames is always a how-to, since frames composites media and does not generate it.

A how-to shows the steps with real commands, says what frames expects of the material (size, frame rate, alpha, how it is named), and shows the document fragment that brings it in. See [motion graphics](howto/motion-graphics.md) and [effects](howto/effects.md).

## Writing an extension

An extension is a program that takes a document and gives a document. It finds personal data and covers it, cuts silence, places captions from a transcript, cuts to a beat, translates titles. frames has no extension API: an extension reads what frames reports ([FRAMES-23](../spec/FRAMES-23/SPEC.md)) and writes JSON.

- `frames <name>` runs `frames-<name>` from `PATH`, with the global options frames was given first and then the arguments written after the name. Standard input and output pass through. Installing an extension is putting it on `PATH`.
- It finds clips by `id` and with `timeline --json`, where things are with `evaluate` and `locate`, and what is drawn with `still`, `extract` and `sheet`. All of these take the document itself, so what it sees is what frames draws.
- It writes its document to standard output, so extensions chain: `frames autocut doc.json | frames privacy - | frames render - -o out.mov`.
- It keeps what it knows about a clip in that clip's `metadata`, which frames does not read: which extension added it and why.
- It checks `frames --version` against the versions it is written for.
- It acts before resolve. Something that must happen while frames renders is a role or a provider, not an extension.
- An extension that must be sure of what is drawn, such as one that covers personal data, resolves the document once, checks that resolved document with `evaluate`, `still` and `extract`, and passes it on to be rendered. It does not read or change the resolved document, whose form is frames' own. Since only frames commands take a resolved document, such an extension runs last in a chain.

### A minimal extension

`frames-number` puts `1/3`, `2/3`, ... in the top right corner over each storyline clip. It reads the edit ranges from `timeline --json` and adds one title per clip to `clips`. It needs `jq`.

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
            style: "label",
            placement: "top-right",
            animation: "none",
            lane: 9,
            metadata: { by: "frames-number", clip: (.value.id // .value.place) }
        } ]) }'
```

```sh
chmod +x frames-number && mv frames-number /usr/local/bin/
frames number /path/to/work/short.json > /path/to/work/numbered.json
frames number /path/to/work/short.json | frames still - --at 0.5,3 -o /path/to/out/numbered.png
```

What it relies on:

- `timeline --json` gives each storyline clip's `edit` range as `[start, end)` in sequence seconds, which is the clock of a sequence clip's `at`, so the range goes straight into the title.
- The global options are passed on to the `frames` it calls, so `frames --theme shorts/shorts number doc.json` reads the timeline under that theme.
- Each added title says in `metadata` which extension added it and for which clip, so a later run, or another extension, can find and replace them.

## Editing without changing what is shown

frames keeps no state between commands, so an edit (a blade, a trim, a ripple delete, a move) is a document in and a document out, written by you or an extension. `timeline` checks the result like any other document. An edit that only restructures, such as a split, should leave every frame as it was. These rules keep it so:

- **Split.** The first part keeps the clip's `id`, and the others take new ones. Its incoming `transition` and `fadeIn` stay on the first part and its `fadeOut` goes to the last. Every later part takes `"transition": "cut"`, so a theme's default transition does not play at the split.
- **Unparented connected clips** (titles, media without `parent`) go with the part that holds their start. Their `at` does not change, since on a video clip time is media time. One without `at` spans its storyline clip's edit range, so write its `at` before splitting, or it shrinks to one part.
- **Parented clips** (shapes and adjustments placed by an area, and clips with `parent: true`) that cross the cut are copied onto each part, keeping their `at`. The copy before the cut has its exit turned off and the copy after it has its entrance turned off: `{ "entrance": "frames/fade", "exit": "none" }` and `{ "entrance": "none", "exit": "frames/fade" }`. A loop starts again on the second part.
- **Still and solid clips** count clip time from their own start, so on every part after the first, connected `at` and keyframes move back by where that part starts.
- **Ripple** (a trim or delete that closes the gap). Later storyline clips and what is connected to them move by themselves. Every later sequence clip in `clips`, which is on the sequence clock, moves its `at` and its keyframes by the same amount.

### A split, worked

Before: a recording after a title card, with a box that fades in and out around `Total` and a subtitle.

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "id": "intro", "solid": "#111827", "duration": 1 },
    { "id": "demo", "media": "/path/to/recording.mp4", "in": 0, "out": 3, "transition": "frames/fade", "fadeOut": 0.5,
      "connected": [
        { "id": "ring", "at": [0.5, 1.4], "shape": "box", "area": "Total", "animation": "frames/fade" },
        { "id": "note", "at": [1.2, 2.4], "title": "Shipping is added here", "style": "subtitle" } ] }
  ] }
```

After a blade at media second 1 of `demo`:

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "id": "intro", "solid": "#111827", "duration": 1 },
    { "id": "demo", "media": "/path/to/recording.mp4", "in": 0, "out": 1, "transition": "frames/fade",
      "connected": [
        { "id": "ring", "at": [0.5, 1.4], "shape": "box", "area": "Total",
          "animation": { "entrance": "frames/fade", "exit": "none" } } ] },
    { "id": "demo-2", "media": "/path/to/recording.mp4", "in": 1, "out": 3, "transition": "cut", "fadeOut": 0.5,
      "connected": [
        { "id": "ring-2", "at": [0.5, 1.4], "shape": "box", "area": "Total",
          "animation": { "entrance": "none", "exit": "frames/fade" } },
        { "id": "note", "at": [1.2, 2.4], "title": "Shipping is added here", "style": "subtitle" } ] }
  ] }
```

- `demo` keeps its id, the `frames/fade` in and the start of the media. `demo-2` takes the rest, the `fadeOut`, and a `cut` in.
- The box crosses the cut, so both parts get a copy with the same `at`. Each copy is drawn only where its window meets its part: `ring` from 1.5 to 2, `ring-2` from 2 to 2.4 on the sequence clock. Its fade in stays on the first and its fade out on the second.
- The subtitle starts at media second 1.2, inside `demo-2`, so it moves there unchanged.

Check that nothing moved: `timeline` shows the same duration, and `evaluate` gives the same items at any time, only with new places.

```sh
frames timeline /path/to/work/after.json
for t in 1.6 1.99 2 2.2 2.35 3; do
  diff <(frames evaluate /path/to/work/before.json --at $t | jq -c '[.items[] | [.kind, .bounds, .opacity]]') \
       <(frames evaluate /path/to/work/after.json  --at $t | jq -c '[.items[] | [.kind, .bounds, .opacity]]') && echo "$t same"
done
```

## Practical notes

These are not contract, but help whoever writes documents.

- OCR confuses similar characters (`0` and `O`). Read the `ocr` output before pointing, and point with a part of the text that is less confusable, plus `nth`.
- Text areas match case as written: `"Total"` does not match `Item total`.
- On a 1206-wide vertical video a subtitle line holds about 21 Korean characters. Longer subtitles wrap, and more than two lines are hard to read.
- Starting a connected shape while the screen is still moving puts it where the text was at that frame. Start after the screen settles, or follow it with area keyframes.
- A box found on one screen stays where that text was. When the recording changes screens, end the box at the change, or start another one on the new screen.
- PNG is lossless and does not shrink when written again. Use JPEG or HEIC for smaller files.
- `transcode` target: a 1080×1920, 35-second short (11.7 MB) comes to about 3.4 MB at PSNR around 44 dB at `medium`, about 5.5 MB (50 dB) at `high`, and about 2.2 MB (38 dB) at `low`. Text on screen stays sharp at every level.
- HEVC looks slightly better than H.264 at the same level, at about the same size, and some browsers cannot play it. H.264 is the default for delivery.
