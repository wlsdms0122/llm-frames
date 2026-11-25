# Making a pack

A pack is a directory of looks and pieces made to share or sell: presets, themes, templates, LUTs, media and fonts, and for a form its guide and examples. frames reads it as data, so a pack never needs a change to frames, and nothing in a pack is code. The rules are [FRAMES-17](../spec/FRAMES-17/SPEC.md), forms are [FRAMES-25](../spec/FRAMES-25/SPEC.md), and how to write a preset is [PRESET.md](PRESET.md).

## What is in a pack

A pack is a directory with a `pack.json` at its root and any of these folders:

| Folder | Holds | Named as |
| --- | --- | --- |
| `presets/transition/`, `presets/animation/`, `presets/filter/`, `presets/head/` | presets ([PRESET.md](PRESET.md)) | `<pack>/<name>` in a transition, animation or filter choice, or a stroke's `start` or `end` |
| `themes/` | themes | `<pack>/<name>` in `--theme` or a document's `theme` |
| `templates/` | templates ([A template](#a-template)) | `<pack>/<name>` in a template instance |
| `luts/` | `.cube` LUTs | `<pack>/<name>` in a filter's `lut` op |
| `media/` | mattes, overlays, stingers, logos, music and other media: image sequences as folders, sequence documents as `.json` files (without `params`) | `<pack>/<name.ext>` for a file, `<pack>/<dir>` for an image sequence |
| `fonts/` | font files | by family, in the `font` list of the pack's themes |
| `guide.md`, `examples/` | a form's guide and example documents | read by people and agents, not by frames |

The pack `mine` used on this page:

```
mine/
  pack.json
  presets/transition/dip.json        mine/dip
  presets/filter/film.json           mine/film
  presets/filter/warm-screen.json    mine/warm-screen
  themes/dark.json                   mine/dark
  templates/intro.json               mine/intro
  templates/lower-third.json         mine/lower-third
  templates/end-card.json            mine/end-card
  luts/film.cube                     mine/film, in a lut op
  media/logo.png                     mine/logo.png
  media/light-leak/0000.png ...      mine/light-leak, an image sequence
```

`pack.json` says which versions of frames the pack is written for, and what `frames packs` shows:

```json
{ "engine": "^0.1", "name": "Mine", "version": "1.0.0", "description": "A dark look, a dip, two grades and three templates for an interview series" }
```

- `engine` is required. `^0.1` is 0.1.0 or later before 1.0.0, and `^1` is any 1.x. Outside its range the pack stops when it is used, naming both versions: `pack "mine" is written for frames ^1, and this is frames 0.1.0`.
- `name`, `version` and `description` are optional strings, only for people. Any other key stops, and so does a pack directory without a `pack.json`.

## Installing

Installing a pack is copying its directory into `$FRAMES_HOME/packs/`. `FRAMES_HOME` defaults to `~/.config/frames`. frames has no network command.

```sh
mkdir -p ~/.config/frames/packs
cp -R /path/to/mine ~/.config/frames/packs/
frames packs
```

```
frames  Frames  0.1.0  Dissolves, dips, pushes, slides, wipes and zooms between clips, animations that bring a clip in, keep it moving and take it out, colour and detail filters, and heads that end a stroke.
mine  Mine  1.0.0  A dark look, a dip, two grades and three templates for an interview series
```

To update a pack, replace its directory. A resolved document keeps what it took from the pack, presets, themes and templates as values and media, LUTs and fonts pinned by hash ([FRAMES-19](../spec/FRAMES-19/SPEC.md)), so it does not change when the pack does. While you work on a pack, point `FRAMES_HOME` at a folder of your own, so you try it without touching your installed packs:

```sh
mkdir -p /path/to/try/packs && cp -R /path/to/mine /path/to/try/packs/
FRAMES_HOME=/path/to/try frames packs mine
```

## Naming

- **The directory is the pack's name.** `mine/dip` is `presets/transition/dip.json` in `$FRAMES_HOME/packs/mine/`. The `name` in `pack.json` is only what the pack calls itself and need not match.
- **A name has one `/`.** `mine/dip` names something in the pack `mine`, and `frames/fade` something in the pack `frames`, which ships with frames and holds its presets. Any other spelling (`dip`, `mine/sub/dip`, `./dip`) names nothing, and an unknown pack or a name a pack does not hold stops. An absolute path is the other way to name a file.
- **A pack names its own files like anyone else does.** A template in `mine` that uses its own theme writes `"theme": "mine/dark"`, and a filter preset writes its LUT as `mine/film`, not as a relative path. So every file has one spelling, and the pack works wherever `FRAMES_HOME` is.
- **The kind comes from where the name is written.** A transition and an animation may both be called `pop`, since `"transition"` and `"animation"` look in different folders, and `mine/film` is a filter preset in a filter choice and a LUT in a `lut` op.
- **Name a thing for what it looks like, not where it is used.** `dip`, `warm-screen` and `lower-third` say what you get, and `episode-3-intro` says nothing to the next reader. Use lowercase words joined by `-`, as the `frames` pack does.
- **Pick a pack name that is unlikely to clash**, since two packs cannot share a directory. `frames` is taken: an installed pack of that name stops every command that reads packs.

Media in `media/` is named with its extension (`"media": "mine/logo.png"`), and an image sequence by its folder (`{ "imageSequence": "mine/light-leak", "fps": 30 }`). The pack `film` in this repository's `packs/` holds five filter presets, each built on a LUT from its own `luts/`.

## A theme

A pack theme holds only the keys it changes from the base theme. `frames theme` prints the base theme, which also lists every key.

`themes/dark.json`:

```json
{ "colors": { "background": "#111827", "text": "#F9FAFB", "accent": "#F59E0B" },
  "styles": { "title": { "size": 88, "color": "accent" } } }
```

A document takes it with `"theme": "mine/dark"`, and any command with `--theme mine/dark`. A theme in a pack, a theme file or a template's own `theme`, looks for its `font` families in the pack's `fonts/` before the machine's fonts, so a pack that must keep its look carries its fonts.

## A form

A form is a kind of result (a music video, a lecture, an ad, a vertical short), and a pack is how it is taught ([FRAMES-25](../spec/FRAMES-25/SPEC.md)). Adding a form is adding a pack, and frames does not change. A form pack holds:

- `guide.md`: who the result is for and where it is seen, its theme, its format and how its recurring pieces are built, its rules for text, cuts, sound and length each with its reason, which presets to use and not, and an example. [GUIDE.md](GUIDE.md#writing-a-guide) shows how to write one.
- `themes/<name>.json`, when its look differs from the base theme, with only the keys it changes.
- `examples/*.json`, documents that run once their media paths are changed. Write the paths as absolute placeholders under `/path/to/`, and say in the guide which files they stand for.
- Its own presets and templates, when the `frames` pack does not give its look.

A form's edits differ in how many clips, titles and shapes they hold, so a form is taught, not templated. Its guide and examples teach how to write the document, and templates cover only the fixed pieces inside it (a title card, a lower third, an end card).

The forms in this repository's `packs/` are `demo`, `pr-evidence` and `shorts`. Copy one to start a form of your own.

## A template

A template is a sequence document with published parameters, as an NLE's motion graphics template exposes some of its values (Premiere's MOGRT, Final Cut's published parameters). It lives in `templates/` and is used by `<pack>/<name>`.

`templates/lower-third.json`, a name and a role beside a bar, on a transparent frame:

```json
{
  "kind": "sequence",
  "format": { "size": [1920, 1080], "background": "#00000000" },
  "theme": { "styles": { "name": { "size": 56, "weight": "bold" }, "role": { "size": 36 } } },
  "params": {
    "name":     { "type": "text", "default": "Name Surname", "description": "first line" },
    "role":     { "type": "text", "default": "Role", "description": "second line" },
    "accent":   { "type": "color", "default": "#FFFFFF", "description": "colour of the bar beside the text" },
    "length":   { "type": "number", "default": 5, "description": "seconds on screen" },
    "entrance": { "type": "choice", "options": ["frames/rise", "frames/slide-left", "frames/fade"], "default": "frames/rise", "description": "how the text comes in and goes" }
  },
  "storyline": [
    { "solid": "#00000000", "duration": { "param": "length" },
      "connected": [
        { "shape": "rect", "width": 8, "height": 136, "anchor": "bottom-left", "position": [96, 960], "fill": { "param": "accent" },
          "animation": "frames/fade" },
        { "title": { "param": "name" }, "style": "name", "anchor": "bottom-left", "position": [128, 904], "animation": { "param": "entrance" } },
        { "title": { "param": "role" }, "style": "role", "anchor": "bottom-left", "position": [128, 960], "animation": { "param": "entrance" } } ] }
  ]
}
```

`templates/intro.json`, a title card on the pack's dark look:

```json
{ "kind": "sequence",
  "theme": "mine/dark",
  "format": { "size": [1920, 1080], "fps": 30 },
  "params": {
    "title":      { "type": "text", "default": "Episode title", "description": "the headline, one or two lines" },
    "background": { "type": "color", "default": "#111827", "description": "colour behind the headline" },
    "entrance":   { "type": "choice", "options": ["frames/rise", "frames/zoom", "none"], "default": "frames/rise", "description": "how the headline comes in" }
  },
  "storyline": [
    { "solid": { "param": "background" }, "duration": 2,
      "connected": [ { "title": { "param": "title" }, "style": "title", "width": 1600, "animation": { "param": "entrance" } } ] }
  ] }
```

`templates/end-card.json`, which takes media as arguments: the show's logo as an `image` and a clip of the next episode as a `video`. Neither has a default, so every use gives both.

```json
{ "kind": "sequence",
  "theme": "mine/dark",
  "format": { "size": [1920, 1080], "fps": 30, "background": "#111827" },
  "params": {
    "logo": { "type": "image", "description": "the show's logo, a PNG with alpha" },
    "next": { "type": "video", "description": "a clip from the next episode" },
    "line": { "type": "text", "default": "Next time", "description": "the line above the clip" }
  },
  "storyline": [
    { "solid": "#111827", "duration": 4,
      "connected": [
        { "media": { "param": "logo" }, "width": 240, "placement": "top-left" },
        { "title": { "param": "line" }, "style": "title", "anchor": "bottom-left", "position": [960, 300], "scale": 0.6 },
        { "media": { "param": "next" }, "width": 864, "height": 486, "anchor": "top-left", "position": [960, 340] } ] }
  ] }
```

## Parameters

A parameter is a value left open for whoever uses a preset or a template, as an NLE publishes a control. Presets and templates declare them the same way, in `params`, which maps a name to a parameter object. This is the one table for both ([FRAMES-17](../spec/FRAMES-17/SPEC.md)).

| Key | Meaning |
| --- | --- |
| `type` | one of the types below. Required |
| `default` | a value of the type. Required in a preset. Optional in a template, where a parameter without one must be given an argument |
| `description` | one line on what the parameter changes, which `presets` and `frames packs` print. Required |
| `options` | for a `choice` only, and required there: the values it may take, a list of at least two distinct values. The `default` is one of them |

| Type | A value is | In a preset | In a template |
| --- | --- | --- | --- |
| `number` | a number | yes | yes |
| `color` | a colour: `#RRGGBB`, `#RRGGBBAA`, `color(<space> r g b)` or `color(<space> r g b / a)` with `srgb`, `srgb-linear`, `display-p3` or `rec2020`, or the name of a theme colour ([FRAMES-26](../spec/FRAMES-26/SPEC.md#colour-values)) | yes | yes |
| `choice` | one of its `options` | yes, with eases as options | yes |
| `text` | a string | no | yes |
| `video` | a video, or an image sequence | no | yes |
| `sequence` | a compound clip: a sequence document, or a sequence template instance | no | yes |
| `image` | an image file | no | yes |
| `audio` | an audio file | no | yes |

- `{"param": "<name>"}` stands for a value of the parameter's type, never for a key. In a template it stands anywhere a value of that type is accepted. Where it may stand in a preset is in [PRESET.md](PRESET.md).
- A `text` stands for text on screen: a title, given as a string or as a run's `text`.
- A `choice` stands where one of its options is accepted. Names (presets, styles, shape styles, themes, templates) are taken only by a choice, so a template lists what its user may pick. In a template, a choice of animation presets may include `"none"`, as `intro` does.
- A media argument (`video`, `sequence`, `image`, `audio`) is any media form: an absolute path, a pack file such as `mine/logo.png`, `{"imageSequence": ...}`, a sequence document, or `{"template": ..., "args": ...}`. An argument object is media only when it holds `kind`, `imageSequence` or `template`.
- A parameter is the preset's or template's own. A template's arguments reach a preset only where the template passes them on in a choice's `args`.
- Give every parameter a `description` written for whoever fills it in, and a `default` wherever there is a sensible one: a template whose parameters all have one renders on its own.

## Using a template

A template is used as media, `{"template": "<pack>/<name>", "args": {...}}`, where it plays as a compound clip. On the storyline it lasts its own length, and connected or on a lane it sits over what is below wherever its background is transparent:

```json
{ "kind": "sequence",
  "format": { "size": [1920, 1080], "fps": 30 },
  "storyline": [
    { "media": { "template": "mine/intro", "args": { "title": "Checkout, fixed", "entrance": "frames/zoom" } } },
    { "media": "/path/to/interview.mov", "in": 0, "out": 3, "filter": "mine/warm-screen",
      "transition": { "preset": "mine/dip", "args": { "color": "#F59E0B" } },
      "connected": [ { "at": [0.5, 3], "media": { "template": "mine/lower-third", "args": { "name": "Mina Park", "role": "Engineer", "length": 2.5 } } } ] },
    { "media": { "template": "mine/end-card", "args": { "logo": "mine/logo.png", "next": "/path/to/next.mov" } },
      "transition": "frames/fade" }
  ] }
```

`timeline` shows what is inside each instance, with places continued from the clip that holds it:

```
storyline[1].connected[0]  compound  visible [2.5, 5)  animation none
  storyline[1].connected[0].media.storyline[0]  -  edit [0, 2.5)  drawn [0, 2.5)  clip [0, 2.5)  speed 1  transition none
  storyline[1].connected[0].media.storyline[0].connected[1]  title  visible [0, 2.5)  animation frames/rise / - / frames/rise
```

A template also renders and checks on its own. Arguments go in a JSON file given with `--args`, and a template whose parameters all have defaults needs none:

```json
{ "logo": "/path/to/logo.png", "next": "/path/to/next.mov" }
```

```sh
frames timeline mine/end-card --args /path/to/end-card-args.json
frames render mine/end-card --args /path/to/end-card-args.json -o /path/to/out/end-card.png --at 1
frames still mine/lower-third --at 0.1,1,4.9 -o /path/to/out/lower-third.png
```

### A template is closed

A template resolves on the base theme and its own `theme`. The theme of the document that uses it and `--theme` do not reach it, so only its arguments change it and it looks the same for every caller. `--theme` with a template stops: `a template resolves on the base theme and its own theme, so it takes no --theme`. A template that wants a pack's look names that theme, as `intro` names `mine/dark`, and keys it does not set come from the base theme of the frames it runs on. A document given as an argument keeps the look of the document that wrote it.

### What frames checks

A template is checked once against its parameter types, before any argument: each media parameter's type picks the keys its clip takes, and a choice is checked with every option at every place it stands, as if each option were written there. So a choice of `rect` and `path` in `shape`, beside `points`, stops, since a `rect` takes no `points`. A template that passes has its keys and types right for every argument of the right type. Then each use is checked, and a message about the arguments names the args file first:

| Stops | Message |
| --- | --- |
| an unknown argument | `/path/to/args.json: top level (template arguments): unknown argument "tone". Allowed: title, background, entrance` |
| a choice outside its options | `/path/to/args.json: entrance (template arguments): unknown value "frames/pop". Allowed: frames/rise, frames/zoom, none` |
| an argument of the wrong type | `/path/to/args.json: background (template arguments): expected a colour, found 12` |
| a media argument whose probed kind is not its type | `/path/to/args.json: logo (template arguments): parameter "logo" takes image media, found video` |
| a missing argument without a default | `/path/to/args.json: top level (template arguments): missing argument "logo", which has no default` |
| a parameter nothing in the template refers to | `params.tone (parameter): "tone" is declared but nothing refers to it` |
| a value its place cannot take | `storyline[0].duration (solid): a still or solid clip needs a duration above 0, found 0`, from a `length` of 0 |

Values that depend on an argument are checked for each use, where they stand: a number its place does not take, the length of a text, how long a video is, what a text area finds in a media. Check a template with `timeline` and its defaults, then with arguments that push it: the longest name it should hold, the shortest `length`, the smallest picture.

## What `frames packs <pack>` prints

`frames packs <pack>` lists what one pack holds, one line each: the kind, the name a document gives it and, for a preset, its description. Under a preset or a template that publishes parameters, it prints one indented line for each parameter in the order they are declared: its name, its type, its default as JSON (`-` when it has none) and its description.

```sh
frames packs mine
```

```
mine  Mine  1.0.0  A dark look, a dip, two grades and three templates for an interview series
transition  mine/dip  Dips to a colour and holds a beat, then the next clip comes up out of it
  color  color  "#000000"  colour of the dip
  curve  choice  "linear"  pace of the fade
filter  mine/film  Warm colour negative with fine grain, for people and daylight
  grain  number  0.015  strength of the grain
filter  mine/warm-screen  Warmer and a little crisper, for screen recordings that look cold
  warmth  number  600  how much warmer, in kelvin
theme  mine/dark
template  mine/end-card
  logo  image  -  the show's logo, a PNG with alpha
  next  video  -  a clip from the next episode
  line  text  "Next time"  the line above the clip
template  mine/intro
  title  text  "Episode title"  the headline, one or two lines
  background  color  "#111827"  colour behind the headline
  entrance  choice  "frames/rise"  how the headline comes in
template  mine/lower-third
  name  text  "Name Surname"  first line
  role  text  "Role"  second line
  accent  color  "#FFFFFF"  colour of the bar beside the text
  length  number  5  seconds on screen
  entrance  choice  "frames/rise"  how the text comes in and goes
lut  mine/film
media  mine/light-leak
media  mine/logo.png
```

A template's lines come from its `params` alone, so a template whose media is not there still lists them, and a broken declaration stops the listing, naming its place. `frames presets` lists the presets of every pack by kind, and `frames presets <kind> <name>` prints one preset's JSON, its `params` included.
