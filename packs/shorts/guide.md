# shorts

A Korean vertical short: 9:16, a headline on a black bar at the top, outlined subtitles on a black bar at the bottom, the picture between them, scenes that push up.

## What it is for

Viewers scrolling a vertical feed on a phone watch it: YouTube Shorts, Instagram Reels, TikTok. They hold the phone upright, often with the sound off, and decide in the first second whether to stay or swipe on. The platform draws its own buttons over the right side and its caption over the bottom of the picture. So the headline says at once what the video gives, the subtitles carry what a voice would say, and nothing that matters sits where the platform draws.

## Theme

`shorts/shorts`. Every document of this form writes `"theme": "shorts/shorts"`.

- `baseWidth` is 1080, so every theme length is an output pixel of a 1080 wide short. The font is Apple SD Gothic Neo, which holds Hangul and Latin in one face.
- A red `accent` (`#FF3B30`) for outlines and labels, and a yellow `highlight` (`#FFE14D`) for the one highlighted run.
- Text styles: `headline` (84, bold, white, a 104 line, at the top 110 below the frame's top edge, centred, at most two lines), `subtitle` (66, bold, white with a black stroke 7 wide, at the bottom with its last line 330 above the frame's bottom edge, centred, at most two lines), `label` (40, bold, white on a red rounded box, one line). The run styles `headline-highlight` and `subtitle-highlight` are the same sizes in `highlight`.
- Shape styles: `outline` (a red stroke 10 wide, corners rounded 18) and `bar` (opaque black fill).
- `placement.padding` is 40, so a title placed by `placement` keeps 40 from the frame's sides.
- Defaults: every storyline clip after the first comes in with `frames/push-up` in 0.3 seconds, and subtitles, labels and media clips pop in and out (`frames/pop`). The headline and shapes take no animation.

## Format

`"size": [1080, 1920]`, `"fps": 30`, `"background": "#000000"`, `conform` left at `fit`. Each scene is a storyline clip, fitted 1080 wide.

**The bars.** Two rects in the `bar` style in `clips`, without `at`, so they hold for the whole video: the top bar 1080 by 420 at `"anchor": "top-left", "position": [0, 0]`, and the bottom bar 1080 by 520 at `"anchor": "bottom-left", "position": [0, 1920]`. The picture shows between them, from 420 to 1400. A fitted picture taller than that zone reaches under the bars and is covered there, so a portrait screenshot shows the middle 980 pixels of its fitted height, and a landscape recording sits whole in the zone.

**The headline.** One title in the `headline` style in `clips`, after the bars, with no `placement` and no `position`: the style sets it on the top bar. Two lines end at about 320, inside the bar. Without `at` it holds for the whole video; a video in parts gives each part's headline its own `at`, back to back on the sequence clock.

**Subtitles.** Titles in the `subtitle` style, connected to the scene they belong to, with no `placement` and with `"lane": 2`. Clips on lane 1 stack in document order, connected clips before sequence clips, so a subtitle on lane 1 would be under the bars; on lane 2 it draws over the bottom bar, its last line ending at 1590, above the platform's caption.

**Outlines.** A rect in the `outline` style connected to its scene and parented to it, its area in the scene's media pixels and a request for `frames find-text`, which fills it with the rectangle `frames ocr` finds for the text (the extension is in the frames repository under `extensions/find-text/`): `{ "shape": "rect", "style": "outline", "parent": "summary", "area": { "tool": "find-text", "from": "Total", "to": "42,000", "padding": 16 } }`. It stays on lane 1, under the bars. It is drawn on by its `trim`, from `[0, 0]` to `[0, 1]` in 0.3 seconds with `"ease": "ease-out"`. On a recording it follows the row with `"track": { "tool": "track-motion", "target": "area" }`, a request for `frames track-motion`, which fills it with the track data `frames track` prints for the outline's area (the extension is under `extensions/track-motion/`), and comes in whole.

**Labels.** A title in the `label` style on lane 2, parented to its outline (`"parent": "<the outline's id>"`) and set at a point of the outline's box: `"position": { "area": { "clip": "<the outline's id>" }, "point": "bottom-left" }, "anchor": "top-left"`. It hangs below the outline's left end and stays left of x 960, out of the platform's buttons.

**Zoom.** A crop keyframe from `{ "scale": 1 }` to an area around the subject, a request for `frames find-text` or the rectangle `frames ocr` reports, zooms a scene. Give the request `"aspectRatio": [1080, 1920]`, the frame's ratio, which a scene's box has, so the zoomed crop lies inside the recording and fills the frame with no empty band above or below it. A subject wider than the recording holds at that ratio stops, and is zoomed less. Use it on a landscape recording where the subject is a part of its width. A portrait screenshot already fills the picture zone's width, so it is shown whole and the outline carries the eye.

## Rules

### Text

- The headline is one or two lines of at most 10 syllables each, broken with `\n` where you want the break. It is the hook, read in the first second. It has no `width`, so it breaks only at `\n`, and a longer line runs toward the frame's edges.
- A subtitle is one spoken phrase on one line of at most 14 syllables, two lines at the most, the second after a `\n`. Viewers read it while they watch, and 15 syllables fill the width. It has no `width`, so it does not wrap by itself.
- Subtitles follow the voice, in spoken Korean (해요체), without a full stop at the end. They stand in for a voice that many viewers have muted.
- Numbers are written as digits (`42,000원`, `3초`). Digits are read faster than words.
- Labels are one to three words. A label is one line, and one that does not fit stops.

