# FRAMES-28: Master and loudness

Status: draft

## Summary

The master chain and the loudness meter: a sequence's own `audioFilter`, which processes its mix after the sum and before the file, as an NLE's master or main bus takes effects; `limiter`, an audio op with a look-ahead and a true-peak detector, written out so every mixer limits the same way and usable on clips as on the master; and the meter that `loudness` prints, ITU-R BS.1770-5 integrated loudness, EBU Tech 3341 momentary and short-term loudness, EBU Tech 3342 loudness range, and BS.1770-5 true peak, measured on a medium's sound or on a document's mix before and after its master chain. A loudness target is not a key: an extension measures and writes the gain that reaches it.

## Motivation

An edit is delivered at a loudness and under a peak: EBU R 128 asks for -23 LUFS and a true peak at or below -1 dBTP, and the streaming services normalise to their own levels. Without a master chain the mix is the plain sum of its sounds, and the samples a hot passage carries past full scale are clipped where the master stores them as 24-bit PCM ([FRAMES-21](../FRAMES-21/SPEC.md)), before any file exists, so no tool run on the file afterwards can take the clip back out. A limiter on each clip does not hold the sum of several clips under a ceiling. And without a meter an agent cannot know how loud its mix is: it could only render, encode and measure the encoded file with another tool, which reads the clipped sum, never the mix before the master chain, and gives a number frames cannot promise. With a sequence `audioFilter` and `limiter` the master is held under its ceiling by a published formula, and with `loudness` an extension that normalises to -23 LUFS reads the mix's integrated loudness, writes the difference into the limiter's `gain`, and checks the master, as Premiere Pro's Loudness Normalization measures, sets one static gain and limits.

## Rules

### The master

A sequence's `audioFilter` is its **master chain**: the audio filter its mix passes through after every sound is summed and before the mix goes to the encoder, as an NLE's master or main bus takes effects.

