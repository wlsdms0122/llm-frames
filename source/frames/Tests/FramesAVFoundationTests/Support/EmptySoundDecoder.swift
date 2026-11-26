//
//  EmptySoundDecoder.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/23/26.
//

import Frames
import FramesAVFoundation

// The `avfoundation` decoder reading no frames of sound from `emptyFile`, with its rate and channels, as it reads a
// file whose sound track holds none over the range read.
struct EmptySoundDecoder: MediaDecoder {
    // MARK: - Property
    private let emptyFile: String
    private let decoder = AVFoundationDecoder()

    var largestPictureSide: Int {
        decoder.largestPictureSide
    }

    // MARK: - Initializer
    init(emptyFile: String) {
        self.emptyFile = emptyFile
    }

    // MARK: - Public
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Pixels {
        try decoder.picture(of: file, atFrame: index, reading: reading)
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
        let sound = try decoder.sound(of: file, from: start, to: end)
        guard file.path == emptyFile else { return sound }

        return SoundBuffer(sampleRate: sound.sampleRate, channels: sound.channels, samples: [], layout: sound.layout)
    }

    // Reports no medium and no time, as a run's report of it would be empty.
    func readings() -> MediaReadings {
        MediaReadings(media: [], seconds: StageTimes())
    }

    // MARK: - Private
}
