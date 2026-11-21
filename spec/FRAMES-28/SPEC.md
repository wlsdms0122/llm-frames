# FRAMES-28: Buses and loudness

Status: draft

## Summary

Buses and the loudness meter: every sequence's sum is a bus whose chain is the sequence's own `audioFilter`, run on the sum of its sounds wherever the sequence plays, as a compound clip's or a template instance's bus inside another sequence and as the mix when it is the outermost, as an NLE's submix and main bus take effects; `limiter`, an audio op with a look-ahead and a true-peak detector, written out so every mixer limits the same way and usable on clips as on buses; and the meter that `loudness` prints, ITU-R BS.1770-5 integrated loudness, EBU Tech 3341 momentary and short-term loudness, EBU Tech 3342 loudness range, and BS.1770-5 true peak, measured on one sound, a medium's or a document's mix. A loudness target is not a key: an extension measures and writes the gain that reaches it.

## Motivation

A mix is made to a loudness and under a peak: EBU R 128 asks for -23 LUFS and a true peak at or below -1 dBTP, and the streaming services normalise to their own levels. Without a chain on the sequence's bus the mix is the plain sum of its sounds, and the samples a hot passage carries past full scale are clipped where `render` stores them as 24-bit PCM in its file ([FRAMES-21](../FRAMES-21/SPEC.md)), so no tool run on the file afterwards can take the clip back out. A limiter or a compressor on each clip does not act on the sum of several clips, as one on a dialogue submix or on the main bus does. And without a meter an agent cannot know how loud its mix is: it could only render, encode and measure the encoded file with another tool, which reads the clipped sum and gives a number frames cannot promise. With a sequence `audioFilter` and `limiter` every sample of the mix is held at or under a ceiling by a published formula, and with `loudness` an extension that normalises to -23 LUFS measures the document, writes the difference into the limiter's `gain`, and measures again.

## Rules

### Buses

Every sequence's sum is a **bus**: the sum of its sounds, passed through a chain of audio filters, as an NLE's submix or main bus takes effects. A sequence's `audioFilter` is its bus's **chain** wherever the sequence plays: rendered on its own, and as the media of a compound clip or a template instance inside another sequence ([FRAMES-17](../FRAMES-17/SPEC.md)).

- It takes the forms of a clip's `audioFilter` ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)): a preset name, `{preset, args, mix}`, an op, or a list of those, the first applied first, with every op of the op table, the `limiter` among them. It is checked as a clip's is.
- It is static, since a sequence takes no keyframes: each op parameter and each entry's `mix` holds one value over the whole sequence.
- The chain runs on the stereo sum, each entry's ops on both channels and its output mixed with its input by its `mix`.
- A sequence with no sound, one none of whose clips plays sound ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)), takes an `audioFilter` as any sequence does, and its chain processes silence: every op of the table gives silence for silence, so the sequence still plays no sound. A template is checked once, before its arguments ([FRAMES-17](../FRAMES-17/SPEC.md)), so whether its arguments play sound never decides whether its `audioFilter` stands.

A compound clip or a template instance plays its nested sequence's bus inside the sequence that holds it, in this order:

1. Its inner sounds are placed as [FRAMES-13](../FRAMES-13/SPEC.md#mixing) places them: each with its own audio filter, level and pan, and the compound clip's `pan` added to each sound's pan, cut to -1 and 1. Pan comes before the sum.
2. The bus sums them, with the buses of the compound clips inside it, in the outermost sequence's time, each sound after the compound clip's retiming, as the mix plan lays segments ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)).
3. The nested sequence's `audioFilter` runs on the sum, then the compound clip's own `audioFilter`, which takes keyframes as a clip's does ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), then the compound clip's level: its `volume`, its fades and a transition's crossfade.
4. The result is added to the bus of the sequence that holds the compound clip.

