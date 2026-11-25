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
// track of the file shares. One reader stays open after the last frame read, until it is closed, so frames in order
// decode forward from it instead of from the previous sync sample each time.
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
    // How AVAssetReader gives the decoder the frames' samples (FRAMES-21 Rules).
    let decodedFormat: DecodedFormat

    var frameTimes: [Double] {
        frames.map(CMTimeGetSeconds)
    }

    // The size of the picture as the file stores it, and the transform from its pixels to the displayed picture's,
    // both with a top left origin.
    let storedSize: CGSize
    let transform: CGAffineTransform

    private let asset: AVURLAsset
    // A track is only read once it is loaded, which AVFoundation allows from any thread.
    nonisolated(unsafe) private let track: AVAssetTrack
    private let state = OSAllocatedUnfairLock<ReadState>(uncheckedState: ReadState())
    // The frames whose buffers `state` holds, read without its lock while a frame is being read.
    private let heldFrames = OSAllocatedUnfairLock<Set<Int>>(initialState: [])

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
        self.decodedFormat = loaded.decodedFormat
        self.frames = try Self.frames(of: track, in: asset, edits: loaded.edits, path: path)
        self.duration = CMTimeGetSeconds(loaded.duration)
    }

    // MARK: - Public
    // A buffer `buffer(atFrame:path:turn:)` gave as it is displayed, with no colour matched: its R'G'B', taken from its
    // Y'CbCr by the formulas in double precision where it holds Y'CbCr, a value beyond the nominal range kept.
    func image(of buffer: CVImageBuffer) -> CIImage {
        guard case let .yCbCr(layout) = decodedFormat else {
            return displayed(CIImage(cvImageBuffer: buffer, options: [.colorSpace: NSNull()]))
        }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let samples = layout.encodedSamples(of: buffer)

        return displayed(CIImage(
            bitmapData: samples.withUnsafeBytes { Data($0) },
            bytesPerRow: width * 4 * MemoryLayout<Float>.size,
            size: CGSize(width: width, height: height),
            format: .RGBAf,
            colorSpace: nil
        ))
    }

    // The picture of frame `index` as it is displayed, tagged with the colour its frame carries, which Core Image's
    // colour management converts from.
    func taggedImage(
        atFrame index: Int,
        path: String,
        turn: Int
    ) throws -> CIImage {
        displayed(CIImage(cvImageBuffer: try buffer(atFrame: index, path: path, turn: turn).buffer))
    }

    // Whether the buffer of a frame a reader read past the frame it was opened for is held.
    var holdsFrames: Bool {
        !heldFrames.withLock(\.isEmpty)
    }

    // Whether the buffer of frame `index` is held.
    func holds(frame index: Int) -> Bool {
        heldFrames.withLock { $0.contains(index) }
    }

    // The buffer of frame `index` as the file stores it, in `decodedFormat`, the samples decoded to reach it, and
    // whether a reader was opened again for it, which the first reader opened on the video is not. A reader opened for
    // it reads `turn` frames, frame `index` and the frames after it by the step from the frame asked before, within
    // `forwardReach` of it, and holds the buffers of the others, which later asks give with no reader. Every buffer
    // held of a frame up to `index` is let go of.
    func buffer(
        atFrame index: Int,
        path: String,
        turn: Int
    ) throws -> (buffer: CVImageBuffer, decoded: Int, reopened: Bool) {
        let time = frames[index]
        let (shown, decoded, reopened) = try state.withLockUnchecked { state -> (CVImageBuffer?, Int, Bool) in
            let step = state.asked.map { index - $0 }.flatMap { $0 > 0 ? $0 : nil } ?? 1
            state.asked = index
            let held = state.held.first { $0.index == index }
            state.held.removeAll { $0.index <= index }
            defer { heldFrames.withLock { [kept = Set(state.held.map(\.index))] in $0 = kept } }
            if let held { return (held.buffer, 0, false) }
            if let reader = state.reader, reader.index == index { return (reader.picture, 0, false) }
            if let reader = state.reader, reader.index < index, (time - reader.time).seconds <= Self.forwardReach {
                let before = reader.decoded
                let picture = try reader.read(frame: index, at: time, path: path)

                return (picture, reader.decoded - before, false)
            }

            let reopened = state.hasOpened
            let reader = try FrameReader(
                asset: asset,
                track: track,
                pixelFormat: decodedFormat.pixelFormat,
                start: time,
                path: path
            )
            state.reader = reader
            state.hasOpened = true
            let picture = try reader.read(frame: index, at: time, path: path)
            state.held = []
            let following = stride(from: index + step, to: frames.count, by: step).prefix(turn - 1).prefix {
                (frames[$0] - time).seconds <= Self.forwardReach
            }
            for next in following {
                guard let buffer = try reader.read(frame: next, at: frames[next], path: path) else { break }
                state.held.append((next, buffer))
            }

            return (picture, reader.decoded, reopened)
        }
        guard let shown else { throw DecoderError.noFrame(file: path, index: index, count: frames.count) }

        return (shown, decoded, reopened)
    }

    // Lets go of the reader open on the video, so the next frame read opens one at that frame, and keeps the buffers
    // held. A read in progress ends first.
    func close() {
        state.withLockUnchecked { $0.reader = nil }
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
        let hasAlpha = formats.first.map(hasAlpha) ?? false
        let matrix = formats.first.flatMap {
            CMFormatDescriptionGetExtension($0, extensionKey: kCMFormatDescriptionExtension_YCbCrMatrix) as? String
        }
        let layout = formats.first.flatMap {
            YCbCrLayout(
                format: $0,
                matrix: matrix.map { Int(CVYCbCrMatrixGetIntegerCodePointForString($0 as CFString)) },
                hasAlpha: hasAlpha
            )
        }
        let segments = try waiter.value(of: .segments, key: "segments", in: track)

        return TrackFacts(
            storedSize: try waiter.value(of: .naturalSize, key: "naturalSize", in: track),
            preferredTransform: try waiter.value(of: .preferredTransform, key: "preferredTransform", in: track),
            nominalFrameRate: try waiter.value(of: .nominalFrameRate, key: "nominalFrameRate", in: track),
            bitsPerComponent: bitsPerComponent,
            hasAlpha: hasAlpha,
            taggedColor: taggedColor(of: formats.first, bitsPerComponent: bitsPerComponent),
            decodedFormat: layout.map(DecodedFormat.yCbCr) ?? .halfFloatRGBA,
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

extension VideoReader {
    // The reader open on the video, none before the first frame is read and after it is closed, the frame asked last,
    // the buffers of the frames the last reader opened read past the frame it was opened for, and whether a reader
    // was ever opened.
    private struct ReadState {
        var reader: FrameReader?
        var asked: Int?
        var held: [(index: Int, buffer: CVImageBuffer)] = []
        var hasOpened = false
    }
}
