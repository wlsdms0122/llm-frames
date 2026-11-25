# FRAMES-8: Time

Status: accepted

## Summary

The three clocks of a sequence (clip, sequence and media time), which clock each instant is on, how storyline clips are laid end to end, time remapping from clip time to media time, and the ranges, windows and transitions on them.

## Motivation

Most editing mistakes are time mistakes. A title placed on the moment a speaker appears, a zoom keyed to a gesture, a sound effect on a door closing: each is placed on the content of one clip. Keeping a clip's keyframes and its connected clips on that clip's own timeline means trimming it, or any clip before it, never slides them off the content they were placed on. Freeze frames, reverse and speed ramps are everyday NLE tools, and writing them as one keyframable map from clip time to media time, as After Effects' Time Remap does, gives them the keyframes and eases every other property already has.

## Rules

Three clocks meet on a sequence. **Clip time** is a storyline clip's own timeline. **Sequence time** is the time of the output. **Media time** ([FRAMES-1](../FRAMES-1/SPEC.md)) is the clock of a media file itself.

**Instants are on the clock of what they belong to: a storyline clip, or the sequence. Durations are sequence seconds.**

| Instant | Clock |
| --- | --- |
| a storyline clip's own `keyframes` | that clip's clip time |
| a connected clip's `at` and `keyframes` | its storyline clip's clip time |
| a sequence clip's `at` and `keyframes` | sequence time |
| a sequence's own `keyframes` | that sequence's sequence time |
| `in` and `out` of a storyline clip | that clip's clip time |
| `in` and `out` of a connected or sequence media clip | that clip's media time |

