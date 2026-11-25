# Motion graphics

frames draws titles, shapes and their keyframes and animations. A graphic beyond them (an animated logo, a chart that draws itself, a lower third laid out with CSS) is made somewhere else and brought in as media ([FRAMES-25](../../spec/FRAMES-25/SPEC.md)). A web page is a convenient place to make one: write it in HTML and CSS, render it frame by frame to PNG files with a transparent background in a headless browser, and bring the folder in as `{"kind": "imageSequence", "directory": ...}` media ([FRAMES-3](../../spec/FRAMES-3/SPEC.md)).

## What frames expects

- **A folder of PNG files.** frames takes every PNG in the folder, in natural order (`2.png` before `10.png`), so keep nothing else in it. Naming frames `0000.png`, `0001.png`, ... keeps them in order in any file browser too.
- **The rate in the media.** `{"kind": "imageSequence", "directory": "/path/to/lower-third", "fps": 30}` plays frame `n` at media second `n / 30`. Render at the document's `fps`, so each frame lands on one output frame. An image sequence plays like a video and takes `in`, `out`, `speed` and `timeRemap`.
- **Alpha.** PNG keeps its alpha, so whatever the page leaves transparent shows the picture below.
- **The output size.** A media clip without `width` or `height` is fitted to the frame. Make the page the size of the document's `format.size` and draw the graphic where it should sit, and it lands there with no placing.
- **The last frame holds.** When a clip's window is longer than its media, the last frame stays on screen. Render only the entrance, and let `at` say how long the graphic stays.

## 1. Write the page

The page draws one frame, the one its URL asks for. CSS animations run on their own clock, so the script pauses every animation and sets its time from `?frame=` and `?fps=`, which makes a screenshot a frame at a known time.

```html
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; width: 1280px; height: 720px; background: transparent; overflow: hidden; }
  .bar { position: absolute; left: 64px; bottom: 96px; padding: 18px 28px;
         background: #2563eb; color: white; font: 600 40px -apple-system, sans-serif;
         border-radius: 12px; animation: in 0.6s cubic-bezier(0.2, 0.8, 0.2, 1) both; }
  .bar small { display: block; font-weight: 400; font-size: 24px; opacity: 0.85;
               animation: fade 0.4s 0.4s both; }
  @keyframes in { from { transform: translateX(-120%); } to { transform: none; } }
  @keyframes fade { from { opacity: 0; } }
</style>
</head>
<body>
  <div class="bar">Checkout, fixed<small>The total now includes shipping</small></div>
  <script>
    // Holds every animation at the time the frame number in the URL asks for.
    const query = new URLSearchParams(location.search)
    const seconds = Number(query.get("frame") || 0) / Number(query.get("fps") || 30)
    for (const animation of document.getAnimations()) {
      animation.pause()
      animation.currentTime = seconds * 1000
    }
  </script>
</body>
</html>
```

- `background: transparent` on the page and the browser's transparent default background below give the PNG its alpha.
- CSS animations and transitions, and the Web Animations API, all show up in `document.getAnimations()`. Motion driven by `requestAnimationFrame` or a timer does not, so compute it from `seconds` instead.
- Open the page in a browser with `?frame=12` to look at one frame while you write it.

## 2. Render the frames

Headless Chrome writes one screenshot per call. Give it the output size and a transparent background colour (`00000000`, the last two digits being alpha):

```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p /path/to/lower-third
for frame in $(seq 0 29); do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1280,720 \
    --default-background-color=00000000 \
    --screenshot="/path/to/lower-third/$(printf %04d $frame).png" \
    "file:///path/to/lower-third.html?frame=$frame&fps=30"
done
```

Thirty frames are one second at 30 fps, enough for this entrance. Each call starts the browser, which takes a few seconds. For a long graphic, a Puppeteer or Playwright script that keeps one page open and takes each screenshot with `omitBackground: true` is much faster, and the page stays the same.

## 3. Check the material

```sh
frames probe /path/to/lower-third
```

```
kind imageSequence
size 1280x720
duration none
fps none
alpha yes
audio none
```

The folder probes as an image sequence. `alpha yes` says the transparency came through, and the size should be the document's. Duration and rate are `none` because the rate is the one the document writes.

## 4. Bring it in

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "kind": "media", "media": "/path/to/recording.mp4", "in": 0, "out": 3 }
  ],
  "clips": [
    { "at": [0.5, 3], "kind": "media", "media": { "kind": "imageSequence", "directory": "/path/to/lower-third", "fps": 30 }, "lane": 2 }
  ] }
```

```sh
frames timeline /path/to/work/lower-third.json
frames still /path/to/work/lower-third.json --at 0.6,0.9,1.4,2.5 -o /path/to/out/lower-third.png
```

The bar slides in from 0.5 seconds, the second line fades in after it, and from 1.5 seconds the last frame holds until 3. On a lane above the storyline the graphic covers every storyline clip it spans. To have it ride on one storyline clip instead, put it in that clip's `connected` with `at` on the clip's clip time, and give it `parent` set to the clip's `id` when it should also move with the clip's transform and transitions ([FRAMES-10](../../spec/FRAMES-10/SPEC.md)).

To take it away, either render the exit in the page as well and let the frames run out at the end of `at`, or give the clip an exit animation: `"animation": { "entrance": "none", "exit": "frames/fade" }`.

## Notes

- Text in the graphic is pixels to frames. Change the page and render again to change it. Words that change from edit to edit are better as frames titles over a graphic that has none, and a graphic used with different words in many edits is better as a template whose words are `text` parameters ([PACK.md](../PACK.md#a-template)).
- A graphic used in many edits belongs in a pack: put the folder in the pack's `media/` and name it `<pack>/<folder>` in `imageSequence`, so the pack carries it ([PACK.md](../PACK.md)).
- A browser renders the fonts installed on the machine. Use the same font as the form's theme, so the graphic and the titles match.
