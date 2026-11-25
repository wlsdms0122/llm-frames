# pr-evidence

A screenshot or a short recording that proves what a pull request changes, with the claim written above the picture and the lines that prove it outlined.

## What it is for

The reviewers of a pull request watch it, in the pull request's description or in a review comment on the code host, shown inline at the width of the page, about 900 pixels on a desktop and often muted. They look at it before or beside the code and decide from it whether the change does what the title says. People come back to it later from the history, without the context of the review. So it states one claim and shows the proof of that claim, and nothing in it can be read as something else.

## Theme

`pr-evidence/pr-evidence`. Every document of this form writes `"theme": "pr-evidence/pr-evidence"`.

- `baseWidth` is 1206, the width of a phone screenshot at 3x, so on a picture 1206 pixels wide every theme length is a pixel of the picture. On a wider or narrower picture the outlines and labels scale with it and keep their size relative to the text they mark.
- Black text on white (`text`, `background`) and a red `accent`.
- Text styles: `lead` (44, bold) for the conclusion, `body` (38) for the reason, both on a 64 line and one line long, `label` (36, bold, white on a red rounded box, one line) for a label, and `caption` (36, bold, white on a dark rounded box, two lines at most, placed at the bottom of the frame) for a line of words on a recording.
- Shape styles: `outline` (a red stroke 8 wide, corners rounded 18), `cover` (opaque black fill) and `dim` (black at 60% opacity).
- `border` is 3 wide and light grey, for a screenshot whose white background would otherwise meet the white page.
- No default transition, filter or animation, as in the base theme. A reviewer who pauses on any frame sees every mark whole.

## Format

The frame is measured from the content: `"size": { "fit": "content" }` with a white background. The picture is the first storyline clip, so its width gives the length scale.

**The picture.** A screenshot is a storyline clip with a `duration` of 1, a recording a storyline clip with `in`, `out` and `"volume": 0`. Each takes `"border": true`. Crop a screenshot to the rows that make the claim and the rows that give them their meaning, across the whole width of the picture: `"crop": [0, y, W, h]`, with `W` the picture's width and `y` and `h` read from `frames ocr <picture>`, which prints every line's rectangle. A crop found by text is only as wide as its lines, and the length scale would follow that width, so the outlines and labels would come out thin. A recording is usually shown whole.

**The header.** The template `pr-evidence/header` is a white strip 1206 by 208 with the conclusion in `lead` and the reason in `body` below it, both 40 from its left edge. It is a sequence clip in `clips`, as wide as the picture and set on its top edge:

```json
{ "kind": "media", "media": { "kind": "template", "template": "pr-evidence/header",
             "args": { "conclusion": "Total includes shipping", "reason": "42,000 is the item total plus 4,000 shipping" } },
  "width": 1206, "anchor": "bottom-left", "position": [0, 0] }
```

Under content fit the frame grows to hold it, so the picture keeps every pixel of its own below it. `width` is the picture's width (1280 for a 1280 by 720 recording). The template is drawn at 1206 wide and scaled to `width`, so at 1206 its text is sharpest.

**The marks.** Every mark is a connected clip parented to the picture's clip, so its area is in the picture's media pixels and moves with it. A mark's area is a request for `frames/find-text` that names its line by text, and `frames frames/find-text` fills it with the rectangle `frames ocr` finds there (a tool of the pack `frames`, which ships with frames), so a new screenshot needs no measuring again:

- An **outline** is a rect in the `outline` style on a reason line: `{ "kind": "rect", "style": "outline", "parent": "checkout", "area": { "tool": "frames/find-text", "from": "Item total", "to": "38,000", "padding": 16 } }`. `from` and `to` take the label at the left of a row and its value at the right, so the outline holds the whole row.
- A **label** is a title in the `label` style parented to its outline, set at a point of the outline's box: give the outline an `id` and the label `"position": { "area": { "clip": "<the outline's id>" }, "point": "bottom-right" }, "anchor": "top-right"`, without `width`, so its background hugs its text. Put it on the side where the picture has room, so it covers no line a reader needs.
- A **cover** is a rect in the `cover` style over personal data: `{ "kind": "rect", "style": "cover", "parent": "checkout", "area": { "tool": "frames/find-text", "text": "jane@example.com", "padding": 12 } }`.
- A **dim** darkens everything but the reason lines: a rect in the `dim` style over the crop, with an inverted mask of the lines, `{ "kind": "rect", "style": "dim", "parent": "checkout", "area": [0, 130, 1206, 800], "mask": { "shape": "rect", "area": <the lines' area>, "radius": 18, "invert": true } }`. It comes before the outlines, so they draw over it.

