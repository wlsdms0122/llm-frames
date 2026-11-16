//
//  MediaDecoder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the pictures of media files for the providers, the analysis commands and the renderer. Frames are named by
// index: frame i of a video or an image sequence is the one at `file.frameTimes[i]`.
package protocol MediaDecoder: Sendable {
    // Frame `index` of `file`, a video, a still or an image sequence directory, in the working space. A still has the
    // one frame 0. A video whose frames count differently from the pinned `frameTimes` stops.
    func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> Bitmap
}
