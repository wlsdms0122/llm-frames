# FRAMES-13: Audio

Status: accepted

## Summary

How clips play sound: volume, fades, keyframed volume, transition crossfades, and how gains multiply.

## Motivation

Sound is media that frames places and does not make, so its rules are only how levels combine.

## Rules

- A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept.
- A storyline clip's sound plays over its drawn range, its handles included, and another clip's over its visible window ([FRAMES-8](../FRAMES-8/SPEC.md)). A video without a sound track, a still, an image or layout document, and a compound clip none of whose clips has sound play no sound.
- `fadeIn` and `fadeOut` are seconds, and ramp the volume from and to 0 at the ends of the clip's window, or of a storyline clip's drawn range.
- `volume` is keyframable, for ducking and longer fades.
- During a storyline transition the outgoing clip's sound fades out and the incoming clip's sound fades in, linearly over the transition, from their handles. Where a handle runs out of media, that sound is silent.
- Gains multiply: volume, fades and the transition crossfade all apply.
- A compound clip's sounds join the outer mix, with their times mapped through the compound clip and their gains multiplied by its own.
- Sounds that overlap are mixed. Everything is cut at the end of the sequence.
- A sequence with no sound has no audio track.

## Interactions

The mix plan is [FRAMES-20](../FRAMES-20/SPEC.md). The mixer and the sound format are [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered


## Notes
