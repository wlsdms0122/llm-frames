# The frames specification

This is where what is decided about frames is kept. Whatever is built or done for frames follows it, and nothing that work does adds to it. Where a decision lands a cost on the work, or where it cannot be measured, the spec that makes the decision says so in a **Note.**, so whoever does the work next is told rather than left to find it.

This describes **frames 1.0.0**.

## What frames is

frames is a non-linear video and image editor driven by JSON documents and a command line, in the class of Final Cut Pro, Premiere Pro and After Effects compositions. An agent or a program writes a document, frames resolves and evaluates it, and a decoder, a renderer, a mixer and an encoder turn the result into a PNG, a master file or a delivery file.

A document is a sequence, as in an NLE: a primary storyline of clips, clips connected to them and clips on the sequence's own clock, on lanes, with transitions, keyframes, filters, masks, track mattes, parenting and time remapping. The same model edits a still and a video, since a still is a sequence rendered as one frame. Work is iterative, as in any editor: edit the document, check it with `still`, `sheet` and `timeline`, edit again, render, and use what was rendered as media in the next document.

frames holds the editing tools that any result uses. The shape of a purpose (an annotation look, where a title goes in a lecture, a grid of pictures side by side, a band of text above a vertical cut) is made with those tools by packs and extensions, installed beside frames and not part of it ([FRAMES-25](FRAMES-25/SPEC.md)).

- A resolved document and the files it pins are enough to make the result again.
- frames composites media and does not generate it. Motion graphics, illustrations and diagrams are made with other tools (HTML in a headless browser, an image model, a design tool) and arrive as media: a PNG, a PNG sequence, a video with alpha, or for vector artwork a page of a PDF, a still with no pixels of its own, which is drawn at whatever size it is shown at ([FRAMES-3](FRAMES-3/SPEC.md)).
- Titles, shapes (rect, ellipse, path), masks and track mattes are built in, as the basics of any NLE. Their geometry is part of frames, and how they move is keyframes and presets.
- Looks and edits can be shared and sold as packs: presets, themes, LUTs, mattes, overlays and templates with published parameters ([FRAMES-17](FRAMES-17/SPEC.md)).

### Principles

| Principle | Meaning |
| --- | --- |
| The editing model is the product | Documents, time, areas and points, parenting, masks, presets, themes, templates, text layout (fonts, line breaks, wrapping, boxes) and evaluation at a time are defined once, here, and implemented once. Recognising text, shaping it and tracking are providers ([FRAMES-21](FRAMES-21/SPEC.md)) |
| Rendering is replaceable roles | A decoder reads media files, a renderer draws display lists, a mixer mixes the mix plan, and an encoder writes the file ([FRAMES-21](FRAMES-21/SPEC.md)). None of them knows clips, keyframes or presets. Apple's frameworks fill every role first (AVFoundation, and Core Graphics with Core Image as `quartz`). A renderer is a 2D compositor with a font rasterizer (Core Graphics and Core Image, Skia), and ffmpeg can fill the decoder, the mixer or the encoder |
| Standard vocabulary | Names come from NLEs and compositing tools: storyline, connected clip, in and out points, lane, keyframe, transition, crop, title, transform, anchor point, parenting, mask, track matte, time remapping, compound clip, published parameter, blend mode, LUT, matte, display list |
| Composite, do not generate | Anything beyond titles and shapes arrives as media |
| Tools, not purposes | frames gives editing tools: clips, titles, shapes, masks, parenting, tracking, retiming, filters, presets. What to do with them for a purpose (an annotation look, choosing highlights, cutting to a beat, a before and after grid) is composition: the theme, template, guide and data of the next row, or an extension, a program that reads what frames reports and writes documents ([FRAMES-25](FRAMES-25/SPEC.md)). The test: a new purpose (a music video, a lecture, an ad, a product demo) is added without changing frames. A rule that holds for one purpose only belongs in a pack, and the specification names packs only as examples of what packs do |
| Look is theme, a reusable piece is a template, judgement is guide, effect is data | Sizes, colours, text styles and default presets live in a theme. A piece of fixed structure made to be used again (a lower third, an intro, an end card), with its media and text as parameters, is a template. Who a form is for and the rules it keeps, each with its reason, live in a guide. Transitions, animations, filters, LUTs and mattes are data files, and adding one needs no rebuild. Packs carry them |
| Unknown keys stop | Every object has a fixed set of keys. A typo stops with the place it was found instead of rendering as "no effect" |
| Ambiguity stops | A reference that matches more than one thing stops and lists what it matched, such as a text area whose text is on more than one line |
| A value that still does what it says is clamped, one that cannot stops | A transition longer than its clips, an out point past the end of the media, an opacity an overshooting ease carries past 1: each is clamped to what fits and still does its job. A clip that is never visible (outside the sequence, or cropped to none of its media), a one-line title wider than its `width`: each stops |
| No legacy keys | When a key changes, old documents stop. There is no compatibility branch |
| Master at full quality, deliver separately | `render` writes a master that never trades quality for size. Delivery files are made from the same frames (`--deliver`) or from it (`transcode`) |
| Reproducible from the resolved document | What can differ between machines is fixed into the resolved document. Recognised text, tracks, text layout, themes, presets and templates are written out as values, and the files the roles still open (media, mattes, LUTs, fonts) are pinned by hash. Rendering it again with the same version of frames and the same roles gives the same text, places and timing on any machine that has the same files, and the same frames on the same machine |
| Sound is media | frames places sound files on the timeline. Speech synthesis, recording and transcription happen outside |

