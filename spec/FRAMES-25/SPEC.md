# FRAMES-25: Forms, guides and extensions

Status: accepted

## Summary

What sits outside the engine and uses only what frames has: forms, which are packs with a guide and examples that an edit may start from; how-tos; the iterative way an edit is made; and extensions, programs that take a document and give a document.

## Motivation

Purposes change faster than tools and differ between editors. A music video is cut to the beat, a lecture needs captions and chapter cards, an ad needs an end card and a cut for every placement, a tutorial needs zooms on the part being explained. Each of these is made from the same tools: clips on a storyline, titles, shapes, masks, transitions, sound. If frames carried each purpose as a feature, every new kind of work would wait on a change to frames, and the core would fill with rules that only one purpose keeps. Keeping purposes in packs and programs outside the engine lets a new one be added without changing frames, and keeps every rule in the core one that any result uses.

## Rules

Guides, how-tos and extensions sit outside the engine. They only use what frames already has.

### Forms and how-tos

A form is a kind of result (a music video, a lecture, an ad, a vertical short) and is a pack ([FRAMES-17](../FRAMES-17/SPEC.md)): its guide (`guide.md`), a theme when its look differs from the base theme (`themes/`, only the keys it changes), its examples (`examples/`, each runs once its paths are changed), and any presets and templates of its own. A form is optional: it is a starting point an edit may take, change or leave, and a document needs none. Adding a form is adding a pack, and frames does not change. A form's edits differ in how many clips, titles and shapes they hold, so a form is taught, not templated. A guide holds:

- what the form is for: who watches it, and where
- its theme
- its format: size, rate, conform, and how its recurring pieces (a title card, a lower third, an end card) are built from titles, shapes and templates
- its rules for text, cuts, sound and length, each with a one-line reason
- which presets to use and which not to, with the reason
- an example

A how-to (`howto/<name>.md`) teaches a technique that belongs to no form, so it has no theme and no example of its own. Making material outside frames is a how-to.

A missing look becomes a preset or a pack. A missing capability goes into this specification and the model first, and into the roles only when it needs a new kind of pixel, sound or file work. A form-only feature, or one that serves a purpose rather than editing, is never hidden in either.

### How an edit is made

An edit is made the way it is made in any NLE, by going round until it holds:

1. Look at the material. `probe` it, lay video out with `sheet` every 1 to 2 seconds, then again every 0.5 seconds over the part chosen, and listen to its sound. Where a place has to be found or followed, `track` it, or `ocr` it when it is found by its text on screen.
2. Edit the document: the storyline, connected clips, titles, shapes, masks, sound. Templates from packs come in as media where they fit, and a form's guide and examples, when there is one, are where to start.
3. Check: `timeline` for times, `still` for frames at chosen instants, `sheet` for a range. Go back to 2 until it holds.
4. Render the master, lay it out with `sheet`, and check it against [FRAMES-24](../FRAMES-24/SPEC.md).
5. Deliver: `--deliver` with the render, or `transcode` for where it goes.
6. Reuse: a rendered master is media like any other ([FRAMES-3](../FRAMES-3/SPEC.md)). A piece rendered once (an intro, a background plate, an effect baked by an extension) comes into the next edit as a file.

### Extensions

Three kinds of thing are added to frames without changing this specification.

| Kind | What is added | Where |
| --- | --- | --- |
| data | presets, themes, templates, LUTs, mattes and media, in packs | [FRAMES-17](../FRAMES-17/SPEC.md) |
| implementations | a decoder, renderer, mixer or encoder, a shaping, tracker or OCR provider, built into frames under the name `--decoder` and the other options pick | [FRAMES-21](../FRAMES-21/SPEC.md) |
| extensions | programs that take a document and give a document | here |

An extension reads what frames reports ([FRAMES-23](../FRAMES-23/SPEC.md)) and writes or changes documents. It cuts silence out of an interview (autocut), cuts B-roll to the beats of a track (beat cut), places captions from a transcript, translates titles, covers a region in every frame that shows it, or bakes an effect frames has no op for. Its interface is documents and the machine output, so frames has no extension API.

