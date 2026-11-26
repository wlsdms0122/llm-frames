# FRAMES-30: Memory limit

Status: draft

## Summary

A limit on the memory one run of frames holds, set with the global option `--memory` and by default three eighths of the machine's memory, as DaVinci Resolve limits its own memory and After Effects and Premiere Pro keep memory for other programs. The limit is one budget for the run, which the holders of large memory it counts draw from: the decoder's readers, the frames it reads ahead and those its turns hold, and the frame a render's encoder holds behind the one it writes, which hold less where the budget is short, and the media pictures the renderer keeps, the output frames each command draws, reads or writes, and the mixed sound, which the document and the command fix. The budget counts the decoding service's memory by a model and measures the process's own memory as the system counts it, and grants a holder more than it cannot work without only where the model and the measurement together leave room. A limit under what the run cannot work without is refused before the first frame, and what the budget counts never passes the limit. The limit changes how long a run takes and never its frames, and the run report gives what the budget counted beside the process's measured memory.

## Motivation

A render that shows many videos at once holds memory in two places: frames's process, and the decoding service the platform runs for it, which holds each reader's decoded frames outside the process. Without a limit, a render of a few dozen high resolution videos read as half floats holds more than a machine of 16 GB of memory has, and the machine swaps through the render, while the user has no way to say how much frames may hold beside the other programs they run. A bound fixed by the decoder at a fraction of the machine's memory covers only its readers, is no one's choice, and is never seen in a report. Editing programs give the user this setting: DaVinci Resolve a limit on its own memory, After Effects and Premiere Pro the memory left for other programs.

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

**Note.** Three eighths is the largest share in eighths at which a render of 16 videos of ProRes 4444 read as half floats left a third of the reference machine's 16 GB free beside a working day's programs.

### The budget