### Shape of the system

```
theme.json, packs ──┐
presets/ ───────────┤
                    ▼
document.json ─▶ resolve ─▶ resolved document ─▶ evaluate ─┬─▶ display lists ─▶ renderer ─┐
                  ▲   ▲                                    └─▶ mix plan ──────▶ mixer ────┴─▶ encoder ─▶ PNG / MOV / MP4
      OCR, shaping and tracker providers

analysis: probe, ocr, track, extract, sheet, timeline, evaluate, locate          delivery: transcode (decoder, encoder)
every media file is read through the decoder
```

- **Document:** what the agent writes. There is one kind, `sequence` ([FRAMES-6](FRAMES-6/SPEC.md), with its keys in [FRAMES-7](FRAMES-7/SPEC.md)), and a still is a sequence rendered as one frame. Any document can be a template ([FRAMES-17](FRAMES-17/SPEC.md)).
- **Resolve:** checks keys, merges the theme, reads presets and packs, applies preset and template arguments, finds text areas through OCR where a document uses them, lays out text with real fonts, and plans time. Its output is the resolved document ([FRAMES-19](FRAMES-19/SPEC.md)). It creates no media.
- **Evaluate:** turns a resolved document and a time into a display list (what to draw at that instant, with every keyframe, animation, transition, parent, mask, track matte and time remap already applied), and a resolved sequence into one mix plan for its sound. It is deterministic, calls no provider, and is shared by every role. Both build on `geometry(clip, t)`, a clip's keyframed geometry at t with its tracked motion and its parent's geometry, without animation. It takes a clip whose areas are found and whose theme lengths are scaled, so resolve calls it before the resolved document exists to measure a content-fit frame ([FRAMES-6](FRAMES-6/SPEC.md)).
- **Decoder, renderer, mixer, encoder:** the four roles that read media and make pixels, sound and files ([FRAMES-21](FRAMES-21/SPEC.md)). Between the decoder and the encoder every picture holds working values, one extended-range sRGB for every sequence with one set of formulas. The sequence's colour space decides how its output is encoded and clipped, and by its peak, for `rec2100-pq` its `format.peak`, with each media clip's `toneMap`, whether an HDR picture brighter than that peak is tone mapped down to it on the way in ([FRAMES-26](FRAMES-26/SPEC.md)).
- **Providers:** OCR, shaping and tracking, which resolve and the analysis tools call ([FRAMES-21](FRAMES-21/SPEC.md)). They read media files (through the decoder) and fonts, never drawn pixels, so no resolved value depends on a renderer. A resolved document needs neither again.
- **Analysis:** commands that give the agent and extensions facts to write a document with, as versioned JSON ([FRAMES-23](FRAMES-23/SPEC.md)). They take no part in rendering.
- **Transcode:** writes a delivery file at a quality level from a still, an audio file or a video file with the encoder role. It is not part of rendering.

