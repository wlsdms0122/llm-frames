# Text on a path

frames sets a title's text on straight lines ([FRAMES-5](../../spec/FRAMES-5/SPEC.md)), and no key bends a line along a curve. Text on a path is made from what frames already reports and draws: `evaluate` says where each character of a title lies along its line, and one title per character, moved to that distance along the path and turned to the path there, sets the text on it. A script does the arithmetic and writes the document, so the result is an ordinary document that `timeline`, `still` and `render` check like any other.

## The method

- **A path is measured by its arc length.** The script samples the curve finely into a polyline and adds up its segments, so the distance along the path at every sample is known, and the point at any distance is found between two samples. A circular arc of radius 300 sampled into 2000 segments measures 942.4777 against πr = 942.4778, and a cubic Bézier is sampled the same way, since it has no closed form for its length.
- **A character goes where its line put it.** Each character `evaluate` reports has a `rect`, its glyph box in the title's text box ([FRAMES-23](../../spec/FRAMES-23/SPEC.md#text-placement)): its `x` is where its pen starts and its width is the sum of its glyphs' advances. The middle of that advance, at distance `x + w / 2` from where the line starts, is the distance along the path where the character's middle goes, on its baseline. This is how SVG's `textPath` places a glyph.
- **The angle is the path's tangent there**, `atan2(dy, dx)` in degrees. Angles in frames are degrees clockwise with y running down ([FRAMES-1](../../spec/FRAMES-1/SPEC.md)), so this angle is the title's `rotation` as it stands.
- **The anchor is a corner, not the baseline.** A title's `anchor` names a point of its box, and `rotation` turns the title about it ([FRAMES-1](../../spec/FRAMES-1/SPEC.md#placement)). No anchor lies on the baseline, so the script anchors each character's title at `top-left` and moves its `position` back from the point on the path by the vector from that corner to the character's baseline middle, turned by the same angle.
- **Tracking and kerning become distances along the path.** Tracking lies between boxes and kerning is inside the advances ([FRAMES-5](../../spec/FRAMES-5/SPEC.md#spacing)), so both are already in each character's `x` and width, and the path keeps them as arc length. A character's own title has no neighbour, so no tracking is added to it, and its glyph is drawn where the word's pen put it.
- **A character is measured alone as well.** A line is as tall as the largest of its faces, so a character set in one face may sit lower in its line than in a title of its own. The script evaluates the new titles once before it places them and reads each one's own baseline.

## 1. Write the title

Write the text as one title, with an `id` the script can find, in a style of its own and without animation. Each character's title copies the title's keys, so whatever it is given here (`style`, `character`, `paragraph`, `at`, `lane`) each character has.

```json
{ "kind": "sequence",
  "format": { "size": [1280, 720], "fps": 30 },
  "theme": { "styles": { "path": { "size": 96, "weight": "bold", "tracking": 60 } } },
  "storyline": [ { "kind": "solid", "color": "#111827", "duration": 1 } ],
  "clips": [ { "id": "word", "kind": "title", "text": "AVATAR on a path", "style": "path", "position": [640, 360], "animation": "none" } ] }
```

## 2. Read where its characters lie

```sh
frames evaluate /path/to/work/word.json --at 0
```

```
{"evaluate": "0.1.0", ..., "items": [ ...,
  {"place": "clips[0]", "id": "word", "kind": "title", "item": "glyphs", ..., "characters": [
    {"text": "A", "range": [0, 1], "level": 0, "rect": [0, 0, 40.896, 76.288086], "baseline": 62.400391},
    {"text": "V", "range": [1, 2], "level": 0, "rect": [44.736, 0, 37.376, 76.288086], "baseline": 62.400391},
    {"text": "A", "range": [2, 3], "level": 0, "rect": [85.952, 0, 37.952, 76.288086], "baseline": 62.400391},
    ... ] } ],
  "texts": [ {"place": "clips[0]", "id": "word", "text": "AVATAR on a path", "writingMode": "horizontal-tb", "direction": "ltr", ...} ] }
```

The output is shortened here. `size` 96 is a theme length, 64 pixels on a frame 1280 wide. The tracking of 60 is the 3.84 pixels between the first `A`'s box and the `V`'s, and the kerning of `AV` and `VA` is why the three `A`s are 40.896, 37.952 and 43.84 wide. The script reads these numbers itself; this is what it reads.

## 3. Set it on the path

`on-path.py` replaces the title with one title per character. It calls `frames evaluate` twice: once on the title, for where the characters lie along the line, and once on the new titles at the origin, for each one's own baseline. Spaces take their distance along the path and draw nothing, so they get no title. `--guide` also draws the path as one curved `path` shape, a thin line to check against: its vertices and tangents are the curve's own ([FRAMES-11](../../spec/FRAMES-11/SPEC.md#shapes)), so frames draws the curve itself and not the script's samples.

```python
# on-path.py: replaces a title with one title per character, set along a path.
# Usage: python3 on-path.py <document.json> <title id> arc|bezier [--guide] > <out.json>
import json, math, subprocess, sys

# A path is a polyline fine enough that its chords are its arc length: angles in degrees, clockwise, y down.
def arc(center, radius, start, end, count=2000):
    return [(center[0] + radius * math.cos(math.radians(start + (end - start) * k / count)),
             center[1] + radius * math.sin(math.radians(start + (end - start) * k / count)))
            for k in range(count + 1)]

def bezier(p0, p1, p2, p3, count=2000):
    points = []
    for k in range(count + 1):
        u = k / count
        weights = ((1 - u) ** 3, 3 * u * (1 - u) ** 2, 3 * u * u * (1 - u), u ** 3)
        points.append(tuple(sum(w * p[axis] for w, p in zip(weights, (p0, p1, p2, p3))) for axis in (0, 1)))
    return points

PATHS = {
    "arc": arc((640, 520), 300, 180, 360),
    "bezier": bezier((140, 520), (420, 120), (860, 760), (1140, 300)),
}

# The same paths as a path shape's vertices: the arc as two quarter circles, each tangent 4/3 (√2 - 1) of the radius.
GUIDES = {
    "arc": [{"vertex": [340, 520], "outTangent": [0, -165.69]},
            {"vertex": [640, 220], "inTangent": [-165.69, 0], "outTangent": [165.69, 0]},
            {"vertex": [940, 520], "inTangent": [0, -165.69]}],
    "bezier": [{"vertex": [140, 520], "outTangent": [280, -400]}, {"vertex": [1140, 300], "inTangent": [-280, 460]}],
}

# The point at a distance along the path, and the angle of the path's tangent there.
def along(points, lengths, distance):
    index = next((k for k in range(1, len(lengths)) if lengths[k] >= distance), len(lengths) - 1)
    (x0, y0), (x1, y1) = points[index - 1], points[index]
    part = (distance - lengths[index - 1]) / max(lengths[index] - lengths[index - 1], 1e-9)
    return (x0 + (x1 - x0) * part, y0 + (y1 - y0) * part), math.degrees(math.atan2(y1 - y0, x1 - x0))

def evaluate(document, time):
    run = subprocess.run(["frames", "evaluate", "-", "--at", str(time)],
                         input=json.dumps(document), capture_output=True, text=True, check=True)
    return json.loads(run.stdout)

def characters(evaluation, clip_id):
    found = [character for item in evaluation["items"] if item["id"] == clip_id
             for character in item["characters"] or []]
    return sorted(found, key=lambda character: character["range"][0])

document_path, title_id, path_name = sys.argv[1:4]
document = json.load(open(document_path))
title = next(clip for clip in document["clips"] if clip.get("id") == title_id)
time = title["at"][0] if "at" in title else 0
index = document["clips"].index(title)

# 1. The title as one line: where each character lies along it, kerning and tracking included.
evaluation = evaluate(document, time)
vertical = next(text for text in evaluation["texts"] if text["id"] == title_id)["writingMode"] != "horizontal-tb"
groups = []
for character in characters(evaluation, title_id):
    # The characters of a ligature share one box and become one title.
    if groups and groups[-1]["rect"] == character["rect"]:
        groups[-1]["text"] += character["text"]
    else:
        groups.append(dict(character))
groups = [group for group in groups if not group["text"].isspace()]
inline = 1 if vertical else 0
start = min(group["rect"][inline] for group in groups)
end = max(group["rect"][inline] + group["rect"][inline + 2] for group in groups)

# 2. One title per character, measured alone: a character alone takes the baseline of its own face.
clips = []
for number, group in enumerate(groups):
    clip = {key: value for key, value in title.items() if key not in ("placement", "width", "keyframes")}
    clip.update({"id": f"{title_id}-{number}", "text": group["text"], "anchor": "top-left",
                 "position": [0, 0], "rotation": 0})
    clips.append(clip)
document["clips"][index:index + 1] = clips
alone = evaluate(document, time)

# 3. Each title turned to the tangent, with its advance's middle on its baseline at its distance along the path.
points = PATHS[path_name]
lengths = [0.0]
for (x0, y0), (x1, y1) in zip(points, points[1:]):
    lengths.append(lengths[-1] + math.hypot(x1 - x0, y1 - y0))
offset = (lengths[-1] - (end - start)) / 2
for clip, group in zip(clips, groups):
    own = characters(alone, clip["id"])[0]
    advance = group["rect"][inline + 2]
    if vertical:
        local = (own["baseline"], own["rect"][1] + advance / 2)
    else:
        local = (own["rect"][0] + advance / 2, own["baseline"])
    (x, y), tangent = along(points, lengths, offset + group["rect"][inline] - start + advance / 2)
    rotation = tangent - 90 if vertical else tangent
    cos, sin = math.cos(math.radians(rotation)), math.sin(math.radians(rotation))
    clip["position"] = [round(x - (local[0] * cos - local[1] * sin), 3), round(y - (local[0] * sin + local[1] * cos), 3)]
    clip["rotation"] = round(rotation, 3)

if "--guide" in sys.argv:
    document["clips"].insert(index, {"id": f"{title_id}-path", "kind": "path", "points": GUIDES[path_name],
                                     "stroke": {"paint": "#F59E0B", "width": 2}, "fill": False, "animation": "none"})
json.dump(document, sys.stdout, ensure_ascii=False, indent=1)
```

```sh
python3 on-path.py /path/to/work/word.json word arc --guide > /path/to/work/arc.json
python3 on-path.py /path/to/work/word.json word bezier --guide > /path/to/work/bezier.json
frames timeline /path/to/work/arc.json
```

The arc is the upper half of a circle of radius 300 about (640, 520), run from left to right, and the Bézier an S curve across the frame. Change `PATHS` for your own: any list of points close enough together works, and `GUIDES` for its guide. The text is centred on the path. Text longer than the path runs off its ends along the tangent of its first or last segment.

Each character becomes a title like this one, the first `A` on the arc:

```json
{ "id": "word-0", "kind": "title", "text": "A", "style": "path", "position": [336.72, 320.552], "animation": "none",
  "anchor": "top-left", "rotation": -53.415 }
```

## 4. Check it

```sh
frames render /path/to/work/arc.json -o /path/to/out/arc.png --at 0
frames render /path/to/work/bezier.json -o /path/to/out/bezier.png --at 0
```

Look at the pictures, then check the numbers: `evaluate` carries each character's baseline middle to the output by its `transform`, and on the arc every one should lie 300 pixels from the centre.

```sh
frames evaluate /path/to/work/arc.json --at 0 | python3 -c '
import json, math, sys
for item in json.load(sys.stdin)["items"]:
    for character in item["characters"] or []:
        a, b, c, d, tx, ty = item["transform"]
        x, y, width, height = character["rect"]
        px, py = a * (x + width / 2) + c * character["baseline"] + tx, b * (x + width / 2) + d * character["baseline"] + ty
        print(character["text"], round(px, 2), round(py, 2), round(math.hypot(px - 640, py - 520), 2))
'
```

```
A 399.89 340.14 300.0
V 428.03 307.71 300.0
A 460.5 279.61 300.01
T 493.55 258.16 300.01
...
h 881.86 342.51 300.0
```

Every character prints 300.0 or 300.01. The 0.01 is a kerned character: the snippet takes the middle of the character's own box, which is wider than its advance in the word, so the point lies a little way along the tangent. Taken at the middle of the advance in the word, every character lies within 0.0006 pixels of the arc and within 0.03 pixels of the Bézier, and every `rotation` within 0.05 degrees of the exact tangent, since the tangent of a polyline turns in steps, 0.09 degrees a segment on this arc. In the rendered arc the ink of the flat-bottomed letters (`A`, `T`, `R`, `n`, `h`) starts between 300.1 and 300.5 pixels from the centre, and the capitals reach 345.7 to 346.3, their cap height above the baseline. The first `A`'s ink lies 0.28 degrees further along the arc than the middle of its advance: alone the `A` is 43.84 wide, and kerning against the `V` took 2.94 pixels from its advance in the word and nothing from its glyph.

## Right-to-left and vertical text

**Right-to-left text needs nothing more.** `evaluate` gives characters in logical order, the order they are read, and their boxes where they lie on the line ([FRAMES-5](../../spec/FRAMES-5/SPEC.md#direction)): in `שלום עולם` the first character, `ש`, has the box furthest right, at x 269.07. The script places by the box, so the path keeps the line's visual order, and Hebrew reads from the end of the path back to its start, as it reads on a straight line. A mixed title such as `Frames 2.0 יצאה היום` with `"direction": "rtl"` comes out the same way, `Frames 2.0` on the right half of the arc and the Hebrew on the left.

**Vertical text is set along the path with its column turned to it.** In a vertical writing mode the inline axis is y, each character's `rect` runs down the line, and `baseline` is the x of the central baseline ([FRAMES-5](../../spec/FRAMES-5/SPEC.md#writing-mode)). The script reads the distance along the line from y, puts the middle of each character's advance on its central baseline, and turns each title by the tangent less 90 degrees, so the column runs along the path. Each title keeps the title's `writingMode`, so ideographs stand in their vertical forms, `、` and `。` sit in the line-over corner of their cells, and Latin letters lie on their sides. With the default theme fonts, `縦書きの道、ABC。` sets `縦` in PingFang and the rest in Apple SD Gothic Neo. The line is 89.6 wide with its baseline at 44.8, while `書` alone is 76.8 wide with its baseline at 38.4, which is why the script measures each character alone. On the arc, the ink of the upright ideographs centres between 299.4 and 301.6 pixels from the centre, on the path. A vertical column suits a path that runs downward: on the top of the arc its characters lie on their sides.

## What it does not give

- **Scripts whose letters join.** A title of one Arabic letter is shaped alone, in its isolated form, so the letters of `مرحبا بكم` stand apart and the word is broken. Isolated forms are also wider than joined ones, `ب` 48.49 pixels alone against 26.44 in the word, so they overlap. In Devanagari a character is a grapheme cluster, so a conjunct and a reph stay whole (`न्दी` and `र्म` are one character each), but the headline that runs along a word is drawn in one piece per character and turns at each. Set such text on a straight title.
- **Bent glyphs.** Each glyph is drawn rigid and only turned: on a tight curve the inside of the letters crowds and the outside opens, as in every text on a path tool that does not warp outlines.
- **Ligatures that bend.** An optional ligature such as `fi` or `ffi` is one box for its characters, so it becomes one title and stays straight. To bend between its letters, turn ligatures off in the style, `"features": {"liga": 0}`, or give it tracking, which turns them off ([FRAMES-5](../../spec/FRAMES-5/SPEC.md#spacing)).
- **One line.** The script sets the characters of one line. For several lines on several paths, write one title per line.
- **Pieces drawn across characters.** A background, a highlight and an underline are drawn by each character's title alone, as separate pieces. Leave them out of the style, and draw a band along the path as a `path` shape with a wide stroke instead. The script also assumes the title has no `scale` and no `cornerPin`, since it places each character by its unscaled box.
- **Motion along the path.** The document is set at one instant. Each character's title takes `position` and `rotation` keyframes, so the script can write a keyframe per frame to move the text along the path, but between two keyframes a position moves in a straight line ([FRAMES-4](../../spec/FRAMES-4/SPEC.md)), which cuts the curve. A path that changes shape, text that changes, or keyframed tracking needs the script to run again for each instant it is written for. The title's own keyframes are dropped.
- **Animation by character.** Each character is a clip of its own, so `"by": "character"` on one of them moves only that one. Stagger the characters' entrances by their `at` instead.
