# demo

A feature demo: a landscape video that shows one feature being used, step by step, between a title card and an end card.

## What it is for

People who will use the feature watch it: users reading release notes or a changelog, customers on a product or help page, teammates in a launch post or a chat. They watch it on a desktop or a laptop, in a player inside the page, usually with sound and from the start, because they chose to learn the feature. So it shows the real product doing one thing from start to finish, slowly enough to follow, and says in words what each step is.

## Theme

`demo/demo`. Every document of this form writes `"theme": "demo/demo"`.

- It keeps the base theme's `baseWidth` of 1920, so on a 1920 by 1080 demo every theme length is an output pixel. White text on black, as in the base theme.
- A red `accent` (`#FF453A`) for outlines and labels, and a yellow `highlight` (`#FFD60A`) for the small line of the cards. Both read on a white product screen and on the black cards.
- Text styles: `title` is the base theme's (96, bold, centred in the frame) and sets the cards. `subtitle` is 44, white on a black box at 70% opacity with corners rounded 12, with no stroke, at the bottom 108 above the frame's bottom edge, centred. `kicker` (48, bold, `highlight`) is a run style for the small line of a card. `label` is 36, bold, white on a red rounded box, one line.
- Shape style `outline`: a red stroke 8 wide, corners rounded 18.
- Defaults: subtitles fade in and out (`frames/fade`), labels pop in and out (`frames/pop`). No default transition, filter or other animation, as in the base theme.

## Format

`"size": [1920, 1080]`, `"fps": 30`, `"background": "#000000"`, `conform` left at `fit`. A recording of another 16:9 size is fitted to the frame, and a picture of another shape is shown whole with black around it.

**The title card.** The template `demo/title-card`, a storyline clip whose media is the template:

```json
{ "id": "title-card", "media": { "template": "demo/title-card", "args": { "area": "Checkout", "feature": "Totals now include shipping" } } }
```

| Param | Type | Default | What it is |
| --- | --- | --- | --- |
| `area` | text | `Checkout` | the first line, small and in `highlight`: the part of the product |
| `feature` | text | `Totals now include shipping` | the second line: what the feature does |
| `length` | number | 2 | seconds on screen |

**The end card.** The template `demo/end-card`, the last storyline clip, brought in with `"transition": "frames/fade"`:

| Param | Type | Default | What it is |
| --- | --- | --- | --- |
| `headline` | text | `Available in version 2.4` | the first line: where to get the feature |
| `detail` | text | `Settings > Checkout > Shipping` | the second line, small and in `highlight`: where to find it |
| `length` | number | 2 | seconds on screen |

Each card is a black 1920 by 1080 solid with one centred title in the `title` style whose small line is a `kicker` run, and the title fades in and out. A card is the same in every demo, so it is a template and only its words change.

**Steps.** Each step is captioned by a title in the `subtitle` style connected to the clip it belongs to, with no placement, so the style sets it at the bottom, centred, on its dark box. It moves to the top (`"placement": "top"`) only when it would cover what its step points at.

**Outlines.** A rect in the `outline` style connected to the step's clip and parented to it, its area in the clip's media pixels and a request for `frames find-text`, which fills it with the rectangle `frames ocr` finds for the text (the extension is in the frames repository under `extensions/find-text/`): `{ "shape": "rect", "style": "outline", "parent": "add", "area": { "tool": "find-text", "text": "Add shipping", "padding": 22 } }`. On a recording where the line moves, the outline follows it with `"track": { "tool": "track-motion", "target": "area" }`, a request for `frames track-motion`, which fills it with the track data `frames track` prints for the outline's area (the extension is under `extensions/track-motion/`).

**Labels.** A title in the `label` style parented to its outline (`"parent": "<the outline's id>"`) and set at a point of the outline's box: `"position": { "area": { "clip": "<the outline's id>" }, "point": "bottom-right" }, "anchor": "top-right"`. It hangs below the outline's right end.

**Zoom.** Crop keyframes zoom a step onto what it uses: `{ "scale": 1 }` first, so the viewer sees where it is, then an area around it, a request for `frames find-text` or the rectangle `frames ocr` reports. Give the request `"aspectRatio": [1920, 1080]`, the frame's ratio, so the zoomed crop lies inside the recording and fills the frame with no empty band at its sides.

## Rules

### Text

- The title card names the product area in its small line and the feature in its large line. Viewers check in the first second that this is the demo they want.
- A subtitle names one step as an instruction or what the step shows ("Click Add shipping"), in one line of at most about 40 characters. It is read while the hand moves, so it says what to watch, not why.
- One subtitle per step, back to back, each with its own `at` in its clip's seconds. A step without words is one the viewer has to guess.
- The end card says where the feature is: a version in its large line, a menu or a plan in its small line. It is what a viewer looks for after the demo.
- Labels are one to four words, and name the result, not the action ("38,000 + 4,000", "saved").
- A run in another style only on the cards. Subtitles sit on a dark box where the yellow is loud, and a demo's steps are all equally important.

