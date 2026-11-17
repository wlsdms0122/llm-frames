# pr-evidence

A screenshot or a short recording that proves what a pull request changes.

## What it is for

The reviewers of a pull request watch it, in the pull request's description or in a review comment on the code host (GitHub, GitLab), shown inline at the width of the page, about 900 pixels on a desktop. They look at it before or beside the code and decide from it whether the change does what the title says. People come back to it later from the history, without the context of the review. So it states one claim and shows the proof of that claim, and nothing in it can be read as something else.

## Theme

`pr-evidence/pr-evidence`. Every document of this form writes `"theme": "pr-evidence/pr-evidence"`.

It changes only `shapes.label.sides`, to `["right", "bottom", "left"]`. A label never goes above a box, where it would cover the line above, and the line above is often the one that gives the boxed line its meaning. Everything else is the base theme: red boxes with white-on-red labels, a white banner with black text, the base `fill` colour, and no default presets but `pop` on labels.

## Format

**A screenshot** is an `image` document on the screenshot, in this order of operations:

1. `crop` to a band: `{"crop": {"band": <area>}}`, the area usually `{"from": "<first line>", "to": "<last line>"}` around the lines that make the claim and the lines that give them their meaning.
2. The covers: a `fill` with an opaque `color` over every piece of personal data the crop keeps.
3. The boxes, one on each reason line, with a `label` when the line alone does not say why it is boxed.
4. The banner: `{"banner": [{"text": "<conclusion>", "style": "bannerHead"}, "<reason>"], "edge": "top"}`.
5. `{"border": true}`, so a screenshot with a white background keeps its edge on a white page.

Its size is the source's. Leave out `resize`: the code host scales the picture to the page, and text captured at 2x stays sharp when it does.

**Two states** (before and after) are a `layout` with `"columns": 2`, the headings `Before` and `After`, each item an image document made as above without its own banner, and the banner in the layout's `banner`.

**A recording** is a `sequence` whose top band is the banner, built from titles:

