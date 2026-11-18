# Recommended structure

This is not part of the specification. It is the structure of the implementation in `source/frames`, which makes the specification easier to keep, and another implementation may ignore it.

## Stages

```
1. check      walk the JSON tree against the key tables; a template's params are checked where they are written
2. read       the theme (base, --theme, the document's), presets and packs, a template and its arguments,
              media facts (probe), then the media rows of the key tables
3. plan time  storyline clips end to end, transitions, edit and drawn ranges, clip time maps and timeRemap,
              the window of every other clip, lanes
4. plan       nested documents and template instances, the format and content fit, areas and points found
              (OCR provider), crops conformed, tracks (tracker provider), parents and track mattes, titles set
              (shaping provider), where each clip is placed and how it is drawn, theme lengths scaled, the sound.
              timeline reports here, resolve writes the resolved document with every file pinned by hash
5. evaluate   the display list at a time, the mix plan
6. roles      decoder, renderer, mixer, encoder
```

A command that takes a resolved document reads it and starts at stage 5. `render` checks every role before the first frame: the output paths and the time, every pinned file's hash, the decoder on every pinned media, the renderer on every frame's display list, the mixer on the mix plan and the encoder on each target.

## Drawing a frame

```
evaluate(resolved, t):
  list = display list of the frame size, with the format background
  list += clips on negative lanes visible at t, lowest lane first, in document order
  for each storyline clip whose drawn range holds t (outgoing, then incoming, or the reverse for "over": "outgoing"):
      media time = the clip's time map at its clip time, timeRemap applied, clamped to the media
      inner = picture(frame at that media time, rect = conformed crop at t, dest = its box,
                      filter, radius, border, shadow, transform, opacity, mask, track matte)
              or, for a solid, a path filling the frame
      list += picture(source = [inner], dest = the frame, blend,
                      transition motion, opacity, reveal and matte for its side at t)
  list += the transition cover at t, a colour or a picture
  list += clips on positive lanes visible at t, lowest lane first, in document order:
      values = keyframes at t, with the animation at t, tracked motion and the parent's transform composed
      a picture, a path, glyphs or an adjustment, with its mask, track matte, reveal and blend
  return list
```

- A compound clip and a template instance are a picture whose source is the nested display list at their media time.
- A clip used as a track matte draws no item of its own, and is drawn into the track matte of the clip that names it.
- A renderer may draw a glyphs item once and reuse it while only its transform changes. Decoded media frames are cached.

## Modules

The package `Frames` is split into one target for the engine, one per backend of a role or a provider, and one for the commands.

| Target | Owns |
| --- | --- |
| `Frames` | the engine: documents, resolve, evaluation and the role and provider interfaces. It imports no backend |
| `FramesAVFoundation` | the `avfoundation` decoder, mixer and encoder: reading pictures and sound, time stretching, downmixing, ProRes, H.264, HEVC and AAC |
| `FramesQuartz` | the `quartz` renderer, Core Graphics and Core Image: drawing items, filters and LUTs, blend modes, mattes and track mattes as kernels, and the check of a display list before the first frame |
| `FramesVision` | the `vision` OCR provider |
| `FramesCoreText` | the `coretext` shaping provider |
| `FramesPointTracker` | the `point` tracker provider |
| `FramesCommand` | the commands, their arguments and messages, the role table that builds each role by name, extensions, and the pack `frames` in `Resources/packs/frames` |
| `FramesTool` | the `frames` executable |

Inside `Frames`, one folder per module:

| Folder | Owns |
| --- | --- |
| `JSON` | reading JSON into a tree, with errors that name a line and column, and writing values back the way they were written |
| `Model` | document types, the key tables (`Model/Model/Table`), the key checker, keyframes, and filling parameters with arguments |
| `Theme` | the base theme, merging, checking a theme, and the theme layer of a clip |
| `Preset` | reading presets and evaluating spans |
| `Filter` | the filter ops' colour science and reading `.cube` LUTs |
| `Pack` | finding packs and their manifests, presets, themes, media and templates by name, and instantiating templates |
| `Area` | finding areas and points, reading order, and the OCR and tracker provider interfaces |
| `Text` | text layout (fonts, line breaking, wrapping, boxes) and the shaping provider interface |
| `Resolve` | the time plan and the sequence plan: media facts, content fit, crops, geometry, parents, track mattes, tracks, appearance, sound, presets with their arguments, and file hashes |
| `Resolved` | the resolved document: its model, writing it, and reading and checking it |
| `Evaluate` | display lists at a time, animation and transition sampling, parents, shapes, the mix plan, and the display list and mix plan as JSON |
| `Role` | the decoder, renderer, mixer and encoder interfaces, and the bitmaps, sound buffers and targets they exchange |
| `Render` | the render pipeline from a resolved document through the roles to a PNG, a master and a delivery file |
| `Export` | `still`, `sheet` and `extract`: frames of a video or a sequence drawn to PNG files without encoding a video |
| `Analysis` | the reports of `probe`, `ocr`, `track`, `timeline`, `evaluate` and `locate`, and their machine output |
| `Transcode` | image, audio and video delivery files |

Each folder holds its types at its top and their values in `Model/`. Tests follow the targets: `FramesTests` for the engine, one test target per backend, `FramesCommandTests`, `FramesRenderTests` for whole renders, and `FramesTestMedia`, which writes the media the tests use.

## Package

```
frames/
  manifest.toml
  README.md                what frames is, how to build it, the commands and the document reference
  spec/                    the specification
  document/
    ARCHITECTURE.md        this document
    GUIDE.md               the editing loop, and how to write a guide, a how-to or an extension
    PRESET.md              how to write a preset
    PACK.md                how to make a pack, a form and a template
    howto/<name>.md
  packs/<name>/            packs kept beside the tool and installed by copying, not part of it
  source/install.sh        builds the tool and installs it with the pack it ships
  source/film-luts.py      writes the LUTs of packs/film
  source/frames/           the Swift package
    Package.swift
    Sources/Frames/                the engine
    Sources/FramesAVFoundation/    Sources/FramesQuartz/    Sources/FramesVision/
    Sources/FramesCoreText/        Sources/FramesPointTracker/
    Sources/FramesCommand/         the commands
      Resources/packs/frames/      the pack that ships with frames, its presets named frames/<name>
        pack.json
        presets/transition/*.json
        presets/animation/*.json
        presets/filter/*.json
    Sources/FramesTool/            the `frames` executable
    Tests/
```

## Order of work

1. The contract as data: key tables, the base theme, presets, spans and easing. Pure data with easy unit tests.
2. Resolve and `timeline`: templates, packs, text areas, text layout and the time plan without rendering, tested against [FRAMES-8](../spec/FRAMES-8/SPEC.md).
3. Evaluate: display lists at a time and the mix plan, tested as data without drawing.
4. The first roles, `avfoundation` and `quartz`: the decoder, the renderer (pictures, paths, glyphs, adjustments, filters, LUTs, blend modes, masks, mattes and track mattes), the mixer, and the encoder for ProRes and H.264. Checked against [FRAMES-24](../spec/FRAMES-24/SPEC.md) with `still` and `sheet`.
5. `transcode`, `probe`, `extract`, `sheet`, `ocr`, `track`, `evaluate`, `locate`, `packs`, and the machine output of [FRAMES-23](../spec/FRAMES-23/SPEC.md).
6. The presets of the pack `frames`, the base theme, the packs in `packs/` and the how-tos.
