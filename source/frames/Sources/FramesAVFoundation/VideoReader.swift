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
import os

// A video file's first picture track, loaded once. `frames` holds the time each presented frame is presented at, in
// order, and frame i is `frames[i]`. `frameTimes` and `duration` are on the file's presentation timeline, which every
// track of the file shares. One reader stays open after the last frame read, so frames in order decode forward from it
// instead of from the previous sync sample each time.
final class VideoReader: Sendable {
    // MARK: - Property
    // A later frame further ahead than this, in seconds, restarts the reader at it rather than decoding up to it.
    private static let forwardReach: Double = 1

    let frames: [CMTime]
    let displaySize: Size
    let fps: Double
    let duration: Double
    let hasSound: Bool
    let hasAlpha: Bool
    let taggedColor: TaggedColor

    var frameTimes: [Double] {
        frames.map(CMTimeGetSeconds)
    }

    private let asset: AVURLAsset
    // A track is only read once it is loaded, which AVFoundation allows from any thread.
    nonisolated(unsafe) private let track: AVAssetTrack
    private let storedSize: CGSize
    private let transform: CGAffineTransform
    private let open = OSAllocatedUnfairLock<FrameReader?>(uncheckedState: nil)

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
        // The rate is stored as a 32-bit float, so it is read back in its shortest decimal form, 29.97 and not
        // 29.969999313354492, and then as the exact rate the encoder would write it at.
        let nominal = Double("\(loaded.nominalFrameRate)") ?? Double(loaded.nominalFrameRate)
        self.fps = FrameTiming(fps: nominal).rate
        self.hasSound = loaded.hasSound
        self.hasAlpha = loaded.hasAlpha
        self.taggedColor = loaded.taggedColor
        self.frames = try Self.frames(of: track, in: asset, edits: loaded.edits, path: path)
        self.duration = CMTimeGetSeconds(loaded.duration)
    }

    // MARK: - Public
    // The picture of frame `index` as it is displayed: the last decoded frame presented at or before its presented
    // time, taken to R'G'B' half floats by the matrix and range the file says, with no colour matched. Asking for the
    // frame read last decodes nothing.
    func image(
        atFrame index: Int,
        path: String
    ) throws -> CIImage {
        let time = frames[index]
        let shown = try open.withLockUnchecked { open -> CVImageBuffer? in
            if let reader = open, reader.index == index { return reader.picture }
            if let reader = open, reader.index < index, (time - reader.time).seconds <= Self.forwardReach {
                return try reader.read(frame: index, at: time, path: path)
            }

            let reader = try FrameReader(
                asset: asset,
                track: track,
                pixelFormat: kCVPixelFormatType_64RGBAHalf,
                start: time,
                path: path
            )
            open = reader

            return try reader.read(frame: index, at: time, path: path)
        }
        guard let shown else { throw DecoderError.noFrame(file: path, index: index, count: frames.count) }

        return displayed(CIImage(cvImageBuffer: shown, options: [.colorSpace: NSNull()]))
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
        let bitsPerComponent = depth as? Int ?? 8
        let segments = try waiter.value(of: .segments, key: "segments", in: track)

        return TrackFacts(
            storedSize: try waiter.value(of: .naturalSize, key: "naturalSize", in: track),
            preferredTransform: try waiter.value(of: .preferredTransform, key: "preferredTransform", in: track),
            nominalFrameRate: try waiter.value(of: .nominalFrameRate, key: "nominalFrameRate", in: track),
            bitsPerComponent: bitsPerComponent,
            hasAlpha: formats.first.map(hasAlpha) ?? false,
            taggedColor: taggedColor(of: formats.first, bitsPerComponent: bitsPerComponent),
            edits: segments.filter { !$0.isEmpty }.map(\.timeMapping),
            duration: try waiter.value(of: .duration, key: "duration", in: asset),
            hasSound: !(try waiter.tracks(of: asset, type: .audio)).isEmpty
        )
    }

    // The code points the format names, through the strings Core Video keeps them as, and the maximum luminance of
    // its mastering display: SMPTE ST 2086 metadata holds it in units of 0.0001 cd/m², a 32-bit number at byte 16.
    private static func taggedColor(
        of format: CMFormatDescription?,
        bitsPerComponent: Int
    ) -> TaggedColor {
        let tag = { (key: CFString) in
            format.flatMap { CMFormatDescriptionGetExtension($0, extensionKey: key) as? String }.map { $0 as CFString }
        }
        let volume = format.flatMap {
            CMFormatDescriptionGetExtension($0, extensionKey: kCMFormatDescriptionExtension_MasteringDisplayColorVolume)
                as? Data
        }
        let peak = volume.flatMap { data -> Double? in
            guard data.count >= 20 else { return nil }
            let luminance = data[data.startIndex + 16..<data.startIndex + 20].reduce(0) { $0 << 8 | UInt32($1) }

            return Double(luminance) / 10_000
        }

        return TaggedColor(
            primaries: tag(kCMFormatDescriptionExtension_ColorPrimaries).map {
                Int(CVColorPrimariesGetIntegerCodePointForString($0))
            },
            transfer: tag(kCMFormatDescriptionExtension_TransferFunction).map {
                Int(CVTransferFunctionGetIntegerCodePointForString($0))
            },
            matrix: tag(kCMFormatDescriptionExtension_YCbCrMatrix).map {
                Int(CVYCbCrMatrixGetIntegerCodePointForString($0))
            },
            bitDepth: bitsPerComponent,
            masteringDisplayPeak: peak.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    // A codec that carries alpha says so in its format: HEVC with alpha by its codec type, and ProRes 4444 and the
    // other RGB codecs by an alpha flag or a depth of 32 bits a pixel, where 24 has none.
    private static func hasAlpha(_ format: CMFormatDescription) -> Bool {
        let containsAlpha = CMFormatDescriptionGetExtension(
            format,
            extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel
        )
        let depth = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_Depth)

        return CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVCWithAlpha
            || containsAlpha as? Bool == true
            || depth as? Int == 32
    }

    // The time each sample is presented at, read without decoding. An undecoded sample carries its time before the edit
    // list, so it is mapped through the edit that holds it, and one no edit holds is never presented.
    private static func frames(
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

        var frames: [CMTime] = []
        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(sample) > 0 else { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            if let edit = edits.first(where: { CMTimeRangeContainsTime($0.source, time: time) }) {
                frames.append(CMTimeMapTimeFromRangeToRange(time, fromRange: edit.source, toRange: edit.target))
            }
        }
        guard reader.status == .completed else { throw DecoderError.unreadable(file: path) }

        return frames.sorted { CMTimeCompare($0, $1) < 0 }
    }

    // The transform is written for a top left origin, and Core Image's is at the bottom left, so it is applied between
    // the flips of the stored and the displayed picture.
    private func displayed(_ image: CIImage) -> CIImage {
        let storedFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: storedSize.height)
        let displayFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: displaySize.height)

        return image.transformed(by: storedFlip.concatenating(transform).concatenating(displayFlip))
    }
}
