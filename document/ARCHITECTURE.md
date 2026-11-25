# Recommended structure

This is not part of the specification. It is the structure of the implementation in `source/frames`, which makes the specification easier to keep, and another implementation may ignore it.

## Stages

```
1. check      walk the JSON tree against the key tables; a template's params are checked where they are written
2. read       the theme (base, --theme, the document's), presets and packs, a template and its arguments,
              media facts (probe), then the media rows of the key tables
3. plan time  storyline clips end to end, transitions, edit and drawn ranges, clip time maps and timeRemap,
              the window of every other clip, lanes
4. plan       nested documents and template instances, the format and content fit, areas and points, crops
              conformed, tracks (tracker provider), parents and track mattes, titles set (shaping provider),
              where each clip is placed and how it is drawn, theme lengths scaled, the sound.
              timeline reports here, resolve writes the resolved document with every file pinned by hash
5. evaluate   the display list at a time, the mix plan
6. roles      decoder (media to working values), renderer, mixer, encoder (working values to the sequence's
              colour space)
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

## Colour between the roles

Every picture from the decoder to the encoder is a bitmap of working values ([FRAMES-26](../spec/FRAMES-26/SPEC.md)): RGBA at half float, extended-range sRGB encoded, with premultiplied alpha, so HDR and wide gamut values pass below 0 and above 1.

- The decoder converts each picture from its colour space, the `colorSpace` written where its media is named or else its tags, and tone maps an HDR picture to the target peak its display list item carries (`targetPeak`).
- The renderer composites and filters in the one working space, each formula in its home form and the form-free ones in the form the sequence's `compositing` names, and clips only where a formula says so.
- The encoder converts each frame to the sequence's colour space, clips it to that space's gamut and peak, and tags the file.
- Analysis pictures, which the OCR and tracker providers and transition mattes read and `still`, `sheet` and `extract` write, are read at 8 bits per channel in sRGB, each channel from 0 to 1.

The formulas (primaries and their matrices, transfers, H.273 code points, ICC matrix profiles, the BT.2390 EETF) live in one place, the `Color` folder, which the roles, the filters, `transcode` and the previews call, so every backend converts colour alike.

## Modules

The package `Frames` is split into one target for the engine, one per backend of a role or a provider, and one for the commands.

| Target | Owns |
| --- | --- |
| `Frames` | the engine: documents, resolve, evaluation and the role and provider interfaces. It imports no backend |
| `FramesAVFoundation` | the `avfoundation` decoder, mixer and encoder: reading pictures into working values and sound, time stretching, downmixing, writing frames in a colour space with its tags, ProRes, H.264, HEVC Main 10 and AAC |
| `FramesQuartz` | the `quartz` renderer, Core Graphics and Core Image on half float working values: drawing items, filters and LUTs, blend modes, mattes and track mattes as kernels, and the check of a display list before the first frame |
| `FramesVision` | the `vision` OCR provider |
| `FramesCoreText` | the `coretext` shaping provider |
| `FramesTracker` | the `point` tracker provider in `PointTracker`, the `planar` tracker provider in `PlanarTracker`, and in `Image` the grey images, pyramids and sampling they read frames with |
| `FramesCommand` | the commands, their arguments and messages, the role table that builds each role by name, extensions, and the pack `frames` in `Resources/packs/frames` |
| `FramesTool` | the `frames` executable |

Inside `Frames`, one folder per module:

| Folder | Owns |
| --- | --- |
| `JSON` | reading JSON into a tree, with errors that name a line and column, and writing values back the way they were written |
| `Model` | document types, the key tables (`Model/Model/Table`), the key checker, keyframes, and filling parameters with arguments |
| `Theme` | the base theme, merging, checking a theme, and the theme layer of a clip |
| `Preset` | reading presets and evaluating spans |
| `Look` | the look merge of a value's layers, from theme to style to clip, by the value structure of each keyframable key, reading a layer's JSON into that structure, and timing each leaf of the merged value over its keyframes, each number checked against its leaf's domain |
| `Color` | colour spaces, their primaries, transfers and H.273 code points, conversions between working values and a colour space, media colour outside the table (ICC matrix profiles and tone curves), tone mapping and the compositing form: the one place for the colour formulas |
| `Filter` | the filter ops' colour science and reading `.cube` LUTs |
| `Loudness` | the loudness meter over a range of a stereo 48 kHz mix: K-weighting, integrated loudness, loudness range, momentary and short-term maxima, sample peak, and true peak by the peak detector and its interpolating filter, which the `avfoundation` limiter also reads |
| `Pack` | finding packs and their manifests, presets, themes, media and templates by name, and instantiating templates |
| `Area` | finding areas and points, reading order, and the OCR and tracker provider interfaces |
| `Text` | text layout (fonts, line breaking, wrapping, boxes) and the shaping provider interface |
| `Resolve` | the time plan and the sequence plan: media facts, content fit, crops, geometry, parents, track mattes, tracks, appearance, sound, presets with their arguments, and file hashes |
| `Resolved` | the resolved document: its model, writing it, reading it, and checking it and the files it pins |
| `Evaluate` | display lists at a time, animation and transition sampling, parents, shapes, the mix plan and a sequence's mix through the mixer, and the display list and mix plan as JSON |
| `Role` | the decoder, renderer, mixer and encoder interfaces, and the bitmaps, picture readings, sound buffers and targets they exchange |
| `Render` | the render pipeline from a resolved document through the roles to a PNG, a master with or without a delivery file, or a delivery file alone |
| `Export` | `still`, `sheet` and `extract`: frames of a video or a sequence drawn to PNG files without encoding a video |
| `Analysis` | the reports of `probe`, `ocr`, `track`, `timeline`, `evaluate`, `locate` and `loudness`, and their machine output |
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
  extensions/<name>/       first-party extensions, frames-<name> with its README and check, installed by putting
                           frames-<name> on PATH, not part of the tool
  source/frames/           the Swift package
    Package.swift
    Sources/Frames/                the engine
    Sources/FramesAVFoundation/    Sources/FramesQuartz/    Sources/FramesVision/
    Sources/FramesCoreText/        Sources/FramesTracker/
    Sources/FramesCommand/         the commands
      Resources/packs/frames/      the pack that ships with frames, its presets named frames/<name>
        pack.json
        presets/transition/*.json
        presets/animation/*.json
        presets/filter/*.json
        presets/head/*.json
    Sources/FramesTool/            the `frames` executable
    Tests/
```

## Order of work

1. The contract as data: key tables, the base theme, presets, spans and easing. Pure data with easy unit tests.
2. Resolve and `timeline`: templates, packs, areas and points, text layout and the time plan without rendering, tested against [FRAMES-8](../spec/FRAMES-8/SPEC.md).
3. Evaluate: display lists at a time and the mix plan, tested as data without drawing.
4. The first roles, `avfoundation` and `quartz`: the decoder, the renderer (pictures, paths, glyphs, adjustments, filters, LUTs, blend modes, masks, mattes and track mattes), the mixer, and the encoder for ProRes and H.264. Checked against [FRAMES-24](../spec/FRAMES-24/SPEC.md) with `still` and `sheet`.
5. `transcode`, `probe`, `extract`, `sheet`, `ocr`, `track`, `evaluate`, `locate`, `packs`, and the machine output of [FRAMES-23](../spec/FRAMES-23/SPEC.md).
6. The presets of the pack `frames`, the base theme, the packs in `packs/` and the how-tos.
