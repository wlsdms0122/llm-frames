//
//  MediaDecoder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the pictures and sound of media files. Frames are named by index: frame i of a video or an image sequence is
// the one at `file.frameTimes[i]`. A page of a PDF, a file whose `page` is set, is read by a region of its pixel grid at
// a scale (FRAMES-21 Rules), not by frame.
package protocol MediaDecoder: Sendable {
    // The largest picture the decoder holds, as the most pixels on a side. A frame or a region of a page larger than it
    // on either side is refused, naming its size.
    var largestPictureSide: Int { get }

    // Frame `index` of `file`, a video, a still or an image sequence directory, read as `reading` says: working values
    // at depth `halfFloat`, or an analysis picture at depth `eight`. A still has the one frame 0. A video whose frames
    // count differently from the pinned `frameTimes` stops, and so does a picture no fixed formula converts, an image
    // with a LUT-based ICC profile or a video with a code point H.273 reserves, unless `reading` names its colour space.
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap

    // `region` of the grid of the page `file` names at `scale` pixels per media pixel, read as `reading` says, as one
    // draw: working values at depth `halfFloat`, with what the page paints nothing over and what lies off it
    // transparent, or an analysis picture at depth `eight`, the page over white (FRAMES-3 PDF pages). A working
    // reading's target peak does not apply, since a page is not HDR. A region whose width or height is under 1 or above
    // `largestPictureSide`, a scale of 0 or less, and a page the decoder refuses stop.
    func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Bitmap

    // How the pictures of `file`, a video, a still, an image sequence directory or a page, are taken to working values.
    func colorReading(of file: MediaFile) throws -> ColorReading

    // Refuses, before any frame is read, a file it cannot read, a picture larger than `largestPictureSide`, a video
    // whose frames count differently from the pinned `frameTimes`, a page it does not read (FRAMES-3 PDF pages), and,
    // where `reading` is how its pictures are to be read, a picture that reading would stop at: one no fixed formula
    // converts, with no colour space named. `reading` is nil where no picture is read, or where the caller reads it as
    // `colorReading(of:)` says.
    func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws

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

    // A display list's media frame, read as the frame says.
    package func picture(of frame: MediaFrame) throws -> Bitmap {
        try picture(of: MediaFile(media: frame.media), atFrame: frame.index, reading: frame.reading)
    }

    // MARK: - Private
}