- It takes the forms of a clip's `audioFilter` ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)): a preset name, `{preset, args, mix}`, an op, or a list of those, the first applied first, with every op of the op table, the `limiter` among them. It is checked as a clip's is.
- It is static, since a sequence takes no keyframes: each op parameter and each entry's `mix` holds one value over the whole sequence.
- The mixer sums the segments of the mix plan, each after its own audio filter, gains and pan ([FRAMES-13](../FRAMES-13/SPEC.md#mixing)), then runs the master chain over the stereo sum, each entry's ops on both channels and its output mixed with its input by its `mix`, then hands the result to the encoder. It runs over the whole mix, from sequence time 0 for as long as the output's frames last ([FRAMES-21](../FRAMES-21/SPEC.md)), as one sound: its ops start at rest at sequence time 0 as a segment's do ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), a limiter as [Limiter](#limiter) gives, and a limiter reads silence past the end of the mix.
- Samples past full scale after the master chain are still clipped where a file stores them as PCM ([FRAMES-13](../FRAMES-13/SPEC.md#mixing)). A `limiter` at `mix` 1 with its `ceiling` at 0 or below, last in the chain, keeps the master's true peak at its ceiling ([Limiter](#limiter)), so nothing is left to clip.
- `audioFilter` on a sequence with no sound, one none of whose clips plays sound ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)), stops, since it would process silence.
- `audioFilter` on a sequence used as media inside another, a compound clip's document or a template instanced in another sequence ([FRAMES-17](../FRAMES-17/SPEC.md)), stops, naming the place, since there it would process a mix of several sounds inside another mix, which is a bus ([README](../README.md#what-frames-leaves-out)). A template rendered on its own takes its `audioFilter` as any sequence does.

**Note.** A nested sequence's `audioFilter` stops, where a compound clip's `colorSpace` does not apply inside another sequence ([FRAMES-9](../FRAMES-9/SPEC.md)), so a bus on a compound clip can later give it a meaning as an addition, a minor version ([FRAMES-18](../FRAMES-18/SPEC.md)), and no document that renders today would sound different then.

### Limiter

`limiter` is an op of the audio filter table ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), taken by a clip's `audioFilter`, by an audio preset's `ops` and by the master chain. It raises a sound by `gain`, then turns it down wherever its true peak would pass `ceiling`, starting `lookahead` seconds before the peak so the sound is never cut, and lets it back up by `release`, as an NLE's limiter does (Final Cut Pro's Limiter with Gain, Lookahead and Release, Premiere Pro's Hard Limiter with Input Boost).

| Parameter | Form | Default |
| --- | --- | --- |
| `gain` | dB, the input gain | 0 |
| `ceiling` | dBTP, 0 or less | -1, the maximum true peak of EBU R 128 |
| `lookahead` | seconds, above 0 and at most 0.05 | 0.005 |
| `release` | seconds, above 0 | 0.1 |

A parameter outside its range stops where it is written, and in a preset when it is read, as every op's does ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).

**The formula.** With Fs = 48000, a sound of N samples per channel, x_c[n] the op's input on channel c at sample n, n from 0 to N - 1, and a parameter that moves on a clip taken at each sample from its envelope ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)), holding its first or last value outside the sound:

1. **Gain.** x'_c[n] = 10^(`gain`[n] / 20) × x_c[n], with x'_c[n] = 0 for every n before 0 and from N on: the limiter reads silence before its sound starts and past its end.
2. **Interpolation.** On each channel, the four phases of the 48-tap interpolating filter of ITU-R BS.1770-5 Annex 2 ([Interpolating filter](#interpolating-filter)) give u_c,p[m] = Σ h_p[k] x'_c[m - k] over k from 0 to 11, for p from 0 to 3. The four values u_c,0[n + 6] to u_c,3[n + 6] are the sound oversampled 4 times between samples n and n + 1, at about n + 1/8, n + 3/8, n + 5/8 and n + 7/8.
3. **Detector.** P[n] is the largest of |x'_c[n]| and the eight values |u_c,p[n + 5]| and |u_c,p[n + 6]|, p from 0 to 3, over all its channels: the sample and the true peak of the two intervals beside it, linked across the channels as the compressor's level is ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), so it never moves a stereo image. Its level is L[n] = 20 log10(P[n]) in dBTP, and a silent P[n] of 0 is a level below every ceiling.
4. **Target.** c[n] = min(0, `ceiling`[n] - L[n]) in dB: the gain that brings P[n] to the ceiling, and 0 dB where it is already under it.
5. **Look-ahead.** With D[n] = round(`lookahead`[n] × Fs) samples, halves rounded up, and D the largest D[n] for n from 0 to N - 1, the hold h[n] = min of c[k] over k from n to n + D.
6. **Release.** r[n] = h[n] where h[n] ≤ r[n - 1], and r[n] = β r[n - 1] + (1 - β) h[n] where h[n] > r[n - 1], with β = exp(-1 / (`release`[n] × Fs)): the gain falls to its hold at once and rises back to it as the release smoothing of the compressor does ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).
7. **Smoothing.** g[n] = (r[n - D[n]] + ... + r[n]) / (D[n] + 1), the mean of r in dB over the D[n] + 1 samples that end at n, so the gain falls along a ramp D[n] samples long that ends at the peak.
8. **Output.** y_c[n] = x'_c[n] × 10^(g[n] / 20) on every channel, for n from 0 to N - 1.

The limiter runs from sample -D, D samples before its sound starts, with r[-D - 1] = 0 dB, so its first sample's gain is read over samples it has computed. At rest it has a gain of 0 dB and reads silence. Its output is aligned with its input, with no latency: it reads ahead in its input, which the mixer holds whole.

**What it holds.** Every k from n - D[n] to n has n inside [k, k + D], so h[k] ≤ c[n], and r[k] ≤ h[k] at every k, so g[n] ≤ c[n] at every sample: the gain applied at n brings the sample at n and the interpolated values beside it to the ceiling or under it. A moving `lookahead` changes how long the ramp is and keeps that bound, since the hold looks D ahead, the largest window the sound takes.

**Note.** The gain moves between samples, so the `truePeak` of the output, which the meter reads from the output's own samples, can pass the ceiling where the gain falls fastest, by less than 0.01 dB on the sounds measured (sines, noise bursts and a dense mix 8 dB over full scale, at a `lookahead` from 0.0015 to 0.01). A shorter `lookahead` makes the ramp steeper and distorts low tones, and a shorter `release` lets the gain pump with the sound's waveform at low frequencies.

**Note.** The ceiling is held as frames' meter reads a true peak ([Loudness meter](#loudness-meter)). The four points of the Annex 2 filter can read a peak between them up to 0.55 dB low at 0.45 of the sample rate, as BS.1770-5 says of 4 times oversampling, and another meter interpolates otherwise: a limited mix read with a 16 times interpolator came out up to 0.23 dB above its ceiling. A document whose acceptance another meter decides takes a `ceiling` about 0.3 dB lower.

**Note.** The limiter is defined by its formula, which is the contract: a running minimum of the target gain over the look-ahead window, then a mean over a window of the same length, so the gain meets each peak along a ramp and never after it.

**Keyframes.** On a clip the limiter's `gain`, `ceiling`, `lookahead` and `release` and its entry's `mix` are timed leaves, as every op parameter is ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)): a sampled `ceiling` above 0 is clamped to 0, a sampled `lookahead` above 0.05 to 0.05 and one at or below 0 is a window of 0 samples, and a sampled `release` at or below 0 follows its target at once. The limiter has no identity, since it limits at every `gain` and `ceiling`, so it eases in or out by its entry's `mix`. Its state, r and its window, starts at rest wherever the segment's ops start at rest, where a clip's sound starts and on each repeat of a loop ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), and it reads silence past the end of its segment.

