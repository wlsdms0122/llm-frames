# FRAMES-16: Presets that ship

Status: draft

## Summary

The 42 presets that ship with frames, by name and look.

## Motivation

Templates and forms are timed to these names, so their names, looks and files are part of the contract.

## Rules

The names, how each looks, and the preset files frames ships are the contract, so a template timed to `pop` keeps its timing. Changing a shipped preset's numbers raises the major version ([FRAMES-18](../FRAMES-18/SPEC.md)). Seconds are the default length.

**transition (14)**

| Name | Looks like | Seconds |
| --- | --- | --- |
| `fade` | cross dissolve, the next clip fades in | 0.4 |
| `dip-black` | fades to black, then the next clip comes up (a big scene change, black cover) | 0.7 |
| `flash` | a white flash (a result or a reveal, white cover) | 0.3 |
| `push-left` | the next clip pushes the previous one out to the left | 0.45 |
| `push-up` | the next clip pushes the previous one up (vertical video) | 0.45 |
| `slide-left` | the next clip slides in from the right and covers | 0.45 |
| `slide-right` | the next clip slides in from the left | 0.45 |
| `slide-up` | the next clip slides up from the bottom and covers | 0.45 |
| `uncover-left` | the previous clip leaves to the left and uncovers the next (`over: outgoing`) | 0.45 |
| `wipe-left` | the next clip is wiped in from the right | 0.5 |
| `wipe-right` | the next clip is wiped in from the left | 0.5 |
| `wipe-down` | the next clip is wiped in from the top | 0.5 |
| `zoom-in` | the next clip starts large and settles | 0.4 |
| `zoom-out` | the next clip starts small and grows | 0.4 |

**animation (14)**

| Name | Looks like |
| --- | --- |
| `none` | appears and disappears |
| `fade` | fades in and out |
| `pop` | starts small and pops to size |
| `stamp` | starts large and lands like a stamp |
| `zoom` | starts large and shrinks into place |
| `draw` | drawn in with reveal |
| `wipe` | wiped in from the left, as if written |
| `rise` | rises a little from below |
| `drop` | comes down from above |
| `slide-left` | slides in from the right and leaves to the left |
| `bounce` | bounces into place |
| `pulse` | pops, then pulses until it ends. An arrow jabs with nudge |
| `blink` | blinks |
| `shake` | lands large, shakes side to side, then trembles while it stays |

**filter (14)**

| Name | Looks like |
| --- | --- |
| `mono` | black and white |
| `noir` | high-contrast black and white |
| `sepia` | old brown photo |
| `warm` | warmer, towards yellow |
| `cool` | cooler, towards blue |
| `vivid` | stronger colour |
| `faded` | washed-out film |
| `bright` | one step brighter |
| `dark` | one step darker |
| `soft` | highlights glow softly |
| `sharpen` | crisper text edges |
| `blur` | blurred |
| `vignette` | darker edges that pull the eye to the centre |
| `pixelate` | square blocks, as a look |

## Interactions

Their format is [FRAMES-14](../FRAMES-14/SPEC.md) and [FRAMES-15](../FRAMES-15/SPEC.md). Changing their numbers is a major change ([FRAMES-18](../FRAMES-18/SPEC.md)).

## Alternatives considered


## Notes
