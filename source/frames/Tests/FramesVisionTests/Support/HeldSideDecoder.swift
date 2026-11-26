//
//  HeldSideDecoder.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/21/26.
//

import Frames
import FramesAVFoundation

// The `avfoundation` decoder stating a smaller largest picture, so a test reaches the scale a provider falls to when
// the decoder does not hold a page at 4 pixels per point.
struct HeldSideDecoder: MediaDecoder {
    // MARK: - Property
    let largestPictureSide: Int
    private let decoder = AVFoundationDecoder()

    // MARK: - Initializer
    init(largestPictureSide: Int) {
        self.largestPictureSide = largestPictureSide
    }

    // MARK: - Public
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        play: MediaPlay,
        reading: PictureReading
    ) throws -> Pixels {
        try decoder.picture(of: file, atFrame: index, play: play, reading: reading)
    }

    func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Pixels {
        try decoder.picture(of: file, region: region, scale: scale, reading: reading)
    }

    func pageSize(of file: MediaFile) throws -> Size {
        try decoder.pageSize(of: file)
    }

    func pictureSize(of file: MediaFile) throws -> Size {
        try decoder.pictureSize(of: file)
    }

    func colorReading(of file: MediaFile) throws -> ColorReading {
        try decoder.colorReading(of: file)
    }

    func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws {
        try decoder.check(file, reading: reading)
    }

    func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        try decoder.sound(of: file, from: start, to: end)
    }

    func frameRendered(showing frames: [MediaFrame]) {
        decoder.frameRendered(showing: frames)
    }

    // Reports no medium and no time, as a run's report of it would be empty.
    func readings() -> MediaReadings {
        MediaReadings(media: [], seconds: StageTimes())
    }

    // MARK: - Private
}