#### Interpolating filter

The four phases h_0 to h_3, each 12 taps, h_p[0] first, as BS.1770-5 Annex 2 gives them. h_2 is h_1 reversed and h_3 is h_0 reversed.

| k | h_0 | h_1 | h_2 | h_3 |
| --- | --- | --- | --- | --- |
| 0 | 0.0017089843750 | -0.0291748046875 | -0.0189208984375 | -0.0083007812500 |
| 1 | 0.0109863281250 | 0.0292968750000 | 0.0330810546875 | 0.0148925781250 |
| 2 | -0.0196533203125 | -0.0517578125000 | -0.0582275390625 | -0.0266113281250 |
| 3 | 0.0332031250000 | 0.0891113281250 | 0.1015625000000 | 0.0476074218750 |
| 4 | -0.0594482421875 | -0.1665039062500 | -0.2003173828125 | -0.1022949218750 |
| 5 | 0.1373291015625 | 0.4650878906250 | 0.7797851562500 | 0.9721679687500 |
| 6 | 0.9721679687500 | 0.7797851562500 | 0.4650878906250 | 0.1373291015625 |
| 7 | -0.1022949218750 | -0.2003173828125 | -0.1665039062500 | -0.0594482421875 |
| 8 | 0.0476074218750 | 0.1015625000000 | 0.0891113281250 | 0.0332031250000 |
| 9 | -0.0266113281250 | -0.0582275390625 | -0.0517578125000 | -0.0196533203125 |
| 10 | 0.0148925781250 | 0.0330810546875 | 0.0292968750000 | 0.0109863281250 |
| 11 | -0.0083007812500 | -0.0189208984375 | -0.0291748046875 | 0.0017089843750 |

The values are computed in floating point, so the Annex's 12.04 dB attenuation before the filter and its gain after it, which give headroom to integer arithmetic, are left out.

**Note.** BS.1770-5 gives this filter as one that satisfies its requirements, not as the only one, so two BS.1770 meters may read a true peak a little apart. frames fixes it, in the limiter and in the meter, so every mixer limits and measures alike.

### Loudness meter

The meter measures stereo sound at 48 kHz, two channels L and R, as the mixer gives it ([FRAMES-21](../FRAMES-21/SPEC.md)). It is a fixed formula of frames, not a role: it measures the samples the mixer gives. Its input is the N samples of a range, s_c[n] for n from 0 to N - 1, and it reads nothing before or after them.

**K-weighting.** Each channel passes through two biquads in turn, y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2], each at rest at the start of the range, its past samples 0, with the coefficients of BS.1770-5 at 48 kHz:

| Stage | b0 | b1 | b2 | a1 | a2 |
| --- | --- | --- | --- | --- | --- |
| 1, the shelf that models the head | 1.53512485958697 | -2.69169618940638 | 1.19839281085285 | -1.69065929318241 | 0.73248077421585 |
| 2, the high-pass | 1 | -2 | 1 | -1.99004745483398 | 0.99007225036621 |

**Loudness of a window.** For a window of W samples starting at sample a, z_c is the mean of y_c[n]² over n from a to a + W - 1 on channel c, and its loudness is l = -0.691 + 10 log10(z_L + z_R) in LUFS, each channel's weight 1 as BS.1770-5 gives left and right. A silent window, z_L + z_R = 0, has a loudness below every gate.

