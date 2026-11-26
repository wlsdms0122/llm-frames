//
//  TimedDecoder.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation

@testable import Frames

// A recording decoder that spends `readSeconds` of `clock` on each picture it reads and reports them as `decode`, and
// each read of `/abs/run.mp4` as one picture read and decoded by the `identity` conversion.
final class TimedDecoder: MediaDecoder, @unchecked Sendable {
    // MARK: - Property
    private let decoder: RecordingDecoder
    private let clock: ManualClock
    private let readSeconds: Double
    private let lock = NSLock()
    private var reads = 0
    private var times = StageTimes()

    // MARK: - Initializer
    init(
        clock: ManualClock,
        readSeconds: Double
    ) {
        self.decoder = RecordingDecoder(log: RoleCallLog())
        self.clock = clock
        self.readSeconds = readSeconds
    }

    // MARK: - Lifecycle
    var largestPictureSide: Int {
        decoder.largestPictureSide
    }

    func picture(
        of file: MediaFile,
        atFrame index: Int,
        play: MediaPlay,
        reading: PictureReading
    ) throws -> Pixels {
        clock.advance(by: readSeconds)
        lock.withLock {
            reads += 1
            times.add(readSeconds, to: .decode)
        }

        return try decoder.picture(of: file, atFrame: index, play: play, reading: reading)
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

    func readings() -> MediaReadings {
        lock.withLock {
            let media = reads == 0 ? [] : [
                MediumReading(
                    path: "/abs/run.mp4",
                    page: nil,
                    conversion: .identity,
                    device: .cpu,
                    pixelFormat: "16-bit float RGBA",
                    framesRead: reads,
                    framesDecoded: reads,
                    reopened: 0
                )
            ]

            return MediaReadings(media: media, seconds: times)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
