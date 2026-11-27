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
// read, the play of each frame asked for, the frames each telling names to read ahead, and the media frames each frame
// rendered showed.
final class ReadingDecoder: MediaDecoder {
    // MARK: - Property
    private let pictureReadings = OSAllocatedUnfairLock<[String: [PictureReading]]>(initialState: [:])
    private let regions = OSAllocatedUnfairLock<[String: [PageRegionRequest]]>(initialState: [:])
    private let askedPlays = OSAllocatedUnfairLock<[MediaPlay]>(initialState: [])
    private let renderedFrames = OSAllocatedUnfairLock<[[MediaFrame]]>(initialState: [])
    private let tellings = OSAllocatedUnfairLock<[Telling]>(initialState: [])
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
        play: MediaPlay,
        reading: PictureReading
    ) throws -> Pixels {
        pictureReadings.withLock { $0[file.path, default: []].append(reading) }
        askedPlays.withLock { $0.append(play) }

        return .bitmap(Bitmap(width: 2, height: 2, depth: .eight, bytesPerRow: 8, pixels: Data(repeating: 255, count: 16)))
    }

    func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Pixels {
        pictureReadings.withLock { $0[file.path, default: []].append(reading) }
        regions.withLock { $0[file.path, default: []].append(PageRegionRequest(region: region, scale: scale)) }

        return .bitmap(Bitmap(width: 2, height: 2, depth: .eight, bytesPerRow: 8, pixels: Data(repeating: 255, count: 16)))
    }

    func pageSize(of file: MediaFile) throws -> Size {
        pageSize
    }

    func pictureSize(of file: MediaFile) throws -> Size {
        Size(width: 2, height: 2)
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

    func readAhead(
        of file: MediaFile,
        atFrames indices: [Int],
        play: MediaPlay,
        reading: PictureReading
    ) {
        let asked = askedPlays.withLock(\.count)
        tellings.withLock { $0.append(Telling(path: file.path, indices: indices, play: play, asked: asked)) }
    }

    func frameRendered(showing frames: [MediaFrame]) {
        renderedFrames.withLock { $0.append(frames) }
    }

    // Reports no medium and no time, as a run's report of it would be empty.
    func readings() -> MediaReadings {
        MediaReadings(media: [], seconds: StageTimes())
    }

    // MARK: - Public
    // The play of each frame asked for, in the order they were asked for.
    var plays: [MediaPlay] {
        askedPlays.withLock { $0 }
    }

    // Each telling of frames to read ahead, in the order they came.
    var told: [Telling] {
        tellings.withLock { $0 }
    }

    // The media frames each frame rendered showed, a list for each frame in the order they were rendered.
    var frames: [[MediaFrame]] {
        renderedFrames.withLock { $0 }
    }

    // The readings of the file at `path`, in the order they were asked for.
    func readings(of path: String) -> [PictureReading] {
        pictureReadings.withLock { $0[path] ?? [] }
    }

    // The regions and scales of the page at `path`, in the order they were asked for.
    func regions(of path: String) -> [PageRegionRequest] {
        regions.withLock { $0[path] ?? [] }
    }

    // MARK: - Private
}

extension ReadingDecoder {
    // Frames `indices` of the file at `path` told to be read ahead in `play`, once `asked` frames had been asked for.
    struct Telling: Equatable, Sendable {
        let path: String
        let indices: [Int]
        let play: MediaPlay
        let asked: Int
    }
}
