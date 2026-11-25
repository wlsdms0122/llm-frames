# find-text

`frames-find-text` is an extension of frames: it takes a document whose areas may hold a request for it, a place named by its text on screen, and gives the same document with each of those requests filled with the rectangle `frames ocr` finds, so once every request in it is filled the result is a plain frames document that any frames command takes.

```sh
frames find-text /path/to/edit.json | frames render - -o /path/to/out/edit.mp4
```

frames itself takes areas as rectangles `[x, y, w, h]` and clip areas `{"clip": "<id>", "padding": p}`, and `frames ocr --json` reports every line it recognises with its rectangle. This extension joins the two: it reads only frames' machine output (`timeline` and `ocr`, with `--json`), never a resolved document, and links no frames code.

## Install

It is one Python 3 script that uses the standard library alone. Copy or link it into a directory on `PATH`:

```sh
ln -s "$PWD/extensions/find-text/frames-find-text" /usr/local/bin/frames-find-text
```

`frames find-text` then runs it, with the global options written before `find-text` (`--theme`, `--ocr` and the other role options) passed to every frames command it runs. It runs the `frames` on `PATH`, or the executable the environment variable `FRAMES_EXECUTABLE` names. It is written for frames 0.x and stops on another major version. A frames command that fails stops the extension with the command line it ran, the global options it passed included, and what frames printed, so a theme left out shows: `frames-find-text: frames timeline /tmp/frames-find-text-1a2b/document.json --json failed: frames: ...`.

```
frames find-text <document.json | -> [--languages <tag>[,<tag>...]] [--report <report.json>]
```