The outermost sequence's bus is the last: its chain runs on the whole mix, and its output is **the mix**, the sound the mixer hands to the encoder. Samples past full scale in the mix are clipped where a file stores them as PCM ([FRAMES-13](../FRAMES-13/SPEC.md#mixing)). A `limiter` at `mix` 1, last in the outermost sequence's `audioFilter`, holds every sample of the mix at or under its `ceiling`, which is 0 or below ([Limiter](#limiter)), so nothing is left to clip.

Level after the sum equals level on each sound where a bus has no chain, since the sum, the pan law and a gain are linear and a gain on both channels commutes with the pan law. So a compound clip with no chain sounds as its sounds each at its level would, and with a chain its fade fades the processed sound, and a compressor in the chain does not undo the fade, as on a clip ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).

**State.** A bus's chain is one sound over its span, as a segment's audio filter is over its segment:

- The span of a compound clip's bus is where its sound is heard: the range its sound plays over ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)), its drawn range or its visible window with its edges moved by its `split`, in the outermost sequence's time, cut to the span of the bus that holds it and to the end of the sequence. The outermost bus spans the mix plan's length, the N samples from sequence time 0 ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)). A bus's samples are the samples k of the mix whose time k / 48000 lies in its span.
- Its ops start at rest at the first sample of its span, as a segment's do ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), read the bus's sum over its span and silence before it and past its end, and their output outside the span is not heard. A limiter there runs as [Limiter](#limiter) gives over a sound of the span's samples: its pre-roll reads silence, and over the last D samples of the span its look-ahead reads silence, so it turns the sound down there only for peaks inside the span.
- The chain runs in the outermost sequence's time, after the compound clip's retiming: a compound clip at `speed` 2 plays its sounds twice as fast with their pitch kept, and its chain's seconds (a `release`, a `lookahead`, a `hold`) are seconds of the outermost sequence.
- A looped compound clip is one bus over its whole span. Each repeat's sounds are segments of their own, at rest at the start of each repeat ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), and the chain runs on across the seams without starting again, since a sum has no media that jumps.

**Note.** A bus is content: its chain is part of what the sequence sounds like, as its clips' audio filters are, and `render` writes its file and a delivery file from the one mix ([FRAMES-21](../FRAMES-21/SPEC.md)).

**Note.** A compound clip's `pan` is added to its sounds before their sum, so the chain inside it reads the sound panned, and a compressor, a gate or a limiter there, which reads the louder of the two channels, acts on the panned sound.

### Limiter

`limiter` is an op of the audio filter table ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), taken by a clip's `audioFilter`, by an audio preset's `ops` and by a sequence's `audioFilter`. It raises a sound by `gain`, then turns it down wherever its true peak would pass `ceiling`, along a ramp `lookahead` seconds long that ends at the peak, and lets it back up by `release`, as an NLE's limiter does (Final Cut Pro's Limiter with Gain, Lookahead and Release, Premiere Pro's Hard Limiter with Input Boost).

| Parameter | Form | Default |
| --- | --- | --- |
| `gain` | dB, the input gain | 0 |
| `ceiling` | dBTP, 0 or less | -1, the maximum true peak of EBU R 128 |
| `lookahead` | seconds, from 0.0015 to 0.05, static | 0.005 |
| `release` | seconds, above 0 | 0.1 |

A parameter outside its range stops where it is written, and in a preset when it is read, as every op's does ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).

**The formula.** With Fs = 48000, a sound of N samples per channel, x_c[n] the op's input on channel c at sample n, n from 0 to N - 1, and a `gain`, `ceiling` or `release` that moves on a clip taken at each sample from its envelope ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)), holding its first or last value outside the sound:

1. **Gain.** x'_c[n] = 10^(`gain`[n] / 20) × x_c[n], with x'_c[n] = 0 for every n before 0 and from N on: the limiter reads silence before its sound starts and past its end.
2. **Interpolation.** On each channel, the four phases of the 48-tap interpolating filter of ITU-R BS.1770-5 Annex 2 ([Interpolating filter](#interpolating-filter)) give u_c,p[m] = Σ h_p[k] x'_c[m - k] over k from 0 to 11, for p from 0 to 3. The four values u_c,0[n + 6] to u_c,3[n + 6] are the sound oversampled 4 times between samples n and n + 1, at about n + 1/8, n + 3/8, n + 5/8 and n + 7/8.
3. **Detector.** P[n] is the largest of |x'_c[n]| and the eight values |u_c,p[n + 5]| and |u_c,p[n + 6]|, p from 0 to 3, over all its channels: the sample and the true peak of the two intervals beside it, linked across the channels as the compressor's level is ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), so it never moves a stereo image. Its level is L[n] = 20 log10(P[n]) in dBTP, and a silent P[n] of 0 is a level below every ceiling.
4. **Target.** c[n] = min(0, `ceiling`[n] - L[n]) in dB: the gain that brings P[n] to the ceiling, and 0 dB where it is already under it.
5. **Look-ahead.** With D = round(`lookahead` × Fs) samples, halves rounded up, from 72 to 2400, the hold h[n] = min of c[k] over k from n to n + D.
6. **Release.** r[n] = h[n] where h[n] ≤ r[n - 1], and r[n] = β r[n - 1] + (1 - β) h[n] where h[n] > r[n - 1], with β = exp(-1 / (`release`[n] × Fs)): the gain falls to its hold at once and rises back to it as the release smoothing of the compressor does ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).
7. **Smoothing.** g[n] = (r[n - D] + ... + r[n]) / (D + 1), the mean of r in dB over the D + 1 samples that end at n, so the gain falls along a ramp D samples long that ends at the peak.
8. **Output.** y_c[n] = x'_c[n] × 10^(g[n] / 20) on every channel, for n from 0 to N - 1.

The limiter runs from sample -D, D samples before its sound starts, with r[-D - 1] = 0 dB, so its first sample's gain is read over samples it has computed. At rest it has a gain of 0 dB and reads silence. Its output is aligned with its input, with no latency: it reads ahead in its input, which the mixer holds whole.

**What it holds.** Every k from n - D to n has n inside [k, k + D], so h[k] ≤ c[n], and r[k] ≤ h[k] at every k, so g[n] ≤ c[n] at every sample: the gain applied at n brings P[n], the input's sample at n and its interpolated values in the two intervals beside it, to the ceiling or under it. So every output sample y_c[n] is at or under the ceiling, |y_c[n]| ≤ 10^(`ceiling` / 20). An interpolated value of the output is a sum of 12 output samples, each times a tap of one phase, so it is at most the ceiling times the largest sum of the absolute taps of a phase ([Interpolating filter](#interpolating-filter)): 2.0228271484375 for h_1 and h_2, against 1.4342041015625 for h_0 and h_3, so the output's true peak is at most the ceiling plus 6.12 dB for every input. Where g holds over those 12 samples the value is the input's interpolated value times that gain, so it is at or under the ceiling.

**Note.** The `truePeak` of the output, which the meter reads from the output's own samples, passes the ceiling only where the gain moves within the filter's 12 taps, and how far it passes it is measured. At a `ceiling` of -1, a `lookahead` of 0.0015, 0.005 and 0.05 and a `release` of 0.000001, 0.1 and 1, the five signals of the limiter check of [FRAMES-24](../FRAMES-24/SPEC.md) read at most 0.019 dB over the ceiling, the noise bursts at a `lookahead` of 0.0015 and a `release` of 0.000001, and under 0.004 dB over it from a `lookahead` of 0.005. Other sounds (sines from 50 Hz to 0.45 of the sample rate, square waves, clicks, white noise and noise bursts up to 50 dB over full scale, and a dense mix 8 dB over full scale, at a `release` from 0.000001 to 1) read at most 0.025 dB over, on white noise 50 dB over full scale at a `lookahead` of 0.0015 and a `release` of 0.000001. Below a `lookahead` of 0.0015 the ramp is a few samples long and the gain moves inside the 12 taps: at one sample or none the output read up to 2 dB over the ceiling, so the range starts at 0.0015. A shorter `lookahead` also makes the ramp steeper and distorts low tones, and a shorter `release` lets the gain pump with the sound's waveform at low frequencies.

**Note.** The detector and frames' meter read a true peak at the same four points ([Loudness meter](#loudness-meter)). The four points of the Annex 2 filter can read a peak between them up to 0.55 dB low at 0.45 of the sample rate, as BS.1770-5 says of 4 times oversampling, and another meter interpolates otherwise: a limited mix read with a 16 times interpolator came out up to 0.23 dB above its ceiling, and the same mixes limited 0.25 dB lower read under the ceiling there.

**Note.** The limiter is defined by its formula, which is the contract: a running minimum of the target gain over the look-ahead window, then a mean over a window of the same length, so the gain meets each peak along a ramp and never after it.

**Keyframes.** On a clip the limiter's `gain`, `ceiling` and `release` and its entry's `mix` are timed leaves, as the other op parameters are ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)): a sampled `ceiling` above 0 is clamped to 0, and a sampled `release` at or below 0 follows its target at once. Its `lookahead` is static, part of the op's structure as a band's `type` is: it sets D, the one window the hold and the ramp share, so it holds one value over the op, and a keyframe that writes it, or writes a preset argument it reads, stops, naming the clip and the keyframe. The limiter has no identity, since it limits at every `gain` and `ceiling`, so it eases in or out by its entry's `mix`. Its state, r and its window, starts at rest wherever the segment's ops start at rest, where a clip's sound starts and on each repeat of a loop ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), and it reads silence past the end of its segment.

