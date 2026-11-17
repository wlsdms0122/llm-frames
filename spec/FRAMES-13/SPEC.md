# FRAMES-13: Audio

Status: accepted

## Summary

How clips play sound: volume, pan, fades, keyframed volume and pan, transition crossfades with the transition preset's curve, how gains multiply, and which clips play no sound.

## Motivation

An edit's sound is laid like its pictures: a music bed under the whole piece and ducked under speech, dialogue from the camera clips, a sound effect placed on the left as something leaves the frame, a crossfade at every cut that would otherwise click. Sound is media that frames places and does not make, so its rules are how levels and positions combine, fixed so that every mixer gives the same mix: the pan law, the crossfade curves and the order gains multiply in.

## Rules

### Level and position

- A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept.
- A storyline clip's sound plays over its drawn range, its handles included, and another clip's over its visible window ([FRAMES-8](../FRAMES-8/SPEC.md)). A video without a sound track, a still, and a compound clip none of whose clips has sound play no sound.
- A clip with `timeRemap` plays no sound ([FRAMES-8](../FRAMES-8/SPEC.md)). `volume`, `pan`, `fadeIn` and `fadeOut` on it stop, since they would do nothing. Sound for a remapped shot is placed as an audio clip of its own.
- `fadeIn` and `fadeOut` are seconds, and ramp the volume linearly from and to 0 at the ends of the range its sound plays over: a storyline clip's drawn range, or another clip's visible window, so a clip the sequence end or tracking cuts still fades out before the cut.
- `volume` is keyframable, for ducking and longer fades.
- `pan` places a sound between the left and right channels of the output, from -1 (left) through 0 (centre, the default) to 1 (right). It is keyframable. How it acts depends on how many channels the sound has:

| Channels | Left gain | Right gain | At the centre |
| --- | --- | --- | --- |
| 1 (mono) | cos((p + 1)π/4) | sin((p + 1)π/4) | both channels at cos(π/4), 3 dB down, so the sound's power is the same at every pan (the equal-power pan law) |
| 2 (stereo) | min(1, 1 - p), on the left channel | min(1, 1 + p), on the right channel | both channels at 1 (a balance, as an NLE's balance control: turning it to one side lowers the other) |
| more than 2 | as stereo, after the mixer mixes the sound down to two channels ([FRAMES-21](../FRAMES-21/SPEC.md)) | | |

A mono sound is placed into both output channels at those gains. A stereo sound keeps its channels apart, each taking its own gain.

### Crossfades

- During a storyline transition the outgoing clip's sound fades out and the incoming clip's sound fades in, over the transition, from their handles. Where a handle runs out of media, that sound is silent.
- The curve is the transition preset's `audio` ([FRAMES-14](../FRAMES-14/SPEC.md)). With u the progress through the transition, from 0 at its start to 1 at its end at an even pace:

| `audio` | Outgoing gain | Incoming gain |
| --- | --- | --- |
| `constant-power` (default) | cos(uπ/2) | sin(uπ/2) |
| `constant-gain` | 1 - u | u |

**Note.** Two unrelated sounds add in power, and `constant-power` keeps their sum level through the transition. Two sounds that are the same signal (a cut inside one take) add in amplitude, and `constant-gain` keeps that level, where `constant-power` would swell by 3 dB in the middle.

### Mixing

- Gains multiply: volume, fades and the transition crossfade all apply. Pan acts after them, on the channels.
- A compound clip's sounds join the outer mix, with their times mapped through the compound clip, their gains multiplied by its own, and its pan added to theirs, cut to -1 and 1.
- Sounds that overlap are mixed. Everything is cut at the end of the sequence.
- A sequence with no sound has no audio track.
- The mix plan carries each sound as segments with a gain envelope and a pan envelope ([FRAMES-20](../FRAMES-20/SPEC.md)), and the mixer applies the gains and the pan law above.

## Interactions

Clocks, windows and `timeRemap` are [FRAMES-8](../FRAMES-8/SPEC.md). Keyframes and eases are [FRAMES-4](../FRAMES-4/SPEC.md). A transition's `audio` is declared in its preset ([FRAMES-14](../FRAMES-14/SPEC.md)). The mix plan is [FRAMES-20](../FRAMES-20/SPEC.md). The mixer, the downmix and the sound format are [FRAMES-21](../FRAMES-21/SPEC.md).

## Alternatives considered

A linear crossfade only: two unrelated sounds dip by 3 dB in the middle of it. Constant power is the default an NLE uses, and constant gain stays for a cut inside one take.

A linear pan law on a mono sound: a sound moved across the centre would dip in power there. The equal-power law keeps it level, as an NLE pans a mono clip.

Panning a stereo sound by the mono law: a centred stereo sound would play 3 dB down. A balance leaves it at unity at the centre.

Sound under time remapping, with its pitch kept or shifted: a hold or a reverse gives sound few edits keep, and a sound placed as its own clip is cut as the edit needs.

Audio filters (EQ, compression): left out (README). Volume and pan are what placing sound needs, and processed sound arrives as media.

## Notes
