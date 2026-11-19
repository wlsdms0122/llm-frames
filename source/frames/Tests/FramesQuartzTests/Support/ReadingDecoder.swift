//
//  ReadingDecoder.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/20/26.
//

import Foundation
import Frames
import os

// Gives every picture as a white 2 by 2 bitmap at depth `eight`, and records each reading it is asked for by the path
// of the file read.
final class ReadingDecoder: MediaDecoder {
    // MARK: - Property
    private let readings = OSAllocatedUnfairLock<[String: [PictureReading]]>(initialState: [:])

    // MARK: - Initializer
    init() {}

    // MARK: - Lifecycle
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap {
        readings.withLock { $0[file.path, default: []].append(reading) }

        return Bitmap(width: 2, height: 2, depth: .eight, bytesPerRow: 8, pixels: Data(repeating: 255, count: 16))
    }

    func colorReading(of file: MediaFile) throws -> ColorReading {
        .formulas(.srgb)
    }

    func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws {}

    func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        SoundBuffer(sampleRate: 48_000, channels: 2, samples: [])
    }

    // MARK: - Public
    // The readings of the file at `path`, in the order they were asked for.
    func readings(of path: String) -> [PictureReading] {
        readings.withLock { $0[path] ?? [] }
    }

    // MARK: - Private
}
