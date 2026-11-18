# Making a pack

A pack is a directory of looks and edits made to share or sell: presets, themes, templates, LUTs, media and fonts, and for a form its guide and examples. frames reads it as data, so a pack never needs a rebuild of frames. The rules are [FRAMES-17](../spec/FRAMES-17/SPEC.md), and forms are [FRAMES-25](../spec/FRAMES-25/SPEC.md).

## What is in a pack

```
mine/
  pack.json
  presets/transition/drop-in.json      mine/drop-in
  presets/animation/lift.json          mine/lift
  presets/filter/warm-screen.json      mine/warm-screen
  themes/dark.json                     mine/dark
  templates/intro.json                 mine/intro
  templates/callout.json               mine/callout
  luts/film.cube                       mine/film
  media/grain.mov                      mine/grain.mov
  media/confetti/0000.png ...          mine/confetti (an image sequence)
  fonts/Pretendard-Bold.otf            by its family, in a theme's font list
  guide.md, examples/                  for a form, read by people and agents
```

Every folder is optional. The right column is how a document names each file.

`pack.json` says which versions of frames the pack is written for, and what `frames packs` shows:

```json
{ "engine": "^1", "name": "Mine", "version": "1.0.0", "description": "A dark look, two presets and an intro for vertical videos" }
```

- `engine` is required: `^1` is any 1.x, `^1.2` is 1.2.0 or later before 2.0.0. Outside its range the pack stops when it is used, naming both versions.
- `name`, `version` and `description` are optional strings, only for people. Any other key stops.

## Installing

Installing is copying the directory into `$FRAMES_HOME/packs/`. `FRAMES_HOME` defaults to `~/.config/frames`.

```sh
mkdir -p ~/.config/frames/packs
cp -R /path/to/mine ~/.config/frames/packs/
frames packs
frames packs mine
```

```
mine  Mine  1.0.0  A dark look, two presets and an intro for vertical videos
transition  mine/drop-in  The next clip drops in from the top and covers the previous one, which dims under it. For a change of topic in a vertical video
animation  mine/lift  Rises a little while it fades in, breathes while it stays, then fades out. For a caption that stays on screen for a while
filter  mine/warm-screen  Warmer and a little lifted, with crisp text. For screen recordings that look cold
theme  mine/dark
template  mine/callout
template  mine/intro
```

To update a pack, replace its directory. A document already resolved keeps what it took from the pack ([FRAMES-19](../spec/FRAMES-19/SPEC.md)), so it does not change when the pack does. While you work on a pack, point `FRAMES_HOME` at a folder of your own so you try it without touching your installed packs:

```sh
FRAMES_HOME=/path/to/try frames packs mine
```

## Naming

- **The directory is the pack's name.** `mine/drop-in` is `presets/transition/drop-in.json` in `$FRAMES_HOME/packs/mine/`. The `name` in `pack.json` is only a display name and need not match.
- **A name has one `/`.** `mine/drop-in` names something in the pack `mine`, and `frames/fade` something in the pack `frames`, which ships with frames. Any other spelling (`fade`, `mine/sub/drop-in`, `./drop-in`) names nothing.
- **A pack names its own files like anyone else does.** A template in `mine` that uses its own theme writes `"theme": "mine/dark"`, not a relative path. So every file has one spelling, and the pack works wherever `FRAMES_HOME` is.
- **The kind comes from where the name is written.** A transition and an animation may both be called `pop-in`, since `"transition"` and `"animation"` look in different folders.
- **Pick names for what a thing looks like, not where it is used.** `drop-in`, `warm-screen` and `lower-third` say what you get. `episode-3-intro` says nothing to the next reader. Use lowercase words joined by `-`, as the shipped presets do.
- **Pick a pack name that is unlikely to clash**, since two packs cannot share a directory. `frames` is taken by the pack that ships with frames, and an installed pack of that name stops every command that reads packs. A short brand or project name works.

Presets are covered in [PRESET.md](PRESET.md). LUTs are `.cube` files named in a filter's `lut` op as `mine/film`. Media in `media/` is named with its extension (`mine/grain.mov`), and an image sequence is a folder named without one (`{ "imageSequence": "mine/confetti", "fps": 30 }`).

[packs/film](../packs/film/) is a pack of looks: five filters, each a LUT from its `luts/` followed by grain and a vignette or halation, used as `"filter": "film/warm-negative"`. `source/film-luts.py` writes its LUTs, so a look is tuned there and the script run again.

## A theme

A pack theme holds only the keys it changes from the base theme. `frames theme` prints the base theme, which is also the list of every key.

```json
{ "colors": { "background": "#111827", "text": "#F9FAFB", "accent": "#F59E0B", "onAccent": "#111827" },
  "styles": { "headline": { "size": 88, "color": "accent" } } }
```

A document takes it with `"theme": "mine/dark"`, and any command with `--theme mine/dark`. A theme in a pack looks for its `font` families in the pack's `fonts/` before the machine's, so a pack that must keep its look carries its fonts.

## A form

A form is a kind of result (a PR screenshot, a vertical short, a demo), and its pack is how it is taught. Adding a form is adding a pack, and frames does not change. A form pack holds:

