# FRAMES-30: Memory limit

Status: draft

## Summary

A limit on the memory one run of frames holds, set with the global option `--memory` and by default half of the machine's memory, as DaVinci Resolve limits its own memory and After Effects and Premiere Pro keep memory for other programs. The limit is one budget for the run, which the holders of large memory it counts draw from: the decoder's readers, the frames it reads ahead and those its turns hold, and the frames the encoder holds, which hold less where the budget is short, and the media pictures the renderer keeps and the mixed sound, which the document fixes. A limit under what the run cannot work without is refused before the first frame. The limit changes how long a run takes and never its frames, and the run report gives what the budget saw.

## Motivation

A render that shows many videos at once holds memory in two places: frames's process, and the decoding service the platform runs for it, which holds each reader's decoded frames outside the process. Without a limit, a render of 24 videos of 1206 by 2622 pixels read as half floats drove a machine of 16 GB of memory to swap 9 GB a render ([FRAMES-21](../FRAMES-21/SPEC.md#notes)), and the user had no way to say how much frames may hold beside the other programs they run. A bound fixed by the decoder at a fraction of the machine's memory covers only its readers, is no one's choice, and is never seen in a report. Editing programs give the user this setting: DaVinci Resolve a limit on its own memory, After Effects and Premiere Pro the memory left for other programs.

## Rules

### The option

`--memory <size>` is a global option ([FRAMES-23](../FRAMES-23/SPEC.md#rules)), written before the command word as the role options are, so a pack's tool is given it with the others ([FRAMES-25](../FRAMES-25/SPEC.md#tools)). It sets the limit of every run that command makes.

```
size   = number unit
number = digit+ [ "." digit+ ]
unit   = "MB" | "GB"
```

`MB` is 2^20 bytes and `GB` 2^30 bytes, the units the system states a machine's memory in. A size is written with no space, its unit in capitals, and is at least 1 MB: `6GB`, `1.5GB`, `512MB`. Its bytes are the number times the unit, rounded down to a whole byte. A size that is not of this form, or under 1 MB, stops naming `--memory`. A size above the machine's memory is the limit as written.

Without `--memory` the limit is half of the machine's physical memory, rounded down to a whole MB ([Notes](#notes)).

### The budget

A run's limit is one budget, which each holder of large memory the run counts draws from. A holder has a floor, the least it holds for the run to work, and holds its floor or more. The budget counts each holder at the larger of its floor and what it holds, and the run's total is the sum over the holders. A holder that gives way, one the table names a way to hold less, is granted more than its floor only where the total stays within the limit. A holder that does not give way is granted all it holds whatever the total, and the holders that give way find that much less room. Holding less is always granted.

| Holder | What it holds | Floor | Where the budget is short |
| --- | --- | --- | --- |
| `readers` | the memory the decoding service holds for each reader the decoder keeps open on a video, by the decoder's cost of that reader ([FRAMES-21](../FRAMES-21/SPEC.md#rules)) | one reader of the costliest video the run reads | the decoder closes readers, and a video whose reader it closed takes turns |
| `readAhead` | each frame the decoder reads ahead and has not yet given, a picture of the video's displayed size at 8 bytes a pixel | none | the decoder reads the frame where it is asked, not ahead |
| `turns` | the decoded frames a turn holds for later asks ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), each at the bytes of the buffer the decoder is given it in | none | the turn holds fewer frames, and the video takes its next turn sooner |
| `pictures` | the media pictures the renderer keeps, those of the frame drawn last and those the frame being drawn has read ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)), each at the bytes the decoder gives it in | for `sheet`, every cell that shows a picture, of the frames' size at 4 bytes a pixel; none for any other command | does not give way |
| `frames` | the output frames in flight, each of the sequence's size at 8 bytes a pixel: for a video the frame being drawn, the frame the encoder writes, and a second the encoder holds behind it while that one is written, and for a PNG the one frame | for a video two frames, and for a PNG the one frame | the render waits for the frame being written before it hands the encoder the next |
| `sound` | the run's mixed sound: two channels of 32-bit samples at 48 kHz over the mix plan's length ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)) | all of it | does not give way |

