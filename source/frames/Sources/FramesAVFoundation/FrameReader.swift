//
//  FrameReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import CoreVideo

// An AVAssetReader open on a video's picture track from a presented time, read forward: it stands after frame `index`,
// holds that frame's decoded picture, and keeps the sample it read past it for the next frame. Not thread safe; its
// video reader holds it under a lock.
final class FrameReader {
    // MARK: - Property
    private(set) var index: Int
    private(set) var time: CMTime
    private(set) var picture: CVImageBuffer?

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private var pending: CMSampleBuffer?

    // MARK: - Initializer
    init(
        asset: AVAsset,
        track: AVAssetTrack,
        pixelFormat: OSType,
        start: CMTime,
        path: String
    ) throws {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.timeRange = CMTimeRange(start: start, duration: .positiveInfinity)
        guard reader.startReading() else { throw DecoderError.unreadable(file: path) }

        self.reader = reader
        self.output = output
        self.index = -1
        self.time = .negativeInfinity
    }

    deinit {
        reader.cancelReading()
    }

    // MARK: - Public
    // Reads forward to frame `index` at `time`, at or after the time read last: its picture is the last decoded one
    // presented at or before it.
    func read(
        frame index: Int,
        at time: CMTime,
        path: String
    ) throws -> CVImageBuffer? {
        while let sample = pending ?? output.copyNextSampleBuffer() {
            pending = nil
            guard CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sample), time) <= 0 else {
                pending = sample
                break
            }
            picture = CMSampleBufferGetImageBuffer(sample) ?? picture
        }
        guard reader.status != .failed else { throw DecoderError.unreadable(file: path) }
        self.index = index
        self.time = time

        return picture
    }

    // MARK: - Private
}
