# FRAMES-30: Memory limit

Status: accepted

## Summary

A limit on the memory one run of frames holds by its own count, a budget, set with the global option `--memory` and by default three eighths of the machine's memory, as DaVinci Resolve limits its own memory and After Effects and Premiere Pro keep memory for other programs. The limit is one budget for the run, which the holders it counts draw from: the decoder's readers, the frames it reads ahead and those its turns hold, and the frame a render's encoder holds behind the one it writes, which hold less where the budget is short, and the media pictures the renderer keeps, the output frames each command draws, reads or writes, and the mixed sound, which the document and the command fix. The budget counts what frames holds of frames, pictures and sound by their sizes, and charges each reader open on a video a number of that video's frames, a charge frames sets. Nothing in it is measured. What the budget counts never passes the limit, so a lower limit holds a run to less of it: fewer readers open, fewer frames read ahead and held in turns. The limit is not a bound on what a run really uses: the run holds memory the budget does not count, and the decoding service holds for a reader what it holds, not the reader's cost. A limit under what the run cannot work without is refused before the first frame. The limit changes how long a run takes and never its frames, and the run report gives what the budget counted.

## Motivation

A render that shows many videos at once holds memory in two places: frames's process, and the decoding service the platform runs for it, which holds each reader's decoded frames outside the process. Without a limit, a render of a few dozen high resolution videos read as half floats can hold more than a machine of 16 GB of memory has, and the machine then swaps through the render, while the user has no way to say how much frames may hold beside the other programs they run. A bound fixed by the decoder at a fraction of the machine's memory covers only its readers, is no one's choice, and is never seen in a report. Editing programs give the user this setting: DaVinci Resolve a limit on its own memory, After Effects and Premiere Pro the memory left for other programs.

## Rules

### The option

`--memory <size>` is a global option ([FRAMES-23](../FRAMES-23/SPEC.md#rules)), written before the command word as the role options are, so a pack's tool is given it with the others ([FRAMES-25](../FRAMES-25/SPEC.md#tools)). It sets the limit of every run that command makes.

```
size   = number unit
number = digit+ [ "." digit+ ]
unit   = "MB" | "GB"
```

`MB` is 2^20 bytes and `GB` 2^30 bytes, the units the system states a machine's memory in. A size is written with no space, its unit in capitals, and is at least 1 MB: `6GB`, `1.5GB`, `512MB`. Its bytes are the number times the unit, rounded down to a whole byte. A size that is not of this form, or under 1 MB, stops naming `--memory`. A size above the machine's memory is the limit as written.

Without `--memory` the limit is three eighths of the machine's physical memory, rounded down to a whole MB.

**Note.** Three eighths is a choice of frames whose basis is a measurement on the reference machine, an Apple M1 Pro of 16 GB with macOS 27.2, with a working day's programs open: a render of 16 videos of ProRes 4444 of 1206 by 2622 pixels read as half floats at three eighths, 6 GB, left 23 % of the memory free at its lowest and swapped nothing, and the same render at half, 8 GB, under a build whose budget granted the renderer's pictures whatever the total, began to swap 6 seconds in. On another machine, beside other programs or with other media, the same share can leave more or less free, all the more since what a run really uses can lie above the limit ([What it counts](#what-it-counts)).

### The budget

A run's limit is one budget, which each holder of large memory the run counts draws from. A holder has a floor, the least it holds for the run to work, and holds its floor or more. The budget counts each holder at the larger of its floor and what it holds, and the run's total is the sum over the holders. A holder that gives way, one the table names a way to hold less, is granted more than its floor only where the total and the grant stay within the limit. A holder that does not give way holds at most its floor. Holding less is always granted. So the total never passes the limit once the run's floor is within it.

| Holder | What it holds | Floor | Where the budget is short |
| --- | --- | --- | --- |
| `readers` | each reader the decoder keeps open, one for each play of a video the frame drawn last or the frame being drawn shows, or a command reads on its own ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), at the decoder's cost of that reader | one reader of the costliest video the run reads | the decoder closes readers, for a reader's room or for a turn's frames, and a play whose reader it closed takes turns |
| `readAhead` | each frame the decoder reads ahead for a play and has not yet given or let go of, the play's end letting go of it ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), a picture of the video's displayed size at 8 bytes a pixel | none | the decoder reads the frame where it is asked, not ahead |
| `turns` | the decoded frames a turn holds for later asks of its play, until the play asks them or ends ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), each at the bytes of the buffer the decoder is given it in | none | the decoder closes readers of other plays for the turn's frames, and where none is left to close, the turn holds fewer frames and the play takes its next turn sooner |
| `pictures` | the media pictures of pixels the renderer keeps, frames of videos, stills and image sequences, transition mattes and displacement maps, those of the frame drawn last and those the frame being drawn has read ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)), each kept once for its file, frame and reading whichever play reads it ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), each of its medium's displayed size at 8 bytes a pixel as working values and 4 as an analysis picture | twice the most one display list the renderer checks reads of them, each picture once, the list `still` and `sheet` lay their frames out on among them | does not give way |
| `frames` | the output frames a command holds, a picture of working values at 8 bytes a pixel and an analysis picture at 4: for `render` of a video the frame being drawn, the frame the encoder writes, and a second the encoder holds behind it while that one is written, each of the sequence's size, and for `render` of a PNG the one frame; for `still` and `sheet` the picture they lay out, of its own size, and each frame of a document drawn first to the analysis picture its cell reads, of the frames' size, one at a time and all before the laid out picture is drawn; for `extract` the frame being written, of the sequence's size for a document, and an analysis picture of the medium's displayed size for a video or an image sequence; for `transcode` of a video to a video the frame read, of the video's displayed size, which the encoder copies before the next is read | for `render` of a video two frames, and for every other command one frame: the PNG's, the larger of the laid out picture and a frame drawn first, the frame being written, the frame read | `render` of a video waits for the frame being written before it hands the encoder the next, and every other command's does not give way |
| `sound` | the run's mixed sound: two channels of 32-bit samples at 48 kHz over the mix plan's length ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)) | all of it | does not give way |