**Note.** Each repeat of a loop is its own segment, at rest at its start and reading silence before it and past its end, so a limiter on a looping clip sees a cut at each seam, even where the loop's end runs into its start with no break: where the sound is loud at the seam, its detector reads the step's interpolated values, and the gain can dip on both sides of it, over the D samples before the end of one repeat and over the first samples of the next, which read its pre-roll.

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

**Note.** BS.1770-5 gives this filter as one that satisfies its requirements, not as the only one, so two BS.1770 meters may read a true peak a little apart. frames fixes it, in the limiter and in the meter, so every mixer limits alike and the same samples measure alike.

### Loudness meter

The meter measures stereo sound at 48 kHz, two channels L and R, as the mixer gives it ([FRAMES-21](../FRAMES-21/SPEC.md)). It is a fixed formula of frames, not a role: it measures the samples the mixer gives. Its input is a whole sound, s_c[n] for n from 0 to N - 1, read as 0 before 0 and from N on, and a range of it, the samples n from a to b - 1 ([Measuring loudness](#measuring-loudness)). A range is an interval of the whole sound, not a sound cut out of it: every filter runs over the whole sound from its start, and each measure reads only the blocks, windows, samples and interpolated points that belong to the range.

**K-weighting.** Each channel passes through two biquads in turn, y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2], each at rest at sample 0 of the whole sound, its past samples 0, with the coefficients of BS.1770-5 at 48 kHz:

| Stage | b0 | b1 | b2 | a1 | a2 |
| --- | --- | --- | --- | --- | --- |
| 1, the shelf that models the head | 1.53512485958697 | -2.69169618940638 | 1.19839281085285 | -1.69065929318241 | 0.73248077421585 |
| 2, the high-pass | 1 | -2 | 1 | -1.99004745483398 | 0.99007225036621 |

**Loudness of a window.** For a window of W samples starting at sample w, z_c is the mean of y_c[n]² over n from w to w + W - 1 on channel c, and its loudness is l = -0.691 + 10 log10(z_L + z_R) in LUFS, each channel's weight 1 as BS.1770-5 gives left and right. A silent window, z_L + z_R = 0, has a loudness below every gate.

| Measure | Unit | Definition |
| --- | --- | --- |
| `integrated` | LUFS | BS.1770-5 gated loudness. The gating blocks are the windows of 19200 samples (400 ms) starting at a + 4800 j, for every whole j from 0 whose block ends inside the range, a + 4800 j + 19200 ≤ b (75% overlap). With l_j each block's loudness, J_a is the blocks with l_j > -70. The relative gate is Γ_r = -0.691 + 10 log10(the mean of z_L,j + z_R,j over J_a) - 10, and J_g is the blocks with l_j > -70 and l_j > Γ_r. The measure is -0.691 + 10 log10(the mean of z_L,j + z_R,j over J_g). `null` when J_a is empty |
| `range` | LU | EBU Tech 3342 loudness range. The short-term values s_k are the loudness of the windows of 144000 samples (3 s) starting at a + 4800 k, for every whole k from 0 whose window ends inside the range, a + 4800 k + 144000 ≤ b. S_a is the values with s_k ≥ -70, the gate Γ = 10 log10(the mean of 10^(s_k / 10) over S_a) - 20, and S_g the values of S_a with s_k ≥ Γ. With S_g sorted from lowest to highest as v_1 to v_m and Q(q) = v_i at i = round((m - 1) × q / 100 + 1), halves rounded up, the measure is Q(95) - Q(10). `null` when S_a is empty |
| `momentaryMax` | LUFS | the largest loudness of a window of 19200 samples (400 ms) starting at any sample w from a to b - 19200, ungated (EBU Tech 3341). `null` when the range is shorter than 19200 samples or every such window is silent |
| `shortTermMax` | LUFS | the largest loudness of a window of 144000 samples (3 s) starting at any sample w from a to b - 144000, ungated (EBU Tech 3341). `null` when the range is shorter than 144000 samples or every such window is silent |
| `truePeak` | dBTP | 20 log10 of the largest P[n] for n from a to b - 1, P computed from s as the limiter's detector computes it from x' ([Limiter](#limiter)): each sample of the range and the four interpolated values of each of the two intervals beside it, over both channels, read from the whole sound, so the interval before sample a and the one after sample b - 1 take the samples beside the range. It is the oversampled peak of BS.1770-5 Annex 2 together with the samples themselves, which the Annex's four points lie between and never land on, so `truePeak` is never below `samplePeak` and is the quantity the limiter's detector reads. `null` when every value it reads is 0 |
| `samplePeak` | dBFS | 20 log10 of the largest |s_c[n]| for n from a to b - 1 over both channels. `null` when every such sample is 0 |

- Each measure is written rounded to the nearest hundredth.
- A sine of 997 Hz at full scale on one channel reads -3.01 LUFS, as BS.1770-5 gives: the -0.691 cancels the K-weighting's gain at 997 Hz.
- The relative gate of `integrated` keeps at least one block whenever J_a has one, since one block of J_a is at least as loud as their mean, and the gate of `range` keeps at least one value whenever S_a has one.
- The interpolated points of the whole sound farther than one interval before its first sample or after its last, which the four phases also give, are each a sum over at most five taps of one phase, whose magnitudes add to less than 0.42, so none passes the sound's sample peak, and the `truePeak` of the whole sound is the oversampled peak of all of it.

**Note.** The windows of `momentaryMax` and `shortTermMax` start at every sample, as a file-based meter must for the Tech 3341 test of a 400 ms tone placed 20 ms at a time: a window that moved by 100 ms could miss the tone by up to 50 ms and read 0.6 LU low. The gating blocks and the short-term values of `range` keep the 100 ms step of BS.1770-5 and Tech 3342, which their definitions fix or allow.

**Note.** Tech 3342 asks a file-based meter to let 1.5 s of silence follow the sound before `range` is read. frames measures the range it is given and adds none, as `integrated` uses no incomplete block. So the ends of a range are read by fewer short-term windows than its middle: a sample in its middle lies in 30, a sample in its first 100 ms or in the last 100 ms of its last whole window lies in one, and the fewer than 4800 samples after its last whole window lie in none.

### Measuring loudness

`loudness` measures one sound with the meter and prints its measures as machine output ([FRAMES-23](../FRAMES-23/SPEC.md)).

- A document's sound is its mix ([Buses](#buses)): the document resolved and mixed, without rendering pictures, as `render` mixes it, with the same mixer, over the mix plan's length ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)), the outermost bus's output after its chain, before it is clipped where a file stores it as PCM and encoded. The sum before the chain is the mix of the same document without its `audioFilter`, which an extension measures by writing that document.
- A medium's sound is the sound the mixer plays for a clip of it at `volume` 1 and `pan` 0, with no `audioFilter`, from media time 0 at `speed` 1 ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)): read through the decoder, resampled to 48 kHz, a sound of more than two channels downmixed by ITU-R BS.775 ([FRAMES-21](../FRAMES-21/SPEC.md)), and a mono sound placed at the centre by the pan law. A medium's measures are a fact about a frames mix, the sound a clip of the file plays, and not about the file.
- The range is the samples n from a to b - 1 whose time n / 48000 lies in `[--from, --to)`: media time for a medium and sequence time for a document, from 0 and to the end of the sound when they are not written, the medium's sound or the mix plan's length. With `--from` or `--to` the meter reads the range as an interval of the whole sound ([Loudness meter](#loudness-meter)), so a limited mix measured over part of itself reads the same samples and interpolated points there as over the whole of it, and no false peak at the cut.

**Note.** A medium's measures equal a BS.1770-5 meter's reading of the file only for a stereo file at 48 kHz, and for a mono file at 48 kHz in its loudness: the pan law places a mono sound on each channel at cos(π/4), which keeps its power and reads its peaks 3.01 dB under the file's. A file at another rate is measured after the mixer resamples it to 48 kHz, by the mixer's own filter, which no formula of frames fixes, so two mixers can read it a little apart, its `truePeak` most. A medium of more than two channels is measured after the BS.775 downmix the mixer applies, so a 5.1 file reads otherwise than on a 5.1 BS.1770-5 meter, which weights its surrounds by 1.41 and adds the channels' powers.

**Note.** Measuring a range reads the sound from its start: the K-weighting and the interpolating filter run over every sample before the range, a document is mixed whole from sequence time 0, and a medium is read from media time 0, so a sample's K-weighted value and an interpolated point's value are the same in every range that holds them.

**Note.** A loudness target is an extension's, and its steps hold for any chain. To normalise a document to -23 LUFS it measures the document, adds -23 minus `integrated` to the `gain` of a `limiter` last in the sequence's `audioFilter` (adding one where there is none), measures again, and checks `integrated` and `truePeak`, adding what is left of the difference until `integrated` is within its tolerance ([FRAMES-25](../FRAMES-25/SPEC.md#extensions)). One step is exact only where nothing the gain reaches depends on level: the limiter turns more of the sound down the more it is raised, and a compressor or a gate after a gain changes its own gain with the level, so the loudness moves by less or more than the gain written, and the -70 LUFS gate of `integrated` takes in or leaves out blocks as the level moves. A clip is normalised by its `volume` the same way, measuring a document that holds that clip alone with its `audioFilter`, since `volume` applies after the clip's audio filter ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)).

## Interactions

The audio op table, its checks, keyframes and state at rest are [FRAMES-13](../FRAMES-13/SPEC.md), and the sequence key is in the key table of [FRAMES-7](../FRAMES-7/SPEC.md). The resolved sequence carries its chain ([FRAMES-19](../FRAMES-19/SPEC.md)), the mix plan carries its buses as a tree with each chain as `filter` beside its length ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)), and the mixer sums and runs them ([FRAMES-21](../FRAMES-21/SPEC.md)). The `loudness` command's usage, options and machine output are [FRAMES-23](../FRAMES-23/SPEC.md), the checks on buses and a limited mix are [FRAMES-24](../FRAMES-24/SPEC.md), and the extensions that normalise loudness are [FRAMES-25](../FRAMES-25/SPEC.md). Audio presets are [FRAMES-14](../FRAMES-14/SPEC.md).

## Alternatives considered

A loudness target as a key the mixer reaches in two passes, measuring and then setting the gain: an extension reaches it with the meter and the limiter's `gain`, a document then holds the gain it is mixed at, and none of Premiere Pro, Final Cut Pro, DaVinci Resolve and After Effects keeps a live loudness target on a timeline's mix.

Resolve measuring the mix and pinning a gain on it: resolve calls providers and never a role, and the mix is the mixer's output.

A platform limiter (AUPeakLimiter, Logic's Limiter): its algorithm is not published, and the formulas of the audio ops are the contract ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).

A ceiling in `format`: a limiter is an audio effect every NLE also puts on clips, so it belongs in the one op table.

`loudness` reporting the sum before the outermost chain beside the mix: the sum before it is the mix of the same document without its `audioFilter`, which an extension measures by writing that document, and one measurement of one sound gives a medium and a document the same output.

A sample-peak limiter: it misses the peaks between samples that AAC decoding and digital to analogue converters reproduce (BS.1770-5 Annex 2, Attachment 1).

A nested sequence's `audioFilter` ignored, as a compound clip's `colorSpace` is inside another sequence ([FRAMES-9](../FRAMES-9/SPEC.md)): `colorSpace` is how a sequence's output is encoded, and its chain is part of its sound, so ignoring it would change how the sequence sounds inside another.

A sequence's chain set for a delivery codec: the chain is part of the sequence's own sound, and the master and the delivery file are both encoded from the one mix ([FRAMES-21](../FRAMES-21/SPEC.md)). A limit for one delivery is another render of the document, a document an extension writes with its own `audioFilter`.

`audioFilter` on a sequence with no sound stopping, as on a clip that plays no sound: a template is checked once, before its arguments ([FRAMES-17](../FRAMES-17/SPEC.md)), and whether a template plays sound can depend on them, a `video` argument without a sound track, so the check could not be made there, and a chain on silence gives silence. A clip's `audioFilter` on a clip that plays no sound stops, a rule of the clip ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)).

A compound clip's `pan` after its bus, as a balance on the sum: a mono sound inside it is placed by the equal-power pan law and a stereo one by a balance ([FRAMES-13](../FRAMES-13/SPEC.md#level-and-position)), so a balance after the sum would change the sound of every compound clip that holds a mono sound and whose `pan` is not 0.

A compound clip's level before its bus, multiplied into each of its sounds' gains: a fade would then reach the chain before its ops, and a compressor or a limiter in it would undo the fade.

A looped compound clip's chain at rest at each repeat, as a clip's audio filter is: a clip's filter starts again because its media jumps there, and a bus's chain runs on the sum in the outermost sequence's time, where the repeats follow one another as one sound.

A `volume` key on the sequence: the `gain` of a `limiter` at `mix` 1 in its `audioFilter` raises or lowers the whole sum before it limits it, as Final Cut Pro's Limiter Gain and Premiere Pro's Input Boost do, and a compound clip's `volume` sets its bus's level in the sequence that holds it.

A separate `gain` op: it would add nothing over `volume` on clips and compound clips and a limiter's `gain` on a sequence.

A `lookahead` that takes keyframes: the hold and the ramp share its window, so a moving one would have the hold look as far ahead as the largest value the sound takes, and a value written at one time would move the gain before every peak of the sound.

The gain smoothed by a mean of linear gains: the compressor and the gate smooth their gain in dB ([FRAMES-13](../FRAMES-13/SPEC.md#audio-filters)), and the limiter's release and ramp do the same, so the three ops share one domain and either domain keeps the bound.

## Notes

**Note.** The mixer holds the whole mix in memory, and the buses' chains and the meter each pass over all of it: the limiter's interpolation costs 48 multiplications and additions per sample per channel, and the meter's `momentaryMax` and `shortTermMax` read a window at every sample, which running sums make one pass. An hour of stereo at 48 kHz in 32-bit floats is about 1.4 GB per copy of the mix.

**Note.** Lossy coding such as AAC can raise a true peak, so a delivery file can read above the limited mix it is encoded from. frames has not measured how far its own delivery AAC raises it.
