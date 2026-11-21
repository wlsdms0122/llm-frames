//
//  ReadingDecoder.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/20/26.
//

import Foundation
import Frames
import os

// Gives every picture, a frame or a region of a page, as a white 2 by 2 bitmap at depth `eight`, every page the size
// `pageSize`, and records each reading it is asked for, and each region and scale of a page, by the path of the file
// read.
final class ReadingDecoder: MediaDecoder {
    // MARK: - Property
    private let readings = OSAllocatedUnfairLock<[String: [PictureReading]]>(initialState: [:])
    private let regions = OSAllocatedUnfairLock<[String: [PageRegionRequest]]>(initialState: [:])
    private let pageSize: Size

    let largestPictureSide: Int

    // MARK: - Initializer
    init(
        pageSize: Size = Size(width: 2, height: 2),
        largestPictureSide: Int = 16_384
    ) {
        self.pageSize = pageSize
        self.largestPictureSide = largestPictureSide
    }

    // MARK: - Lifecycle

    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap {
        readings.withLock { $0[file.path, default: []].append(reading) }

        return Bitmap(width: 2, height: 2, depth: .eight, bytesPerRow: 8, pixels: Data(repeating: 255, count: 16))
    }

    func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Bitmap {
        readings.withLock { $0[file.path, default: []].append(reading) }
        regions.withLock { $0[file.path, default: []].append(PageRegionRequest(region: region, scale: scale)) }

        return Bitmap(width: 2, height: 2, depth: .eight, bytesPerRow: 8, pixels: Data(repeating: 255, count: 16))
    }

    func pageSize(of file: MediaFile) throws -> Size {
        pageSize
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

    // The regions and scales of the page at `path`, in the order they were asked for.
    func regions(of path: String) -> [PageRegionRequest] {
        regions.withLock { $0[path] ?? [] }
    }

    // MARK: - Private
}