Durations (a media clip's natural length, `duration`, transition and animation `seconds`, loop `period`, `fadeIn`, `fadeOut`) are always sequence seconds. A sound connected to a clip at speed 2 plays its full length at its own speed, and an entrance takes the same time on every clip.

### Clip time and media time

A video, image sequence or compound storyline clip shows, at clip time c, its media at media time `timeRemap(c)`. `timeRemap` is the identity unless the clip writes `timeRemap` keyframes, so without remapping clip time is media time: trimming `in` moves nothing connected, and a time read from a frame of the media (with `extract`, `sheet` or `ocr`) is a clip time. A still or solid clip's clip time is the seconds since the clip started.

`timeRemap` is a keyframable property of timed media clips (video, image sequence and compound media, on the storyline or as connected and sequence media clips), as After Effects' Time Remap. Its value is the media time shown at the instant of its keyframe, in media seconds, and its keyframes are on the clock of the clip's other keyframes (the table above).

- Its keyframes interpolate with their eases ([FRAMES-4](../FRAMES-4/SPEC.md)). Two keys with the same value hold a frame, values that decrease play backwards, and eased keys give speed ramps.
- Before its first key and after its last it holds their values, so one key is a freeze frame.
- It is written only in keyframes. A static `timeRemap` stops.
- A clip with `timeRemap` takes no `speed`: both on one clip stop. It plays no sound ([FRAMES-13](../FRAMES-13/SPEC.md)).
- A media time it gives outside the media is clamped to the media's first or last frame, as every media time is before a frame is drawn.

**Note.** Sound for a remapped shot is placed as an audio clip of its own, cut to the picture as the edit needs.

### Storyline clips on the sequence clock

A storyline clip starts at `start` on the sequence clock and lasts `duration`:

```
timed media clip:       duration = (out - in) / speed
still or solid clip:    duration = duration key

clip time c to sequence time:
  timed media clip:       start + (c - in) / speed
  still or solid clip:    start + c

media time at clip time c (timed media clip):
  timeRemap(c), and c without timeRemap
```

`speed` is 1 on a clip with `timeRemap`. The map is the same line outside the clip, so a keyframe before `in` keeps its time and its ease, and the handles below play on it. Outside the clip the clip-time line continues, and its media time is `timeRemap` held at its edge values, then clamped to the media.

- `in` and `out` are edit points on clip time. The first storyline clip starts at 0, each next clip starts where the previous one ends, and the sequence ends where the last one ends. A transition does not change the length of the sequence.
- The first storyline clip has no transition: one written on it stops, and the default does not apply. To open from black or end on it, put a solid clip there and give the clip after it a transition.
- A transition belongs to the clip it brings in and is centred on their edit point, so its progress is that clip's value, which that clip's motion blur moves ([FRAMES-29](../FRAMES-29/SPEC.md)). It lasts `min(transition seconds, previous duration, next duration)`. During it the outgoing clip plays on past its `out`, and the incoming clip starts before its `in`, on the clip time beyond them (the handles). Where the media runs out, its first or last frame holds, and a still or solid clip simply goes on. Evaluation clamps to the media's first and last frame before it writes a frame, so a decoder is only asked for frames that exist.
- A storyline clip has two ranges on the sequence clock. Its **edit range** is `[start, end)`, between its edit points. Its **drawn range** runs from the start of its incoming transition to the end of its outgoing one.
- Every range and window holds its start and not its end, so a frame at an edit point belongs to the clip that starts there.

### Windows

- `at` is `[start, end]` or a single start. A window's start and end are both instants. A single start is an instant followed by a duration, the clip's natural length `(out - in) / speed` for video, audio, image sequence and compound media. Under a storyline clip whose speed is not 1 the two forms differ: `[2, 6]` ends at clip second 6, and `2` ends when the media does. When titles, shapes, adjustments and stills take `at`, it is `[start, end]`.
- A connected or sequence media clip with `timeRemap` takes `at` as `[start, end]`, and takes no `in`, `out` or `loop`: its `timeRemap` keys give the media time at every instant of its window, so any of them stops. Without `at` it takes the default window below, which is a `[start, end]` window; a single start stops, since a remapped clip has no natural length.
- A connected clip without `at` spans its storyline clip's edit range, and a sequence clip without `at` spans the whole sequence.
- A media clip plays from `in` at its own `speed` (default 1), whatever the speed of its storyline clip: at sequence time s in a window that starts at sequence time s0, its media time is `in + (s - s0) × speed`. When its window is longer than the media, video holds its last frame and audio goes silent, unless `loop` is true, in which case it repeats from `in` to `out` to fill the window.
- A connected clip is attached by its start, as in an NLE, and plays its whole window across edit points and transitions, over or under whatever its lane puts it with ([FRAMES-9](../FRAMES-9/SPEC.md)). Its parent ([FRAMES-10](../FRAMES-10/SPEC.md)) moves it and does not change its window.
- Connected and sequence clips are cut to the sequence, from 0 to its end. A clip with a picture that has nothing left stops ("never visible"), and so does a sound, since it would never play.
- A connected audio clip is only anchored by its start. It plays its window, or its natural length, across transitions. One whose start lies outside its storyline clip's drawn range stops.
- A window `[start, end]` needs its start before its end. One that does not stops.

### The time map at every instant

A clip's **time map** takes sequence time to the media time the clip shows: a storyline clip's through its clip time, and a connected or sequence media clip's through its window. **A time map is defined at every sequence time, inside the clip's window and outside it**, since the instants that read it lie anywhere: a clip's own keyframes, a keyframe before `in` or past `out`, and the instant of a clip parented to it ([A clip's instant](#a-clips-instant)), which need not lie in its window.

- A storyline clip's clip time is its line at every sequence time, and its media time `timeRemap` of that clip time, held at its edge values, or that clip time without `timeRemap` ([above](#storyline-clips-on-the-sequence-clock)).
- A connected or sequence media clip's media time is `in + (s - s0) × speed` at every sequence time s, before its window's start s0 as well, where it lies before `in`. Past `out` it repeats from `in` when `loop` is true and holds the last frame before `out` otherwise, after the window's end as within it. With `timeRemap` it is the keys' value at s, held at their edge values.
- Every media time is clamped to the media's first and last frame, a nested sequence's `[0, duration)`, before a frame is picked. A still and a page show their one picture at every instant, at media time 0, and a solid, a title, a shape and an adjustment clip have no media time.
- A connected clip has no clip time of its own: its instants are on its storyline clip's clip time.
- `timeline --at` reports the clip time and the media time of the frame shown at any sequence time ([FRAMES-23](../FRAMES-23/SPEC.md)), so a program reads a frame a clip shows where the clip draws nothing and computes no time map itself.

### A clip's instant

A clip's **instant** is where a value it writes without keyframes takes effect: a connected or sequence clip's start (a connected clip without `at` starts at its storyline clip's `in`, a sequence clip without `at` at 0), and a storyline clip's `in`. It is on the clip's own clock. The frame of a media that the instant shows is found by carrying the instant to the clip time of the clip whose media it is, and turning that into media time through that clip's time map: its `timeRemap` when it has one, otherwise clip time is media time. So a clip parented to a time-remapped clip shows, at its instant, the frame its parent shows at that clip's start. A tracked clip's short forms find their target on that frame ([FRAMES-12](../FRAMES-12/SPEC.md#the-track)).

## Interactions

Keyframes and eases are [FRAMES-4](../FRAMES-4/SPEC.md). A media time picks a frame as [FRAMES-3](../FRAMES-3/SPEC.md) says. Windows are narrowed by tracking ([FRAMES-12](../FRAMES-12/SPEC.md)). Sound under these clocks is [FRAMES-13](../FRAMES-13/SPEC.md). The resolved document writes every instant in sequence time ([FRAMES-19](../FRAMES-19/SPEC.md)).

## Alternatives considered

Keyframes and connected clips on the sequence clock: trimming a clip, or one before it, would slide them off the content they were placed on. Separate keys for an instant and a window: the form already says which. Retiming as speed segments, as a retime editor shows them: one keyframable map from clip time to media time gives holds, reverse and ramps with the eases keyframes already have, and leaves clip time equal to media time wherever it is not written. Pitch-corrected sound under remapping: a hold or a reverse has no sound worth keeping, and a sound placed as its own clip is cut as the edit needs.

A connected or sequence clip's time map defined on its window alone, with no media time outside it: resolve and evaluation read it outside the window wherever a clip parented to it takes effect or a keyframe of a clip tracked in its media lies there, so a map cut at the window would leave those values on a frame that no rule names.

## Notes