### Marks

- An outline goes on the control the next step uses, or on the result a step makes, while its subtitle is on screen. The eye follows the outline to where to look next.
- One outline at a time. Two outlines split the eye, and a demo has a single path.
- A one-line subtitle and its box cover the bottom 180 pixels of the frame. When what a step points at sits there, give that step's subtitle `"placement": "top"`. A subtitle over the thing it names hides the step.
- Zoom when what a step uses is small, and keep it out of the bottom of the frame where the subtitle sits. Zoom back out before a step elsewhere on the screen.

### Cuts

- Each step is its own storyline clip of the recording with its own `in` and `out`, cut where the screen is still. Cuts on a still screen are not seen.
- Waits (loading, typing a long text) are cut out or taken at `"speed": 2`. A viewer learns nothing from a wait, and the feature should not look slower or faster than it is beyond that.
- Clips of one recording follow each other with no transition (the default, `cut`). A `frames/fade` brings in the clip after the title card, a different recording or a screenshot of another screen, and the end card. A dissolve says "elsewhere", a cut says "and then".

### Sound

- The recording's own sound is off (`"volume": 0`) unless it is part of the feature. Clicks and fans are noise in a demo.
- Music, if any, is an audio clip in `clips` at a `volume` of 0.2 to 0.3 with a `fadeOut` of 1 second, so it never covers a voice or a feature sound.

### Length

- 20 to 90 seconds, one feature. A second feature is a second demo, since a viewer came for one.
- The title card and the end card are 1.5 to 2 seconds each (`length`). They are read, not watched.
- A step is on screen at least as long as its subtitle takes to read, about 2 seconds for a short line. A viewer reads first and watches second.

## Presets

- Use `frames/fade` at its default 0.4 seconds out of the title card, between different recordings or screens, and into the end card.
- Keep the theme defaults: `frames/fade` on subtitles, `frames/pop` on labels.
- An outline comes in whole. It may take `frames/wipe`, which reveals it from the left and leads the eye along a row.
- `frames/zoom-in` can bring in a result that the demo builds to, once.
- Do not use `frames/push-*`, `frames/slide-*`, `frames/uncover-left` or `frames/wipe-*` between steps. They suggest the product itself moves that way.
- Do not use `frames/flash`, `frames/shake`, `frames/blink` or `frames/pulse`. They are for a short's attention, and a demo has its viewer's already.
- Do not use filters on the recording. The demo shows the product as it is, colours included.

## Example

`examples/checkout.json` is a 9.8 second demo of one feature in four storyline clips: the title card, a recording, a screenshot and the end card. It names its media by placeholder paths under `/path/to/`, so change each to an absolute path of your own before it runs:

- `/path/to/checkout.mov`: a 1280 by 720 recording, at least 2.8 seconds long, of an order summary on a desktop, where `Add shipping` is clicked at 1 second, the `Shipping` row appears and `Total` turns from `38,000` to `42,000`.
- `/path/to/checkout.png`: a portrait screenshot 1206 pixels wide of the same summary on a phone, with the rows `Item total` with `38,000`, `Shipping` with `4,000` and `Total` with `42,000`, and a `Pay 42,000` button below them.

It shows the format and the rules together:

- The title card is `demo/title-card` with `area` `Checkout` and `feature` `Totals now include shipping`, 2 seconds.
- The recording plays from `in` 0 to `out` 2.8 with its sound off, brought in with a `frames/fade`. Its first step, "Click Add shipping", outlines the button from 0.2 seconds. Its second step, from 1.1 seconds, outlines the `Total` row from 1.2 and follows it with a track request that names the outline's area, once the total reads `42,000`, and hangs the label `38,000 + 4,000` below it at 1.4.
- The screenshot of the phone comes in with a `frames/fade`, since it is another screen, and holds 3 seconds. It zooms from the whole screenshot at 0.6 seconds to the rows from `Item total` to the row's `42,000` at 1.4 (`"toNth": 0` picks the row's and not the button's), under one subtitle.
- The end card is `demo/end-card` with `headline` `Available in version 2.4` and `detail` `Settings > Checkout > Shipping`, brought in with a `frames/fade`.

Its outlines and its zoom are requests for `frames find-text`, and the `Total` outline's track a request for `frames track-motion` that names that outline's area, so it goes through `frames find-text` and then `frames track-motion`, which fill them and write the frames document: `frames find-text /path/to/checkout.json | frames track-motion - > /path/to/out/checkout.json`. Check that document with `frames timeline` and `frames still --at 1,2.6,4.2,7.2,9`: the cards' small lines in yellow, each subtitle on its box at the bottom, the outline on `Add shipping` and then on the `Total` row with its label, the zoomed rows of the phone screen. Then lay the whole of it out with `frames sheet`.