- `size` is the recording's width `W` and its height plus the band, `[W, H + B]`, with `"inset": [B, 0, 0, 0]`, `"conform": "fit"` and `"background": "#FFFFFF"`, so the band is white like an image banner and the recording keeps its own pixels below it.
- With `s = W / 1206` (the theme's `baseWidth`), the band for a conclusion and one reason line is `B = 208 × s`, rounded up to an even number: 40 points of room, two lines of 64, and 40 points of room. Each more reason line adds `64 × s`.
- The banner lines are sequence clips without `at`, so they hold for the whole video: the conclusion in `bannerHead` at `"position": [40 × s, 40 × s]` with `"anchor": "top-left"`, and each reason line in `banner` 64 × s below the one before it.
- For a 1280 by 720 recording, `s` is 1.0614, the size is `[1280, 942]`, the inset `[222, 0, 0, 0]`, and the lines sit at `[42, 42]` and `[42, 110]`.

## Rules

### Text

- The conclusion comes first, in `bannerHead`, as one sentence of what is now true ("Total includes shipping"). A reviewer reads the first line and may stop there.
- The reason follows in one or two `banner` lines and says what in the picture proves the conclusion. A conclusion without its proof is a claim, not evidence.
- No `**` in the banner or in labels. The emphasis colour is yellow, which cannot be read on the white band.
- A label is one to four words and names the fact its box shows ("42,000 = 38,000 + 4,000", "now 4,000"). A label is one line, and one that does not fit stops.
- Write in the language of the pull request. A reviewer reads the evidence beside its description.

### Emphasis

- Only the reason lines get a box. A box on anything else asks the reviewer to check something that proves nothing.
- One box per reason line, with a label only where the line alone does not say why it matters. A picture full of boxes points at nothing.
- A `dim` around the reason lines is used only when the crop still holds much more than they do. It darkens the context the reader may need, so it is the exception.
- Personal data is covered with an opaque `fill` at opacity 1 with no animation (`"color": "#000000"`, or the colour of the screen behind it, and `"animation": "none"` on a sequence), on every clip and every frame that shows it. On video, use `track`, or area keyframes from `ocr --json` where the data leaves the screen and comes back. Evidence is posted where many people read it, and one frame is enough to leak it.
- A template is a closed box, so a recording given to one is covered first: render it with its covers to a master and pass that file. The template cannot cover what it cannot see.
- The finished file is checked with `ocr` (`frames ocr out.png`, and over a range with `--from`, `--to` and `--step 0.5` for a video), and no covered text may come back. A cover that misses by a frame or a few pixels shows in text recognition before a person sees it.

### Cuts

- Crops are bands (`{"band": ...}`), since evidence keeps whole lines. A line cut in half can be read as hiding its other half.
- A recording is cut to the action: from just before the input to just after the result shows, at speed 1. Speeding it up changes what it proves about time.
- Cut a recording only where nothing changes on the screen, and put a `fade` at the cut. A cut that hides itself looks like something was taken out.
- Transitions are `fade` at 0.3 to 0.5 seconds. A plain dissolve shows that time passed without telling a story.
- No filters. The colours of a screen are part of what it shows.
- No music, and a recording's own sound is turned off (`"volume": 0`) unless the sound is the evidence. Reviewers watch inline and muted, and sound that proves nothing is noise.

### Length

- One claim per picture or video. A second claim is a second piece of evidence, since the banner states one conclusion.
- A recording runs at most 30 seconds, and under 15 is better. It plays inline and is watched more than once.
- A still is enough when the result does not move. A recording is for what happens over time: an animation, a sequence of states, something that loads.

## Presets

- Use `fade` between recording parts, at 0.3 to 0.5 seconds: `{"preset": "fade", "seconds": 0.4}`.
- Labels keep the theme's default `pop`. It lands the label once and then holds still.
- Boxes and covers take no animation. The theme leaves `shape` at `none`, so a reviewer who pauses on any frame sees the box whole. Write `"animation": "none"` on covers anyway, so a `--theme` given on the command line cannot animate them.
- Do not use filters, for the reason in Cuts.
- Do not use moving transitions (`push-*`, `slide-*`, `uncover-left`, `wipe-*`, `zoom-*`), `flash` or `dip-black`. They make an edit look like a story and pull the eye from the proof.
- Do not use `pulse`, `blink` or `shake`. They draw the eye away from the reason lines, and the frame a reviewer pauses on may catch them mid-motion.

## Example

Two examples are in `examples/`. They name their media by placeholder paths under `/path/to/`, so change each to an absolute path of your own before they run:

- `/path/to/checkout.png`: a screenshot of an order summary with the lines `Order summary`, `Ship to` and an email address, `Item total 38,000`, `Shipping 4,000` and `Total 42,000`, one above the other.
- `/path/to/checkout.mov`: a 1280 by 720 recording of an order summary, at least 1.4 seconds long, that shows the line `Total 42,000` on its first frame. A recording of another size changes `size`, `inset` and the title positions as Format says.

`examples/screenshot.json` is the screenshot form, its operations in the order Format gives. The band crop runs from `Order summary` to `Total`, so it keeps the heading for context and the address line with it, and the address is covered before anything is boxed:

```json
{ "shape": "fill", "id": "address", "area": "Ship to", "color": "#000000" }
```

The three reason lines each get a box, and only the total, whose box alone does not say why it is boxed, gets a label (`38,000 + 4,000`). The banner gives the conclusion, then the reason.

`examples/recording.json` is the recording form for a 1280 by 720 recording: `size` `[1280, 942]` and `inset` `[222, 0, 0, 0]` make the band, and two sequence clips without `at` write the banner into it for the whole video, the conclusion at `[42, 42]` and the reason at `[42, 110]`. The recording plays at speed 1 with its sound off, and the box on `Total` is connected to it, so it stays on the line.

Check each with `frames timeline` and `frames still` (the screenshot is checked by putting it in a one-clip sequence, or by rendering it to a PNG). Render, then run `frames ocr` on the result and make sure the address does not come back.