The run's floor is the sum of the holders' floors, so a limit is kept or refused by the document, the command and the machine's decoder alone. `render` knows its floor once it has checked every pinned medium, made the mix plan of a video and had the renderer check every frame's display list, and refuses a limit under it in `check`, before the first frame, naming the limit as it is written, or as the default's whole GB or MB, and the floor and each holder's in the table's order: `memory limit 1.5GB is under the 2 GB this run needs: readers 1.2 GB, readAhead 0 MB, turns 0 MB, pictures 0 MB, frames 768 MB, sound 51.2 MB`, a size of 1 GB or more in GB to two places and a smaller one in MB to one place, with no trailing zeros. The other commands that read frames refuse in the same words, each before it writes anything. `extract`, `still` and `sheet`, and `transcode` of a video to a video, have the decoder check every file they read, which raises the `readers` floor to each video's reader, and `extract`, `still` and `sheet` of a document have the renderer check every list they draw, the command and its arguments fix each one's `frames` floor, and each refuses a limit under the run's floor once those checks are done, before it reads a frame, makes a directory or removes an existing output. A sheet's own list is among the lists `still` and `sheet` check before a cell's picture is read, so a sheet is drawn whole or refused before its first cell. The sheet's list reads a frame of a video or an image sequence as its analysis picture, nests the display list of a document's frame where the sequence's output is `srgb` and the frame has no motion blur, and reads any other frame of a document as the analysis picture it is drawn to first, of the frames' size at 4 bytes a pixel, which the check counts before that frame is drawn. `ocr` and `track` of a video have no check of a file before they read it, so its reader, the run's floor, is raised as the decoder opens that reader for the first frame they ask, and they refuse there, before that frame is decoded. They print nothing until every frame is read, so a refusal leaves no output.