- `<document.json>` is an absolute path, or `-` for standard input. The document is printed to standard output, and a stop prints `frames-find-text: <reason>` to standard error and exits with 1.
- `--languages` gives `frames ocr --languages` the recognition languages, BCP 47 tags in order of preference. Without it the OCR provider detects the language of each picture. Give it for lines that mix scripts, with the non-Latin language first (`ko-KR,en-US`).
- `--report` writes what was filled to a `.json` file, so a rectangle of the filled document can be traced back to its text ([FRAMES-25](../../spec/FRAMES-25/SPEC.md#requests)). The path is absolute and ends in `.json`, compared ignoring case, as `frames render --report`'s does, and another path, or the document's own, stops before the document is read. The report is written before the document is printed, and a stop writes none. Its first key names the extension and its version, as frames' machine output names its command, and `requests` holds each request filled, in the order of the document:

```json
{
  "find-text": "0.1.0",
  "requests": [
    { "place": "storyline[0]#menu.connected[0]#box", "key": "area",
      "request": { "tool": "find-text", "text": "Cinnamon bun", "padding": 8 },
      "media": "/path/to/board.png", "mediaTime": null, "page": null,
      "lines": [ { "text": "Cinnamon bun 3.80", "rect": [212, 418, 236.5, 31] } ],
      "rect": [204, 410, 252.5, 47] }
  ]
}
```

  `place` and `key` are the clip and the key the request stands at, as the extension's messages name them. `media`, `mediaTime` and `page` are the picture read: the media time of the frame, `null` for a still or a page, and the page, `null` for any medium but a PDF. `lines` are the recognised lines the request matched, in `ocr`'s order, as `frames ocr --json` gives them: one for `text`, and for `from` and `to` both ends and every line between them. `rect` is the rectangle written, padding and aspect ratio included.

## The requests

A request is a hole a tool fills ([FRAMES-25](../../spec/FRAMES-25/SPEC.md#requests)): an object with the key `tool`, which names the tool, and that tool's arguments beside it. This extension fills the requests whose `tool` is `find-text`:

| Request | Means |
| --- | --- |
| `{"tool": "find-text", "text": "Total", "nth": 0, "padding": 8}` | the recognised line that contains the text |
| `{"tool": "find-text", "from": "Sourdough", "to": "Flat white", "fromNth": 0, "toNth": 0, "padding": 8}` | the rectangle around the `from` line, the `to` line and every recognised line whose vertical centre lies between the top of the higher one and the bottom of the lower one |

Either takes `"aspectRatio": [w, h]`, below.

- A request stands wherever an area does, as a `crop`, an `area` and a mask's `area`, on a clip and in a keyframe, and as the `area` of a point `{"area": <request>, "point": "right"}`, in the places below. Anywhere else it stops.
- Text is compared with whitespace removed, and a line matches when it contains the text. Case counts.
- `nth`, `fromNth` and `toNth` pick one match, counted from 0 in the order `frames ocr` lists lines: top to bottom by row and left to right within a row.
- Without `nth`, text that more than one line contains stops, and the message lists every match with its rectangle and line. The same holds for each end of a `from`/`to` request.
- Text that no line contains, or an `nth` past the last match, stops, naming the place, the text, the nth and the media read.
- `padding` grows the rectangle found on every side, in the pixels of the media searched. It is optional, 0 or more, and 0 by default.
- `aspectRatio` `[w, h]`, two numbers above 0, makes the rectangle written that ratio and keeps it inside the picture searched. The part of the padded rectangle inside the picture grows about its centre along one axis until its width to its height is w to h, then slides to lie inside the picture, whose size is the `size` `frames ocr --json` reports for it. So a `crop` that zooms on the text, given the ratio of the clip's box (the frame's `size` for a storyline clip), fills the box with no transparent band past the picture, which a `fit` conform of a rectangle of another ratio leaves ([FRAMES-9](../../spec/FRAMES-9/SPEC.md)). Where the picture holds no rectangle of that ratio around that part, it stops, naming the picture, its size and the ratio. It is optional, and without it the rectangle is the padded one. The ratio is two numbers, as `format`'s `size` is, so a frame's size is written as it stands and 16 by 9 is exact, which a number such as 1.7778 is not.
- A request holds the keys of one of the two, and any other key stops.
- A request for any other tool is left as written, so this extension and another chain in either order where neither needs a value the other finds. A target for `frames track-motion` named by its text is the clip's own `area` holding a `find-text` request, which the track request names with `"target": "area"` ([its README](../track-motion/README.md)), so this extension runs first: `frames find-text doc.json | frames track-motion - | frames render - -o out.mp4`.

## Where it works

A request is searched in the pixels its key is written in, which `timeline --json` reports for every clip ([FRAMES-23](../../spec/FRAMES-23/SPEC.md#a-clips-times-and-spaces)): a `crop` or a `mask` in the clip's `ownSpace`, and a `position`, `area`, `points` or `cornerPin` in its `space`. Where that space is the media pixels of a clip whose media is a video, an image, an image sequence or a page of a PDF, the request is searched in that clip's media. So a child of a storyline clip or a media clip is searched in its parent's media, and so is a child of a shape placed by `area` or `points`, of an adjustment clip or of a clip with a corner pin that is itself written in such media, as frames places it.

Anywhere else it stops, naming the place and the space its entry reports:

- output pixels: an unparented clip, a storyline clip's `position` and `cornerPin`, and a child of a solid or of a storyline clip with a corner pin;
- a box: a child of a title or of a rect or ellipse placed by `width` and `height`, and such a clip's own `mask`;
- the media pixels of a compound clip or a template instance, whose picture is drawn and not read.

Under a rect or ellipse placed by `width` and `height`, an `area` or the area of a point is in the box its parent gives its children, which is that parent's clip area ([FRAMES-2](../../spec/FRAMES-2/SPEC.md#clip-areas)), so the stop says how to write it: `{"clip": "<the parent's id>"}` for an area and `{"area": {"clip": "<the parent's id>"}, "point": "bottom-right"}` for a point, with the parent's id and the point as written. A crop or a mask in a clip's own box, where a clip area stops, and a place in a title's box, whose text `evaluate` reports, get no such form.

## The frame searched

A still or a page has one picture. On a video or an image sequence the request is searched on the frame the searched clip shows at the sequence time its value takes effect at, read from the entry of the clip that writes it:

| Request | Sequence time |
| --- | --- |
| a static value | the clip's `instant` |
| a keyframe's value | its `at` carried by the clip's `clock`, `origin + at / speed` |

The extension writes a copy of the document with a value in the place of every request, its own and every other tool's, since frames takes none: a placeholder rectangle where an area stands, and no `track` where a track request stands, since a clip's times and spaces do not depend on its track. So frames resolves it and times its clips as it times the document once its requests are filled. A request of another tool anywhere else has no such value, and stops, naming the tool that fills it first. It reads `timeline --json` once, and `timeline --at <t> --json` once for each sequence time, whose entry for the searched clip gives the `mediaTime` of the frame its time map shows there, whether the clip draws anything at t or not and inside the sequence or outside it. So `speed`, `in`, `loop`, `timeRemap` and transitions are applied by frames, and the extension computes no time and follows no parent.

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
        { "id": "box", "parent": "menu", "shape": "rect", "area": { "tool": "find-text", "text": "Cinnamon bun", "padding": 8 },
          "stroke": { "width": 6, "color": "#F2B33D" } },
        { "parent": "menu", "title": "New this week", "style": "subtitle", "anchor": "left",
          "position": { "area": { "tool": "find-text", "text": "Cinnamon bun", "padding": 28 }, "point": "right" } } ] }
  ]
}
```

```sh
frames find-text /path/to/menu.json > /path/to/out/menu.frames.json
frames still /path/to/out/menu.frames.json --at 1 -o /path/to/out/check.png
```

The box's `area` and the note's point are filled with `[x, y, w, h]` in the board's pixels, as `frames ocr /path/to/board.png` reports the line, grown by the padding.

## Check

The check runs without frames, on frames output recorded in `fixtures/`:

```sh
python3 -m unittest discover -s extensions/find-text
```
