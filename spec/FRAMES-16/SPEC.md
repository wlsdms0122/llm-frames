# FRAMES-16: Presets that ship

Status: accepted

## Summary

The 47 presets that ship with frames as the pack `frames`, by name and look: 14 transitions, 13 animations, 14 filters and 6 heads.

## Motivation

Every NLE comes with a stock set of transitions, title animations and looks (a cross dissolve, a dip to colour, a push, a slide, a wipe, black and white), so an edit can be cut before any pack is installed. Templates and packs are timed to these names: a lower third that enters with `frames/rise` keeps its timing on every frames of the same major version only if the name, the look and the file stay the same. So the stock set is part of the contract.

## Rules

They are the pack `frames`, which ships with frames, so a document names them like any pack's presets: `frames/pop` ([FRAMES-17](../FRAMES-17/SPEC.md)). The tables give the names in the pack. The names, how each looks, and the preset files frames ships are the contract, so a template timed to `frames/pop` keeps its timing. Changing a shipped preset's numbers raises the major version ([FRAMES-18](../FRAMES-18/SPEC.md)). Seconds are the default length.

None of them publishes parameters, so each is named bare. `args` given to a transition, an animation or a filter stops as an unknown argument ([FRAMES-14](../FRAMES-14/SPEC.md)), and a head takes no arguments ([FRAMES-11](../FRAMES-11/SPEC.md#shapes)). Each description says how the preset looks and moves, never what it is for.

**transition (14)**

| Name | Looks like | Seconds |
| --- | --- | --- |
| `fade` | cross dissolve: the next clip fades in over the previous one at an even rate | 0.4 |
| `dip-black` | fades to black, holds a beat, then the next clip comes up out of it (black cover) | 0.7 |
| `flash` | a quick white flash, the clips changing at its peak, that fades off onto the next clip (white cover) | 0.3 |
| `push-left` | the next clip pushes the previous one out to the left, both moving as one strip | 0.45 |
| `push-up` | the next clip pushes the previous one up and out, both moving as one strip | 0.45 |
| `slide-left` | the next clip slides in from the right and covers the previous one, which stays still | 0.45 |
| `slide-right` | the next clip slides in from the left and covers the previous one, which stays still | 0.45 |
| `slide-up` | the next clip slides up from the bottom and covers the previous one, which stays still | 0.45 |
| `uncover-left` | the previous clip slides away to the left and uncovers the next one, which waits still beneath (`over: outgoing`) | 0.45 |
| `wipe-left` | a hard edge crosses from right to left and wipes the next clip in | 0.5 |
| `wipe-right` | a hard edge crosses from left to right and wipes the next clip in | 0.5 |
| `wipe-down` | a hard edge comes down from the top and wipes the next clip in | 0.5 |
| `zoom-in` | the next clip fades in large over the previous one and settles to size | 0.4 |
| `zoom-out` | the next clip fades in small over the previous one and grows to fill the frame | 0.4 |

Every transition but `fade`, `dip-black` and `flash` eases in and out. All of them crossfade the sound at constant power.

**animation (13)**

| Name | Looks like |
| --- | --- |
| `none` | appears and disappears at once, with no motion |
| `fade` | fades in and out |
| `pop` | starts small and pops to size with a slight overshoot, then shrinks a little as it fades out |
| `stamp` | starts large, speeds up and lands with a small give, then fades out |
| `zoom` | starts large and shrinks smoothly into place, then grows away as it fades out |
| `wipe` | wiped in from the left at an even pace, and wiped away to the right |
| `rise` | rises a little from below as it fades in, and drifts up as it fades out |
| `drop` | comes down from above and settles, and falls on down as it fades out |
| `slide-left` | slides in from the right by its own width, and leaves to the left |
| `bounce` | falls from above and bounces into place, then fades out |
| `pulse` | pops in, then swells and settles in a steady pulse until it ends |
| `blink` | blinks on and off until it ends |
| `shake` | lands large, shakes side to side, then trembles while it stays |

`none` ships as a file with no span, so `presets` lists `frames/none` with the others, and a clip given it simply shows. The choice `none` reads no file and shows the clip the same way.

**filter (14)**

| Name | Looks like |
| --- | --- |
| `mono` | black and white, every colour turned to its grey |
| `noir` | high-contrast black and white with deep blacks |
| `sepia` | an old brown photo, muted and faded |
| `warm` | warmer light, towards yellow |
| `cool` | cooler light, towards blue |
| `vivid` | stronger colour and a little more contrast |
| `faded` | washed-out film, with lifted blacks and muted colour |
| `bright` | half a stop brighter |
| `dark` | half a stop darker |
| `soft` | highlights glow softly |
| `sharpen` | crisper edges and fine detail |
| `blur` | evenly blurred |
| `vignette` | darker towards the edges and corners |
| `pixelate` | square blocks |

**head (6)**

The line endings Figma, Illustrator and PowerPoint share, named as Figma names them where it has a name, its line arrow, circle arrow and diamond arrow, with InDesign's solid square and bar. Each is given in units u of its stroke ([FRAMES-11](../FRAMES-11/SPEC.md#shapes)):

| Name | Looks like | Length | The line stops (`inset`) |
| --- | --- | --- | --- |
| `arrow` | a filled triangle 4u wide at its base, its tip at the end | 4u | at the middle of its base, 4u back from the tip |
| `line-arrow` | an open arrow, Figma's line arrow: the two sides of the `arrow` triangle, each a band u thick lying inside the triangle, meeting at the tip and cut along its base | 4u | where the bands' inner edges meet, √5 u back from the tip |
| `circle` | a filled circle 4u across, touching the end | 4u | at its centre, 2u back |
| `square` | a filled square 4u on a side, its front side across the end | 4u | at its centre, 2u back |
| `diamond` | a filled rhombus 4u long and 4u wide, its front corner at the end | 4u | at its centre, 2u back |
| `bar` | a filled bar 4u long across the stroke and u thick, its front side across the end | u | at its middle, u / 2 back |

Their outlines, in the head's own coordinates with the tip at the origin and the base at x = -`length`, are straight segments through these points, and the circle's four cubic segments:

| Name | `points` |
| --- | --- |
| `arrow` | `[-4, 2]`, `[0, 0]`, `[-4, -2]` |
| `line-arrow` | `[0, 0]`, `[-4, 2]`, `[-4, r]`, `[-√5, 0]`, `[-4, -r]`, `[-4, -2]`, with r = (4 - √5) / 2, where a band's inner edge, u inside its side, meets the base |
| `circle` | `[0, 0]`, `[-2, 2]`, `[-4, 0]`, `[-2, -2]`, each with its tangents k long along the circle, k = 4/3 × (√2 - 1) × 2 |
| `square` | `[0, 2]`, `[0, -2]`, `[-4, -2]`, `[-4, 2]` |
| `diamond` | `[0, 0]`, `[-2, -2]`, `[-4, 0]`, `[-2, 2]` |
| `bar` | `[0, 2]`, `[0, -2]`, `[-1, -2]`, `[-1, 2]` |

**Note.** A circle has no exact form in cubic Bézier segments. Four segments whose tangents are 4/3 × (√2 - 1) of the radius long, the circle Core Graphics and Skia draw for an ellipse, lie at most 0.027% of the radius off it, under 6e-4 of a pixel for a head 4 pixels across, and pass through it at the four vertices.

frames ships no audio preset. Audio filters are written in place or come from packs ([FRAMES-13](../FRAMES-13/SPEC.md)).

## Interactions

Their format is [FRAMES-14](../FRAMES-14/SPEC.md) and [FRAMES-15](../FRAMES-15/SPEC.md), and for the heads [FRAMES-11](../FRAMES-11/SPEC.md#shapes). Changing their numbers is a major change ([FRAMES-18](../FRAMES-18/SPEC.md)). The base theme names none of them as a default ([FRAMES-22](../FRAMES-22/SPEC.md)). Which to use for a kind of result is a guide's judgement ([FRAMES-25](../FRAMES-25/SPEC.md)).

## Alternatives considered

Shipping no presets: every pack would carry its own cross dissolve, and two packs' fades would differ. Presets made for one purpose, such as one that traces one kind of shape's outline in: a purpose is not frames's to ship (Capabilities, not purposes, in the [README](../README.md#principles)), and a shape's `trim` keyframes draw any stroke on ([FRAMES-11](../FRAMES-11/SPEC.md)). Descriptions that say when to use a preset: when to use one is a guide's judgement and differs by result, while how it looks is the same everywhere.

An open arrow stroked as a polyline, two lines with the stroke's join at the tip: a miter would reach √5 / 2 stroke widths past the end of the outline and a round join would round the tip. Bands lying inside the triangle keep the tip at the end.

## Notes