**Two states.** Before and after are two pictures side by side: the before picture as the storyline clip, and the after picture as a connected media clip with the same `crop` and `border`, `"anchor": "top-left"` and `"position": [W + 40, 0]`. Its marks are parented to it. Each takes a heading above it, a title in `lead` with `"width": 600`, `"anchor": "bottom-left"`, at `[40, -16]` and `[W + 80, -16]`. The header sits above the headings, at `"position": [0, -80]` and `"width": 1206`. Cover the personal data in both pictures. `examples/before-after.json` is this layout with its numbers written out: with `W` the picture's width, the after picture is at `[W + 40, 0]` and the headings at `[40, -16]` and `[W + 80, -16]`.

**A caption.** A recording that needs a line of words on it takes a title in the `caption` style: white on a dark box, two lines at most, at the bottom of the frame. Its style places it, so it writes no `position`, and it does not change the measured frame: `{ "at": [1.2, 2.8], "kind": "title", "text": "The total updates as shipping is added", "style": "caption" }`. It lies over the bottom of the recording, so use it where nothing that proves the claim is shown there, and keep the claim itself in the header.

## Rules

### Text

- The conclusion comes first, as one sentence of what is now true ("Total includes shipping"). A reviewer reads the first line and may stop there.
- The reason follows in one line and says what in the picture proves the conclusion. A conclusion without its proof is a claim, not evidence.
- Each fits on one line of the header. The styles take one line, so a longer one stops, and a reason that needs two lines is two claims.
- No run in another style in the header or in labels. One weight and one colour read fastest on a white strip.
- A label is one to four words and names the fact its outline shows ("38,000 + 4,000", "now 4,000"). It is read beside the line, not instead of it.
- Write in the language of the pull request. A reviewer reads the evidence beside its description.

### Marks

- Only the reason lines get an outline. An outline on anything else asks the reviewer to check something that proves nothing.
- One outline per reason line, with a label only where the line alone does not say why it matters. A picture full of outlines points at nothing.
- A dim is used only when the crop still holds much more than the reason lines. It darkens the context the reader may need, so it is the exception.
- Personal data is covered with a `cover` at full opacity with `"animation": "none"`, on every clip and every frame that shows it. Evidence is posted where many people read it, and one frame is enough to leak it.
- On a recording, a cover follows a line that moves with the data and stays on screen the whole time, such as the total in the same list. A track follows the target its clip names, and a request's arguments are values, so the line followed is a clip of its own: a null, `{"kind": "null"}`, which draws nothing, its `area` a `frames/find-text` request for it and its `track` `{ "tool": "frames/track-motion", "target": "area" }`, with an `id`, and the cover parented to it, its `area` a `frames/find-text` request for the data. `frames frames/find-text` fills both areas on the frame the recording shows at their start, and `frames frames/track-motion` then fills the line's track with that line followed from that frame (a tool of the pack `frames`, which ships with frames). The cover's area is found where the data is and the line's motion carries it as its parent's, so it leaves an edge with the data and comes back with it. A track request on the cover that names its own area follows the data itself and suits only data that never reaches an edge, since the tracker loses text as it leaves the screen.
- When nothing that moves with the data stays on screen, cut or crop the recording so the data never crosses an edge.
- A template is a closed box whose text cannot be found from outside, so a recording given to one is covered first: render it with its covers to a master and pass that file.
- Check the finished file with `frames ocr <out.png>`, and on a video over every frame (`--from 0 --to <duration> --step <1 / fps>`): no covered text may come back. Then look at a `sheet` of the rendered master at the same step wherever covered data crosses an edge. Text cut in half by an edge does not come back in `ocr`, and people can still read it.

### Cuts