### What frames leaves out

- Effects as code run by a renderer: shaders and scripts. Packs carry data only, so every role can draw them. Filters, LUTs, matte transitions and blend modes cover most of what such effects are bought for, and the rest is made outside and arrives as media (the effects how-to). A per-pixel kernel carried as data in a portable shading language is where a later contract would add them.
- Stabilisation.
- Processing a mix of several sounds: audio filters on a compound clip, a bus or the master, a limiter, a loudness target. Each clip's own sound takes audio filters ([FRAMES-13](FRAMES-13/SPEC.md)).
- Perspective tracking (corner pin). The tracker reports a target's four corners, and the motion fitted from them is a move, a uniform scale and a rotation ([FRAMES-12](FRAMES-12/SPEC.md)). The four corners leave room to add a corner pin later.
- Curved paths. A path shape is straight segments between its points ([FRAMES-11](FRAMES-11/SPEC.md)).
- Right-to-left and mixed-direction text. Text is laid out left to right, so `align` names physical sides.
- GIF and WebM output. Rendering makes MOV, MP4 and PNG.
- Speech synthesis, recording and transcription. Sound arrives as files.
- Generating graphics. They arrive as media.
- SVG. Vector artwork arrives as a page of a PDF, and an extension converts SVG to PDF (`rsvg-convert -f pdf`, Inkscape) before it is named ([FRAMES-3](FRAMES-3/SPEC.md)).
- Fetching packs over the network. Installing is copying.

Adding any of these later raises the minor version ([FRAMES-18](FRAMES-18/SPEC.md)). Whoever adds one updates the key tables, the README and the specification together.

## How the specification works

The specification is a record of decisions, kept as specs. A spec is not rewritten once it is decided. When what it decides has to change, a new spec replaces it, and the old one stays where it was: what held before is still there to read, it is plain that it no longer holds, and the spec that replaced it says what holds instead. So the specification is also the project's history, and it can be read in the order things were decided.

A spec belongs to a series. A series is a folder that holds a `TEMPLATE.md`, and the template gives the series' prefix, the fields a spec's head may write and the sections every spec holds. `spec/` is a series itself when it holds a template, and each folder in it that holds one is a series too. Beside its series, `spec/` holds this page and the review in [`review/`](review/README.md), and nothing else.

A spec is a folder `<PREFIX>-N/` in its series: its `SPEC.md`, and beside it, in folders, the resources only that spec needs, such as the cases that measure it. What the project uses everywhere, its tools and its code, is not a spec's to hold. `<PREFIX>-N` is the spec's key and names it across the specification. N is the next number free in the series when the spec is drafted, it is never used again, and it says nothing else about the spec.

A `SPEC.md` opens with `# <PREFIX>-N:` and its title, then the fields its template declares, in the template's order. Status is always written:

- **`draft`**: proposed, not decided. It is changed freely and nothing is held to it. A draft that is not accepted is deleted.
- **`accepted`**: decided. A draft is accepted when it meets [the acceptance criteria](review/CRITERIA.md), which a review checks one by one.

Every `SPEC.md` holds every section of its template, in order, and a section with nothing to say is left empty.

**How a rule is written.** A rule gives a form whole, the way a drawing gives a part's dimensions and not only its material. What a name, a spelling, a field or a layout may be is a grammar or a table, and the prose beside it says what each part means. A rule says what a thing is. It is not written against the one input that raised it: that input is a case, and why the form is what it is goes in a **Note.**

**Supplement or supersede.** An accepted spec is supplemented in place while what it decides stays as it was: its prose made clearer, its resources added to or corrected. Where it has cases, that means every case keeps its answer. A change to what it decides is not a supplement. It is a new spec that replaces the old one whole and says so on the line after its status, `Supersedes: <KEY>, <KEY>`, naming specs of any series. Nothing replaces part of a spec. A spec is superseded when an accepted spec names it under `Supersedes`, and when that spec is accepted, the superseded one says so on its own head, `Superseded-By: <KEY>`, so whoever opens it sees at once that it no longer holds. Its text is not touched. The tool that accepts a draft writes that line, and the tool that checks the specification sees that the two agree. Until frames's first release, an accepted spec is changed in place even when what it decides moves.

