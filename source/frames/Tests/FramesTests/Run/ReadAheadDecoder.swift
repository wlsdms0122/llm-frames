//
//  ReadAheadDecoder.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation

@testable import Frames

// A recording decoder that reads each picture's next one ahead, beside its caller, as a decoder with a thread of its
// own does. It reads its first picture on the caller's thread, spending `readSeconds` of `clock` in `decode`; every
// later picture is the one read ahead, which the caller waits `waitSeconds` of `clock` for. Each read ahead spends
// `aheadDecodeSeconds` in `decode` and `aheadConversionSeconds` in `workingConversion` on the decoder's own thread,
// so `clock` does not move for it. Every picture is of `/abs/run.mp4` by the `identity` conversion.
final class ReadAheadDecoder: MediaDecoder, @unchecked Sendable {
    // MARK: - Property
    private let decoder: RecordingDecoder
    private let clock: ManualClock
    private let readSeconds: Double
    private let waitSeconds: Double
    private let aheadDecodeSeconds: Double
    private let aheadConversionSeconds: Double
    private let lock = NSLock()
    private var framesRead = 0
    private var framesDecoded = 0
    private var times = StageTimes()
    private var readAhead = StageTimes()
    private var waiting: Double = 0

    // MARK: - Initializer
    init(
        clock: ManualClock,
        readSeconds: Double,
        waitSeconds: Double,
        aheadDecodeSeconds: Double,
        aheadConversionSeconds: Double
    ) {
        self.decoder = RecordingDecoder(log: RoleCallLog())
        self.clock = clock
        self.readSeconds = readSeconds
        self.waitSeconds = waitSeconds
        self.aheadDecodeSeconds = aheadDecodeSeconds
        self.aheadConversionSeconds = aheadConversionSeconds
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
        let isReadAhead = lock.withLock { framesRead > 0 }
        if isReadAhead {
            clock.advance(by: waitSeconds)
        } else {
            clock.advance(by: readSeconds)
        }
        lock.withLock {
            if isReadAhead {
                waiting += waitSeconds
            } else {
                times.add(readSeconds, to: .decode)
                framesDecoded += 1
            }
            framesRead += 1

            for (stage, seconds) in [(RunStage.decode, aheadDecodeSeconds), (.workingConversion, aheadConversionSeconds)] {
                times.add(seconds, to: stage)
                readAhead.add(seconds, to: stage)
            }
            framesDecoded += 1
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

    func readings() -> MediaReadings {
        lock.withLock {
            let media = [
                MediumReading(
                    path: "/abs/run.mp4",
                    page: nil,
                    conversion: .identity,
                    device: .cpu,
                    pixelFormat: "16-bit float RGBA",
                    framesRead: framesRead,
                    framesDecoded: framesDecoded,
                    reopened: 0
                )
            ]

            return MediaReadings(media: media, seconds: times, readAhead: readAhead, waiting: waiting)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