| Measure | Unit | Definition |
| --- | --- | --- |
| `integrated` | LUFS | BS.1770-5 gated loudness. The gating blocks are the windows of 19200 samples (400 ms) starting at 4800 j, for every whole j whose block ends inside the range (75% overlap). With l_j each block's loudness, J_a is the blocks with l_j > -70. The relative gate is Γ_r = -0.691 + 10 log10(the mean of z_L,j + z_R,j over J_a) - 10, and J_g is the blocks with l_j > -70 and l_j > Γ_r. The measure is -0.691 + 10 log10(the mean of z_L,j + z_R,j over J_g). `null` when J_a is empty |
| `range` | LU | EBU Tech 3342 loudness range. The short-term values s_k are the loudness of the windows of 144000 samples (3 s) starting at 4800 k, for every whole k whose window ends inside the range. A is the values with s_k ≥ -70, the gate Γ = 10 log10(the mean of 10^(s_k / 10) over A) - 20, and R the values of A with s_k ≥ Γ. With R sorted from lowest to highest as v_1 to v_n and P(q) = v_i at i = round((n - 1) × q / 100 + 1), halves rounded up, the measure is P(95) - P(10). `null` when A is empty |
| `momentaryMax` | LUFS | the largest loudness of a window of 19200 samples (400 ms) starting at any sample, ungated (EBU Tech 3341). `null` when the range is shorter than 19200 samples or every such window is silent |
| `shortTermMax` | LUFS | the largest loudness of a window of 144000 samples (3 s) starting at any sample, ungated (EBU Tech 3341). `null` when the range is shorter than 144000 samples or every such window is silent |
| `truePeak` | dBTP | 20 log10 of the largest of every |s_c[n]| and every |u_c,p[m]| over both channels, the four phases and every m from 0 to N + 10, u computed from s as the limiter computes it from x' ([Limiter](#limiter)), with the samples outside the range read as 0: the oversampled peak of BS.1770-5 Annex 2 together with the samples themselves, which the Annex's four points lie between and never land on, so `truePeak` is never below `samplePeak` and is the quantity the limiter's detector reads. `null` when every sample is 0 |
| `samplePeak` | dBFS | 20 log10 of the largest |s_c[n]| over both channels. `null` when every sample is 0 |

- Each measure is written rounded to the nearest hundredth.
- A sine of 997 Hz at full scale on one channel reads -3.01 LUFS, as BS.1770-5 gives: the -0.691 cancels the K-weighting's gain at 997 Hz.
- The relative gate of `integrated` keeps at least one block whenever J_a has one, since one block of J_a is at least as loud as their mean, and the gate of `range` keeps at least one value whenever A has one.

**Note.** The windows of `momentaryMax` and `shortTermMax` start at every sample, as a file-based meter must for the Tech 3341 test of a 400 ms tone placed 20 ms at a time: a window that moved by 100 ms could miss the tone by up to 50 ms and read 0.6 LU low. The gating blocks and the short-term values of `range` keep the 100 ms step of BS.1770-5 and Tech 3342, which their definitions fix or allow.

**Note.** Tech 3342 asks a file-based meter to let 1.5 s of silence follow the sound before `range` is read. frames measures the range it is given and adds none, as `integrated` uses no incomplete block, so the last 3 s of a range is read whole and its tail counts once.

### Measuring loudness

`loudness` measures a medium's sound or a document's mix with the meter and prints the measures as machine output ([FRAMES-23](../FRAMES-23/SPEC.md)).

- A document is resolved and mixed, without rendering pictures, as `render` mixes it, with the same mixer, so the measures are of the sound `render` writes before it is clipped and encoded. `mix` measures the sum of the mix plan's segments before the master chain, and `master` the sound after it, the same as `mix` when the sequence has no `audioFilter`.
- A medium is measured as the mixer plays a clip of it at `volume` 1 and `pan` 0 from media time 0 at `speed` 1 ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)): read through the decoder, resampled to 48 kHz, a sound of more than two channels downmixed by ITU-R BS.775 ([FRAMES-21](../FRAMES-21/SPEC.md)), and a mono sound placed at the centre by the pan law, so a mono or stereo file reads as a BS.1770-5 meter reads it, and the number is the one a clip of it adds to a mix at `volume` 1. It is reported as `master`, and `mix` is `null`.
- The range is the samples n whose time n / 48000 lies in `[--from, --to)`: media time for a medium and sequence time for a document, from 0 and to the end of the sound when they are not written, the medium's sound or the whole mix.