### Highlight and marks

- A run in `headline-highlight` or `subtitle-highlight` marks at most one word or number in the headline and one in a subtitle. The yellow is where the eye jumps, and two places split it.
- An outline goes on the thing the subtitle is talking about, while it is talking about it. Pointing at something no one mentions makes the viewer search.
- One outline at a time, with at most one label. A small screen holds one point.
- Nothing that matters goes in the right 120 pixels or under the bars. The platform draws its buttons on the right, and the bars cover the picture beyond 420 to 1400.

### Cuts

- A scene lasts 2 to 4 seconds. A still picture held longer is where viewers swipe away.
- Scenes change with the theme's `frames/push-up`, so write no `transition` between them. The push moves the way the feed moves.
- A jump inside one recording, the same screen going on, takes `"transition": "cut"`. A push there would look like a new scene.
- Subtitles change back to back, each with its own `at` in its scene's seconds, so one is always on screen while someone speaks.

### Sound

- A screen recording's own sound is off (`"volume": 0`). Clicks and system sounds say nothing to a viewer in a feed.
- A voice or music is an audio clip in `clips`; music sits at a `volume` of 0.2 to 0.3 under a voice. Subtitles carry every word of the voice, since many viewers watch muted.

### Length

- 15 to 60 seconds. Shorter says too little to be worth the swipe, and longer loses most viewers before the end.
- The first frame already shows the headline and a picture: no intro card, no fade from black. Viewers decide in the first second.
- End on the result, held for at most a second. An end card is where viewers leave.

## Presets

- Keep the theme defaults: `frames/push-up` between scenes and `frames/pop` on subtitles, labels and media clips. They are timed for a 1 to 2 second subtitle.
- Draw outlines on with `trim` keyframes, as in Format. `frames/wipe` reveals a shape from the left and suits an outline too.
- `frames/zoom-in` can open a scene that reveals a result.
- `frames/stamp` or `frames/bounce` can land one label that carries the point of the video.
- Do not use horizontal transitions (`frames/push-left`, `frames/slide-left`, `frames/slide-right`, `frames/uncover-left`, `frames/wipe-left`, `frames/wipe-right`). They move across the vertical swipe.
- Do not use `frames/dip-black` or `frames/fade` between scenes. A dip reads as the end, and a dissolve is slow for a 2 second scene.
- Do not use `frames/fade` on subtitles. A line of 1 to 2 seconds spends too much of it fading.
- Do not use `frames/noir`, `frames/sepia`, `frames/mono` or `frames/faded` on a screen recording. The colours of an app's screen mean something. `frames/vivid` and `frames/warm` are for camera footage.
- Use `frames/shake` and `frames/blink` at most once, for a warning. Used more, they are noise.

## Example

`examples/checkout.json` is a 5.9 second short in two scenes. It names its media by placeholder paths under `/path/to/`, so change each to an absolute path of your own before it runs:

- `/path/to/checkout.png`: a portrait screenshot 1206 pixels wide of an order summary with the rows `Order summary`, `Ship to` with `jane@example.com`, `Item total` with `38,000`, `Shipping` with `4,000`, `Total` with `42,000` and `Arrives in 2 days`, and a `Pay 42,000` button below them. Rows are read with their label at the left and their value at the right.
- `/path/to/checkout.mov`: a 1280 by 720 recording, at least 2.8 seconds long, of the same summary on a desktop, where `Add shipping` is clicked at 1 second and `Total` turns from `38,000` to `42,000`.

It shows the format and the rules together:

- The bars and the headline are in `clips` without `at`. The headline is `[ { "text": "결제 금액이\n" }, { "text": "한눈에", "style": "headline-highlight" }, { "text": " 보여요" } ]`, two short lines broken by hand and one word highlighted.
- The first scene is the screenshot for 3.5 seconds. Its subtitles change back to back at `[0, 1.6]` and `[1.6, 3.5]`, the second with `합계` highlighted. The outline on the `Total` row draws on from 1.8 to 2.1 seconds, and the label `배송비 포함` pops in under its left end at 2.1. `"toNth": 0` picks the row's `42,000` and not the button's.
- The second scene is the recording from `in` 0.4 to `out` 2.8 with its sound off, pushed up by the theme. Its outline follows the `Total` row from 1.1 seconds with a track request that names its area, once the total reads `42,000`, while the subtitle names the amount.
- No clip names a transition or an animation except the outline's `trim` keyframes: the theme pushes the second scene up and pops the subtitles and the label in.

Its outlines are requests for `frames find-text`, and the recording's outline's track a request for `frames track-motion` that names its area, so it goes through `frames find-text` and then `frames track-motion`, which fill them and write the frames document: `frames find-text /path/to/checkout.json | frames track-motion - > /path/to/out/checkout.json`. Check that document with `frames timeline` and `frames still --at 0.3,2.6,4.6`: the headline sits on the top bar, each subtitle on the bottom bar above 1590, the outline on the `Total` row in both scenes, and the label left of x 960. Then lay the whole of it out with `frames sheet`.