- A screenshot's crop keeps whole rows across the whole width. A line cut in half can be read as hiding its other half.
- A recording is cut to the action: from just before the input to just after the result shows, at speed 1. Speeding it up changes what it proves about time.
- Cut a recording only where nothing changes on the screen, and put a `frames/fade` at the cut. A cut that hides itself looks like something was taken out.
- No filters. The colours of a screen are part of what it shows.

### Sound

- No music, and a recording's own sound is off (`"volume": 0`) unless the sound is the evidence. Reviewers watch inline and muted, and sound that proves nothing is noise.

### Length

- One claim per picture or video. A second claim is a second piece of evidence, since the header states one conclusion.
- A recording runs at most 30 seconds, and under 15 is better. It plays inline and is watched more than once.
- A still is enough when the result does not move. A recording is for what happens over time: an animation, a sequence of states, something that loads.

## Presets

- Use `frames/fade` at a cut inside a recording, at 0.3 to 0.5 seconds: `{ "preset": "frames/fade", "seconds": 0.4 }`. It shows that time passed without telling a story.
- Marks take no animation. A label on a recording may take `frames/fade` to come in where its line changes, never on a still: a still is the frame at 0, where an entrance has not begun.
- Do not use filters, for the reason in Cuts.
- Do not use moving transitions (`frames/push-*`, `frames/slide-*`, `frames/uncover-left`, `frames/wipe-*`, `frames/zoom-*`), `frames/flash` or `frames/dip-black`. They make an edit look like a story and pull the eye from the proof.
- Do not use `frames/pulse`, `frames/blink` or `frames/shake`. The frame a reviewer pauses on may catch them mid-motion.

## Example

Three examples are in `examples/`. They name their media by placeholder paths under `/path/to/`, so change each to an absolute path of your own before they run:

- `/path/to/checkout.png`: a screenshot 1206 pixels wide of an order summary with the rows `Order summary`, `Ship to` with `jane@example.com`, `Item total` with `38,000`, `Shipping` with `4,000`, `Total` with `42,000` and `Arrives in 2 days`, and a `Pay 42,000` button below them. Rows are read with their label at the left and their value at the right.
- `/path/to/checkout-before.png`: the same screenshot before the change, without the `Shipping` row and with `Total` at `38,000`.
- `/path/to/checkout.mov`: a 1280 by 720 recording, at least 2.8 seconds long, of the same summary on a desktop, where `Add shipping` is clicked at 1 second, the `Shipping` row appears and `Total` turns from `38,000` to `42,000`, and the list then scrolls up so that the email leaves the top edge.

`examples/screenshot.json` is a screenshot: the crop `[0, 130, 1206, 800]` keeps the rows from the heading to `Arrives in 2 days` across the whole width, the email is covered, the three reason rows are outlined, and only the total, whose row alone does not say why it is outlined, takes the label `38,000 + 4,000`. `"toNth": 0` picks the row's `42,000` and not the button's. The header is set on the picture's top edge. On your own screenshot change the crop's `y` and `h` to your rows.

`examples/before-after.json` is two states side by side: the screenshot before the change as the storyline clip and the one after it as a media clip 40 to its right, each with its email covered and its total outlined, a heading above each, and the header above the headings. In the before picture `"toNth": 1` picks the total's `38,000` and not the item total's.

`examples/recording.json` is a recording from 0.4 to 2.8 seconds with its sound off. The cover on the email is parented to a null whose track follows `Total`, so it scrolls off the top with the email. The outline and its label come in at 1.2 seconds, once the total reads `42,000`, and the outline follows the row with a track request that names its area, since the row stays on screen. The header is 1280 wide, the recording's width.

Each names its lines with requests for `frames/find-text`, so it goes through `frames frames/find-text` first, which fills them and writes the frames document: `frames frames/find-text /path/to/screenshot.json > /path/to/out/screenshot.json`. `examples/recording.json` also holds track requests for `frames/track-motion` that name areas `frames frames/find-text` fills, so it goes through `frames frames/track-motion` after `frames frames/find-text`: `frames frames/find-text /path/to/recording.json | frames frames/track-motion - > /path/to/out/recording.json`. Check that document with `frames timeline` and `frames still --at 0` (and `frames sheet` over a recording), render it, and run `frames ocr` on the result to make sure the email does not come back. The labels are set on their outline's box by a clip area, so they need no text of their own.