The decoder keeps its count of open readers ([FRAMES-21](../FRAMES-21/SPEC.md#rules)) as a rule of its own, which closes readers whatever the budget holds.

Where `readers` and `turns` want the same room, a turn's frames come first: a turn is admitted with room for the frames it keeps, for which the decoder closes the readers of other plays as it does for a reader ([FRAMES-21](../FRAMES-21/SPEC.md#rules)). A reader opened for a turn whose frames are not kept reads one frame for its opening, and the play opens another at its next frame, so the room of a turn's frames spares more readers opened than the same room left to an open reader.

### What it counts

The budget counts two kinds of thing. What frames holds and knows the size of, it counts by that size: the frames read ahead, the decoded frames turns hold, by the bytes of the buffers the decoder is given them in, the media pictures of pixels the renderer keeps, the output frames and the mixed sound. A reader open for a play of a video it counts by a charge frames sets, the decoder's cost of a reader ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), a number of frames of that video. The charge is what makes the limit close readers, and a reader closed lets go of what the platform's decoding service holds for it, which frames does not see.

The rest of what a run uses is not counted: the renderer's working memory (its layers, masks, nested rasters and motion blur's sums), the pictures of pages the renderer keeps, whose regions and scales it finds as it draws, the memory a reader holds in the process, what the decoding service holds for a reader beyond its cost, the encoder's own buffers, a provider's pictures, and the pools that keep memory a holder has given back. So what a run really uses can lie above the limit, by an amount the budget does not know.

**Note.** A reader's cost is charged because the decoding service was seen to hold most of what a render of many videos used, and less where readers were closed: on the reference machine, an Apple M1 Pro of 16 GB with macOS 27.2, in renders of 8 and 16 videos of ProRes 4444 of 1206 by 2622 pixels read as half floats, the service held 3.45 to 5.43 GB and the process 1.17 to 2.01 GB at limits of 4 and 6 GB, and at 2 GB, where the budget closed readers 2310 times, the service held 1.26 GB for 16 videos. In such a render with every reader open, the service held 1.23 times what the budget counted of its `readers` and `turns`. Another codec, picture size or system version can make the service hold more or less for a reader than its cost.

### Frames are the same at any limit

A run gives the same frames at every limit at or above its floor. A reader closed for room makes its play's next read a turn, which decodes the frames it gives as a reader opened at them does, a frame not read ahead is read where it is asked by the same read, a frame a turn does not hold is read where it is asked, from the reader left open or from a reader opened at it, which decode it alike ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), and a frame the encoder takes after the one before is written is the same frame. The limit changes how long the run takes.

### Report

The run report's `memory` gives the limit and what the budget counted ([FRAMES-23](../FRAMES-23/SPEC.md#runs)):

| Field | Value |
| --- | --- |
| `limit` | the limit in bytes |
| `floor` | the run's floor in bytes |
| `peak` | the largest total the budget counted at once, in bytes, at most `limit` |
| `holders` | one object for each holder of the table above, in its order, keyed by its name: `{floor, peak, refused}` |

A holder's `floor` and `peak` are bytes, its `peak` the most the budget counted it at, and `refused` the times the budget refused it more: for `readers` the readers the decoder closed for a reader's room, each of which makes a turn when its play is read again, for `readAhead` the frames the decoder read where they were asked for want of room, for `turns` the times a turn was refused room for its frames, each of which closes the reader of another play where one is open and otherwise leaves the turn holding fewer frames, and for `frames` the frames the render handed the encoder only once the frame before was written, for want of room. A holder that does not give way has `refused` 0.

## Interactions

The decoder's readers, their cost, turns and reading ahead are [FRAMES-21](../FRAMES-21/SPEC.md#rules), which takes its room for readers and frames read ahead from this budget. The global options and the run report are [FRAMES-23](../FRAMES-23/SPEC.md). The mix plan is [FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan). Stages and what a run reports are [FRAMES-23](../FRAMES-23/SPEC.md#runs).

## Alternatives considered

A limit written as a fraction of the machine's memory (`--memory 0.5`), as the default is: the same command line would hold another amount on another machine, while a user who sets the limit sizes room beside programs whose needs they know in bytes, so the written form is a size and the fraction is the default's rule alone.

A limit written as the memory left for other programs, as After Effects and Premiere Pro take it: frames cannot see what other programs hold, so the bound it would keep is the machine's memory less that amount, a size the user can write.

An environment variable or a configuration file for the limit: frames takes every setting of a whole run as a global option, and `FRAMES_HOME` says only where packs are installed, so a second way would be two places to look for one setting.

Setting apart a share of the budget for the frames turns keep, or having the open readers leave room for one turn's frames: a share is a number frames would tune to one render, and the room of one turn serves one video, while every video whose reader is closed keeps the frames of its own turn at the same time.

A bound on the decoder's readers alone, at a fixed quarter of the machine's memory: it left the frames read ahead and the frames in flight uncounted, no one chose it, and a user could not move it.

Reading a decoded frame on the GPU through a Core Video texture cache, which keeps a texture made on a frame until it ages out a second after it was last used, and only when the cache is next used: every texture kept holds its frame in the decoding service, as measured on the reference machine's system, so a reader the limit closes leaves its frames there, and the smaller the limit the more the service holds, since every turn's reader decodes into new frames.

Counting the media pictures the renderer keeps as they are read, granted whatever the total: the total then passes the limit by those pictures, so the limit bounds nothing, while a floor the renderer finds from the display lists it checks before the first frame holds every picture of pixels a frame reads and those of the frame before it.

A limit that bounds what a run really uses, measured from the process and from the decoding service the platform runs for it: the system runs one instance of the service for each process that decodes, and no interface the system supports names the instance that serves frames. `launchctl print` names it in text the system does not keep as an interface, the process the system holds responsible for the instance is the terminal frames runs in, and the instances of two frames processes started together have the same name and the same start, so a measurement by any of these would read the wrong instance or would count another run's service as frames's. So frames cannot know what a run really uses, and cannot bound it.

Measuring the process's memory and adding what it holds beyond what the budget counts in it to the budget's total: frames does not see the decoding service's memory, so the correction makes the process's part of the total exact and leaves the service's part unbounded, at the cost of a measurement at every grant and a rule for the measurement's error, while the budget works as a control without it.

## Notes
