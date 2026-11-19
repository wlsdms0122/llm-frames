# FRAMES-17: Packs and templates

Status: accepted

## Summary

Packs, the directories of data that carry presets, themes, templates, LUTs, media, fonts and guides to share or sell, templates, sequence documents with published parameters used as media, and the one parameter table that preset parameters and template parameters share.

## Motivation

Editors build a piece once and use it many times: a lower third for every speaker in a series, an end card for every episode, an intro with the show's name, a grade for every shot of a scene. Premiere Pro's Motion Graphics templates and Final Cut Pro's published parameters let such a piece be reused with only some of its values open, and its makers share and sell them in bundles with their looks, fonts and media. frames needs one way for those bundles to be found, named and checked, a template closed so that only its arguments change it, and one kind of parameter, so that a preset's colour and a template's colour are written, checked and listed the same way.

## Rules

### Packs

A pack is a bundle of data that frames reads: presets, themes, templates, LUTs, media and fonts, with a guide and examples for people and agents. Nothing in a pack is code (README). It is a directory with a `pack.json` at its root and any of these folders. `pack.json` gives the `engine` versions of frames the pack is written for ([FRAMES-18](../FRAMES-18/SPEC.md)), and optionally what the pack calls itself (`name`), its version (`version`) and a `description`, for `frames packs` to show: `{ "engine": "^1", "name": "Studio", "version": "1.0.0", "description": "Lower thirds, an end card and a warm grade" }`.

