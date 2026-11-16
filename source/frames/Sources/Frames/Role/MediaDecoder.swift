//
//  MediaDecoder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the pictures and sound of media files for the providers, the analysis commands, the renderer and the mixer.
// Frames are named by index: frame i of a video or an image sequence is the one at `file.frameTimes[i]`.
package protocol MediaDecoder: Sendable {
    // Frame `index` of `file`, a video, a still or an image sequence directory, in the working space. A still has the
    // one frame 0. A video whose frames count differently from the pinned `frameTimes` stops.
    func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> Bitmap

    // Refuses, before any frame is read, a file it cannot read or a video whose frames count differently from the
    // pinned `frameTimes`.
    func check(_ file: MediaFile) throws

    // The first sound track of `file` over media time [start, end) on the file's presentation timeline, at the file's
    // sample rate and channels. A range running past the end of the sound gives the frames there are, and an empty one
    // gives none, with the rate and channels.
    func sound(
        of file: String,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer
}