**Note.** A medium of more than two channels is measured after the BS.775 downmix the mixer applies, so a 5.1 file reads otherwise than on a 5.1 BS.1770-5 meter, which weights its surrounds by 1.41 and adds the channels' powers. The number `loudness` prints is the one the file brings into a frames mix.

**Note.** A loudness target is an extension's: to normalise a document to -23 LUFS it measures `mix.integrated`, writes `gain` = -23 - `mix.integrated` on a `limiter` at the end of the sequence's `audioFilter`, and checks `master.integrated` and `master.truePeak` ([FRAMES-25](../FRAMES-25/SPEC.md#extensions)). A clip is normalised the same way, by its `volume` from `loudness` of its media over its range.

## Interactions

The audio op table, its checks, keyframes and state at rest are [FRAMES-13](../FRAMES-13/SPEC.md), and the sequence key is in the key table of [FRAMES-7](../FRAMES-7/SPEC.md). The resolved sequence carries the master chain ([FRAMES-19](../FRAMES-19/SPEC.md)), the mix plan carries it as `master` ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)), and the mixer runs it ([FRAMES-21](../FRAMES-21/SPEC.md)). The `loudness` command's usage, options and machine output are [FRAMES-23](../FRAMES-23/SPEC.md), the checks on a limited master are [FRAMES-24](../FRAMES-24/SPEC.md), and the extensions that normalise loudness are [FRAMES-25](../FRAMES-25/SPEC.md). Audio presets are [FRAMES-14](../FRAMES-14/SPEC.md).

## Alternatives considered

A loudness target as a key the mixer reaches in two passes, measuring and then setting the gain: an extension reaches it with the meter and the limiter's `gain`, a document then holds the gain it is mixed at, and none of Premiere Pro, Final Cut Pro, DaVinci Resolve and After Effects keeps a live loudness target on a timeline's mix.

Resolve measuring the mix and pinning a master gain: resolve calls providers and never a role, and the mix is the mixer's output.

A platform limiter (AUPeakLimiter, Logic's Limiter): its algorithm is not published, and the formulas of the audio ops are the contract ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).

A ceiling in `format`: a limiter is an audio effect every NLE also puts on clips, so it belongs in the one op table.

A sample-peak limiter: it misses the peaks between samples that AAC decoding and digital to analogue converters reproduce (BS.1770-5 Annex 2, Attachment 1).

Audio filters on compound clips, as buses, now: they need a mix plan shaped as a tree and a change to how a compound clip's pan is added to its sounds' ([FRAMES-13](../FRAMES-13/SPEC.md#mixing)), and a compound clip rendered to a file and placed as an audio clip takes an `audioFilter` meanwhile.

A master `volume` key: the limiter's `gain` is the master gain, as Final Cut Pro's Limiter Gain and Premiere Pro's Input Boost are.

A separate `gain` op: it would add nothing over `volume` on clips and the limiter's `gain` on the master.

A `lookahead` that cannot take keyframes: it is a number whose change alters no decision resolve makes once ([FRAMES-4](../FRAMES-4/SPEC.md)), and the hold over the largest window keeps the limiter's bound while it moves.

The gain smoothed by a mean of linear gains: the compressor and the gate smooth their gain in dB ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), and the limiter's release and ramp do the same, so the three ops share one domain and either domain keeps the bound.

## Notes

**Note.** The mixer holds the whole mix in memory, and the master chain and the meter each pass over all of it: the limiter's interpolation costs 48 multiplications and additions per sample per channel, and the meter's `momentaryMax` and `shortTermMax` read a window at every sample, which running sums make one pass. An hour of stereo at 48 kHz in 32-bit floats is about 1.4 GB per copy of the mix.

**Note.** AAC encoding and decoding can raise a true peak, so a delivery file can read above a master limited at -1 dBTP. Broadcasters ask lower ceilings for data-reduced audio, such as -2 dBTP or lower, and a document that is delivered as AAC takes that `ceiling`. How far frames' delivery AAC raises it is not yet measured.
