# FRAMES-21: Roles and providers

Status: accepted

## Summary

The four roles that read media and make pixels, sound and files, the providers resolve calls (OCR, shaping, tracking), the working space and the files frames writes.

## Motivation

The engine is meant to be swapped: Apple's frameworks first, ffmpeg or Skia later. Fixing what each role takes and gives, and what two of them must agree on, is what lets one replace another.

## Rules

Rendering is four roles. The renderer and the mixer take the two outputs of evaluation, the decoder reads media files for all of frames, and the encoder writes files.

| Role | Takes | Gives | Also |
| --- | --- | --- | --- |
| decoder | a media file and a frame index, or for sound a media time range | a picture in the working space (RGBA with premultiplied alpha, at the media's bit depth or more), or sound | the providers, the analysis commands and `transcode` read through it too |
| renderer | display lists | frames, as pixels | reads pictures through the decoder, applies filter ops, LUTs, blend modes and mattes, draws glyphs |
| mixer | the mix plan | audio, as samples | reads sound through the decoder, stretches time with the pitch kept |
| encoder | frames and audio | a file | `transcode` uses it with the decoder |

- Each role supports everything its input names (items, filter ops, blend modes, LUTs, mattes, media formats, codecs) or refuses before it starts, naming the first thing it lacks and its place. It never drops one silently.
- A renderer draws glyphs from the font files and faces named, at the positions written, and shapes no text. It draws each frame's items as written: rounded rectangles, holes, trimmed strokes, arrows and glyphs. An engine that only runs a filter graph over time fills the decoder, the mixer or the encoder, not the renderer.
- Every decoder keeps [FRAMES-1](../FRAMES-1/SPEC.md) and [FRAMES-3](../FRAMES-3/SPEC.md), and frames are named by index. Frame i is the frame at `frames[i]`: a decoder checks a file's timestamps against the pinned ones and refuses before it starts when it counts them differently. So the text resolve recognised and the pixels a renderer draws come from the same frame, whichever decoder renders.
- A sequence output lasts `duration` to within one frame. Frame k is drawn at sequence time k / fps for every k whose time lies more than a microsecond before `duration`, and frame 0 always, so the last frame is inside the sequence and floating point noise in `duration` adds no frame.
- Every file is tagged with the working space's encoding: BT.709 primaries and the sRGB transfer (IEC 61966-2-1) in a video, an sRGB chunk in a PNG, so every encoder's output looks the same in a player.
- `render` writes a master: a `.mov` (ProRes 422 HQ, or ProRes 4444 when the format's `background` is not opaque, so the frames carry alpha, with 24-bit PCM sound at 48 kHz in stereo), or a PNG for images, layouts and stills. `--deliver` also writes a delivery file from the same frames in the same step: H.264 at the encoder's highest quality with AAC at 256 kbps or more, with transparent parts over black. A sequence without sound gets a silent track as long as its frames, so every master and delivery carries the same tracks.
- A ProRes 4444 master stores premultiplied alpha and says so in its file. Frame k of a video is presented at exactly k / fps, where a rate within a hundred-thousandth of n × 1000 / 1001 is that NTSC rate, so 29.97 is 30000 / 1001 and frame times never drift.
- The working space is sRGB. Decoded pictures are converted to it ([FRAMES-1](../FRAMES-1/SPEC.md)), and every renderer composites, blends, filters and measures matte luminance on sRGB-encoded values, the values W3C Compositing writes its formulas for. `exposure` alone works in linear light: it decodes to linear, multiplies, and encodes back. Luminance is the Rec. 709 luma of the encoded values.
- No role leaves temporary files.
- The same display lists on the same decoder and renderer, of the same version of frames, give the same frames before encoding on the same machine, and on another one to within the rounding of its GPU. File bytes are not promised, since hardware encoders differ. Two renderers give the same geometry, text, timing and operations in the same working space, not the same pixels. The same mix plan on the same decoder and mixer gives the same samples. Every mixer mixes at 48 kHz in stereo: a mono source plays at the same level on both channels, and a source with more channels is downmixed by ITU-R BS.775, so two mixers give the same levels and channels.

`--decoder`, `--renderer`, `--mixer` and `--encoder` pick each role by the name of its implementation. The renderer defaults to `quartz` (Core Graphics and Core Image), and the others to `avfoundation`.

### Providers

| Provider | Takes | Gives |
| --- | --- | --- |
| OCR | a picture from the decoder | recognised lines: each a text and a rectangle in media pixels |
| shaping | a run of text, a font file, a face and a size | glyph ids and advances |
| tracker | pictures from the decoder around one frame, and a rectangle on that frame | a rectangle in media pixels on each frame before and after it, out to where it reports the target lost in each direction |

- What makes one line is the OCR provider's. A document can resolve on one provider and stop on another, where a line is split or joined differently, and the resolved document keeps what was found. The same holds for what a tracker followed.
- `--ocr`, `--shaper` and `--tracker` pick each provider by the name of its implementation. OCR defaults to `vision`, shaping to `coretext` and the tracker to `point`.

## Interactions

Roles take what [FRAMES-20](../FRAMES-20/SPEC.md) gives. Providers are called by resolve for [FRAMES-2](../FRAMES-2/SPEC.md), [FRAMES-5](../FRAMES-5/SPEC.md) and [FRAMES-12](../FRAMES-12/SPEC.md).

## Alternatives considered

Roles loaded at run time as plugins: implementations are built into frames and named by option.

## Notes