A run's limit is one budget, which each holder of large memory the run counts draws from. A holder has a floor, the least it holds for the run to work, and holds its floor or more. The budget counts each holder at the larger of its floor and what it holds, and the run's total is the sum over the holders. A holder that gives way, one the table names a way to hold less, is granted more than its floor only where the total, with the correction for what the process holds beyond what the budget counts in it ([What it measures](#what-it-measures)), stays within the limit. A holder that does not give way holds at most its floor. Holding less is always granted. So the total never passes the limit once the run's floor is within it.

| Holder | What it holds | Floor | Where the budget is short |
| --- | --- | --- | --- |
| `readers` | the memory the decoding service holds for each reader the decoder keeps open on a video, by the decoder's cost of that reader ([FRAMES-21](../FRAMES-21/SPEC.md#rules)) | one reader of the costliest video the run reads | the decoder closes readers, and a video whose reader it closed takes turns |
| `readAhead` | each frame the decoder reads ahead and has not yet given, a picture of the video's displayed size at 8 bytes a pixel | none | the decoder reads the frame where it is asked, not ahead |
| `turns` | the decoded frames a turn holds for later asks ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), each at the bytes of the buffer the decoder is given it in | none | the turn holds fewer frames, and the video takes its next turn sooner |
| `pictures` | the media pictures of pixels the renderer keeps, frames of videos, stills and image sequences, transition mattes and displacement maps, those of the frame drawn last and those the frame being drawn has read ([FRAMES-20](../FRAMES-20/SPEC.md#pictures)), each of its medium's displayed size at 8 bytes a pixel as working values and 4 as an analysis picture | twice the most one display list the renderer checks reads of them, each picture once, the list `still` and `sheet` lay their frames out on among them | does not give way |
| `frames` | the output frames a command holds, a picture of working values at 8 bytes a pixel and an analysis picture at 4: for `render` of a video the frame being drawn, the frame the encoder writes, and a second the encoder holds behind it while that one is written, each of the sequence's size, and for `render` of a PNG the one frame; for `still` and `sheet` the picture they lay out, of its own size, and each frame of a document drawn first to the analysis picture its cell reads, of the frames' size, one at a time and all before the laid out picture is drawn; for `extract` the frame being written, of the sequence's size for a document, and an analysis picture of the medium's displayed size for a video or an image sequence; for `transcode` of a video to a video the frame read, of the video's displayed size, which the encoder copies before the next is read | for `render` of a video two frames, and for every other command one frame: the PNG's, the larger of the laid out picture and a frame drawn first, the frame being written, the frame read | `render` of a video waits for the frame being written before it hands the encoder the next, and every other command's does not give way |
| `sound` | the run's mixed sound: two channels of 32-bit samples at 48 kHz over the mix plan's length ([FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan)) | all of it | does not give way |

The run's floor is the sum of the holders' floors, which the budget counts and never measures, so a limit is kept or refused by the document, the command and the machine's decoder alone. `render` knows its floor once it has checked every pinned medium, made the mix plan of a video and had the renderer check every frame's display list, and refuses a limit under it in `check`, before the first frame, naming the limit as it is written, or as the default's whole GB or MB, and the floor and each holder's in the table's order: `memory limit 1.5GB is under the 2 GB this run needs: readers 1.2 GB, readAhead 0 MB, turns 0 MB, pictures 0 MB, frames 768 MB, sound 51.2 MB`, a size of 1 GB or more in GB to two places and a smaller one in MB to one place, with no trailing zeros. The other commands that read frames refuse in the same words, each before it writes anything. `extract`, `still` and `sheet`, and `transcode` of a video to a video, have the decoder check every file they read, which raises the `readers` floor to each video's reader, and `extract`, `still` and `sheet` of a document have the renderer check every list they draw, the command and its arguments fix each one's `frames` floor, and each refuses a limit under the run's floor once those checks are done, before it reads a frame, makes a directory or removes an existing output. A sheet's own list is among the lists `still` and `sheet` check before a cell's picture is read, so a sheet is drawn whole or refused before its first cell. The sheet's list reads a frame of a video or an image sequence as its analysis picture, nests the display list of a document's frame where the sequence's output is `srgb` and the frame has no motion blur, and reads any other frame of a document as the analysis picture it is drawn to first, of the frames' size at 4 bytes a pixel, which the check counts before that frame is drawn. `ocr` and `track` of a video have no check of a file before they read it, so its reader, the run's floor, is raised as the decoder opens that reader for the first frame they ask, and they refuse there, before that frame is decoded. They print nothing until every frame is read, so a refusal leaves no output.

The decoder keeps its count of open readers ([FRAMES-21](../FRAMES-21/SPEC.md#rules)) as a rule of its own, which closes readers whatever the budget holds.

### What it counts

The budget counts what frames itself holds of the output frames, the frames read ahead, the media pictures of pixels the renderer keeps and the mixed sound, by their sizes, and what the decoding service holds outside the process for each reader, by a model, the decoder's cost of a reader ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), and for the decoded frames turns hold, by the bytes of their buffers, which the service makes. The model's constants lie above the most the service was measured to hold for one reader ([FRAMES-21](../FRAMES-21/SPEC.md#notes)), and a video for which the service holds more than the model gives is counted at less than it holds.

The rest of what the process holds is not counted: the renderer's working memory (its layers, masks, nested rasters and motion blur's sums), the pictures of pages the renderer keeps, whose regions and scales it finds as it draws, the memory a reader holds in the process, the encoder's own buffers, a provider's pictures, and the pools that keep memory a holder has given back. The budget measures it instead.

### What it measures

At each grant that would take a holder past its floor, the budget reads the process's physical footprint, the footprint `footprint` and Activity Monitor show, which holds the memory the process makes, the IOSurfaces it makes among it, and not the decoded frames the decoding service makes and the process maps, which the system counts to the service. The uncounted memory of a reading is the footprint less what the budget counts of `readAhead`, `pictures`, `frames` and `sound` at that moment, or nothing where the footprint is less. The correction is the largest uncounted memory of the readings of the last second, and the budget grants the holder more only where the total, the correction and the grant are within the limit.

**Note.** A second is a rule of frames. The budget counts a grant before its memory is made and a give before its memory is freed, so a reading can be low by what was just granted and high by what was just given, and the largest reading of the last second keeps that error on the side of granting less while it lets the correction fall once memory freed has been seen freed.

So at every grant past a floor, the decoding service's memory as the model counts it and the process's memory as the system counts it, as large as it was at any reading of the last second, are with the grant within the limit. Three things lie outside the limit. What the process makes after a grant, such as the renderer's working memory of the frame being drawn and the memory a reader the grant opened comes to hold in the process as it decodes, is seen at the next grant and is not refused. The decoding service's memory is not seen, and its part of the limit is the model's estimate, which can be low: on the reference machine, a render of 8 videos of ProRes 4444 read as half floats with every reader open had the service hold 1.23 times what the budget counted of its `readers` and `turns`. A run whose floors and uncounted memory pass the limit holds its floors and goes on past the limit, as the run report shows.

### Frames are the same at any limit

A run gives the same frames at every limit at or above its floor. A reader closed for room makes the video's next read a turn, which decodes the frames it gives as a reader opened at them does, a frame not read ahead is read where it is asked by the same read, a frame a turn does not hold is read where it is asked, from the reader left open or from a reader opened at it, which decode it alike ([FRAMES-21](../FRAMES-21/SPEC.md#rules)), and a frame the encoder takes after the one before is written is the same frame. The limit changes how long the run takes. So do the readings of the process's memory, which change which grants the budget makes: the turns a run takes, the counts its report gives and its time can differ between two runs of one command, and its frames do not.

### Report

The run report's `memory` gives the limit, what the budget counted and what it measured ([FRAMES-23](../FRAMES-23/SPEC.md#runs)):

| Field | Value |
| --- | --- |
| `limit` | the limit in bytes |
| `floor` | the run's floor in bytes |
| `peak` | the largest total the budget counted at once, in bytes, at most `limit` |
| `process` | the largest physical footprint the process held over its life, as the system keeps it ([What it measures](#what-it-measures)), in bytes: measured, so it holds what the budget counts in the process and what it does not, and none of the decoding service's memory |
| `uncounted` | the largest uncounted memory of a reading, in bytes, 0 where no holder asked for more than its floor |
| `holders` | one object for each holder of the table above, in its order, keyed by its name: `{floor, peak, refused}` |

A holder's `floor` and `peak` are bytes, its `peak` the most the budget counted it at, and `refused` the times the budget refused it more: for `readers` the readers the decoder closed for room, each of which makes a turn when its video is read again, for `readAhead` the frames the decoder read where they were asked for want of room, for `turns` the turns that held fewer frames for want of room, and for `frames` the frames the render handed the encoder only once the frame before was written, for want of room. A holder that does not give way has `refused` 0.

## Interactions

The decoder's readers, their cost, turns and reading ahead are [FRAMES-21](../FRAMES-21/SPEC.md#rules), which takes its room for readers and frames read ahead from this budget. The global options and the run report are [FRAMES-23](../FRAMES-23/SPEC.md). The mix plan is [FRAMES-20](../FRAMES-20/SPEC.md#the-mix-plan). Stages and what a run reports are [FRAMES-23](../FRAMES-23/SPEC.md#runs).

## Alternatives considered

A limit written as a fraction of the machine's memory (`--memory 0.5`), as the default is: the same command line would hold another amount on another machine, while a user who sets the limit sizes room beside programs whose needs they know in bytes, so the written form is a size and the fraction is the default's rule alone.

A limit written as the memory left for other programs, as After Effects and Premiere Pro take it: frames cannot see what other programs hold, so the bound it would keep is the machine's memory less that amount, a size the user can write.

An environment variable or a configuration file for the limit: frames takes every setting of a whole run as a global option, and `FRAMES_HOME` says only where packs are installed, so a second way would be two places to look for one setting.

A bound on the decoder's readers alone, at a fixed quarter of the machine's memory: it left the frames read ahead and the frames in flight uncounted, no one chose it, and a user could not move it.

Reading a decoded frame on the GPU through a Core Video texture cache, which keeps a texture made on a frame until it ages out a second after it was last used, and only when the cache is next used: every texture kept holds its frame in the decoding service, so a reader closed for a turn leaves its frames there, and the service holds the more beyond what the budget counts the smaller the limit, since every turn's reader decodes into new frames.

Counting the media pictures the renderer keeps as they are read, granted whatever the total: the total then passes the limit by those pictures, so the limit bounds nothing, while a floor the renderer finds from the display lists it checks before the first frame holds every picture of pixels a frame reads and those of the frame before it.

Measuring the decoding service as the process is measured: the system runs one instance of the service for each process that decodes, and no interface the system supports names the instance that serves frames. `launchctl print` names it in text the system does not keep as an interface, the process the system holds responsible for the instance is the terminal frames runs in, and the instances of two frames processes started together have the same name and the same start, so a measurement by any of these would read the wrong instance or would count another run's service as frames's.

Adding the process's footprint at `check` to the run's floor, so that a limit under what the process holds is refused before the first frame: the footprint at that moment depends on what the process did before, so one command line would run or be refused by the moment of a reading, while the floors are fixed by the document, the command and the decoder.

Reading the process's memory on a timer of its own: a grant is where a reading is used, and a reading is one call to the system, so a timer would add a thread and give readings older than the grant.

## Notes