A draft makes the changes it needs in accepted specs beside it, before it is reviewed: a supplement in place, and a spec whose decision moves named under its `Supersedes`. The review reads the draft with those changes.

frames as it stands is every accepted spec that no accepted spec supersedes, the live set. Which specs those are is worked out by a tool and never written down.

Read the specs by area, in this order:

- Values every document uses: [FRAMES-1](FRAMES-1/SPEC.md) units and placement, [FRAMES-2](FRAMES-2/SPEC.md) areas and points, [FRAMES-3](FRAMES-3/SPEC.md) media, [FRAMES-4](FRAMES-4/SPEC.md) keyframes, [FRAMES-5](FRAMES-5/SPEC.md) text layout, [FRAMES-26](FRAMES-26/SPEC.md) colour.
- Documents: [FRAMES-6](FRAMES-6/SPEC.md) documents and stills, then the sequence: [FRAMES-7](FRAMES-7/SPEC.md) keys, [FRAMES-8](FRAMES-8/SPEC.md) time, [FRAMES-9](FRAMES-9/SPEC.md) format and lanes, [FRAMES-10](FRAMES-10/SPEC.md) parenting, [FRAMES-11](FRAMES-11/SPEC.md) clip kinds, masks and track mattes, [FRAMES-12](FRAMES-12/SPEC.md) tracking, [FRAMES-13](FRAMES-13/SPEC.md) audio.
- Looks and reuse: [FRAMES-14](FRAMES-14/SPEC.md), [FRAMES-15](FRAMES-15/SPEC.md) and [FRAMES-16](FRAMES-16/SPEC.md) presets, [FRAMES-22](FRAMES-22/SPEC.md) theme, [FRAMES-17](FRAMES-17/SPEC.md) packs and templates, [FRAMES-18](FRAMES-18/SPEC.md) versions.
- The engine: [FRAMES-19](FRAMES-19/SPEC.md) resolved document, [FRAMES-20](FRAMES-20/SPEC.md) evaluation, [FRAMES-21](FRAMES-21/SPEC.md) roles and providers.
- Using it: [FRAMES-23](FRAMES-23/SPEC.md) commands and machine output, [FRAMES-24](FRAMES-24/SPEC.md) what a result keeps, [FRAMES-25](FRAMES-25/SPEC.md) forms, guides and extensions.

## Conformance

A spec may be measured. Where its rules can be checked, its cases hold them, and whether the work conforms is a fact a run prints and never a judgement. Where they cannot be checked, the review judges the spec by its text alone.

**must / must not** are requirements. **refuses** means the implementation raises an error naming what was wrong and produces nothing else: no partial result, no best guess.

**Note.** A paragraph opening with **Note.** is not a requirement. It says what a rule is for, what an implementation is likely to get wrong, or what the rule would cost written another way. Removing every one of them removes nothing the work is held to, and no case measures one.

The cases are the rules written as data. A case has a name, a note saying which rule it measures and how, an input, and what is expected of it: an answer, or a refusal at a stage. One case breaks one rule, and its note says which. A runner reads each case, gives its input to the implementation, and compares what comes back with what is expected. An implementation that pins a version of this specification conforms to it when it passes the cases of every live spec at that version.

No series is measured yet, so every spec is judged by its text. The checks of [FRAMES-24](FRAMES-24/SPEC.md) are made on rendered output with `still` and `sheet` until cases are written, and the colour of a `display-p3`, `rec2020` or HDR master on a frame from `render --at`, since `still` and `sheet` are SDR previews ([FRAMES-26](FRAMES-26/SPEC.md)). frames refuses at these stages, and a case names the one it expects: `check` (the key tables), `read` (theme, presets, packs and probed media), `resolve` (preset and template arguments, text areas, parents and mattes, layout, content fit, the time plan, tracks and windows), and a role, which refuses before it starts.
