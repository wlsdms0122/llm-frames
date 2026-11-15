# FRAMES-25: Forms, guides and extensions

Status: draft

## Summary

What sits outside the engine and uses only what frames has: forms, as packs with guides, how-tos, and extensions, programs that take a document and give a document.

## Motivation

Purposes (hiding personal data, cutting silence, cutting to a beat) change faster than tools and differ between users. Keeping them out of the engine lets a new form or purpose be added without changing frames.

## Rules

Guides, how-tos and extensions sit outside the engine. They only use what frames already has.

A form is a kind of result (a PR screenshot, a vertical short, a demo) and is a pack ([FRAMES-17](../FRAMES-17/SPEC.md)): its guide (`guide.md`), a theme when its look differs from the base theme (`themes/`, only the keys it changes), its examples (`examples/`, each runs once its paths are changed), and any presets and templates of its own. Adding a form is adding a pack, and frames does not change. A form's edits differ in how many clips, boxes and lines they hold, so a form is taught, not templated. A guide holds:

- what the form is for: who watches it, and where
- its theme
- its format: size, inset, conform, and how the top band or banner is built from titles
- its rules for text, emphasis, cuts and length, each with a one-line reason
- which presets to use and which not to, with the reason
- an example

A how-to (`howto/<name>.md`) teaches a technique that belongs to no form, so it has no theme and no example of its own. Making material outside frames is a how-to.

A missing look becomes a preset or a pack. A missing capability goes into this specification and the model first, and into the roles only when it needs a new kind of pixel, sound or file work. A form-only feature, or one that serves a purpose rather than editing, is never hidden in either.

How to make anything:

1. Pick the form and read its guide.
2. Look at the material. `probe` it, lay video out with `sheet` every 1 to 2 seconds, then again every 0.5 seconds over the chosen range. Check the text to point at with `ocr`.
3. Write the document, with templates from packs as media where they fit. Point at places by their text, and write connected instants in clip seconds. Check times with `timeline` and pictures with `still`.
4. Render the master.
5. Lay the result out with `sheet` and check it against [FRAMES-24](../FRAMES-24/SPEC.md).
6. `transcode` for where it goes.

### Extensions

Three kinds of thing are added to frames without changing this specification.

| Kind | What is added | Section |
| --- | --- | --- |
| data | presets, themes, templates, LUTs, mattes and media, in packs | 9, 10 |
| implementations | a decoder, renderer, mixer or encoder, an OCR, shaping or tracker provider, built into frames under the name `--decoder` and the other options pick | 13 |
| extensions | programs that take a document and give a document | here |

An extension reads what frames reports ([FRAMES-23](../FRAMES-23/SPEC.md)) and writes or changes documents. It finds personal data and covers it, cuts silence, places captions from a transcript, cuts to a beat, translates titles, or bakes an effect frames has no op for. Its interface is documents and the machine output, so frames has no extension API.

- It finds clips by `id` and `timeline`, where things are by `evaluate` and `locate`, and pictures by `still`, `extract` and `sheet`, which take the document itself, so what it sees is what frames draws from the same resolve. An extension that must be sure of what is drawn, such as one that covers personal data, resolves the document once, checks that resolved document with `evaluate`, `still` and `extract`, and has the same resolved document rendered. It passes the resolved document on and does not read it, since its form is frames' own ([FRAMES-19](../FRAMES-19/SPEC.md)). An extension that gives a resolved document ends the chain: only frames commands take it after that, so such an extension runs last, and a chain has one.
- It gives a document on standard output, and `timeline` checks it like any other. Extensions chain: `frames autocut doc.json | frames privacy - | frames render - -o out.mov`.
- `frames <name>` runs `frames-<name>` from `PATH`, so an extension is installed by putting it there.
- An edit (a blade, a trim, a ripple delete, a move) is a document in and a document out, since frames keeps no state between commands for an edit to act on. So editing a document is the agent's or an extension's work, and `timeline` checks the result like any other document. GUIDE.md teaches how to make an edit without changing what is shown: the first part of a split keeps the clip's `id` and the others take new ones, and its incoming transition and `fadeIn` stay on the first part and its `fadeOut` on the last; an unparented connected clip goes with the part that holds its start; a parented clip that crosses the cut is copied onto each part, keeping its `at` (clip time is media time), with its exit turned off before the cut and its entrance after it (`{entrance, exit}` with `none`); a ripple moves every later sequence clip's `at` and keyframes by the same amount.
- An extension acts before resolve. What must act while frames renders is a role or a provider, so a resolved document stays enough to make the result again, and a pack stays data that every role can draw.

Forms that ship with frames, as packs:

- **pr-evidence:** its theme `pr-evidence/pr-evidence` changes only `shapes.label.sides`. The conclusion and the reason go in the banner, the conclusion first in `bannerHead`. Crops are bands (`{"band": ...}`), since evidence keeps whole lines. Labels never go above a box, where they would cover the line above, which is why its theme takes `top` out of `shapes.label.sides`. Only the reason lines get a box. Personal data is covered with an opaque `fill` at opacity 1 with no animation, on every clip and every frame that shows it: on video with `track`, or area keyframes from `ocr --json` where it leaves the screen and comes back. A template is a closed box, so a recording given to one is covered first: render it with its covers to a master and pass that file. The finished file is checked with `ocr`. No filters and no music. Transitions are `fade` at 0.3 to 0.5.
- **shorts:** Korean vertical short-form, 9:16, with the theme `shorts/shorts` ([FRAMES-22](../FRAMES-22/SPEC.md)). A headline in the top band, outlined subtitles with `pop`, `push-up` between scenes.
- **demo:** a feature demo on the base theme.

First how-tos:

- **motion-graphics:** making graphics outside frames. Write HTML, render it to a PNG sequence with alpha in a headless browser, and bring it in as `{"imageSequence": ...}` media.
- **effects:** an effect beyond the filter ops (particles, a glitch, a shader of one's own) is made outside. Render it as a video with alpha and lay it over with a `blend`, or `extract` the frames of the clip's media file over its range, process them, and point the clip's `media` at the result.

## Interactions

Forms are packs ([FRAMES-17](../FRAMES-17/SPEC.md)). Extensions read machine output ([FRAMES-23](../FRAMES-23/SPEC.md)) and pass on resolved documents ([FRAMES-19](../FRAMES-19/SPEC.md)).

## Alternatives considered

Edit operations as frames commands: frames keeps no state between commands for an edit to act on. Render hooks for extensions: a resolved document would stop being enough to make the result again. Forms built into the engine: a form is taught, not templated.

## Notes
