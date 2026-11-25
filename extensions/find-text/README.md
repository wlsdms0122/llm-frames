# find-text

`frames-find-text` is an extension of frames: it takes a document whose areas and points may name a place by its text on screen, and gives the same document with each of those places written as the rectangle `frames ocr` finds, so the result is a plain frames document that any frames command takes.

```sh
frames find-text /path/to/edit.json | frames render - -o /path/to/out/edit.mp4
```

frames itself takes areas as rectangles `[x, y, w, h]` and clip areas `{"clip": "<id>", "padding": p}`, and `frames ocr --json` reports every line it recognises with its rectangle. This extension joins the two: it reads only frames' machine output (`timeline` and `ocr`, with `--json`), never a resolved document, and links no frames code.

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

A form is searched in the pixels its key is written in, which `timeline --json` reports for every clip ([FRAMES-23](../../spec/FRAMES-23/SPEC.md#a-clips-times-and-spaces)): a `crop` or a `mask` in the clip's `ownSpace`, and a `position`, `area`, `points` or `cornerPin` in its `space`. Where that space is the media pixels of a clip whose media is a video, an image, an image sequence or a page of a PDF, the form is searched in that clip's media. So a child of a storyline clip or a media clip is searched in its parent's media, and so is a child of a shape placed by `area` or `points`, of an adjustment clip or of a clip with a corner pin that is itself written in such media, as frames places it.

Anywhere else it stops, naming the place and the space its entry reports:

- output pixels: an unparented clip, a storyline clip's `position` and `cornerPin`, and a child of a solid or of a storyline clip with a corner pin;
- a box: a child of a title or of a rect or ellipse placed by `width` and `height`, and such a clip's own `mask`;
- the media pixels of a compound clip or a template instance, whose picture is drawn and not read.

A `track` target is searched in the clip's own media when it tracks its own media (a video or an image sequence without a corner pin), and otherwise in its parent's media, which a parent with a corner pin or without media of its own does not give ([FRAMES-12](../../spec/FRAMES-12/SPEC.md)).

## The frame searched

A still or a page has one picture. On a video or an image sequence the form is searched on the frame the searched clip shows at the sequence time the form takes effect at, read from the entry of the clip that writes it:

| Form | Sequence time |
| --- | --- |
| a static value | the clip's `instant` |
| a keyframe's value | its `at` carried by the clip's `clock`, `origin + at / speed` |
| a `track` object's `area` | none: the frame shown at the media time its `time` names |

The extension writes a copy of the document with each form in a placeholder rectangle and without `track`, so frames resolves it without searching or tracking and times its clips as it times the document. It reads `timeline --json` once, and `timeline --at <t> --json` once for each sequence time, whose entry for the searched clip gives the `mediaTime` of the frame its time map shows there, whether the clip draws anything at t or not and inside the sequence or outside it. So `speed`, `in`, `loop`, `timeRemap` and transitions are applied by frames, and the extension computes no time and follows no parent.

The media are read with `frames ocr --json` at that media time: the searched clip's `media`, its `page` as `--page`, an image sequence's directory with the `fps` its entry reports as `--fps`, the searched clip's `colorSpace` as `--color-space`, and `--languages` as given. Each distinct media file, time, page, rate, colour space and languages is read once.

## What it does not cover

- Text drawn by frames (titles), which `evaluate` reports exactly in `texts` and `characters`.
- Places inside a compound clip or template instance, or inside a sequence document named as media by its file: their instants are on the nested sequence's time, and `timeline --at` gives a nested document's clips only at the outer sequence's times. Run the extension on the nested document first.
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
