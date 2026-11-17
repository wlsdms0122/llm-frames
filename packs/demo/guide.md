# demo

A feature demo: a landscape video that shows one feature being used, step by step, on the base theme.

## What it is for

People who will use the feature watch it: users reading release notes or a changelog, customers on a product or help page, teammates in a launch post or a chat. They watch it on a desktop or a laptop, in a player inside the page, usually with sound and from the start, because they chose to learn the feature. So it shows the real product doing one thing from start to finish, slowly enough to follow, and says in words what each step is.

## Theme

The base theme. A demo writes no `theme`, so it looks like what frames draws by default and like every other demo made with it: red boxes with white-on-red labels, subtitles in white on a dark rounded box, headlines in white with a black outline. Labels `pop` in, and every other default is none: no default transition, filter or animation.

## Format

- `"size": [1920, 1080]`, `"fps": 30`, `"background": "#000000"`. A recording of another 16:9 size is fitted to it, and one of another shape is shown whole with black around it.
- No `inset`, and `conform` stays `fit`: the recording fills the frame and is never cut.
- A demo has no band and no banner. Its words are built from titles in two places:
  - The title card and the end card are `solid` storyline clips of `#000000`, each with a connected title in the `headline` style placed at `center`. The title card names the product area on its first line and what the feature does on its second, in `**` emphasis. The end card says where to get the feature.
  - Each step is captioned by a connected title in the `subtitle` style, with no placement, so the style puts it at the bottom, centred, on its dark box. It moves to the top only when it would cover what its step points at.
- Boxes, arrows and labels are connected to their scene by `area`, so they stay on the control they point at while the scene zooms.

## Rules

### Text

- The title card names the feature in at most two lines, the second line in `**`. Viewers check in the first second that this is the demo they want.
- A subtitle names one step as an instruction or what the step shows ("Open the order summary"), in one line of at most about 40 characters. It is read while the hand moves, so it says what to watch, not why.
- One subtitle per step, back to back, each with its own `at` in its scene's seconds. A step without words is one the viewer has to guess.
- The end card says where the feature is: a version, a menu, a plan. It is what a viewer looks for after the demo.
- Labels are one to four words, and name the result, not the action ("38,000 + 4,000", "saved").

### Emphasis

- A box goes on the control the next step uses, or on the result a step makes, while its subtitle is on screen. The eye follows the box to where to look next.
- One box at a time. Two boxes split the eye, and a demo has a single path.
- A subtitle and its box cover about the bottom quarter of the frame (its bottom edge is 255 pixels above the bottom on a 1920 wide demo). When what a step points at sits there, give that step's subtitle `"placement": "top"`. A subtitle over the thing it names hides the step.
- Zoom in with crop keyframes when what a step uses is small: `{"scale": 1}` first, so the viewer sees where it is, then an area around it that keeps it out of the bottom quarter. Zoom back out before a step elsewhere on the screen.
- `**` emphasis only on the title card. Subtitles sit on a dark box where the yellow is loud, and a demo's steps are all equally important.

### Cuts

- Each step is its own storyline clip of the recording with its own `in` and `out`, cut where the screen is still. Cuts on a still screen are not seen.
- Waits (loading, typing a long text) are cut out or taken at `"speed": 2`. A viewer learns nothing from a wait, and the feature should not look slower or faster than it is beyond that.
- Clips of one recording follow each other with no transition (the default, `cut`). A `fade` brings in the clip after the title card, a different recording or a screenshot of another screen, and the end card. A dissolve says "elsewhere", a cut says "and then".
- Sound: the recording's own sound is turned off (`"volume": 0`) unless it is part of the feature. Music, if any, is an audio clip in `clips` at `"volume"` 0.2 to 0.3 with a `fadeOut` of 1 second, so it never covers a voice or a feature sound.

### Length

- 20 to 90 seconds, one feature. A second feature is a second demo, since a viewer came for one.
- The title card and the end card are 1.5 to 2 seconds each. They are read, not watched.
- A step is on screen at least as long as its subtitle takes to read, about 2 seconds for a short line. A viewer reads first and watches second.

## Presets

- Use `fade` at its default 0.4 seconds out of the title card, between different recordings, and into the end card.
- Labels keep the base default `pop`. Boxes may take `draw`, which leads the eye along the box as it appears.
- `zoom-in` can bring in a result that the demo builds to, once.
- Do not use `push-*`, `slide-*`, `uncover-left` or `wipe-*` between steps. They suggest the product itself moves that way.
- Do not use `flash`, `shake`, `blink` or `pulse`. They are for a short's attention, and a demo has its viewer's already.
- Do not use filters on the recording. The demo shows the product as it is, colours included.

## Example

`examples/checkout.json` is an 8.4 second demo of one feature in four storyline clips: the title card, a recording, a screenshot and the end card. It names its media by placeholder paths under `/path/to/`, so change each to an absolute path of your own before it runs:

- `/path/to/checkout.mov`: a recording of an order summary screen, at least 1.4 seconds long.
- `/path/to/checkout.png`: a screenshot of the order summary with the lines `Order summary`, `Item total 38,000`, `Shipping 4,000` and `Total 42,000`.

It shows the format and the rules together:

- The title card and the end card are black solids with a centred headline, and only the title card has `**` emphasis.
- The recording plays from `in` 0 to `out` 1.4 with its sound off, brought in with a `fade` since it follows the title card. The screenshot after it is a cut: the same screen goes on.
- Each step has one subtitle. The `Total` line sits in the bottom quarter, so the subtitle of the step that boxes it moves to the top:

```json
{ "at": [1.5, 4], "title": "and the total adds them up", "style": "subtitle", "placement": "top" }
```

Check it with `frames timeline examples/checkout.json` and `frames still examples/checkout.json --at 0.5,2,4.5,7.5 -o check.png`.
