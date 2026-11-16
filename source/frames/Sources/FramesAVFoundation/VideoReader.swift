//
//  VideoReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import CoreImage
import Foundation
import Frames

// A video file's first picture track, loaded once. `frames` are its presented frames in the order they are presented,
// and frame i is `frames[i]`. `frameTimes` and `duration` are in media time: the presentation timeline moved so its 0
// is the first presented frame.
struct VideoReader: Sendable {
    // MARK: - Property
    let frames: [FrameTime]
    let displaySize: Size
    let fps: Double
    let duration: Double
    let hasSound: Bool
    let bitsPerComponent: Int

    var frameTimes: [Double] {
        guard let first = frames.first else { return [] }

        return frames.map { CMTimeGetSeconds(CMTimeSubtract($0.presented, first.presented)) }
    }

    private let asset: AVURLAsset
    // A track is only read once it is loaded, which AVFoundation allows from any thread.
    nonisolated(unsafe) private let track: AVAssetTrack
    private let storedSize: CGSize
    private let transform: CGAffineTransform

    // MARK: - Initializer
    // Nil for a file without a picture track.
    init?(path: String) throws {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let waiter = LoadWaiter(file: path)
        guard let track = try waiter.tracks(of: asset, type: .video).first else { return nil }
        let loaded = try Self.facts(of: track, in: asset, waiter: waiter)

        // The preferred transform is moved so the turned picture starts at the origin, as a player shows it.
        let turned = CGRect(origin: .zero, size: loaded.storedSize).applying(loaded.preferredTransform)
        self.asset = asset
        self.track = track
        self.storedSize = loaded.storedSize
        self.transform = loaded.preferredTransform.concatenating(
            CGAffineTransform(translationX: -turned.minX, y: -turned.minY)
        )
        self.displaySize = Size(width: turned.width.rounded(), height: turned.height.rounded())
        self.fps = Double(loaded.nominalFrameRate)
        self.hasSound = loaded.hasSound
        self.bitsPerComponent = loaded.bitsPerComponent
        let frames = try Self.frames(of: track, in: asset, edits: loaded.edits, path: path)
        self.frames = frames
        self.duration = CMTimeGetSeconds(CMTimeSubtract(loaded.duration, frames.first?.presented ?? .zero))
    }

    // MARK: - Public
    // The picture of frame `index` as it is displayed, tagged with the colour space the file gives: the last decoded
    // frame presented at or before its presented time.
    func image(
        atFrame index: Int,
        path: String
    ) throws -> CIImage {
        let time = frames[index].presented
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: bitsPerComponent > 8
                ? kCVPixelFormatType_64RGBAHalf
                : kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.timeRange = CMTimeRange(start: time, duration: .positiveInfinity)
        guard reader.startReading() else { throw DecoderError.unreadable(file: path) }
        defer { reader.cancelReading() }

        var shown: CVImageBuffer?
        while let sample = output.copyNextSampleBuffer() {
            guard CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sample), time) <= 0 else { break }
            shown = CMSampleBufferGetImageBuffer(sample) ?? shown
        }
        guard let shown else { throw DecoderError.noFrame(file: path, index: index, count: frames.count) }

        return displayed(CIImage(cvImageBuffer: shown))
    }

    // MARK: - Private
    private static func facts(
        of track: AVAssetTrack,
        in asset: AVAsset,
        waiter: LoadWaiter
    ) throws -> TrackFacts {
        let formats = try waiter.value(of: .formatDescriptions, key: "formatDescriptions", in: track)
        let depth = formats.first.flatMap {
            CMFormatDescriptionGetExtension($0, extensionKey: kCMFormatDescriptionExtension_BitsPerComponent)
        }
        let segments = try waiter.value(of: .segments, key: "segments", in: track)

        return TrackFacts(
            storedSize: try waiter.value(of: .naturalSize, key: "naturalSize", in: track),
            preferredTransform: try waiter.value(of: .preferredTransform, key: "preferredTransform", in: track),
            nominalFrameRate: try waiter.value(of: .nominalFrameRate, key: "nominalFrameRate", in: track),
            bitsPerComponent: depth as? Int ?? 8,
            edits: segments.filter { !$0.isEmpty }.map(\.timeMapping),
            duration: try waiter.value(of: .duration, key: "duration", in: asset),
            hasSound: !(try waiter.tracks(of: asset, type: .audio)).isEmpty
        )
    }

    // Every sample's times, read without decoding: its sample time is mapped through the edit that holds it, and one
    // no edit holds is never presented.
    private static func frames(
        of track: AVAssetTrack,
        in asset: AVAsset,
        edits: [CMTimeMapping],
        path: String
    ) throws -> [FrameTime] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw DecoderError.unreadable(file: path) }

        var frames: [FrameTime] = []
        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(sample) > 0 else { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            if let edit = edits.first(where: { CMTimeRangeContainsTime($0.source, time: time) }) {
                let presented = CMTimeMapTimeFromRangeToRange(time, fromRange: edit.source, toRange: edit.target)
                frames.append(FrameTime(sample: time, presented: presented))
            }
        }
        guard reader.status == .completed else { throw DecoderError.unreadable(file: path) }

        return frames.sorted { CMTimeCompare($0.presented, $1.presented) < 0 }
    }

    // The transform is written for a top left origin, and Core Image's is at the bottom left, so it is applied between
    // the flips of the stored and the displayed picture.
    private func displayed(_ image: CIImage) -> CIImage {
        let storedFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: storedSize.height)
        let displayFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: displaySize.height)

        return image.transformed(by: storedFlip.concatenating(transform).concatenating(displayFlip))
    }
}
