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

// A video file's first picture track, loaded once. `presentationTimes` are its frames' timestamps on the file's
// presentation timeline, after its edit list, in order, and frame i is the one presented at `presentationTimes[i]`.
struct VideoReader: Sendable {
    // MARK: - Property
    let presentationTimes: [CMTime]
    let displaySize: Size
    let fps: Double
    let duration: Double
    let hasSound: Bool
    let bitsPerComponent: Int

    // Media time is 0 at the first presented frame.
    var frameTimes: [Double] {
        guard let first = presentationTimes.first else { return [] }

        return presentationTimes.map { CMTimeGetSeconds(CMTimeSubtract($0, first)) }
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
        nonisolated(unsafe) var pictureTrack: AVAssetTrack?
        let loaded = try LoadWaiter().value { () async throws -> TrackFacts? in
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let (naturalSize, preferredTransform, nominalFrameRate, formats, segments) = try await track.load(
                .naturalSize,
                .preferredTransform,
                .nominalFrameRate,
                .formatDescriptions,
                .segments
            )
            let depth = formats.first.flatMap {
                CMFormatDescriptionGetExtension($0, extensionKey: kCMFormatDescriptionExtension_BitsPerComponent)
            }
            pictureTrack = track

            return TrackFacts(
                storedSize: naturalSize,
                preferredTransform: preferredTransform,
                nominalFrameRate: nominalFrameRate,
                bitsPerComponent: depth as? Int ?? 8,
                edits: segments.filter { !$0.isEmpty }.map(\.timeMapping),
                duration: try await asset.load(.duration),
                hasSound: !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
            )
        }
        guard let loaded, let track = pictureTrack else { return nil }

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
        self.duration = CMTimeGetSeconds(loaded.duration)
        self.hasSound = loaded.hasSound
        self.bitsPerComponent = loaded.bitsPerComponent
        self.presentationTimes = try Self.presentationTimes(of: track, in: asset, edits: loaded.edits, path: path)
    }

    // MARK: - Public
    // The picture of frame `index` as it is displayed, tagged with the colour space the file gives: the last decoded
    // frame presented at or before its timestamp.
    func image(
        atFrame index: Int,
        path: String
    ) throws -> CIImage {
        let time = presentationTimes[index]
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
        guard let shown else { throw DecoderError.noFrame(file: path, index: index, count: presentationTimes.count) }

        return displayed(CIImage(cvImageBuffer: shown))
    }

    // MARK: - Private
    // Every sample's timestamp, read without decoding. Samples carry the track's media timeline, so each is mapped
    // through the edit that holds it, and one no edit holds is never presented.
    private static func presentationTimes(
        of track: AVAssetTrack,
        in asset: AVAsset,
        edits: [CMTimeMapping],
        path: String
    ) throws -> [CMTime] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw DecoderError.unreadable(file: path) }

        var times: [CMTime] = []
        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(sample) > 0 else { continue }
            let mediaTime = CMSampleBufferGetPresentationTimeStamp(sample)
            if let edit = edits.first(where: { CMTimeRangeContainsTime($0.source, time: mediaTime) }) {
                times.append(CMTimeMapTimeFromRangeToRange(mediaTime, fromRange: edit.source, toRange: edit.target))
            }
        }
        guard reader.status == .completed else { throw DecoderError.unreadable(file: path) }

        return times.sorted { CMTimeCompare($0, $1) < 0 }
    }

    // The transform is written for a top left origin, and Core Image's is at the bottom left, so it is applied between
    // the flips of the stored and the displayed picture.
    private func displayed(_ image: CIImage) -> CIImage {
        let storedFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: storedSize.height)
        let displayFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: displaySize.height)

        return image.transformed(by: storedFlip.concatenating(transform).concatenating(displayFlip))
    }
}
