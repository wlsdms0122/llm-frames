//
//  MediaDecoder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the pictures and sound of media files. Frames are named by index: frame i of a video or an image sequence is
// the one at `file.frameTimes[i]`. A page of a PDF, a file of kind `page`, is read by a region of its pixel grid at a
// scale (FRAMES-21 Rules), not by frame.
package protocol MediaDecoder: Sendable {
    // The largest picture the decoder holds, as the most pixels on a side. A frame or a region of a page larger than it
    // on either side is refused, naming its size.
    var largestPictureSide: Int { get }

    // Frame `index` of `file`, a video, a still or an image sequence directory, read as `reading` says: working values
    // at depth `halfFloat`, as a bitmap or a surface (FRAMES-21 Pictures), or an analysis picture at depth `eight`, a
    // bitmap. A still has the one frame 0. A video whose frames count differently from its `frameTimes` stops,
    // and so does a picture no fixed formula converts, an image with a LUT-based ICC profile or a video with a code
    // point H.273 reserves, unless `reading` names its colour space. `play` is the play the frame is read in, whose
    // reader a video's frame is read forward from (FRAMES-21 Rules).
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        play: MediaPlay,
        reading: PictureReading
    ) throws -> Pixels

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
    ) throws -> Pixels

    // The size in media pixels of the page `file` names, as it is displayed (FRAMES-3 PDF pages), which its pixel grid
    // covers at scale 1. A file that names no page, or a page the file does not hold, stops.
    func pageSize(of file: MediaFile) throws -> Size

    // The size in pixels of the pictures of `file`, a video, a still or an image sequence directory, as displayed: the
    // size of every picture `picture(of:atFrame:play:reading:)` gives of it. A page, a sound and a file it cannot read stop.
    func pictureSize(of file: MediaFile) throws -> Size

    // How the pictures of `file`, a video, a still, an image sequence directory or a page, are taken to working values.
    func colorReading(of file: MediaFile) throws -> ColorReading

    // Refuses, before any frame is read, a file it cannot read, a picture larger than `largestPictureSide`, a video
    // whose frames count differently from its `frameTimes`, a page it does not read (FRAMES-3 PDF pages), and,
    // where `reading` is how its pictures are to be read, a picture that reading would stop at: one no fixed formula
    // converts, with no colour space named. `reading` is nil where no picture is read, or where the caller reads it as
    // `colorReading(of:)` says.
    func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws

    // Ends the frame being rendered, which showed `frames`: the media frames the renderer read for it, in the order it
    // read them, those it drew from a picture it kept from another play's read among them. frames renders the frames of
    // a document one after another, so a play none of `frames` is in is over: the decoder closes what it opened to read
    // it, gives back to the run's budget what it holds for it and keeps no record of it, so a frame asked in it later
    // starts it as a new play does. In a play of them, the frame shown last in a reading is the frame the play asked
    // last in it, whoever read it (FRAMES-21 Rules). A file read with no frame rendered is one play until the command
    // ends.
    func frameRendered(showing frames: [MediaFrame])

    // What the decoder has read since it was made, how it read each medium's pictures and its time reading
    // (FRAMES-23 Runs).
    func readings() -> MediaReadings

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
    // Frame `index` of `file` read on its own, as working values in the colour space its tags name, an HDR picture
    // taken as display light.
    package func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> Pixels {
        try picture(of: file, atFrame: index, play: .file, reading: .tagged)
    }

    // A display list's media frame, read as the frame says: a frame by its index in its play, and a page whole as a
    // provider reads it.
    package func picture(of frame: MediaFrame) throws -> Pixels {
        let file = MediaFile(picture: frame.media)
        switch frame.picture {
        case let .frame(index):
            return try picture(of: file, atFrame: index, play: frame.play, reading: frame.reading)

        case .page:
            return .bitmap(try providerPicture(ofPage: file, reading: frame.reading).picture)
        }
    }

    // The scale a provider reads a page of `size` media pixels at: 4 pixels per media pixel, or the largest at which
    // the decoder holds the whole page where that is less (FRAMES-21 Rules).
    package func providerScale(ofPageSize size: Size) -> Double {
        PageRegion.heldScale(of: size, atMost: 4, largest: largestPictureSide)
    }

    // The whole page `file` names as a provider reads it, at `providerScale(ofPageSize:)`, read as `reading` says,
    // with that scale, which a provider divides what it finds by to give it in the page's media pixels.
    package func providerPicture(
        ofPage file: MediaFile,
        reading: PictureReading
    ) throws -> (picture: Bitmap, scale: Double) {
        let size = try pageSize(of: file)
        let (region, scale) = PageRegion.wholePage(
            of: size,
            atMost: providerScale(ofPageSize: size),
            largest: largestPictureSide
        )

        return (try picture(of: file, region: region, scale: scale, reading: reading).bitmap, scale)
    }

    // MARK: - Private
}