The run's floor is the sum of the holders' floors. `render` knows its floor once it has checked every pinned medium and made the mix plan, and refuses a limit under it in `check`, before the first frame, naming the limit as it is written, or as the default's whole GB or MB, and the floor and each holder's in the table's order: `memory limit 1.5GB is under the 2 GB this run needs: readers 1.2 GB, readAhead 0 MB, turns 0 MB, pictures 0 MB, frames 768 MB, sound 51.2 MB`, a size of 1 GB or more in GB to two places and a smaller one in MB to one place, with no trailing zeros. A command that reads a video without a document to check (`ocr`, `track`, `extract`, `sheet`, `probe`, `transcode` of a video) raises the `readers` floor to a video's reader as it opens its first, and refuses there in the same words before that video's first frame is decoded. `sheet` gives the budget its `pictures` floor once it has checked every list it draws, and refuses a limit under the run's floor there, in the same words, before a cell's picture is read.

The decoder keeps its count of open readers ([FRAMES-21](../FRAMES-21/SPEC.md#rules)) as a rule of its own, which closes readers whatever the budget holds.

### What it counts

The budget counts what frames itself holds of the frames in flight, the frames read ahead, the frames turns hold, the media pictures the renderer keeps and the mixed sound, by their sizes, and what the decoding service holds outside the process by a model, the decoder's cost of a reader, whose constants are the most measured on the reference machine ([FRAMES-21](../FRAMES-21/SPEC.md#notes)). The model errs high for the videos measured. The rest of what a run holds lies outside the limit: the renderer's working memory (its layers, masks, nested rasters and motion blur's sums), the memory a reader holds in the process, the encoder's own buffers and a provider's pictures. So the memory a run holds is more than the budget counts by those.

### Frames are the same at any limit

A run gives the same frames at every limit at or above its floor. A reader closed for room makes the video's next read a turn, which decodes the frames it gives as a reader opened at them does, a frame not read ahead is read where it is asked by the same read, a frame a turn does not hold is read where it is asked, from the reader left open or from a reader opened at it, which decode it alike ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), and a frame the encoder takes after the one before is written is the same frame. The limit changes how long the run takes.

### Report

The run report's `memory` gives the limit and what the budget saw ([FRAMES-23](../FRAMES-23/SPEC.md#runs)):

| Field | Value |
| --- | --- |
| `limit` | the limit in bytes |
| `floor` | the run's floor in bytes |
| `peak` | the largest total the budget counted at once, in bytes |
| `holders` | one object for each holder of the table above, in its order, keyed by its name: `{floor, peak, refused}` |

A holder's `floor` and `peak` are bytes, its `peak` the most the budget counted it at, and `refused` the times the budget refused it more: for `readers` the readers the decoder closed for room, each of which makes a turn when its video is read again, for `readAhead` the frames the decoder read where they were asked for want of room, for `turns` the turns that held fewer frames for want of room, and for `frames` the frames the render handed the encoder only once the frame before was written, for want of room. A holder that only holds its floor has `refused` 0.

## Interactions

The decoder's readers, their cost, turns and reading ahead are [FRAMES-21](../FRAMES-21/SPEC.md#rules), which takes its room for readers and frames read ahead from this budget. The global options and the run report are [FRAMES-23](../FRAMES-23/SPEC.md). The mix plan is [FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan). Stages and what a run reports are [FRAMES-23](../FRAMES-23/SPEC.md#runs).

## Alternatives considered

A limit written as a fraction of the machine's memory (`--memory 0.5`), as the default is: the same command line would hold another amount on another machine, while a user who sets the limit sizes room beside programs whose needs they know in bytes, so the written form is a size and the fraction is the default's rule alone.

A limit written as the memory left for other programs, as After Effects and Premiere Pro take it: frames cannot see what other programs hold, so the bound it would keep is the machine's memory less that amount, a size the user can write.

An environment variable or a configuration file for the limit: frames takes every setting of a whole run as a global option, and `FRAMES_HOME` says only where packs are installed, so a second way would be two places to look for one setting.

A bound on the decoder's readers alone, at a fixed quarter of the machine's memory: it left the frames read ahead and the frames in flight uncounted, no one chose it, and a user could not move it. Measured on the reference machine it never closed a reader in a real render: 32 videos of 1206 by 2622 pixels cost 4.25 GB against a bound of 4.29 GB ([FRAMES-21](../FRAMES-21/SPEC.md#notes)).

Counting the decoding service by what the system reports it holds, read while the run goes: the service serves every process that decodes, its footprint moves after a reader opens and not when, and a run that read it would make its turns depend on other programs, so the same document would take different turns on two runs.

## Notes
