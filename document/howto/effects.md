# Effects

A filter preset combines the filter ops frames has ([FRAMES-15](../../spec/FRAMES-15/SPEC.md)). An effect beyond them, such as particles, a glitch or a shader of your own, is made outside frames and brought in as media ([FRAMES-25](../../spec/FRAMES-25/SPEC.md)). There are two ways, depending on whether the effect adds something over the picture or changes the picture itself.

- **Over the picture:** render the effect as its own layer and lay it over with a `blend`.
- **On the picture:** `extract` the frames of the clip's media over its range, process them, and point the clip's `media` at the result.

## Over the picture

Light leaks, film burns, sparks, dust and particles add light or shapes to whatever is below. Render them as a video with alpha (ProRes 4444, or HEVC with alpha) or as a PNG sequence, and put the result on a lane above the picture:

```json
{ "at": [0.5, 2], "media": "/path/to/light-leak.mov", "blend": "screen", "lane": 3 }
```

- An effect that is light on black needs no alpha. `screen` and `plus-lighter` leave a picture unchanged where the layer is black and brighten it where the layer is lit, which is how light leaks and film burns are delivered.
- Light that should go above reference white, in an HDR sequence or over an HDR highlight, or keep a wide gamut colour goes over with `add`, the unbounded Linear Dodge (Add): `screen` gives less than a value above 1 and `plus-lighter` clips each channel at 1, which also cuts a wide gamut colour towards sRGB ([FRAMES-11](../../spec/FRAMES-11/SPEC.md#blend-modes)).
- An effect with its own alpha (particles, a frame, a scratch) goes over with the default `normal` blend.
- Other modes change what the layer does: `multiply` darkens (dust, vignettes of your own), `overlay` and `soft-light` add contrast, and `color` over a rect of one colour washes the picture in that colour while keeping its luminosity. The modes are those of W3C Compositing and Blending: `normal`, `multiply`, `screen`, `overlay`, `darken`, `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `plus-lighter`, `hue`, `saturation`, `color` and `luminosity`, and `add` ([FRAMES-11](../../spec/FRAMES-11/SPEC.md#blend-modes)).
- `probe` the file first: `alpha yes` says the alpha came through.

A PNG sequence works the same way and needs no encoder. This Python script (Pillow and NumPy) draws a warm glow that drifts across a 1280 by 720 frame and fades in and out:

```python
# leak.py: a warm glow on black that drifts across the frame, for `screen`.
# Usage: python3 leak.py <out-dir> <frames>
import pathlib, sys
import numpy
from PIL import Image

target, count = pathlib.Path(sys.argv[1]), int(sys.argv[2])
target.mkdir(parents=True, exist_ok=True)
height, width = 720, 1280
rows, columns = numpy.mgrid[0:height, 0:width]
for index in range(count):
    progress = index / max(count - 1, 1)
    centre = (-200 + 1700 * progress, 200)
    distance = numpy.hypot(columns - centre[0], (rows - centre[1]) * 1.6)
    glow = numpy.clip(1 - distance / 700, 0, 1) ** 2 * numpy.sin(numpy.pi * progress)
    colour = numpy.stack([glow * 255, glow * 140, glow * 40], axis=-1).astype(numpy.uint8)
    Image.fromarray(colour, "RGB").save(target / f"{index:04d}.png")
```

```sh
python3 leak.py /path/to/leak 45
```

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "media": "/path/to/recording.mp4", "in": 0, "out": 3 }
  ],
  "clips": [
    { "at": [0.5, 2], "media": { "imageSequence": "/path/to/leak", "fps": 30 }, "blend": "screen", "lane": 2 }
  ] }
```

```sh
frames still /path/to/work/leak.json --at 0.6,1,1.3,1.9 -o /path/to/out/leak.png
```

`screen` shows little over a light screen recording and a lot over a dark shot, so look at the result on the material it goes on. Draw the layer the size of the output, since a media clip without `width` or `height` is fitted to the frame. To keep the effect on one storyline clip, put it in that clip's `connected`, with `at` on the clip's clip time. With `parent` set to the clip's `id` it also moves with the clip's transform and transition motion ([FRAMES-10](../../spec/FRAMES-10/SPEC.md)). Its blend still reaches everything below it, so to blend it onto that one picture alone, put the picture and the layer together in a compound clip.

## On the picture

A glitch, a pixel sort or a shader changes the pixels of the clip itself. frames gives you those pixels with `extract`, you change them with any tool, and the clip plays the changed frames as an image sequence.

The example glitches the middle second of a three second recording, from media second 1 to 2.

### 1. Extract the frames

Extract at the document's frame rate, so there is one file per output frame:

```sh
frames extract /path/to/recording.mp4 /path/to/work/raw --from 1 --to 2 --step $(echo "scale=10; 1/30" | bc)
```

`extract` takes frames at `from + k × step` for every time before `--to`, compared to the microsecond, and writes `0000.png`, `0001.png`, ... Write the step with enough digits: `--step 0.0333` falls behind by a little more each frame and gives 31 frames for one second, one of them twice. `0.0333333333` gives 30. On a recording with a variable frame rate this is also right: each file is the frame shown at that output frame's time, which is what frames would have drawn.

When a transition plays into or out of the processed range, it shows the media beyond `in` and `out` (the handles). Extract those as well, from half the transition before the range to half after it.

### 2. Process them

Any tool that reads and writes PNG works. This script splits the colour channels and shifts bands of rows, hardest in the middle of the range:

```python
# glitch.py: splits the colour channels and shifts bands of rows, harder towards the middle of the range.
# Usage: python3 glitch.py <in-dir> <out-dir>
import math, pathlib, random, sys
import numpy
from PIL import Image

source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
target.mkdir(parents=True, exist_ok=True)
files = sorted(source.glob("*.png"))
for index, file in enumerate(files):
    strength = math.sin(math.pi * (index + 0.5) / len(files))
    random.seed(index)
    pixels = numpy.array(Image.open(file).convert("RGBA"))
    split = int(12 * strength)
    pixels[..., 0] = numpy.roll(pixels[..., 0], -split, axis=1)
    pixels[..., 2] = numpy.roll(pixels[..., 2], split, axis=1)
    for _ in range(int(6 * strength)):
        top = random.randrange(pixels.shape[0] - 40)
        height = random.randrange(8, 40)
        pixels[top:top + height] = numpy.roll(pixels[top:top + height], random.randint(-60, 60), axis=1)
    Image.fromarray(pixels).save(target / file.name)
```

```sh
python3 glitch.py /path/to/work/raw /path/to/work/glitched
```

Keep the file names. They carry the order, and the image sequence plays them as they sort.

### 3. Point the clip at them

The processed range becomes its own storyline clip, a blade as [GUIDE.md](../GUIDE.md#editing-without-changing-what-is-shown) teaches, and that part's `media` is the folder:

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "storyline": [
    { "id": "demo", "media": "/path/to/recording.mp4", "in": 0, "out": 1,
      "connected": [ { "at": [0.4, 1], "parent": "demo", "shape": "rect", "area": { "tool": "frames/find-text", "text": "Total", "padding": 8 },
                       "stroke": { "color": "#F59E0B", "width": 4 } } ] },
    { "id": "demo-glitch", "media": { "imageSequence": "/path/to/work/glitched", "fps": 30 }, "transition": "cut",
      "connected": [ { "media": "/path/to/recording.mp4", "in": 1, "out": 2, "opacity": 0 } ] },
    { "id": "demo-end", "media": "/path/to/recording.mp4", "in": 2, "out": 3, "transition": "cut" }
  ] }
```

- The image sequence starts at its own media second 0, which is media second 1 of the recording. So the glitched clip takes no `in` and `out` (it plays all 30 frames), and anything connected to it moves its `at` and keyframes back by 1, the old `in`. If you extracted handles, write where the range sits in the folder: `in` is half the transition, and `out` is `in` plus the range's length.
- An image sequence has no sound. The connected recording over the same media range, with `opacity` 0, keeps the sound playing through the glitch without drawing anything. It has no `at`, so it spans its storyline clip.
- The parts after the first take `"transition": "cut"`, so the theme's default transition does not play inside what was one shot.

### 4. Check that only the effect changed

Run the same document with the unprocessed folder (`raw` in place of `glitched`). It should draw exactly what the original single clip drew, and comparing stills shows that the range, the rate and the times are right before you look at the effect itself. `original.json` is the recording as one storyline clip, `in` 0 and `out` 3, with the same ring. The ring's area is a `frames/find-text` request, so each document goes through `frames frames/find-text` first, which fills it:

```sh
for name in original raw glitch; do
  frames frames/find-text /path/to/work/$name.json > /path/to/work/$name.frames.json
done
for t in 0.9 1 1.5 1.9667 2 2.5; do
  frames still /path/to/work/original.frames.json --at $t -o /path/to/work/a.png
  frames still /path/to/work/raw.frames.json --at $t -o /path/to/work/b.png
  cmp -s /path/to/work/a.png /path/to/work/b.png && echo "$t same" || echo "$t differs"
done
frames still /path/to/work/glitch.frames.json --at 0.9,1,1.5,1.97,2 -o /path/to/out/glitch.png
```

## Notes

- A shape whose area is a `frames/find-text` request, parented to a processed clip, looks for the text in the processed frames, where a glitch may hide it. Point at it by the rectangle `ocr` reports on the original (`[x, y, w, h]`), or keep the shapes on the parts before and after.
- Processing a whole clip is the same with the whole media range. Extract only what plays, since every frame is a full size PNG.
- An effect over everything frames draws, titles and shapes included, starts from the document itself: `extract` given a document writes the composite frames at sequence times, as `still` draws them. Process those and make the folder the storyline of a new document, with the first document connected over it at `opacity` 0 for its sound, or render that first document to a master and use the master as media.
