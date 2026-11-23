# FRAMES-13: Audio

Status: accepted

## Summary

How clips play sound: volume, pan, fades, audio filters (EQ, compressor, gate and limiter) as data, keyframed volume and pan, transition crossfades with the transition preset's curve, split edits, how gains multiply, which clips play no sound, and a video's sound placed alone as an audio clip.

## Motivation

An edit's sound is laid like its pictures: a music bed under the whole piece and ducked under speech, dialogue from the camera clips, a sound effect placed on the left as something leaves the frame, a crossfade at every cut that would otherwise click. Sound is media that frames places and does not make, so its rules are how levels and positions combine and how a clip's sound is processed (an EQ on a voice, a compressor on a narration), fixed so that every mixer gives the same mix: the pan law, the crossfade curves, the order gains multiply in and the formula of every audio filter. A shot's sound often starts before its picture or runs on after it, a J or an L cut, and that is one fact about one clip, held where its edit point is so that a trim moves picture and sound together. A video's sound is also used alone (music from a music video), and placing it must not decode a picture nobody sees.

## Rules

### Level and position

- A clip with sound plays it at `volume` (default 1), following its `speed` with the pitch kept.
- A storyline clip's sound plays over its drawn range, its handles included, with its edges moved by its `split` ([Split edits](#split-edits)), and another clip's over its visible window ([FRAMES-8](../FRAMES-8/SPEC.md)), a visual media clip's with its edges moved by its `split`. A video without a sound track, a still, and a compound clip none of whose clips has sound play no sound.
- A clip with `timeRemap` plays no sound ([FRAMES-8](../FRAMES-8/SPEC.md)). `volume`, `pan`, `fadeIn`, `fadeOut`, `audioFilter` and `split` on it stop, since they would do nothing. Sound for a remapped shot is placed as an audio clip of its own.
- `fadeIn` and `fadeOut` are seconds, and ramp the volume linearly from and to 0 at the ends of the range its sound plays over: a storyline clip's drawn range with its edges moved by its `split`, or another clip's visible window, a visual media clip's with its edges moved by its `split`, so a clip the sequence end or tracking cuts still fades out before the cut.
- `volume` is keyframable, for ducking and longer fades. `audioFilter` processes the sound before its volume ([Audio filters](#audio-filters)).
- `pan` places a sound between the left and right channels of the output, from -1 (left) through 0 (centre, the default) to 1 (right). It is keyframable. How it acts depends on how many channels the sound has:

| Channels | Left gain | Right gain | At the centre |
| --- | --- | --- | --- |
| 1 (mono) | cos((p + 1)π/4) | sin((p + 1)π/4) | both channels at cos(π/4), 3 dB down, so the sound's power is the same at every pan (the equal-power pan law) |
| 2 (stereo) | min(1, 1 - p), on the left channel | min(1, 1 + p), on the right channel | both channels at 1 (a balance, as an NLE's balance control: turning it to one side lowers the other) |
| more than 2 | as stereo, after the mixer mixes the sound down to two channels ([FRAMES-21](../FRAMES-21/SPEC.md)) | | |

A mono sound is placed into both output channels at those gains. A stereo sound keeps its channels apart, each taking its own gain. A `pan` outside -1 to 1 stops, as a value of the wrong type does ([FRAMES-7](../FRAMES-7/SPEC.md)).

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
- A compound clip's or a template instance's sounds join the outer mix through its bus ([FRAMES-28](../FRAMES-28/SPEC.md#buses)): their times mapped through the compound clip and its pan added to theirs, cut to -1 and 1, then summed, passed through the nested sequence's `audioFilter` and the compound clip's own, and multiplied by the compound clip's volume, fades and crossfade.
- Sounds that overlap are mixed. Everything is cut at the end of the sequence.
- The sum of a sequence's sounds is its bus, which the sequence's own `audioFilter` processes ([FRAMES-28](../FRAMES-28/SPEC.md#buses)). The outermost bus's output is the mix, and samples past full scale in it are clipped where a file stores them as PCM, as in an NLE with nothing on its main bus.
- A sequence with no sound mixes to silence, its bus a silent one ([FRAMES-28](../FRAMES-28/SPEC.md#buses)), and its file carries a silent track as long as its frames, since a file's tracks do not depend on what the sequence holds ([FRAMES-21](../FRAMES-21/SPEC.md)).
- The mix plan carries each sound as segments with its audio filter, a gain envelope and a pan envelope, and each bus with its chain and level envelope ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)), and the mixer applies the filter, the gains and the pan law above to each segment, then each bus's chain and level to its sum.

### Split edits

A storyline clip with sound and a visual media clip with sound, connected or in `clips`, take `split: {"before": b, "after": a}`, each in seconds, 0 or more, default 0: a J or an L cut, held on the one clip as Final Cut Pro's expanded audio and Premiere Pro's split edit hold it. **A split is about the edges of a clip's sound**, which every clip with a picture and sound has: it moves them out, the start `b` seconds earlier and the end `a` seconds later, so the B-roll laid over a storyline takes its own sound in early as a shot of the storyline does. **A storyline clip's split is measured from its edit points**, where its edit range starts and ends ([FRAMES-8](../FRAMES-8/SPEC.md)), not from its drawn range, so a transition does not change a cut's lead: its sound's edges are its edit points moved out. It plays on the clip time beyond its `in` and `out`, as a transition's handles play. A trim of its edit points moves its picture and its sound together, and the split goes with them. A visual media clip's split is measured from the edges of its visible window ([FRAMES-8](../FRAMES-8/SPEC.md)), where its sound starts and ends without one. A window narrowed by the sequence end or by a lost target ([FRAMES-12](../FRAMES-12/SPEC.md)) is where the clip ends, picture and sound, and a split moves the edges of a clip's sound from where they are, so it is measured from there. A storyline clip is measured from its edit points since a transition's overlap does not end the clip, where a narrowed window does.

- A visual media clip's sound plays on its time map beyond its window, the media before its `in` and after its window's end, a loop continuing. A visual media clip has no transition, so its sound starts and ends at its moved edges at its own level. One in `clips` is cut against no clip, and its split still moves the edges of its sound, as a connected clip's does.
- At an edge with no transition, the sound starts or ends at its moved edge, at its own level. At an edge with a transition, the clip's own side of the transition's crossfade moves with its sound's edge: it is placed as it would be about the edit point, with the transition's length, place and curve, moved by the split, and the sound plays over it, its handles included. So `b` going up from 0 moves the clip's sound continuously from where it plays without a split.
- The moved sound overlaps its neighbours' sound, which plays and crossfades as it would, and the two are mixed ([Mixing](#mixing)). Its `fadeIn` and `fadeOut` act at the ends of the range its sound plays over.
- `timeline` prints that range for every storyline clip and every visual media clip ([FRAMES-23](../FRAMES-23/SPEC.md)), so a J or an L cut can be checked without listening.
- Its `volume`, `pan` and `audioFilter` keyframes are on its clip time and act over the range its sound plays over, each holding its first or last value beyond its keyframes ([FRAMES-4](../FRAMES-4/SPEC.md)).
- The media must hold sound over the range its sound plays over. A split that reaches before the first sample of its media's sound or past the last stops, naming the clip and the edge, as does a split on a clip that plays no sound (a still, a solid, a video without a sound track, a compound clip none of whose clips has sound, a clip with `timeRemap`). A split that moves a clip's sound to start before the start of the sequence or to end past its end stops, naming the edge, since that sound would lie outside the sequence. The range the sound plays over decides it, the same for a storyline clip and a visual media clip, so a `before` on a storyline clip longer than the clips before it stops as a `before` on the first one does.

### A video's sound alone

A connected or sequence media clip of a video, a compound clip or a sequence template instance that takes only its media's sound (`"picture": false`, [FRAMES-7](../FRAMES-7/SPEC.md)) is an audio clip of that sound, as Final Cut Pro detaches a clip's audio and Premiere Pro unlinks it: music taken from a music video, or a recording's sound laid under other pictures. It takes the keys of an audio clip and `picture`, and plays as an audio clip of a sound file would: its window, `in`, `out`, `speed` and `loop` place the sound as [FRAMES-8](../FRAMES-8/SPEC.md) places any sound, and nothing of its picture is read, drawn or measured. `picture` is `true` when it is not written.

- A J or an L cut of a storyline clip or a visual media clip is its `split` ([Split edits](#split-edits)), not an audio clip of its sound beside it.
- `picture` on a storyline clip stops, since a storyline clip is a picture ([FRAMES-9](../FRAMES-9/SPEC.md)), and so does `picture` on media with no picture to leave out or no sound to keep: a still, an image sequence and an audio file. `"picture": false` on a video without a sound track, or on a compound clip none of whose clips has sound, stops, since it would play nothing.

### Audio filters

`audioFilter` processes a clip's sound with operations from a fixed table, as `filter` does its picture ([FRAMES-15](../FRAMES-15/SPEC.md)) and as an NLE's clip audio effects do: an EQ to take the rumble out of a room and give a voice presence, a compressor to even out its level, a gate to quiet the noise between phrases, a limiter to hold its peaks under a ceiling. The operations are frames vocabulary and their formulas are the contract, so every mixer gives the same sound and a pack's voice chain sounds the same wherever the document is mixed.

| Form | Meaning |
| --- | --- |
| a preset name | an audio preset with its defaults: `<pack>/<name>` for `presets/audio/<name>.json` in a pack, or an absolute path |
| `{preset, args, mix}` | that preset with arguments, as [FRAMES-14](../FRAMES-14/SPEC.md) checks them, and its `mix`. At least one of `args` and `mix` is required |
| an op | one operation written in place, `{"op": ..., ...}`, and its `mix` |
| a list of those | each in turn, the first applied first. It holds at least one entry, and an empty list stops |

```json
"audioFilter": [ { "op": "eq", "bands": [ { "type": "highPass", "frequency": 80 }, { "type": "peak", "frequency": 3000, "gain": 3, "q": 1 } ] },
                 { "op": "compressor", "threshold": -18, "ratio": 3, "knee": 6 } ]
```

**An entry written as an object takes `mix`, from 0 to 1, default 1: its output is its dry input and its wet result mixed by `mix`**, sample by sample on each channel, `dry × (1 - mix) + wet × mix`, as a plug-in's dry/wet control mixes. A preset entry mixes the output of its whole chain, and the next entry takes the mixed sound. `mix` is keyframable, so an audio preset fades in by its `mix` from 0 with none of its op parameters written out. A preset's own ops take no `mix`.

An audio preset is `{description, params, ops}`, `ops` a list of operations. Its `params` are as every preset's ([FRAMES-14](../FRAMES-14/SPEC.md)), and `{"param": "<name>"}` stands for a number wherever an operation takes a number. It never stands for an `op`, a band's `type`, a `convolve` `file` or a key, and since no operation takes a colour or an ease, a `color` or `choice` parameter stops. frames ships no audio preset ([FRAMES-16](../FRAMES-16/SPEC.md)).

| op | Parameters | Meaning |
| --- | --- | --- |
| `eq` | `bands`, a list of at least one band | each band in order, a biquad filter of the RBJ Audio EQ Cookbook |
| `compressor` | `threshold` (dBFS), `ratio` (1 or more), `knee` (dB, 0 or more, default 0), `attack` (seconds above 0, default 0.01), `release` (seconds above 0, default 0.1), `makeup` (dB, default 0) | a feed-forward compressor with a hard knee at `knee` 0 and a soft one above it |
| `gate` | `threshold` (dBFS), `range` (dB, 0 or less, default -80), `attack` (seconds above 0, default 0.001), `hold` (seconds, 0 or more, default 0.05), `release` (seconds above 0, default 0.1) | a noise gate that turns the sound down by `range` while its level stays below `threshold` |
| `limiter` | `gain` (dB, default 0), `ceiling` (dBTP, 0 or less, default -1), `lookahead` (seconds from 0.0015 to 0.05, static, default 0.005), `release` (seconds above 0, default 0.1) | a look-ahead limiter that raises the sound by `gain` and holds its true peak at `ceiling`, its formula given in [FRAMES-28](../FRAMES-28/SPEC.md#limiter) |
| `convolve` | `file` (an impulse response, a media file with sound), `gain` (dB, default 0) | convolves the sound with the impulse response and raises the result by `gain`: a room's reverb, a plate, a speaker or a telephone, as a convolution reverb takes a recorded space ([Convolution](#convolution)) |

| Band key | Form | Default |
| --- | --- | --- |
| `type` | `lowShelf`, `highShelf`, `peak`, `lowPass` or `highPass` | required |
| `frequency` | Hz, above 0 and below 24000 | required |
| `gain` | dB, taken by `lowShelf`, `highShelf` and `peak` only | required where it is taken |
| `q` | above 0 | 0.7071, which is 1/√2 |

A parameter outside its range stops where it is written, and in a preset when it is read, with every parameter at its default and again with a choice's arguments, as filters are checked ([FRAMES-15](../FRAMES-15/SPEC.md)). An unknown op, a band key its `type` does not take, and a missing required key stop.

**EQ.** With Fs = 48000, f the `frequency`, G the `gain`, w = 2πf / Fs, A = 10^(G / 40) and α = sin(w) / (2 × `q`), each band filters each channel on its own as y[n] = (b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2]) / a0, with the coefficients of the cookbook:

| `type` | b0 | b1 | b2 | a0 | a1 | a2 |
| --- | --- | --- | --- | --- | --- | --- |
| `lowPass` | (1 - cos w) / 2 | 1 - cos w | (1 - cos w) / 2 | 1 + α | -2 cos w | 1 - α |
| `highPass` | (1 + cos w) / 2 | -(1 + cos w) | (1 + cos w) / 2 | 1 + α | -2 cos w | 1 - α |
| `peak` | 1 + α A | -2 cos w | 1 - α A | 1 + α / A | -2 cos w | 1 - α / A |
| `lowShelf` | A((A + 1) - (A - 1) cos w + 2√A α) | 2A((A - 1) - (A + 1) cos w) | A((A + 1) - (A - 1) cos w - 2√A α) | (A + 1) + (A - 1) cos w + 2√A α | -2((A - 1) + (A + 1) cos w) | (A + 1) + (A - 1) cos w - 2√A α |
| `highShelf` | A((A + 1) + (A - 1) cos w + 2√A α) | -2A((A - 1) + (A + 1) cos w) | A((A + 1) + (A - 1) cos w - 2√A α) | (A + 1) - (A - 1) cos w + 2√A α | 2((A - 1) - (A + 1) cos w) | (A + 1) - (A - 1) cos w - 2√A α |

**Convolution.** An impulse response is what a space or a device gives back for one click, and a sound convolved with it sounds as if played there. It is data as a LUT is ([FRAMES-15](../FRAMES-15/SPEC.md)), so a reverb is a file and no code, and a mixer swapped for another gives the same sound. With h the impulse response of K samples and G the `gain`, each channel is y[n] = 10^(G / 20) × Σ h[k] x[n - k], k from 0 to K - 1, with x 0 before the sound starts. Nothing scales h: the file's level is the reverb's level, and `gain` trims it.

- The impulse response is read as the mixer reads any sound ([FRAMES-21](../FRAMES-21/SPEC.md)): at 48 kHz, a sound of more than two channels downmixed. One of one channel is the h of both channels of the sound. One of two channels gives the left channel its left and the right channel its right, and neither channel reaches the other.
- `file` is named as a media file is ([FRAMES-3](../FRAMES-3/SPEC.md)), `<pack>/<name.ext>` for a file in a pack's `media/` or an absolute path, and resolve pins it by its hash ([FRAMES-19](../FRAMES-19/SPEC.md)). A file without sound, an image sequence, a page of a PDF or a sequence document stops, and so does an impulse response of no samples or of more than 30 seconds.
- The op adds no delay: y[n] reads x[n] and the samples before it. An impulse response whose first sample is 1 and whose others are 0 leaves the sound as it is at `gain` 0.
- **The sound ends where its span ends, and so does its reverb.** The op's output has the samples of its input, so the tail a clip's last sound leaves is cut at the clip's end, as an NLE's clip effect is cut with its clip. A tail that must ring on is given a longer span: the op is written on a bus that goes on past the sound, a compound clip that holds the clip and runs longer or the sequence's own `audioFilter` ([FRAMES-28](../FRAMES-28/SPEC.md#buses)).
- A reverb beside the dry sound is the entry's `mix`, and a reverb for some clips only, a send, is a compound clip of those clips with the op on it.
- A mixer may compute the sum in any order, in blocks or by a Fourier transform, and its output differs from the formula by rounding alone.

**Level.** The compressor and the gate read one level for all of a sound's channels, so they never move a stereo image: L[n] = 20 log10(m[n]) in dBFS, with m[n] the largest |x[n]| among the channels, and a silent sample's level below every threshold. Each smooths a target gain c[n] in dB into the gain g[n] it applies, as the branching peak detector of Giannoulis, Massberg and Reiss (2012) smooths it: g[n] = β g[n-1] + (1 - β) c[n], with β = exp(-1 / (τ × Fs)) and τ its `attack` or its `release` as below.

**Compressor.** With T the `threshold`, R the `ratio` and W the `knee`, the gain curve maps a level L to y(L) = L where 2(L - T) < -W, to L + (1/R - 1)(L - T + W/2)² / (2W) where |2(L - T)| ≤ W and W is above 0, and to T + (L - T) / R where 2(L - T) > W. Its target is c[n] = y(L[n]) - L[n], τ is `attack` when c[n] < g[n-1] and `release` otherwise, and every channel is multiplied by 10^((g[n] + `makeup`) / 20).

**Gate.** The gate is open at n when L[n] ≥ `threshold`, or when L was at or above `threshold` at a sample less than `hold` seconds before n. Its target c[n] is 0 dB when it is open and `range` when it is closed, τ is `attack` when c[n] > g[n-1] and `release` otherwise, and every channel is multiplied by 10^(g[n] / 20).

- A clip's audio filter acts on its sound as the mixer reads it, at 48 kHz, after its `speed` and after a sound of more than two channels is downmixed ([FRAMES-21](../FRAMES-21/SPEC.md)), and before its volume, fades, crossfades and pan, as a console's insert effects come before its fader. So a fade fades the processed sound, and a compressor does not undo a fade.
- A filter's state, each biquad's past samples, the compressor's and the gate's gain and hold, the limiter's gain and its window ([FRAMES-28](../FRAMES-28/SPEC.md#limiter)), and the past samples a `convolve` reads, starts afresh where the clip's sound starts and where a loop starts a repeat, since its media jumps there, and carries on wherever its media plays on, so the media a split plays before a looping clip's `in` runs into its first repeat with no break. The rule is the same for every `audioFilter`: on a compound clip or a template instance, its own audio filter and its nested sequence's, which run on its bus ([FRAMES-28](../FRAMES-28/SPEC.md#buses)), start afresh where its sound starts and at each repeat of its loop, where its media, the nested sequence, starts again.
- Each segment of the mix plan ([FRAMES-20](../FRAMES-20/SPEC.md)) starts its operations at rest: every biquad's past samples 0, a compressor's gain 0 dB, a gate closed, its gain at `range`, a `convolve`'s past samples 0, and a limiter's gain 0 dB, reading silence before the segment starts and past its end ([FRAMES-28](../FRAMES-28/SPEC.md#limiter)), and each bus's chain does the same over its span ([FRAMES-28](../FRAMES-28/SPEC.md#buses)). A loop starts them again on each repeat.
- `audioFilter` is taken by a clip whose media has sound: a storyline clip or media clip of a video with a sound track, of a compound clip or of a template instance, an audio clip, and a clip of a video's, a compound clip's or a template instance's sound alone. On a clip that plays no sound (a video without a sound track, a compound clip none of whose clips has sound, a clip with `timeRemap`) it stops, since it would do nothing. On a compound clip or a template instance it runs on the clip's bus, after the nested sequence's `audioFilter` and before the clip's volume, fades and crossfades ([FRAMES-28](../FRAMES-28/SPEC.md#buses)).
- `audioFilter` is keyframable. Its timed leaves are its preset arguments, its op parameters (a band's `frequency`, `gain` and `q`, a compressor's or a gate's numbers, a limiter's `gain`, `ceiling` and `release`, and a `convolve`'s `gain`) and its entries' `mix`, and a keyframe's `audioFilter` writes the ones it moves over the clip's static audio filter ([FRAMES-4](../FRAMES-4/SPEC.md)). A sequence's `audioFilter` takes keyframes by the same rules, in the sequence's own `keyframes` on its sequence time ([FRAMES-28](../FRAMES-28/SPEC.md#buses)). Between two keyframes that write it each leaf interpolates as [FRAMES-4](../FRAMES-4/SPEC.md) gives, except a band's `frequency` and `q`, which interpolate geometrically (in log space), as a crop's size does: a pitch is heard by its ratio, so a sweep from 100 Hz to 10 kHz spends as long on each octave, and a `q` is the ratio of a band's centre to its width. Neither reaches 0 between keyframes, even under an ease that overshoots. Its structure is static, written on the clip: its entries in order, their presets and ops, the number and types of its bands, a limiter's `lookahead` ([FRAMES-28](../FRAMES-28/SPEC.md#limiter)) and a `convolve`'s `file`. A keyframe whose lists have another length, or that writes a preset, an op, a band's `type`, a `convolve`'s `file`, a limiter's `lookahead` or a preset argument a `lookahead` reads, stops, naming the clip and the keyframe. A leaf that two keyframes or more write is checked against its range, as its sampled values are, and one a single keyframe writes as a static value ([FRAMES-4](../FRAMES-4/SPEC.md)). A value an ease carries past its range is clamped to it where it is used, and past a bound the range leaves open it takes its limit there: a sampled `frequency` at or above 24000 filters as the cookbook's coefficients do as f approaches 24000, and a sampled `attack` or `release` at or below 0 follows its target at once. An op that eases in or out is keyframed from or to its identity: a `lowShelf`, `highShelf` or `peak` band at `gain` 0, a compressor at `ratio` 1 and `makeup` 0, a gate at `range` 0. A `lowPass` or `highPass` band has no identity, so an `eq` that holds one eases in or out by its entry's `mix`, and neither has a limiter, which limits at every `gain` and `ceiling`. An entry eases in or out whole by its `mix`.

## Interactions

Clocks, windows and `timeRemap` are [FRAMES-8](../FRAMES-8/SPEC.md). Audio presets are read as presets are ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-17](../FRAMES-17/SPEC.md)), and their numbers are checked as filters' are ([FRAMES-15](../FRAMES-15/SPEC.md)). Keyframes and eases are [FRAMES-4](../FRAMES-4/SPEC.md). A transition's `audio` is declared in its preset ([FRAMES-14](../FRAMES-14/SPEC.md)). The mix plan is [FRAMES-20](../FRAMES-20/SPEC.md). The mixer, the downmix and the sound format are [FRAMES-21](../FRAMES-21/SPEC.md). Buses, the limiter's formula and the loudness meter are [FRAMES-28](../FRAMES-28/SPEC.md).

## Alternatives considered

A linear crossfade only: two unrelated sounds dip by 3 dB in the middle of it. Constant power is the default an NLE uses, and constant gain stays for a cut inside one take.

A linear pan law on a mono sound: a sound moved across the centre would dip in power there. The equal-power law keeps it level, as an NLE pans a mono clip.

Panning a stereo sound by the mono law: a centred stereo sound would play 3 dB down. A balance leaves it at unity at the centre.

Sound under time remapping, with its pitch kept or shifted: a hold or a reverse gives sound few edits keep, and a sound placed as its own clip is cut as the edit needs.

Audio filters as names without formulas: the meaning of a pack's voice chain would be each mixer's, as a filter's would be each renderer's ([FRAMES-15](../FRAMES-15/SPEC.md)). The cookbook biquads and the feed-forward compressor are what every DAW and NLE builds its EQ and dynamics on, and are written out exactly.

A level detector by RMS, or one per channel: an RMS window is one more parameter whose shape mixers choose differently, and a compressor per channel moves a stereo image when one side is louder. A linked peak detector with smoothed gain is the form the compressor literature gives as the reference.

A compound clip's audio filter and a nested sequence's ignored or stopped, with processing left to the clips inside it: an NLE processes a compound clip's or a submix's sound as one, a compressor or a limiter on a group of clips acts on their sum and not on each, and a sequence's chain is part of what it sounds like ([FRAMES-28](../FRAMES-28/SPEC.md#buses)). A loudness target is an extension's, which measures with `loudness` and writes a gain ([FRAMES-25](../FRAMES-25/SPEC.md)).

A split edit as an audio clip of the shot's sound beside its storyline clip, with the storyline clip's `volume` keyframed down where the audio clip takes over: the one fact that a shot's sound leads or trails its picture would be written in two places that must stay complementary, since the same media at the same time played twice is about 6 dB louder, and a trim of the edit point would have to change both. `split` keeps the fact one value on the clip ([FRAMES-25](../FRAMES-25/SPEC.md)), and it moves with its edit point.

A split on storyline clips only, as the place an edit point is held: a connected clip with sound, the usual B-roll with its natural sound, would take its sound in early only as a picture clip keyed silent beside a `"picture": false` clip of the same media, the two-place structure above. The J or L cut is about the edges of a clip's sound, which every clip with a picture and sound has, as Final Cut Pro's expanded audio works on connected clips too.

A visual media clip's split measured from its written window, its `at`: where the sequence end or a lost target narrows the window, the clip ends there, its sound without a split included, so a split of 0 would move its sound's edge out past where the clip ends, and the split would no longer be the distance its sound leads or trails its picture. A split moves the edges of a sound from where they are, and the narrowed window is where they are.

Effects after the fader: a compressor after a fade would lift the fade back up, and an NLE's clip effects sit before its volume.

A reverb as a formula with parameters, a Schroeder or a feedback delay network with a room size and a decay: every mixer would have to build the same network to the sample, and each new character of space would be a new op. An impulse response holds any linear space or device as data.

A tail that rings past its clip's end, the clip's sound made longer by the op: a clip's span is the edit's, and a sound that outlasts its span would overlap the next clip's and move every crossfade. A bus has the span the tail needs.

An impulse response scaled to unit energy or unit peak when it is read: the level of a file would then not be its own, and two mixers would have to agree on the measure. `gain` trims a loud one.
## Notes
