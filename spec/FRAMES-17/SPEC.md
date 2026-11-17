# FRAMES-17: Packs and templates

Status: accepted

## Summary

Packs, the directories that carry looks and edits to share or sell, and templates, documents with published parameters used as media.

## Motivation

Looks and reusable pieces made once and used by many need one way to be found, named and checked, and a template must be closed so that only its arguments change it.

## Rules

### Packs

A pack is a set of looks and edits that someone made to share or sell. It is a directory with a `pack.json` at its root and any of these folders. `pack.json` gives the `engine` versions of frames the pack is written for ([FRAMES-18](../FRAMES-18/SPEC.md)), and optionally what the pack calls itself (`name`), its version (`version`) and a `description`, for `frames packs` to show: `{ "engine": "^1", "name": "Shorts", "version": "1.0.0", "description": "Looks for vertical shorts" }`.

| Folder | Holds | Named as |
| --- | --- | --- |
| `presets/<transition, animation or filter>/` | presets | `<pack>/<name>` in a preset choice |
| `themes/` | themes | `<pack>/<name>` in `--theme` or a document `theme` |
| `templates/` | templates ([Templates](#templates)) | `<pack>/<name>` in a template instance |
| `luts/` | `.cube` LUTs | `<pack>/<name>` in a `lut` op |
| `media/` | mattes, overlays, stingers and other media, with image sequences as folders and documents as `.json` files used by file (without `params`) | `<pack>/<name.ext>` for a file and `<pack>/<dir>` for an image sequence, wherever media is taken |
| `fonts/` | font files | by family, in the `font` list of the pack's themes |
| `guide.md`, `examples/` | the guide and example documents of the form a pack is for ([FRAMES-25](../FRAMES-25/SPEC.md)) | read by people and agents, not by frames |

- Installed packs live at `$FRAMES_HOME/packs/<pack>/`, and `FRAMES_HOME` defaults to `~/.config/frames`. Installing a pack is copying its directory there. frames ships presets ([FRAMES-16](../FRAMES-16/SPEC.md)) and no pack, so every pack, a form's too, is one that was installed. frames has no network command.
- A name is an absolute path, `<pack>/<name>` with one `/` and no empty, `.` or `..` part, or a bare name, which is built in. Any other spelling names nothing. An unknown pack, or a name a pack does not hold, stops.
- A pack directory without a `pack.json` stops, and so does one whose `pack.json` misses `engine`, writes a key as another type than a string, or holds another key.
- A theme written in a pack (a theme file, or a theme inside a pack's template) looks for its `font` families in the pack's `fonts/` before the machine's fonts, so a template that must keep its look carries its fonts.
- A pack's files name each other by `<pack>/<name>`, as anything outside does, so every name has one spelling and a pack works wherever `FRAMES_HOME` is. Which pack it is, is the directory it is in: the `<pack>` of `<pack>/<name>` is the directory's name, and the `name` in `pack.json` is only what the pack calls itself, so nothing has to match.
- What resolve takes from a pack goes into the resolved document like anything else ([FRAMES-19](../FRAMES-19/SPEC.md)): presets, themes and templates as values, media and LUTs pinned by hash. A resolved document does not depend on what is installed later.
- `frames packs` lists the installed packs, and `frames packs <pack>` lists what one holds, with descriptions.

### Templates

A template is a document with published parameters, as an NLE's motion graphics template exposes some of its values for editing (Premiere's MOGRT, Final Cut's published parameters). Any document kind can be one.

```json
{
  "kind": "sequence",
  "params": {
    "clip":  { "type": "video", "description": "the recording to show" },
    "title": { "type": "text", "default": "New feature", "description": "headline in the top band" },
    "tone":  { "type": "choice", "options": ["warm", "cool"], "default": "warm", "description": "colour of the whole clip" }
  },
  "storyline": [
    { "media": { "param": "clip" }, "in": 0, "out": 6, "filter": { "param": "tone" },
      "connected": [ { "title": { "param": "title" }, "style": "headline" } ] }
  ]
}
```

- `params` maps a name to `{type, default, description}`. `type` is `video` (a video or an image sequence), `sequence` (a compound clip: a sequence document, or a sequence template instance), `image` (an image, or an image or layout document), `audio`, `text`, `color`, `number` or `choice`, and a `choice` lists its `options`.
- `{"param": "<name>"}` stands for a value anywhere a value of that type is accepted. It never stands for a key. A choice stands where one of its options is accepted, such as a preset name. A `text` stands for text on screen (a title, a label, a banner line, a heading) or the text of an area. Names (presets, styles, themes, templates) are taken only by a choice.
- A template is used as media, `{"template": "<pack>/<name>", "args": {...}}`, where it plays as a compound clip, or draws as an image or a layout when it is one. It is also rendered on its own with `render <template> --args <args.json>`.
- A template resolves on the base theme and its own `theme`. The theme of the document it is used in and `--theme` do not reach it, so only its arguments change it. A template that wants a pack's look names that theme in `theme`. Keys it does not set come from the base theme of the frames it runs on. A document given as an argument keeps the look of the document that wrote it ([FRAMES-22](../FRAMES-22/SPEC.md)).
- A template is checked once against its parameter types, before any argument: each media parameter's type picks its media row, and a choice is checked with every option at every place it stands. A choice that a `shape` takes checks its object with each option's keys, so an `arrow` among them needs its `side` and a `box` beside it refuses one. A template that passes has its keys and types right for every argument of the right type. Values are checked for each instance, where they stand: a number its place does not take (an `in` past its `out`, a lane of 0), and what depends on an argument's content (the length of a text, what OCR finds in a media, how long a video is).
- An unknown arg, an arg of the wrong type (a media arg whose probed kind is not its type included), and a missing arg without a default stop. A declared parameter that nothing in the template refers to stops.
- Resolve then fills the arguments in, so the resolved document holds plain values.

## Interactions

Pack versions are [FRAMES-18](../FRAMES-18/SPEC.md). What resolve takes from a pack is written into the resolved document ([FRAMES-19](../FRAMES-19/SPEC.md)). Forms are packs ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Alternatives considered

A template that takes the theme of the document it is used in: it would change with every caller.

## Notes
