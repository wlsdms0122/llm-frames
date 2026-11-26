# FRAMES-17: Packs and templates

Status: accepted

## Summary

Packs, the directories that carry presets, themes, templates, LUTs, media, fonts, guides and tools to share or sell, templates, sequence documents with published parameters used as media, and the one parameter table that preset parameters and template parameters share.

## Motivation

Editors build a piece once and use it many times: a lower third for every speaker in a series, an end card for every episode, an intro with the show's name, a grade for every shot of a scene. Premiere Pro's Motion Graphics templates and Final Cut Pro's published parameters let such a piece be reused with only some of its values open, and its makers share and sell them in bundles with their looks, fonts and media. frames needs one way for those bundles to be found, named and checked, a template closed so that only its arguments change it, and one kind of parameter, so that a preset's colour and a template's colour are written, checked and listed the same way.

## Rules

### Packs

A pack is the unit everything added to frames from outside is installed in: data that frames reads, presets, themes, templates, LUTs, media and fonts, with a guide and examples for people and agents, and tools, programs a command names ([FRAMES-25](../FRAMES-25/SPEC.md#tools)). frames runs a pack's tool only when a command names it. Resolve, the checks, evaluation and render read a pack's data and run nothing from a pack, so a resolved document is still enough to make its result again, and installing a pack runs nothing. It is a directory with a `pack.json` at its root and any of these folders. `pack.json` gives the `engine` versions of frames the pack is written for ([FRAMES-18](../FRAMES-18/SPEC.md)), and optionally what the pack calls itself (`name`), its version (`version`) and a `description`, for `frames packs` to show: `{ "engine": "^0.1", "name": "Studio", "version": "1.0.0", "description": "Lower thirds, an end card and a warm grade" }`.

| Folder | Holds | Named as |
| --- | --- | --- |
| `presets/<transition, animation, filter, audio or head>/` | presets ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-15](../FRAMES-15/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md)), heads among them a stroke's arrowheads ([FRAMES-11](../FRAMES-11/SPEC.md#shapes)) | `<pack>/<name>` in a preset choice, and a head in a stroke's `start` or `end` |
| `themes/` | themes ([FRAMES-22](../FRAMES-22/SPEC.md)) | `<pack>/<name>` in `--theme` or a document `theme` |
| `templates/` | templates ([Templates](#templates)) | `<pack>/<name>` in a template instance, and as the document a command is given ([FRAMES-23](../FRAMES-23/SPEC.md)) |
| `luts/` | `.cube` LUTs | `<pack>/<name>` in a `lut` op |
| `media/` | mattes, displacement maps (named in a `displace` op), impulse responses (named in a `convolve` op), overlays, stingers, logos, music and other media, with image sequences as folders and sequence documents as `.json` files used by file (without `params`) | `<pack>/<name.ext>` for a file and `<pack>/<dir>` for an image sequence, wherever media is taken |
| `fonts/` | font files | by family, in the `font` list of the pack's themes |
| `tools/<name>/` | a tool: a `tool.json` and the program it runs ([FRAMES-25](../FRAMES-25/SPEC.md#tools)) | `<pack>/<name>` as the command word of `frames <pack>/<name>`, and in a request's `tool` |
| `guide.md`, `examples/` | a guide and example documents ([FRAMES-25](../FRAMES-25/SPEC.md)) | read by people and agents, not by frames |

- A pack whose guide and examples teach one kind of result is a form ([FRAMES-25](../FRAMES-25/SPEC.md)). A form is one kind of pack, and frames reads it like any other.
- Installed packs live at `$FRAMES_HOME/packs/<pack>/`, and `FRAMES_HOME` defaults to `~/.config/frames`. Installing a pack is copying its directory there. frames ships one pack, `frames`, which holds its presets ([FRAMES-16](../FRAMES-16/SPEC.md)) and its tools `frames/find-text` and `frames/track-motion` ([FRAMES-25](../FRAMES-25/SPEC.md#requests)). It is found as if installed, and an installed pack of that name stops. Every other pack is one that was installed. frames has no network command.
- A name is an absolute path, or `<pack>/<name>` with one `/` and no empty, `.` or `..` part. Any other spelling, a bare name too, names nothing. An unknown pack, or a name a pack does not hold, stops.
- A name that finds nothing stops, and its message says what the name could be, in one form for every kind of name a pack holds: a preset of each of the five kinds, a tool, a theme, a template, a LUT and media. Every stop for such a name, in a document, a theme, a template, `--theme`, the document a command is given, `presets` or a command word, says it in these words. The message starts `unknown <kind> "<name>"`, where the kind is `transition preset`, `animation preset`, `filter preset`, `audio preset`, `head preset`, `tool`, `theme`, `template`, `LUT` or `media`.
- Where the name is `<pack>/<name>` and its pack is there, the message names the nearest name of that kind the pack holds, where one is near, and lists every name of that kind the pack holds, by the names a document gives them, in name order: `unknown head preset "frames/arow". Did you mean "frames/arrow"? The pack "frames" holds the head presets frames/arrow, frames/bar, frames/circle, frames/diamond, frames/line-arrow, frames/square`. A tool is hinted the same way: `unknown tool "frames/find-txt". Did you mean "frames/find-text"? The pack "frames" holds the tools frames/find-text, frames/track-motion`. So are a theme, a template, a LUT and media: `unknown media "studio/logo.pgn". Did you mean "studio/logo.png"? The pack "studio" holds the media studio/logo.png, studio/outro.mov`. A pack that holds none of that kind says so: `unknown theme "studio/dark". The pack "studio" holds no themes`.
- Where the name is `<pack>/<name>` and its pack is not there, the message names the nearest pack, where one is near, and lists every pack there is, the shipped one and the installed ones, in name order: `unknown template "stuido/intro". Did you mean the pack "studio"? There is no pack "stuido", and the packs are frames, mine, studio`. Where no pack is near, it lists them alone: `unknown LUT "grade/teal". There is no pack "grade", and the packs are frames, mine, studio`.
- A name that is neither `<pack>/<name>` nor an absolute path gives the rule for names of its kind, after the nearest name of that kind the pack `frames` holds where the whole name is near one: `unknown head preset "circle". Did you mean "frames/circle"? A preset is named <pack>/<name>, and the ones frames ships are frames/<name>`. The rule of a tool is `A tool is named <pack>/<name>, and the ones frames ships are frames/<name>`, of a theme `A theme is named <pack>/<name> or by an absolute path`, of a template `A template is named <pack>/<name> or by an absolute path`, of a LUT `A LUT is named <pack>/<name> or by an absolute path`, and of media `Media is named <pack>/<name.ext>, <pack>/<dir> or by an absolute path`.
- An absolute path names a file and no name a pack holds, so a path where nothing is there gets no hint: `theme "/work/dark.json" is not there`, and so for every kind but a LUT and a tool. A LUT named by a path is read where resolve pins it by its hash, and a file that is not there stops there, with no hint either. A tool is named by `<pack>/<name>` alone, so an absolute path given as a tool is a name of another spelling and gives the rule.
- An option of a template's choice that names a preset or a theme that is not there stops when the template is checked, before any argument ([Templates](#templates)), with the parameter and the option, as JSON, before the name's message: `parameter "join" offers "studio/wpe": unknown transition preset "studio/wpe". Did you mean "studio/wipe"? The pack "studio" holds the transition presets studio/dip, studio/wipe`. An option that writes a preset in an object is named by the preset it writes: `parameter "join" offers {"preset": "studio/dp", "args": {"color": "#FFFFFF"}}: unknown transition preset "studio/dp". Did you mean "studio/dip"? The pack "studio" holds the transition presets studio/dip, studio/wipe`.
- The names a message lists are read from the listing of the pack's folder of that kind alone, and no file in it is read: a preset, a theme, a template or a LUT by its file's name without the extension its kind takes, a tool by its directory's name, and media by its file's name with its extension or an image sequence's directory. The packs a message lists are the directories the packs are in, and none of them is read.
- A name is near another when the fewest characters inserted, deleted or replaced to turn its `<name>`, or the whole of a name of another spelling, into the other's `<name>` (their edit distance) is at most 1, or a third of the longer of the two where that is more, and of two names as near the first in name order is named. A pack is near another pack by the same measure on their names.
- A name a document or a theme looks up in a set known where it stands, and that finds nothing there, is hinted by the same measure on the whole name, the hint the last sentence of its message: a text style, a shape style and a colour among the theme's, a colour a preset names among the theme's colours, the `id` a `parent`, a track matte's `clip` or a clip area's `clip` names among the ids of its document, a parameter a `{"param": "<name>"}` names among its template's `params`, and an argument among the parameters its preset or template publishes. The styles, colours, parameters and arguments a set holds are listed before the hint, in name order, and the ids of a document, which can be many, are not: `clips[0].fill (rect): colour "acent" is not in colors, which hold "accent", "background", "shadow", "text". Did you mean "accent"?` and `clips[2].parent (rect): no clip in the document has the id "logo-bg". Did you mean "logo_bg"?`.
- A pack directory without a `pack.json` stops, and so does one whose `pack.json` misses `engine`, writes a key as another type than a string, or holds another key.
- A tool is a directory `tools/<name>/` holding a `tool.json` and the program. `tool.json` gives the tool's `description`, for `frames packs <pack>` to show as a preset's is shown, and `run`, the name of the file in that directory that is executed: `{ "description": "Fills each frames/find-text request, an area named by its text on screen, with the rectangle ocr finds for it", "run": "find-text" }`. A tool's version is its pack's `version`, and the frames it is written for is its pack's `engine`. Where a tool is named or listed, a tool directory without a `tool.json` stops, and so does a `tool.json` that misses either key, writes one as another type than a string or holds another key, and a `run` that is not the name of an executable file in the tool's directory.
- A theme written in a pack (a theme file, or a theme inside a pack's template) looks for its `font` families in the pack's `fonts/` before the machine's fonts, so a template that must keep its look carries its fonts.
- A pack's files name each other by `<pack>/<name>`, as anything outside does, so every name has one spelling and a pack works wherever `FRAMES_HOME` is. Which pack it is, is the directory it is in: the `<pack>` of `<pack>/<name>` is the directory's name, and the `name` in `pack.json` is only what the pack calls itself, so nothing has to match.
- What resolve takes from a pack goes into the resolved document like anything else ([FRAMES-19](../FRAMES-19/SPEC.md)): presets, themes and templates as values, media, LUTs and fonts pinned by hash. A resolved document does not depend on what is installed later.
- `frames packs` lists the installed packs, and `frames packs <pack>` lists what one holds, its tools among them, with descriptions and parameters. A pack `frames packs` is given that is not there stops, and its message names the nearest pack, where one is near, and lists every pack there is, as for a name whose pack is not there: `packs: unknown pack "stuido". Did you mean the pack "studio"? The packs are frames, mine, studio`, and where no pack is near `packs: unknown pack "grade". The packs are frames, mine, studio`.

### Parameters

A parameter is a value left open for whoever uses a preset or a template, as an NLE publishes a control. Presets ([FRAMES-14](../FRAMES-14/SPEC.md)) and templates declare them the same way, in `params`, which maps a name to a parameter object:

| Key | Meaning |
| --- | --- |
| `type` | one of the types below. Required |
| `default` | a value of the type. Required in a preset. Optional in a template, where a parameter without one must be given an argument |
| `description` | one line on what the parameter changes, which `presets` and `frames packs` print. Required |
| `options` | for a `choice` only, and required there: the values it may take, a list of at least two distinct values. The `default` is one of them |

| Type | A value is | In a preset | In a template |
| --- | --- | --- | --- |
| `number` | a number | yes | yes |
| `color` | a colour ([FRAMES-1](../FRAMES-1/SPEC.md)) | yes | yes |
| `choice` | one of its `options` | yes, with eases as options | yes |
| `text` | a string | no | yes |
| `video` | a video, or an image sequence | no | yes |
| `sequence` | a compound clip: a sequence document, or a sequence template instance | no | yes |
| `image` | a still: an image file or a page of a PDF ([FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages)) | no | yes |
| `audio` | an audio file | no | yes |

- A media type takes every kind of medium it names, by the kind `probe` gives ([FRAMES-23](../FRAMES-23/SPEC.md)): `video` takes kinds `video` and `imageSequence`, and `image` takes every still, kinds `image` and `page`. A PDF of more than one page named as a file is no one medium, and stops there as at `read` ([FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages)). A parameter of type `image` stands for the whole media reference, a page's `{file, page}` included, and no parameter stands for a `page` number alone.
- `{"param": "<name>"}` stands for a value of the parameter's type, and never for a key. Where it may stand in a preset is [FRAMES-14](../FRAMES-14/SPEC.md) and [FRAMES-15](../FRAMES-15/SPEC.md). In a template it stands anywhere a value of that type is accepted.
- A `text` stands for text on screen: a title's `text` given as a string, or a run's `text` ([FRAMES-11](../FRAMES-11/SPEC.md)).
- A `choice` stands where one of its options is accepted. Names (presets, styles, shape styles, themes, templates) are taken only by a choice, so what a template lets its user pick is listed.
- An unknown argument, an argument of the wrong type (a media argument whose probed kind is not its type, and a choice argument that is not one of its options, included), and a missing argument without a default stop. A declared parameter that nothing refers to stops.
- An argument object is media when its `kind` is a kind of media written as an object ([FRAMES-3](../FRAMES-3/SPEC.md)): `sequence` (a document), `page`, `imageSequence` or `template`. The other objects an argument can be are the options of a choice, which may be any value its places take, such as a `{preset, args}` or an ease, and no object of the format but media writes one of those four kinds, so none of them is taken for media. Such an object is checked against its parameter's type, so given to a media parameter it stops as media, without `kind` or with a kind no media object takes.
- A parameter is the preset's or template's own. A preset's `{"param"}` names only its own parameters, and a template's arguments reach a preset only where the template passes them on in a choice's `args`.

### Templates

A template is a sequence document with published parameters, as an NLE's motion graphics template exposes some of its values for editing (Premiere's MOGRT, Final Cut's published parameters). A lower third, for example:

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
    { "kind": "solid", "color": "#00000000", "duration": { "param": "length" },
      "connected": [
        { "kind": "rect", "width": 8, "height": 136, "anchor": "bottom-left", "position": [96, 960], "fill": { "param": "accent" },
          "animation": "frames/fade" },
        { "kind": "title", "text": { "param": "name" }, "style": "name", "anchor": "bottom-left", "position": [128, 904], "animation": { "param": "entrance" } },
        { "kind": "title", "text": { "param": "role" }, "style": "role", "anchor": "bottom-left", "position": [128, 960], "animation": { "param": "entrance" } } ] }
  ]
}
```

An end card takes the logo as an `image` and the next episode as a `sequence`, and an intro takes the show's name as `text` and its music as `audio`, in the same way.

- A template is used as media, `{"kind": "template", "template": "<pack>/<name>", "args": {...}}`, where it plays as a compound clip ([FRAMES-3](../FRAMES-3/SPEC.md)). It is also rendered on its own with `render <template> -o <out> --args <args.json>` ([FRAMES-23](../FRAMES-23/SPEC.md)).
- A template resolves on the base theme and its own `theme`. The theme of the document it is used in and `--theme` do not reach it, so only its arguments change it. A template that wants a pack's look names that theme in `theme`. Keys it does not set come from the base theme of the frames it runs on. A document given as an argument keeps the look of the document that wrote it ([FRAMES-22](../FRAMES-22/SPEC.md)).
- A template is checked once against its parameter types, before any argument: each media parameter's type picks its media row ([FRAMES-7](../FRAMES-7/SPEC.md)), and an `image` parameter the still row, an `audio` parameter as a media clip's media and an `image` parameter as an audio clip's stopping, and a choice is checked with every option at every place it stands, as if each option were written there. So a choice that a clip's `kind` takes, whose options are shapes ([FRAMES-7](../FRAMES-7/SPEC.md)), checks the clip's keys with each option, and `points` beside a choice of `rect` and `path` stops, since a `rect` takes none. A template that passes has its keys and types right for every argument of the right type. Values are checked for each instance, where they stand: a number its place does not take (an `in` past its `out`, a lane of 0, a `duration` of 0), and what depends on an argument's content (the length of a text, how long a video is). An instance that gives an `image` parameter a page makes the clips whose media it is clips of a page, so a `toneMap` or an HDR `colorSpace` on them stops when the template is instantiated with that argument, where its kind is known ([FRAMES-26](../FRAMES-26/SPEC.md#media)).
- **A template draws its design for every parameter value it accepts on the fonts it is resolved with, and stops for a value it cannot draw**, as any value its place does not take stops in an instance. A design that depends on an argument's content is built from tools that follow it: a bar around a name is the name's box ([FRAMES-2](../FRAMES-2/SPEC.md)), so it fits every name, where a bar of fixed width would draw something other than the design around a name it does not fit. A name longer than its title's `width` and `lines` allow is a value the template cannot draw, and it stops ([FRAMES-5](../FRAMES-5/SPEC.md)). Fonts are part of the environment, pinned by hash in the resolved document as media are ([FRAMES-5](../FRAMES-5/SPEC.md)), so where a name stops depends on the fonts it is resolved with, and a pack ships in its `fonts/` the fonts its templates are designed in, so that its templates stop at the same names on every machine.
- Resolve then fills the arguments in, so the resolved document holds plain values.

## Interactions

Pack versions are [FRAMES-18](../FRAMES-18/SPEC.md). What resolve takes from a pack is written into the resolved document ([FRAMES-19](../FRAMES-19/SPEC.md)). The keys of a parameter and a template instance are in the key table of [FRAMES-7](../FRAMES-7/SPEC.md). How a preset takes arguments is [FRAMES-14](../FRAMES-14/SPEC.md). Forms are packs, and how a pack's tool runs is in [FRAMES-25](../FRAMES-25/SPEC.md#tools).

## Alternatives considered

A template that takes the theme of the document it is used in: it would change with every caller. Separate parameter forms for presets and templates: two tables to learn and keep in step, and a colour or a choice that is written one way in a lower third and another way in the dip it uses. A template that may open any value without declaring it: its user could not tell what it is meant to change, and it could not be checked before an argument is given. Code in a pack that runs while frames resolves or renders (scripts, plug-ins): every role must be able to draw what a pack holds and a resolved document must stay enough to make its result again, so a pack's tool runs only when a command names it, before resolve ([FRAMES-25](../FRAMES-25/SPEC.md#tools)).

The parameter type `image` named `still`, the word [FRAMES-3](../FRAMES-3/SPEC.md#pdf-pages) defines for an image or a page: it names what the type takes, but a renamed type is a major change ([FRAMES-18](../FRAMES-18/SPEC.md)) to every template that declares it, so `image` takes a page under the name of one of the kinds it takes, as `video` takes `imageSequence`.

A stop of its own for each kind of name, with its own words for what a pack holds: every kind would teach its own form of the same fact, and a hint learned on presets would not carry to themes or media.

## Notes
