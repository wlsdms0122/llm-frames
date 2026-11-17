# shorts

A Korean vertical short: 9:16, a headline in the top band, outlined subtitles, scenes that push up.

## What it is for

Viewers scrolling a vertical feed on a phone watch it: YouTube Shorts, Instagram Reels, TikTok. They hold the phone upright, often with the sound off, and decide in the first second whether to stay or swipe on. The platform draws its own buttons over the right side and its caption over the bottom of the picture. So the headline says at once what the video gives, the subtitles carry what a voice would say, and nothing that matters sits where the platform draws.

## Theme

`shorts/shorts` ([FRAMES-22](../../spec/FRAMES-22/SPEC.md)). Every document of this form writes `"theme": "shorts/shorts"`.

It sets `baseWidth` to 1080, so its lengths are output pixels on a 1080 wide short. It makes the accent red `#FF3B30` and the emphasis yellow `#FFE14D`. Subtitles are 66 pixels, white with a 7 pixel black outline and no box, their bottom 330 pixels above the bottom of the frame. The headline is 84 pixels, white with the base theme's black outline, its top 110 pixels below the top of the frame. Labels are 40 pixels and boxes 10 pixels wide. Its defaults push every scene up in 0.3 seconds (`push-up`), pop subtitles, labels and media clips in (`pop`), draw shapes in (`draw`), and show the headline without an entrance.

## Format

- `"size": [1080, 1920]`, `"fps": 30`, `"background": "#000000"`.
- `"inset": [420, 40, 120, 40]`, `"conform": "fit"`. The content rect, where the scenes play, is 1000 by 1380 below a 420 pixel top band. A landscape screen recording fits it 1000 wide, and the frame stays black around it.
- The top band is built from the headline: one title in the `headline` style in `clips` with no `placement` and no `position`, so the style puts it at the top, 110 pixels down, centred. Without `at` it holds for the whole video. A video in parts gives each part's headline its own `at`, back to back on the sequence clock. Two lines of 84 pixels end at 320, and the band leaves room below them.
- Subtitles are titles in the `subtitle` style, connected to the scene they belong to, with no `placement`: the style puts them at the bottom, centred, their last line ending at 1590, below a fitted landscape picture and above the platform's caption.
- Boxes, arrows and labels are connected to their scene by `area`, so they stay on the text they point at while the scene zooms.

## Rules

### Text

- The headline is one or two lines of at most 10 syllables each, broken with `\n` where you want the break. It is the hook, read in the first second, and a line that wraps by itself breaks where it likes.
- A subtitle is one spoken phrase on one line of at most 14 syllables, two lines at the most. Viewers read it while they watch, and 15 syllables fill the width.
- Subtitles follow the voice, in spoken Korean (해요체), without a full stop at the end. They stand in for a voice that many viewers have muted.
- Numbers are written as digits (`42,000원`, `3초`). Digits are read faster than words.
- Labels are one to three words. A label is one line, and one that does not fit stops.

### Emphasis

- `**` marks at most one word or number in a subtitle and one in the headline. The yellow is where the eye jumps, and two places split it.
- A box goes on the thing the subtitle is talking about, while it is talking about it. Pointing at something no one mentions makes the viewer search.
- Zoom in on what is talked about with crop keyframes: `{"scale": 1}` first, then the area by its text. The picture is small on a phone, and a screenshot read whole is unreadable there.
- Nothing that matters goes in the right 120 pixels or the bottom 330, where the platform draws over the picture.

### Cuts

- A scene lasts 2 to 4 seconds. A still picture held longer is where viewers swipe away.
- Scenes change with the theme's `push-up`, so write no `transition` between them. The push moves the way the feed moves.
- A jump inside one recording, the same screen going on, takes `"transition": "cut"`. A push there would look like a new scene.
- Subtitles change back to back, each with its own `at` in its scene's seconds, so one is always on screen while someone speaks.

### Length

- 15 to 60 seconds. Shorter says too little to be worth the swipe, and longer loses most viewers before the end.
- The first frame already shows the headline and a picture: no intro card, no fade from black. Viewers decide in the first second.
- End on the result, held for at most a second. An end card is where viewers leave.

## Presets

- Keep the theme defaults: `push-up` between scenes, `pop` on subtitles, labels and media clips, `draw` on shapes. They are timed for a 1 to 2 second subtitle.
- `zoom-in` can open a scene that reveals a result.
- `stamp` or `bounce` can land one label that carries the point of the video.
- Do not use horizontal transitions (`push-left`, `slide-left`, `slide-right`, `uncover-left`, `wipe-left`, `wipe-right`). They move across the vertical swipe.
- Do not use `dip-black` or `fade` between scenes. A dip reads as the end, and a dissolve is slow for a 2 second scene.
- Do not use `fade` on subtitles. A line of 1 to 2 seconds spends too much of it fading.
- Do not use `noir`, `sepia`, `mono` or `faded` on a screen recording. The colours of an app's screen mean something. `vivid` and `warm` are for camera footage.
- Use `shake` and `blink` at most once, for a warning. Used more, they are noise.

## Example

`examples/checkout.json` is a 6 second short in two scenes. It names its media by placeholder paths under `/path/to/`, so change each to an absolute path of your own before it runs:

- `/path/to/checkout.png`: a screenshot of an order summary with the lines `Order summary`, `Item total 38,000`, `Shipping 4,000` and `Total 42,000`.
- `/path/to/result.png`: any picture of the result. Nothing is found by its text.

It shows the format and the rules together:

- The headline is the one title in `clips`, with no `at`, so it holds the top band for the whole video: `"결제 금액이\n**한눈에** 보여요"`, two short lines broken by hand and one word in emphasis.
- The first scene zooms from the whole screenshot to the lines from `Item total` to `Total` with two crop keyframes, then boxes `Total` while its subtitle names it.
- Its subtitles change back to back in the scene's seconds, `[0, 1.6]` then `[1.6, 3.5]`, and the second scene's subtitle spans that scene.
- No clip names a transition or an animation: the theme pushes the second scene up, pops the subtitles and the label in, and draws the box.

Check it with `frames timeline /path/to/work/checkout.json` and `frames still /path/to/work/checkout.json --at 0.5,2.5,4.5 -o /path/to/out/check.png`, where `/path/to/work/` is where you copied it (paths are absolute).
