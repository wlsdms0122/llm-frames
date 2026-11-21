# FRAMES-3: Media references

Status: accepted

## Summary

The forms a document names media in (files, pack media, image sequences, nested sequences as compound clips, and template instances), and how frames picks a frame of each at a media time.

## Motivation

Every role and provider must read the same frame for the same time, or a mask tracked on one frame, the text recognised on another and the picture drawn from a third would not line up. One rule for media time and frame picking, pinned in the resolved document, makes them agree. A rendered result is also media for the next edit, and a sequence can stand where a file does as a compound clip, as a nested sequence does in an NLE, so a piece is built once and used in many places.

## Rules

| Form | Meaning |
| --- | --- |
| `"/abs/file"` | an image, video or audio file, judged by its contents, or a `.json` sequence document, which stands as if written there |
| `"<pack>/<name.ext>"` | a file in a pack's `media/` ([FRAMES-17](../FRAMES-17/SPEC.md)), a `.json` sequence document there included |
| `{"file": "/abs/file.pdf", "page": 3}` | a page of a PDF ([PDF pages](#pdf-pages)): `file` in either form above, `page` the page's number, a whole number from 1. Both keys are required. It names an image, so it stands wherever an image file does |
| `{"imageSequence": "/abs/dir", "fps": 30}` | a numbered image sequence (the directory may be `<pack>/<dir>`, a folder in a pack's `media/`): every PNG in the directory, in natural order (runs of digits compare as numbers), at that rate. It plays like a video: its media seconds are frame index / fps, and it takes `in`, `out`, `speed` and `timeRemap` |
| a sequence document object ([FRAMES-6](../FRAMES-6/SPEC.md)) | a compound clip: the nested sequence plays as a video with sound, and its sequence time is its media time |
| `{"template": "<pack>/<name>", "args": {...}}` | a template instance ([FRAMES-17](../FRAMES-17/SPEC.md)). The template is `<pack>/<name>` or an absolute path |

- A `.json` file or a document object whose `kind` is not `"sequence"` stops ([FRAMES-6](../FRAMES-6/SPEC.md)).
- A document with `params` is a template and is used only as a template instance. Anywhere else it stops.
- A document or template that holds itself, directly or through the documents and templates it names, stops, since it would never end.
- An image sequence's `fps` is above 0, and 0 or less stops.
- Paths are absolute. Inside a pack, its own files are named by `<pack>/<name>` like any other pack's ([FRAMES-17](../FRAMES-17/SPEC.md)).
- A compound clip is evaluated at the media times the outer frames ask for, not at its own frame rate. Its `format` `size`, `background`, `conform` and `compositing` apply, so its picture is its own frame, at its own size, with its own background, its clips composited in its own form. Its `fps`, `colorSpace` and `peak` apply only when it is rendered alone ([FRAMES-26](../FRAMES-26/SPEC.md)). It is part of the document that wrote it, so its theme is merged over the one in effect there. A template instance is not ([FRAMES-17](../FRAMES-17/SPEC.md)).
- A compound clip's duration is the length of its nested sequence ([FRAMES-8](../FRAMES-8/SPEC.md)).
- Alpha is kept for PNG, PNG sequences, video codecs that carry it (ProRes 4444, HEVC with alpha), pages of a PDF and compound clips. This is how graphics made elsewhere come in, and how a compound clip whose background is transparent sits over what is below it.
- At media time s, a video or an image sequence shows the frame whose presentation interval holds s: its timestamp is at or before s, and the next one is after s. OCR, tracking, extraction and drawing all pick frames by this rule, and the resolved document pins each such file's frame timestamps, so evaluation picks the frame once and names it by index. Times are measured to the microsecond: a media time and a timestamp are compared rounded to the nearest microsecond, so floating point noise in a computed media time picks no earlier frame.
- A compound clip has no frames of its own. It is evaluated at whatever time is asked, clamped into `[0, duration)`.

### PDF pages

- A PDF (a file whose contents are a PDF document, ISO 32000) is an image whose picture is one of its pages, a still of kind `image` ([FRAMES-17](../FRAMES-17/SPEC.md)) that takes every key an image takes. A PDF of one page named as a file is that page. A PDF of more than one page named as a file stops at `read`, naming the file and its page count, since it names more than one picture ([Ambiguity stops](../README.md#principles)). A `page` above the page count stops at `read`, naming the count, and so does a `page` whose `file` is not a PDF. A `page` that is not a whole number from 1 stops at `check`.
- **A page's media pixels are points, 1/72 inch on the page.** Its crop box is its `CropBox`, or its `MediaBox` where it writes none, intersected with its `MediaBox`: `[x0, y0, x1, y1]` in the page's user space, its corners put in order so that x0 < x1 and y0 < y1, with width W = x1 - x0 and height H = y1 - y0. With u the page's `UserUnit` (1 where it writes none), a user space unit is u points. With r the page's `Rotate` taken modulo 360, into 0 to 359 (0 where it writes none), the point (x, y) of user space is the media pixel (X, Y), and the page's size in media pixels is w by h:

  | r | X | Y | w by h |
  | --- | --- | --- | --- |
  | 0 | u (x - x0) | u (y1 - y) | u W by u H |
  | 90 | u (y - y0) | u (x - x0) | u H by u W |
  | 180 | u (x1 - x) | u (y - y0) | u W by u H |
  | 270 | u (y1 - y) | u (x1 - x) | u H by u W |

  So media pixel (0, 0) is the top left of the crop box as the page is displayed, turned clockwise by r, as a viewer shows it, and the size need not be a whole number: an A4 page is 595.276 by 841.89. A `Rotate` that is not a multiple of 90, and a page whose w or h is under 1, stop at `read`.
- **A page's picture is its content, rendered as ISO 32000-1 defines, at the scale asked, into working values** ([FRAMES-21](../FRAMES-21/SPEC.md), [FRAMES-26](../FRAMES-26/SPEC.md#media)). Its content is its content streams and what they paint: form XObjects, images, inline images, patterns, shadings, soft masks and the glyphs of Type 3 fonts. Its optional content shows as the document's default configuration (`/OCProperties /D`) sets it. Its annotations are not drawn and no check reads them, since they are a viewer's state (hidden and print flags, form fields) and not the page. The graphics state's device-dependent parameters (transfer functions, halftones, overprint) take no part, since they adjust a printing device. Nothing the page paints outside its crop box is drawn, and what it paints nothing over is transparent: the white a viewer shows is its paper, and a solid below the clip is paper in an edit. A decoder approximates this picture with its PDF renderer. It anti-aliases edges by its own rasteriser ([FRAMES-21](../FRAMES-21/SPEC.md)), and where its renderer departs from ISO 32000-1 the decoder names the departure ([Notes](#notes)).
- A page is drawn at the size it is shown at ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)). Its media pixels say where on the page a crop, a box, a mask or an area lies, not how many pixels are drawn, so a page scaled up, zoomed into or shown inside a scaled compound clip is as sharp as a path drawn in place.
- A page is a still: it has one frame, and `track` stops on a clip of it and on a clip parented to one, as on any still ([FRAMES-12](../FRAMES-12/SPEC.md)). A text area is found on it in its media pixels ([FRAMES-26](../FRAMES-26/SPEC.md#providers-and-analysis-pictures)).
- **A page reads nothing outside its file.** Each of these stops at `read`, naming the file, the page and what it lacks, and in a command that reads its pictures: a PDF that opens only with a password (one encrypted with an empty user password opens); a page that sets text in a font its file does not embed, a font whose descriptor (a Type 0 font's, its descendant font's) holds none of `FontFile`, `FontFile2` and `FontFile3` (a Type 3 font is embedded, its glyphs being procedures in the file), since the font would come from the machine and not be pinned ([Reproducible](../README.md#principles)); a page that draws content held in another file (a stream with `/F`, a reference XObject's `/Ref`), since that file is not pinned; and a page that paints in a colour space no fixed formula converts ([FRAMES-26](../FRAMES-26/SPEC.md#media)). What a page uses is what its content uses: these checks are one walk of the file at `read`, through the page's resources (those it inherits from its page tree included) and its content streams, and through those of every form XObject, pattern, soft mask and Type 3 glyph they paint, inline images included. A font counts where the content sets text in it, not where a resource dictionary only lists it, and annotations are not walked. `transcode` reads a page whose colour or fonts stop here ([FRAMES-23](../FRAMES-23/SPEC.md#transcode)).
- An SVG is not media: it is an image no decoder reads, so it stops at `read` as any file of no kind does. Vector artwork made as SVG arrives converted to a PDF ([README](../README.md#what-frames-leaves-out)).

## Interactions

A sequence document is [FRAMES-6](../FRAMES-6/SPEC.md), and its format is [FRAMES-9](../FRAMES-9/SPEC.md). Media time through a clip's time map, `timeRemap` included, is [FRAMES-8](../FRAMES-8/SPEC.md). Templates are [FRAMES-17](../FRAMES-17/SPEC.md). Pinning is [FRAMES-19](../FRAMES-19/SPEC.md). The decoder that reads every file is in [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered

Showing the frame nearest to s: it shows a frame before its time half the time, and the frame on screen at a time in an NLE is the one whose interval holds it.

Evaluating a compound clip at its own frame rate: under an outer sequence at another rate its frames would repeat or skip, and its motion would not match a clip beside it. Evaluating it at the outer times keeps motion smooth, as an NLE renders a nested sequence at the rate of the sequence it plays in.

A picture document kind (an op list on an image, a grid of images) usable as media: it would be a second model for what a sequence already does. A still is a sequence rendered as one frame ([FRAMES-6](../FRAMES-6/SPEC.md)), and as media it is a compound clip.

SVG read by the decoder: macOS has no public SVG reader, and the one it holds fetches files an `<image>` names and sets text in installed fonts, neither of which is pinned. A converter (`rsvg-convert -f pdf`, Inkscape) writes the same artwork as a PDF, whose fonts and colour spaces the file carries.

A switch that rasterises a vector page once at a fixed size, as After Effects's Continuously Rasterize left off and Motion's Fixed Resolution do: its only effect is a master of lower quality ([Master at full quality](../README.md#principles)).

Rasterising a page once at resolve, at the largest size it is shown at: the raster is generated media pinned for one clip, and a deep zoom (a map of 2000 points shown at 50 times) needs a raster larger than any picture a decoder holds.

A PDF of several pages as an image sequence, a page a frame at a rate: it gives a PDF a meaning no NLE gives it, and a change of page is a cut between two clips.

A PDF of several pages named as a file showing its first page, as After Effects imports one: it hides a choice the document should make ([Ambiguity stops](../README.md#principles)).

Splitting a PDF into files of one page by an extension in place of `page`: choosing a part of a medium is what a media reference does, and a file split to choose a page is generated media.

A white paper behind a page by default: the file paints nothing there, and a solid below the clip makes paper of any colour.

## Notes

**Note.** The `avfoundation` decoder draws a page with Core Graphics (`CGContext.drawPDFPage`) into an extended sRGB floating point context. Measured on the reference machine, its renderer departs from ISO 32000-1 in three ways: a non-isolated transparency group is drawn as isolated (Multiply inside one gives 0.5 where ISO 32000-1 gives 0.4), a knockout group (`/K true`) is drawn as a non-knockout one, and a soft mask has 8 bits (a luminosity of 0.5 gives an alpha of 0.5020, 128 / 255). It draws no annotations. Core Graphics returns the crop box not intersected with the media box and the `Rotate` as written, ignores `UserUnit`, and does not clip to the crop box, so the decoder intersects the boxes, takes the angle modulo 360, multiplies by `UserUnit` and clips to the crop box itself, by the table above.
