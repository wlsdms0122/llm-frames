# FRAMES-8: Time

Status: draft

## Summary

The three clocks of a sequence (clip, sequence and media time), which clock each instant is on, how storyline clips are laid end to end, and the ranges, windows and transitions on them.

## Motivation

Most editing mistakes are time mistakes. Putting a connected clip's instants on its storyline clip's clock lets an agent take times straight from frames it extracted, and trimming an earlier clip never moves anything connected to a later one.

## Rules

Three clocks meet on a sequence. **Clip time** is the time inside one storyline clip. **Sequence time** is the time of the output. **Media time** ([FRAMES-1](../FRAMES-1/SPEC.md)) is the clock of a media file itself.

**Instants are on the clock of what they belong to: a storyline clip, or the sequence. Durations are sequence seconds.**

| Instant | Clock |
| --- | --- |
| a storyline clip's own `keyframes` | that clip's clip time |
| a connected clip's `at` and `keyframes` | its storyline clip's clip time |
| a sequence clip's `at` and `keyframes` | sequence time |
| `in` and `out` of any media clip | that media's media time |

Durations (a media clip's natural length, `duration`, transition and animation `seconds`, loop `period`, `fadeIn`, `fadeOut`) are always sequence seconds. A sound connected to a clip at speed 2 plays its full length at its own speed, and an entrance takes the same time on every clip.

Clip time is the media time of a video, image sequence or compound clip, and the seconds since the clip started for a still or solid clip. It lets an agent take times straight from frames it extracted from a recording, and a connected clip's keyframes say where things are in its storyline clip's media. Trimming or speeding up an earlier clip does not move anything connected to a later one. A clip's `at` and keyframes are on one clock, so moving a clip in time moves both.

A storyline clip starts at `start` on the sequence clock and lasts `duration`:

```
timed media clip:       duration = (out - in) / speed
still or solid clip:    duration = duration key

clip time t to sequence time:
  timed media clip:       start + (t - in) / speed
  still or solid clip:    start + t
```

The map is the same line outside the clip, so a keyframe before `in` keeps its time and its ease, and the handles below play on it.

- `in` and `out` are edit points. The first storyline clip starts at 0, each next clip starts where the previous one ends, and the sequence ends where the last one ends. A transition does not change the length of the sequence.
- The first storyline clip has no transition: one written on it stops, and the default does not apply. To open from black or end on it, put a solid clip there and give the clip after it a transition.
- A transition belongs to the clip it brings in and is centred on their edit point. It lasts `min(transition seconds, previous duration, next duration)`. During it the outgoing clip plays on past its `out`, and the incoming clip starts before its `in`, on the media beyond them (the handles). Where the media runs out, its first or last frame holds, and a still or solid clip simply goes on. Evaluation clamps to the media's first and last frame before it writes a frame, so a decoder is only asked for frames that exist.
- A storyline clip has two ranges on the sequence clock. Its **edit range** is `[start, end)`, between its edit points. Its **drawn range** runs from the start of its incoming transition to the end of its outgoing one.
- Every range and window holds its start and not its end, so a frame at an edit point belongs to the clip that starts there.
- `at` is `[start, end]` or a single start. A window's start and end are both instants. A single start is an instant followed by a duration, the clip's natural length `(out - in) / speed` for video, audio, image sequence and compound media. Under a storyline clip whose speed is not 1 the two forms differ: `[2, 6]` ends at clip second 6, and `2` ends when the media does. When titles, shapes, adjustments and still images take `at`, it is `[start, end]`. A connected clip without `at` spans its storyline clip's drawn range when it is parented and its edit range otherwise, and a sequence clip without `at` spans the whole sequence. A parented clip whose window starts at the clip's `in` starts at the edit point, inside the transition, so one meant for the whole picture leaves out `at`. A parented clip without `at` takes no entrance and no exit, since it comes and goes with its picture.
- A media clip plays from `in` at its own `speed` (default 1), whatever the speed of its storyline clip. When its window is longer than the media, video holds its last frame and audio goes silent, unless `loop` is true, in which case it repeats from `in` to `out` to fill the window.
- An unparented connected clip is attached by its start, as in an NLE, and plays its whole window across edit points and transitions, over whatever is below it. Only the end of the sequence cuts it.
- A parented connected clip ([FRAMES-10](../FRAMES-10/SPEC.md)) is visible where its window meets its storyline clip's drawn range. It is composited with its picture, so a transition covers, wipes or moves it exactly as it does its picture.
- A connected clip with a picture whose window does not meet the range it is visible in stops ("never visible").
- A connected audio clip is only anchored by its start. It plays its window, or its natural length, across transitions. One whose start lies outside its storyline clip's drawn range stops.
- Sequence clips are cut at the end of the sequence. One that starts at or after the end stops.

## Interactions

Keyframes are [FRAMES-4](../FRAMES-4/SPEC.md). Windows are narrowed by tracking ([FRAMES-12](../FRAMES-12/SPEC.md)). The resolved document writes every instant in sequence time ([FRAMES-19](../FRAMES-19/SPEC.md)).

## Alternatives considered

Clip-relative keyframes, as an NLE keeps them: a connected clip's keyframes say where things are in the recording, so they stay on its clock. Separate keys for an instant and a window: the form already says which. Retime (reverse, hold, ramps): the time map is a straight line, which is what lets clip time be media time.

## Notes