| Folder | Holds | Named as |
| --- | --- | --- |
| `presets/<transition, animation, filter or audio>/` | presets ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-15](../FRAMES-15/SPEC.md), [FRAMES-13](../FRAMES-13/SPEC.md)) | `<pack>/<name>` in a preset choice |
| `themes/` | themes ([FRAMES-22](../FRAMES-22/SPEC.md)) | `<pack>/<name>` in `--theme` or a document `theme` |
| `templates/` | templates ([Templates](#templates)) | `<pack>/<name>` in a template instance |
| `luts/` | `.cube` LUTs | `<pack>/<name>` in a `lut` op |
| `media/` | mattes, overlays, stingers, logos, music and other media, with image sequences as folders and sequence documents as `.json` files used by file (without `params`) | `<pack>/<name.ext>` for a file and `<pack>/<dir>` for an image sequence, wherever media is taken |
| `fonts/` | font files | by family, in the `font` list of the pack's themes |
| `guide.md`, `examples/` | a guide and example documents ([FRAMES-25](../FRAMES-25/SPEC.md)) | read by people and agents, not by frames |

- A pack whose guide and examples teach one kind of result is a form ([FRAMES-25](../FRAMES-25/SPEC.md)). A form is one kind of pack, and frames reads it like any other.
- Installed packs live at `$FRAMES_HOME/packs/<pack>/`, and `FRAMES_HOME` defaults to `~/.config/frames`. Installing a pack is copying its directory there. frames ships one pack, `frames`, which holds its presets ([FRAMES-16](../FRAMES-16/SPEC.md)). It is found as if installed, and an installed pack of that name stops. Every other pack is one that was installed. frames has no network command.
- A name is an absolute path, or `<pack>/<name>` with one `/` and no empty, `.` or `..` part. Any other spelling, a bare name too, names nothing. An unknown pack, or a name a pack does not hold, stops.
- A pack directory without a `pack.json` stops, and so does one whose `pack.json` misses `engine`, writes a key as another type than a string, or holds another key.
- A theme written in a pack (a theme file, or a theme inside a pack's template) looks for its `font` families in the pack's `fonts/` before the machine's fonts, so a template that must keep its look carries its fonts.
- A pack's files name each other by `<pack>/<name>`, as anything outside does, so every name has one spelling and a pack works wherever `FRAMES_HOME` is. Which pack it is, is the directory it is in: the `<pack>` of `<pack>/<name>` is the directory's name, and the `name` in `pack.json` is only what the pack calls itself, so nothing has to match.
- What resolve takes from a pack goes into the resolved document like anything else ([FRAMES-19](../FRAMES-19/SPEC.md)): presets, themes and templates as values, media, LUTs and fonts pinned by hash. A resolved document does not depend on what is installed later.
- `frames packs` lists the installed packs, and `frames packs <pack>` lists what one holds, with descriptions and parameters.

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
| `image` | an image file | no | yes |
| `audio` | an audio file | no | yes |

- `{"param": "<name>"}` stands for a value of the parameter's type, and never for a key. Where it may stand in a preset is [FRAMES-14](../FRAMES-14/SPEC.md) and [FRAMES-15](../FRAMES-15/SPEC.md). In a template it stands anywhere a value of that type is accepted.
- A `text` stands for text on screen: a title, given as a string or as a run's `text` ([FRAMES-11](../FRAMES-11/SPEC.md)), or the text an area's text form searches for (`text`, `from`, `to`, [FRAMES-2](../FRAMES-2/SPEC.md)).
- A `choice` stands where one of its options is accepted. Names (presets, styles, shape styles, themes, templates) are taken only by a choice, so what a template lets its user pick is listed.
- An unknown argument, an argument of the wrong type (a media argument whose probed kind is not its type, and a choice argument that is not one of its options, included), and a missing argument without a default stop. A declared parameter that nothing refers to stops.
- An argument object is media only when it holds `kind` (a document), `imageSequence` or `template`. Any other object, such as a choice's `{preset, args}`, is checked against its parameter's type, so given to a media parameter it stops as media missing one of those keys.
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
    { "solid": "#00000000", "duration": { "param": "length" },
      "connected": [
        { "shape": "rect", "width": 8, "height": 136, "anchor": "bottom-left", "position": [96, 960], "fill": { "param": "accent" },
          "animation": "frames/fade" },
        { "title": { "param": "name" }, "style": "name", "anchor": "bottom-left", "position": [128, 904], "animation": { "param": "entrance" } },
        { "title": { "param": "role" }, "style": "role", "anchor": "bottom-left", "position": [128, 960], "animation": { "param": "entrance" } } ] }
  ]
}
```

An end card takes the logo as an `image` and the next episode as a `sequence`, and an intro takes the show's name as `text` and its music as `audio`, in the same way.

- A template is used as media, `{"template": "<pack>/<name>", "args": {...}}`, where it plays as a compound clip ([FRAMES-3](../FRAMES-3/SPEC.md)). It is also rendered on its own with `render <template> -o <out> --args <args.json>` ([FRAMES-23](../FRAMES-23/SPEC.md)).
- A template resolves on the base theme and its own `theme`. The theme of the document it is used in and `--theme` do not reach it, so only its arguments change it. A template that wants a pack's look names that theme in `theme`. Keys it does not set come from the base theme of the frames it runs on. A document given as an argument keeps the look of the document that wrote it ([FRAMES-22](../FRAMES-22/SPEC.md)).
- A template is checked once against its parameter types, before any argument: each media parameter's type picks its media row ([FRAMES-7](../FRAMES-7/SPEC.md)), and a choice is checked with every option at every place it stands, as if each option were written there. So a choice that `shape` takes checks the clip's keys with each option, and `points` beside a choice of `rect` and `path` stops, since a `rect` takes none. A template that passes has its keys and types right for every argument of the right type. Values are checked for each instance, where they stand: a number its place does not take (an `in` past its `out`, a lane of 0, a `duration` of 0), and what depends on an argument's content (the length of a text, how long a video is, what a text area finds in a media).
- **A template draws its design for every parameter value it accepts, and a value it cannot draw stops**, as any value its place does not take stops in an instance. A design that depends on an argument's content is built from tools that follow it: a bar around a name is the name's box ([FRAMES-2](../FRAMES-2/SPEC.md)), so it fits every name, where a bar of fixed width would draw something other than the design around a name it does not fit. A name longer than its title's `width` and `lines` allow is a value the template cannot draw, and it stops ([FRAMES-5](../FRAMES-5/SPEC.md)). Where a name stops depends on the fonts it is set in, which the resolved document pins ([FRAMES-5](../FRAMES-5/SPEC.md)), so a pack should ship in its `fonts/` the fonts its templates are designed in, and then the template stops at the same names on every machine.
- Resolve then fills the arguments in, so the resolved document holds plain values.

## Interactions

Pack versions are [FRAMES-18](../FRAMES-18/SPEC.md). What resolve takes from a pack is written into the resolved document ([FRAMES-19](../FRAMES-19/SPEC.md)). The keys of a parameter and a template instance are in the key table of [FRAMES-7](../FRAMES-7/SPEC.md). How a preset takes arguments is [FRAMES-14](../FRAMES-14/SPEC.md). Forms are packs ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Alternatives considered

A template that takes the theme of the document it is used in: it would change with every caller. Separate parameter forms for presets and templates: two tables to learn and keep in step, and a colour or a choice that is written one way in a lower third and another way in the dip it uses. A template that may open any value without declaring it: its user could not tell what it is meant to change, and it could not be checked before an argument is given. Packs that carry code (scripts, plug-ins): every role must be able to draw what a pack holds, so packs carry data only (README).

## Notes
