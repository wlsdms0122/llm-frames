# Recommended structure

This is not part of the specification. It is structure that makes the specification easier to keep, and an implementation may ignore it.

## Stages

```
1. check      walk the JSON tree against the key tables
2. read       theme, presets, packs, media facts (probe), then check the media rows
3. resolve    template arguments, text areas (OCR provider), text layout (text provider), scale, styles,
              the time plan (durations, edit points, transitions, ranges), tracks (tracker provider), visible windows,
              label sides, units and lanes.
              timeline stops here, resolve writes it out
4. evaluate   the display list at a time, the mix plan
5. roles      decoder, renderer (filter, draw), mixer, encoder
```

## Drawing a frame

```
evaluate(resolved, t):
  items = [fill background]
  items += unparented clips on negative lanes visible at t
  for each storyline unit visible at t, bottom first:
      media time = inverse of the clip's time map at t
      unit = its parented clips on negative lanes
           + picture(source frame at that media time, rect = conformed crop at t, dest = the whole unit, filter)
           + its parented clips on positive lanes, all in content rect coordinates
      items += picture(unit, dest = the content rect, mask = the content rect,
                       transform, opacity, reveal and matte of the transition at t)
  items += transition cover, a fill or a picture
  items += fill of everything outside the content rect, with the content rect as a hole
  for each unparented clip on a positive lane visible at t, in order:
      values = keyframes at t, combined with the animation at t
      items += its picture, glyphs, fill, stroke, arrow or adjust
  return items
```

- A renderer may draw a glyphs item once and reuse it while only its transform changes.
- Decoded media frames are cached.

## Modules

| Module | Owns |
| --- | --- |
| json | reading JSON into a tree, with errors that name a line and column, and writing values back the way they were written |
| model | document types and the key tables |
| theme | the base theme, merging, scale |
| preset | reading presets, spans, easing |
| pack | finding packs, templates and their arguments |
| area | areas, the OCR provider and the tracker provider |
| text | text layout and the shaping provider |
| resolve | the time plan, timeline, the resolved document |
| evaluate | display lists at a time, the mix plan |
| decoder, renderer, mixer, encoder | one module per backend for each role |
| analysis | probe, ocr, track, evaluate, locate, the report `timeline` prints, and the machine output |
| export | still, sheet and extract: frames of a video or a sequence drawn to PNG files without encoding a video |
| transcode | image, audio and video delivery files |
| cli | commands, arguments, error output |

## Package

```
frames/
  manifest.toml
  README.md                commands and the document reference
  spec/                    the specification (spec-series)
  document/
    ARCHITECTURE.md        this document
    GUIDE.md               how to make anything, how to write a guide, a how-to or an extension
    PRESET.md              how to write a preset
    PACK.md                how to make a pack, a form and a template
    howto/<name>.md
  presets/                 built in, laid out as in a pack
    transition/*.json
    animation/*.json
    filter/*.json
  packs/                   the forms that ship with frames
    pr-evidence/  shorts/  demo/
  source/                  the sources and the built tool
```

## Order of work

1. The contract as data: key tables, the base theme, presets, spans and easing. Pure data with easy unit tests.
2. Resolve and `timeline`: templates, packs, text areas, text layout and the time plan without rendering, tested against [FRAMES-8](../spec/FRAMES-8/SPEC.md).
3. Evaluate: display lists at a time and the mix plan, tested as data without drawing.
4. The first roles, `avfoundation` and `quartz`: the decoder, the renderer (pictures, fills, strokes, arrows, glyphs, adjustments, filters, LUTs, blend modes, mattes), the mixer, and the encoder for ProRes and H.264. Checked against [FRAMES-24](../spec/FRAMES-24/SPEC.md) with `still` and `sheet`.
5. `transcode`, `probe`, `extract`, `sheet`, `ocr`, `track`, `evaluate`, `locate`, `packs`, and the machine output of [FRAMES-23](../spec/FRAMES-23/SPEC.md).
6. The 42 presets, the base theme, the form packs (themes, guides, examples) and the first how-tos.
