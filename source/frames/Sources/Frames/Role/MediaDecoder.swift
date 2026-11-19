//
//  MediaDecoder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the pictures and sound of media files. Frames are named by index: frame i of a video or an image sequence is
// the one at `file.frameTimes[i]`.
package protocol MediaDecoder: Sendable {
    // Frame `index` of `file`, a video, a still or an image sequence directory, read as `reading` says: working values
    // at depth `halfFloat`, or an analysis picture at depth `eight`. A still has the one frame 0. A video whose frames
    // count differently from the pinned `frameTimes` stops, and so does a picture no fixed formula converts, an image
    // with a LUT-based ICC profile or a video with a code point H.273 reserves, unless `reading` names its colour space.
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap

    // Refuses, before any frame is read, a file it cannot read or a video whose frames count differently from the
    // pinned `frameTimes`.
    func check(_ file: MediaFile) throws

    // The first sound track of `file` over media time [start, end) on the file's presentation timeline, at the file's
    // sample rate and channels. A range running past the end of the sound gives the frames there are, and an empty one
    // gives none, with the rate and channels.
    func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer
}

extension MediaDecoder {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Frame `index` of `file` as working values in the colour space its tags name, an HDR picture taken as display
    // light.
    package func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> Bitmap {
        try picture(of: file, atFrame: index, reading: .tagged)
    }

    // A display list's media frame as working values, in its colour space and tone mapped to its target peak.
    package func picture(of frame: MediaFrame) throws -> Bitmap {
        try picture(
            of: MediaFile(media: frame.media),
            atFrame: frame.index,
            reading: .working(colorSpace: frame.colorSpace, targetPeak: frame.targetPeak)
        )
    }

    // A display list's media frame as an analysis picture, in its colour space: a transition matte's, or a frame a
    // command shows.
    package func analysisPicture(of frame: MediaFrame) throws -> Bitmap {
        try picture(
            of: MediaFile(media: frame.media),
            atFrame: frame.index,
            reading: .analysis(colorSpace: frame.colorSpace)
        )
    }

    // MARK: - Private
}
