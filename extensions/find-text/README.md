# find-text

`frames-find-text` is an extension of frames: it takes a document whose areas and points may name a place by its text on screen, and gives the same document with each of those places written as the rectangle `frames ocr` finds, so the result is a plain frames document that any frames command takes.

```sh
frames find-text /path/to/edit.json | frames render - -o /path/to/out/edit.mp4
```

frames itself takes areas as rectangles `[x, y, w, h]` and clip areas `{"clip": "<id>", "padding": p}`, and `frames ocr --json` reports every line it recognises with its rectangle. This extension joins the two: it reads only frames' machine output (`timeline`, `evaluate`, `locate`, `probe`, `ocr`, all with `--json` or as JSON), never a resolved document, and links no frames code.

## Install

It is one Python 3 script that uses the standard library alone. Copy or link it into a directory on `PATH`:

```sh
ln -s "$PWD/extensions/find-text/frames-find-text" /usr/local/bin/frames-find-text
```

`frames find-text` then runs it, with the global options written before `find-text` (`--theme`, `--ocr` and the other role options) passed to every frames command it runs. It runs the `frames` on `PATH`, or the executable the environment variable `FRAMES_EXECUTABLE` names. It is written for frames 0.x and stops on another major version.

```
frames find-text <document.json | -> [--languages <tag>[,<tag>...]]
```

- `<document.json>` is an absolute path, or `-` for standard input. The document is printed to standard output, and a stop prints `frames-find-text: <reason>` to standard error and exits with 1.
- `--languages` gives `frames ocr --languages` the recognition languages, BCP 47 tags in order of preference. Without it the OCR provider detects the language of each picture. Give it for lines that mix scripts, with the non-Latin language first (`ko-KR,en-US`).

## The forms

| Form | Means |
| --- | --- |
| `{"text": "Total", "nth": 0, "padding": 8}` | the recognised line that contains the text |
| `{"from": "Sourdough", "to": "Flat white", "fromNth": 0, "toNth": 0, "padding": 8}` | the rectangle around the `from` line, the `to` line and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |

- A form stands wherever an area does, and as the `area` of a point `{"area": <form>, "point": "right"}`, in the places below.
- Text is compared with whitespace removed, and a line matches when it contains the text. Case counts.
- `nth`, `fromNth` and `toNth` pick one match, counted from 0 in the order `frames ocr` lists lines: top to bottom by row and left to right within a row.
- Without `nth`, text that more than one line contains stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` form.
- Text that no line contains, or an `nth` past the last match, stops, naming the place, the text, the nth and the media read.
- `padding` grows the rectangle found on every side, in the pixels of the media searched. It is optional, 0 or more, and 0 by default.
- An object holds the keys of one form, and any other key stops.

## Where it works

A form is searched only where its coordinates are the media pixels of a video, an image, an image sequence or a page of a PDF, with no map between:

- a storyline clip's or media clip's own `crop` and `mask`, searched in its own media, and its `track` target when it tracks its own media (a video or an image sequence without a corner pin);
- the `area`, `points`, `position` and `cornerPin` of a clip parented directly to a storyline clip or media clip of such media without a corner pin, the `mask` of such a child when it is a shape placed by `area` or `points` or an adjustment clip, and its `track` target when it tracks its parent's media, all searched in the parent's media.

Anywhere else it stops, naming the clip and saying the place is not in a medium's pixels: an unparented clip, whose coordinates are output pixels; a storyline clip's `position` or `cornerPin`; a clip parented to a title, a shape, an adjustment clip, a solid, a clip with a corner pin or a compound clip; the mask of a title or of a shape placed by `width` and `height`; and any place inside a compound clip or template instance, whose picture is drawn and not read.

## The frame searched

A still or a page has one picture. On video and image sequences the form is searched on the frame shown at the instant it takes effect:

| Form | Instant |
| --- | --- |
| a static value | the clip's start: a storyline clip's `in`, a connected clip's `at` (its storyline clip's `in` without one), a sequence clip's `at` (0 without one) |
| a keyframe's value | that keyframe's `at`, on the clip's own clock |
| a `track` object's `area` | the media time its `time` names |

The extension asks frames which frame that is. It writes a copy of the document with each form in a placeholder rectangle (and without the masks that hold one and without `track`, which do not move a clip in time), carries the instant to sequence time with `timeline --json`, finds where the searched clip's picture lies with `evaluate`, and asks `locate` for the media file, the media time and the page of the frame under that point. So `speed`, `in`, `loop`, `timeRemap` and transitions are applied by frames. Where frames draws none of the searched clip at the instant (a keyframe outside its window, or past the end of the sequence), it reads a still as it is and a video whose clip has no `speed`, `loop` or `timeRemap` at `in` plus the clip time, and stops otherwise.

The media are read with `frames ocr --json`: a clip's `colorSpace` is passed as `--color-space`, a page of a PDF as `--page`, and `--languages` as given. Each distinct media file, time, page, colour space and languages is read once.

## What it does not cover

- A place whose coordinates reach the media through a map: a clip parented to a shape, an adjustment clip or a clip with a corner pin, or a grandchild of the media clip. Write those as rectangles found with `frames ocr`.
- Text drawn by frames (titles), which `evaluate` reports exactly in `texts` and `characters`.
- Places inside a compound clip or template instance, or inside a sequence document named as media by its file. Run the extension on the nested document first.
- A `track` object's `area` on an image sequence or on media named by a pack, whose file at a media time no report gives.
- A template with `--args`.

## Example

A board shown as a still, a box drawn around one of its lines, and a note at its right:

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080] },
  "storyline": [
    { "id": "menu", "media": "/path/to/board.png", "duration": 4,
      "connected": [
        { "id": "box", "parent": "menu", "shape": "rect", "area": { "text": "Cinnamon bun", "padding": 8 },
          "stroke": { "width": 6, "color": "#F2B33D" } },
        { "parent": "menu", "title": "New this week", "style": "subtitle", "anchor": "left",
          "position": { "area": { "text": "Cinnamon bun", "padding": 28 }, "point": "right" } } ] }
  ]
}
```

```sh
frames find-text /path/to/menu.json > /path/to/out/menu.frames.json
frames still /path/to/out/menu.frames.json --at 1 -o /path/to/out/check.png
```

The box's `area` and the note's point are written as `[x, y, w, h]` in the board's pixels, as `frames ocr /path/to/board.png` reports the line, grown by the padding.

## Check

The check runs without frames, on frames output recorded in `fixtures/`:

```sh
python3 -m unittest discover -s extensions/find-text
```
