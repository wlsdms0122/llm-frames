# FRAMES-21: Roles and providers

Status: accepted

## Summary

The four roles that read media and make pixels, sound and files, the providers resolve and the analysis commands call (shaping, tracking, text recognition), the working space and the files frames writes.

## Motivation

The engine is meant to be swapped, as an NLE swaps its playback engine or a compositing tool its GPU back end: Apple's frameworks first, Skia or ffmpeg later. Without a fixed contract for what each role takes and gives, and for what two of them must agree on (which frame a time names, what colour space blending happens in, how a mono source is spread over two speakers), two implementations would each be right and give different results. Fixing those is what lets one replace another, and keeping text shaping, tracking and text recognition as providers called before evaluation keeps every value a role sees fixed in the resolved document.

## Rules

Rendering is four roles. The renderer and the mixer take the two outputs of evaluation, the decoder reads media files for all of frames, and the encoder writes files.

| Role | Takes | Gives | Also |
| --- | --- | --- | --- |
| decoder | a media file and a frame index, or for sound a media time range | a picture in the working space (RGBA with premultiplied alpha, at the media's bit depth or more), or sound | the providers, the analysis commands and `transcode` read through it too |
| renderer | display lists | frames, as pixels | reads pictures through the decoder, applies filter ops, LUTs, blend modes and transition mattes, draws paths, masks, track mattes and glyphs |
| mixer | the mix plan | audio, as samples | reads sound through the decoder, stretches time with the pitch kept, runs each segment's audio filter, applies each segment's gain and pan envelopes |
| encoder | frames and audio | a file | `transcode` uses it with the decoder |

- Each role supports everything its input names (items, geometry forms, joins, caps, arrowheads, mask modes, track matte modes, filter ops, audio ops, blend modes, LUTs, mattes, media formats, codecs) or refuses before it starts, naming the first thing it lacks and its place. It never drops one silently.
- A renderer draws each frame's items as written ([FRAMES-20](../FRAMES-20/SPEC.md)): pictures with their rounded corners, borders, shadows and transition mattes; paths with their fill, their stroke's joins and caps, their arrowheads and their trim; feathered masks combined in order by their modes; track mattes by alpha or luma; and glyphs from the font files and faces named, at the positions written. It shapes no text and lays nothing out. An engine that only runs a filter graph over time fills the decoder, the mixer or the encoder, not the renderer.
- Every decoder keeps [FRAMES-1](../FRAMES-1/SPEC.md) and [FRAMES-3](../FRAMES-3/SPEC.md), and frames are named by index. Frame i is the frame at `frames[i]`: a decoder checks a file's timestamps against the pinned ones and refuses before it starts when it counts them differently. So what a provider read from a frame (a tracked target, recognised text) and the pixels a renderer draws come from the same frame, whichever decoder renders. A decoder reads a video's nominal frame rate within a hundred-thousandth of a whole number n, or of n × 1000 / 1001, as exactly that rate, so a file's 29.999998 is 30 and probe, resolve and transcode see the rate it was written at.
- A sequence output lasts `duration` to within one frame. Frame k is drawn at sequence time k / fps for every k whose time, measured to the microsecond ([FRAMES-3](../FRAMES-3/SPEC.md)), is before `duration`, and frame 0 always, so the last frame is inside the sequence and floating point noise in `duration` adds no frame.
- Every file is tagged with the working space's encoding: BT.709 primaries and the sRGB transfer (IEC 61966-2-1) in a video, an sRGB chunk in a PNG and an sRGB profile in a JPEG or HEIC, so every encoder's output looks the same in a player.
- `render` writes a master: a `.mov` (ProRes 422 HQ, or ProRes 4444 when the format's `background` is not opaque, so the frames carry alpha, with 24-bit PCM sound at 48 kHz in stereo), or a `.png`, one frame of a sequence ([FRAMES-23](../FRAMES-23/SPEC.md)), with alpha where the frame is not opaque. `--deliver` also writes a delivery file from the same frames in the same step: H.264 at the encoder's highest quality with AAC at 256 kbps or more, with transparent parts over black. A sequence without sound gets a silent track as long as its frames, so every master and delivery carries the same tracks.
- A ProRes 4444 master stores premultiplied alpha and says so in its file. Frame k of a video is presented at exactly k / fps, where a rate within a hundred-thousandth of a whole number n is n and one within a hundred-thousandth of n × 1000 / 1001 is that NTSC rate, so 29.97 is 30000 / 1001 and frame times never drift.
- The working space is sRGB. Decoded pictures are converted to it ([FRAMES-1](../FRAMES-1/SPEC.md)), and every renderer composites, blends, filters and measures the luma of transition mattes and luma track mattes on sRGB-encoded values, the values W3C Compositing writes its formulas for. `exposure` alone works in linear light: it decodes to linear, multiplies, and encodes back. Luma is the Rec. 709 luma of the encoded values. Mask coverage and feather are not colours and are computed as written.
- No role leaves temporary files.
- The same display lists on the same decoder and renderer, of the same version of frames, give the same frames before encoding on the same machine, and on another one to within the rounding of its GPU. File bytes are not promised, since hardware encoders differ. Two renderers give the same geometry, text, timing and operations in the same working space, not the same pixels. The same mix plan on the same decoder and mixer gives the same samples. Two mixers run the audio ops by their formulas at 48 kHz in floating point of 32 bits or more ([FRAMES-13](../FRAMES-13/SPEC.md)), so their samples differ only by rounding and, while a value moves, by how often each computes its coefficients again. Every mixer mixes at 48 kHz in stereo: a mono source plays at the same level on both channels before its pan, and a source with more channels is downmixed by ITU-R BS.775, so two mixers give the same levels and channels. Each segment is then panned by its pan envelope with the pan law of [FRAMES-13](../FRAMES-13/SPEC.md).
- The BS.775 downmix gives Lo = L + 0.7071 C + 0.7071 Ls and Ro = R + 0.7071 C + 0.7071 Rs, drops LFE, adds a single centre surround (3/1, the 4.0 layout) at 0.5 into both sides, and in 7.1 adds each side's side and rear surround at 0.7071 each. A source whose file names no channel layout is taken in SMPTE order for its channel count (3.0, 4.0, 5.0, 5.1, 6.1, 7.1), and a mixer refuses one with a channel BS.775 names no speaker for.

`--decoder`, `--renderer`, `--mixer` and `--encoder` pick each role by the name of its implementation. The renderer defaults to `quartz` (Core Graphics and Core Image), and the others to `avfoundation`.

### Providers

| Provider | Takes | Gives |
| --- | --- | --- |
| shaping | a family, in a pack's font files or among the installed fonts; and a run of text, the faces it is tried in (the style's face, then those of the later families of its `font` list, each a font file and a face), a size, the style's weight and italic, and OpenType feature settings | the family's faces, each with the width, style and weight its OS/2 table declares, which resolve chooses among ([FRAMES-5](../FRAMES-5/SPEC.md)); and the run's glyph ids and advances, each glyph with the place in the text it was set from and the face it was set in: the first of the faces given that has its character, else a face the provider finds on the machine for the weight and italic |
| tracker | pictures from the decoder around one frame, and a quadrilateral on that frame | the target's quadrilateral in media pixels on each frame before and after it, out to where it reports the target lost in each direction |
| OCR | a picture from the decoder, and the recognition languages | recognised lines: each a text and a rectangle in media pixels |

- A quadrilateral is four points in media pixels: the target's top left, top right, bottom right and bottom left corners, in that order. A rectangle is given to a tracker as its four corners. A tracker that follows only position and size gives rectangles as quadrilaterals. Resolve fits the similarity motion from them ([FRAMES-12](../FRAMES-12/SPEC.md)), so a tracker that follows perspective gives a contract a corner pin can later read.
- The recognition languages are a list of BCP 47 tags in order of preference, from the global option `--ocr-languages <tag>[,<tag>...]` (for example `en-US,ko-KR`), or for the `ocr` command from its `--languages` ([FRAMES-23](../FRAMES-23/SPEC.md)). Without either, the provider detects the language of each picture. A provider refuses before it starts on a tag it cannot recognise, naming it. `vision` passes the list as Vision's recognition languages, and detects the language when there is none.
- What was recognised is pinned in the resolved document as the areas it gave ([FRAMES-19](../FRAMES-19/SPEC.md)), so a resolved document needs neither the languages nor the provider again.
- An OCR line's rectangle hugs its text from its highest to its lowest ink, not the font's line box, and `vision` gets it by cutting Vision's line rectangle, width kept, to the rows inside it that hold ink: a pixel farther from the median colour of the rectangle's edge than half the farthest pixel there.
- A provider that fails (it cannot run, or it gives an error for a picture) stops the command, naming what it was asked for: the place in the document or the command's option that asked, the media file and its media time, then the provider's own message.
- What makes one line is the OCR provider's. A document can resolve on one provider and stop on another, where a line is split or joined differently, and the resolved document keeps what was found. The same holds for what a tracker followed.
- `--shaper`, `--tracker` and `--ocr` pick each provider by the name of its implementation. Shaping defaults to `coretext`, the tracker to `point` and OCR to `vision`.

## Interactions

Roles take what [FRAMES-20](../FRAMES-20/SPEC.md) gives. Providers are called by resolve for text layout ([FRAMES-5](../FRAMES-5/SPEC.md)), tracking ([FRAMES-12](../FRAMES-12/SPEC.md)) and text areas ([FRAMES-2](../FRAMES-2/SPEC.md)), and by the analysis commands ([FRAMES-23](../FRAMES-23/SPEC.md)). The pan law is [FRAMES-13](../FRAMES-13/SPEC.md).

## Alternatives considered

Roles loaded at run time as plugins: implementations are built into frames and named by option.

A renderer that draws shapes as primitives of its own (a box, an arrow): paths with joins, caps, trim and arrowheads, and masks as feathered paths, are what Core Graphics, Skia and SVG all draw, so any renderer maps them without a frames-specific shape.

A tracker that reports a rectangle: a rectangle cannot carry rotation, and a later perspective track would need a new contract. A quadrilateral carries both.

Recognition languages in the document: they steer a provider, as `--ocr` picks one, and what they gave is already pinned in the resolved document.

## Notes
