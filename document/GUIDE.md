# Guide

## Practical notes

These are not contract, but help whoever writes documents.

- OCR confuses similar characters (`0` and `O`). Read the `ocr` output before pointing, and point with a part of the text that is less confusable, plus `nth`.
- On a 1206-wide vertical video a subtitle line holds about 21 Korean characters. Longer subtitles wrap, and more than two lines are hard to read.
- Starting a connected shape while the screen is still moving puts it where the text was at that frame. Start after the screen settles, or follow it with area keyframes.
- PNG is lossless and does not shrink when written again. Use JPEG or HEIC for smaller files.
- `transcode` target: a 1080×1920, 35-second short (11.7 MB) comes to about 3.4 MB at PSNR around 44 dB at `medium`, about 5.5 MB (50 dB) at `high`, and about 2.2 MB (38 dB) at `low`. Text on screen stays sharp at every level.
- HEVC looks slightly better than H.264 at the same level, at about the same size, and some browsers cannot play it. H.264 is the default for delivery.