- It finds clips by `id` and `timeline`, where things are by `evaluate` and `locate`, and pictures by `still`, `extract` and `sheet`, which take the document itself, so what it sees is what frames draws from the same resolve. An extension that must be sure of what is drawn (one that keeps captions clear of other text on screen, or one that covers a region) resolves the document once, checks that resolved document with `evaluate`, `still` and `extract`, and has the same resolved document rendered. It passes the resolved document on and does not read it, since its form is frames' own ([FRAMES-19](../FRAMES-19/SPEC.md)). An extension that gives a resolved document ends the chain: only frames commands take it after that, so such an extension runs last, and a chain has one.
- It gives a document on standard output, and `timeline` checks it like any other. Extensions chain: `frames autocut interview.json | frames captions - | frames render - -o out.mov`.
- `frames <name>` runs `frames-<name>` from `PATH`, so an extension is installed by putting it there.
- An edit (a blade, a trim, a ripple delete, a move) is a document in and a document out, since frames keeps no state between commands for an edit to act on. So editing a document is the agent's or an extension's work, and `timeline` checks the result like any other document. GUIDE.md teaches how to make an edit without changing what is shown. For a blade through a storyline clip: the first part keeps the clip's `id` and the others take new ones; every part keeps the clip's keyframes, its `timeRemap` included, since they are on its clip time, which a blade does not change; its incoming transition and `fadeIn` stay on the first part and its `fadeOut` on the last, and every later part takes `"transition": "cut"` so that a theme's default transition does not play at the cut; a connected clip goes with the part that holds its start, and one without `at` first takes its storyline clip's edit range in clip time as `at`, since it would otherwise span only that part; a `parent` or `trackMatte` that named the clip names the part its clip goes with; a connected clip parented to the clip whose window crosses the cut is copied onto each part, each copy parented to its part and its window cut at the edit point, with its exit turned off before the cut and its entrance after it (`{entrance, exit}` with `none`), since a parent outside its window holds its edge transform; on every later part, and on every copy that starts at the edit point, a static text form (an area, a point, a `crop`, a `mask` or a `track` area) is written as the rectangle its text was found at for the clip before the blade, since a static text form is searched at its clip's start or `in` ([FRAMES-2](../FRAMES-2/SPEC.md)), which the blade moves to a frame that may show something else; on a still or solid clip, whose clip time counts from its own start, every later part moves its own keyframes and the `at` and keyframes of its connected clips back by where that part starts; a ripple moves every later sequence clip's `at` and keyframes by the same amount.
- An extension acts before resolve. What must act while frames renders is a role or a provider, so a resolved document stays enough to make the result again, and a pack stays data that every role can draw.

frames ships no form, since a form is a purpose. Forms are packs kept outside the tool, such as those in the frames repository under `packs/`, and are installed like any other pack by copying one into `$FRAMES_HOME/packs/` ([FRAMES-17](../FRAMES-17/SPEC.md)). Their examples name media by absolute paths to change before they run. What a form's guide says binds only edits made from that form, never frames.

First how-tos:

- **motion-graphics:** making graphics outside frames. Write HTML, render it to a PNG sequence with alpha in a headless browser, and bring it in as `{"imageSequence": ...}` media.
- **effects:** an effect beyond the filter ops (particles, a glitch, a shader of one's own) is made outside. Render it as a video with alpha and lay it over with a `blend`, or `extract` the frames of the clip's media file over its range, process them, and point the clip's `media` at the result.

## Interactions

Forms are packs ([FRAMES-17](../FRAMES-17/SPEC.md)). Extensions read machine output ([FRAMES-23](../FRAMES-23/SPEC.md)) and pass on resolved documents ([FRAMES-19](../FRAMES-19/SPEC.md)). A rendered result comes back as media by [FRAMES-3](../FRAMES-3/SPEC.md).

## Alternatives considered

Edit operations as frames commands: frames keeps no state between commands for an edit to act on.

Render hooks for extensions: a resolved document would stop being enough to make the result again.

Forms built into the engine: every new kind of work would need a change to frames, and a form is taught, not templated.

Forms that ship with the tool, found as if installed: the tool would carry purposes, and an installed pack could not take a shipped form's name.

A form chosen first, before any edit, as the only way in: most edits start from material, not from a form, and a form is one starting point among others.

## Notes