- `guide.md`: who the result is for and where it is seen, its theme, its format, its rules for text, emphasis, cuts and length each with its reason, which presets to use and not, and an example. [GUIDE.md](GUIDE.md#writing-a-guide) shows how to write one.
- `themes/<name>.json`, when its look differs from the base theme, with only the keys it changes. The defaults in it (the transition, the animation of each title style) are part of the look.
- `examples/*.json`, documents that run once their media paths are changed. Write the paths as absolute placeholders under `/path/to/`, and say in the guide which files they stand for.
- Its own presets and templates, when the shipped ones do not give its look.

A form's edits differ in how many clips, boxes and lines they hold, so a form is not a template. Its guide and examples teach how to write the document, and templates cover only the fixed pieces inside it (an intro, an end card).

The first forms are in this repository's [packs/](../packs/): `pr-evidence`, `shorts` and `demo`. Copy one to start a form of your own.

## A template

A template is a document with published parameters, as a motion graphics template in an NLE exposes some of its values. Any document kind can be one. It lives in `templates/` and is used by `<pack>/<name>`.

`templates/intro.json`, a title card whose text, colour and entrance can be changed:

```json
{ "kind": "sequence",
  "theme": "mine/dark",
  "format": { "size": [1080, 1920], "fps": 30 },
  "params": {
    "title":      { "type": "text", "default": "New **feature**", "description": "the headline, one or two lines" },
    "background": { "type": "color", "default": "#111827", "description": "colour behind the headline" },
    "entrance":   { "type": "choice", "options": ["mine/lift", "none"], "default": "mine/lift", "description": "how the headline comes in" }
  },
  "storyline": [
    { "solid": { "param": "background" }, "duration": 2,
      "connected": [ { "title": { "param": "title" }, "style": "headline", "placement": "center",
                       "animation": { "param": "entrance" } } ] }
  ] }
```

`templates/callout.json`, a screenshot with one line boxed and labelled:

```json
{ "kind": "image",
  "params": {
    "screen": { "type": "image", "description": "the screenshot" },
    "line":   { "type": "text", "description": "part of the line to box, as ocr reads it" },
    "note":   { "type": "text", "default": "here", "description": "one-line label beside the box" }
  },
  "source": { "param": "screen" },
  "ops": [
    { "shape": "box", "area": { "param": "line" }, "label": { "param": "note" } },
    { "pad": 20 }
  ] }
```

### Parameters

| type | Stands for |
| --- | --- |
| `video` | a video or an image sequence |
| `sequence` | a compound clip: a sequence document or a sequence template instance |
| `image` | an image, or an image or layout document |
| `audio` | a sound |
| `text` | text on screen (a title, a label, a banner line, a heading), or the text of an area |
| `color` | a colour |
| `number` | a number |
| `choice` | one of its `options`, such as a preset or style name |

- `{"param": "<name>"}` stands for a value anywhere a value of its type is accepted. It never stands for a key.
- Names (presets, styles, themes, templates) are taken only through a `choice`, so the template says which ones it was made for.
- Every parameter has a `description`, written for whoever fills it in. Give a `default` wherever there is a sensible one: a template whose parameters all have one renders on its own.

### Using a template

As media in a document, where it plays as a compound clip, or draws as a picture when it is an image or layout:

```json
{ "kind": "sequence",
  "format": { "size": [1080, 1920], "fps": 30 },
  "storyline": [
    { "media": { "template": "mine/intro", "args": { "title": "Checkout, fixed" } } },
    { "media": { "template": "mine/callout", "args": { "screen": "/path/to/shot.png", "line": "Total", "note": "includes shipping" } },
      "duration": 3 }
  ] }
```

On its own, with its arguments in a file:

```json
{ "screen": "/path/to/shot.png", "line": "Total", "note": "includes shipping" }
```

```sh
frames render mine/callout --args /path/to/callout-args.json -o /path/to/out/callout.png
frames timeline mine/intro
frames still mine/intro --at 0.1,1 -o /path/to/out/intro.png
```

### A template is closed

A template resolves on the base theme and its own `theme`. The theme of the document that uses it and `--theme` do not reach it, so only its arguments change it and it looks the same for every caller. `--theme` with a template stops. A template that wants a pack's look names that theme, as `intro` names `mine/dark`, and a template that must keep its fonts carries them in the pack's `fonts/`.

An image or document given as an argument keeps the look of the document that wrote it, not the template's.

### What frames checks

A template is checked once against its parameter types, before any argument is read: every place a parameter stands must take a value of its type, and a choice is tried with each of its options at each place. So a template that passes works for every argument of the right type. Then each use is checked, and a message about the arguments names the args file first:

| Stops | Example |
| --- | --- |
| an unknown argument | `top level (template arguments): unknown argument "tone". Allowed: title, background, entrance` |
| a choice outside its options | `entrance (template arguments): unknown value "mine/pop". Allowed: mine/lift, none` |
| an argument of the wrong type, a media argument whose probed kind is not its type included | `screen (template arguments): parameter "screen" takes image media, found video` |
| a missing argument without a default | `top level (template arguments): missing argument "screen", which has no default` |
| a parameter nothing in the template uses | `params.tone (parameter): "tone" is declared but nothing in the template refers to it` |
| a value its place cannot take, or that fails on the content | a text OCR does not find on the screenshot, a label too long for one line |

Check a template with `timeline` and its defaults, then with arguments that push it: the longest title it should hold, the smallest picture.
