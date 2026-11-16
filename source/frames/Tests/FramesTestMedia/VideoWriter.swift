//
//  VideoWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import Frames

// Writes an H.264 video tagged BT.709 primaries and the sRGB transfer, whose frame i is written at `frameTimes[i]`
// (in multiples of 1/600 second) and drawn by a test in display pixels. `size` is the stored picture, which
// `transform` turns for display. With `sound` it also holds an AAC track of a 440 Hz tone over the whole video.
// The writer's session runs from `start` to `end`, so frames written before `start` are held but never presented.
// `reordersFrames` lets the encoder write B-frames. A `delay` above 0 gives a movie whose edit list shows nothing for
// that long before the video, its samples in a file beside it.
package struct VideoWriter {
    // MARK: - Property
    private static let timescale: Int32 = 600
    private static let sampleRate = 48_000

    private let size: Size
    private let frameTimes: [Double]
    private let start: Double
    private let end: Double
    private let transform: CGAffineTransform
    private let sound: Bool
    private let reordersFrames: Bool
    private let delay: Double

    package var displaySize: Size {
        let turned = CGRect(x: 0, y: 0, width: size.width, height: size.height).applying(transform)

        return Size(width: turned.width, height: turned.height)
    }

    // MARK: - Initializer
    package init(
        size: Size,
        frameTimes: [Double],
        start: Double = 0,
        end: Double,
        transform: CGAffineTransform = .identity,
        sound: Bool = false,
        reordersFrames: Bool = true,
        delay: Double = 0
    ) {
        self.size = size
        self.frameTimes = frameTimes
        self.start = start
        self.end = end
        self.transform = transform
        self.sound = sound
        self.reordersFrames = reordersFrames
        self.delay = delay
    }

    // MARK: - Public
    package func write(
        to path: String,
        drawing: (Canvas, Int) -> Void
    ) async throws {
        let samples = delay > 0 ? (path as NSString).deletingPathExtension + "-samples.mov" : path
        let url = URL(fileURLWithPath: samples)
        let writer = try AVAssetWriter(outputURL: url, fileType: url.pathExtension == "mp4" ? .mp4 : .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: kCVImageBufferTransferFunction_sRGB as String,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAllowFrameReorderingKey: reordersFrames
            ]
        ])
        video.transform = transform
        video.mediaTimeScale = Self.timescale
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(video)
        let audio = sound ? AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]) : nil
        if let audio {
            audio.expectsMediaDataInRealTime = false
            writer.add(audio)
        }
        guard writer.startWriting() else { throw writer.error ?? TestMediaError.unwritable(path) }
        writer.startSession(atSourceTime: mediaTime(start))

        // Sound goes in beside each frame, so the writer can interleave the two.
        for (index, time) in frameTimes.enumerated() {
            let buffer = try pixelBuffer(from: adaptor, path: path) { canvas in drawing(canvas, index) }
            while !video.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard adaptor.append(buffer, withPresentationTime: mediaTime(time)) else {
                throw writer.error ?? TestMediaError.unwritable(path)
            }

            if let audio {
                let next = index + 1 < frameTimes.count ? frameTimes[index + 1] : end
                while !audio.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 1_000_000)
                }
                guard audio.append(try tone(from: time, to: next, path: path)) else {
                    throw writer.error ?? TestMediaError.unwritable(path)
                }
            }
        }
        video.markAsFinished()
        audio?.markAsFinished()
        writer.endSession(atSourceTime: mediaTime(end))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? TestMediaError.unwritable(path) }
        guard delay > 0 else { return }

        let movie = AVMutableMovie(url: url)
        movie.insertEmptyTimeRange(CMTimeRange(start: .zero, duration: mediaTime(delay)))
        try movie.writeHeader(to: URL(fileURLWithPath: path), fileType: .mov, options: [])
    }

    // MARK: - Private
    private func mediaTime(_ seconds: Double) -> CMTime {
        CMTime(value: CMTimeValue((seconds * Double(Self.timescale)).rounded()), timescale: Self.timescale)
    }

    // A frame drawn in display pixels: the context is turned by the inverse of `transform`, between the flips from a
    // top left origin to Core Graphics' bottom left one in each picture.
    private func pixelBuffer(
        from adaptor: AVAssetWriterInputPixelBufferAdaptor,
        path: String,
        drawing: (Canvas) -> Void
    ) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        guard
            let pool = adaptor.pixelBufferPool,
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created) == kCVReturnSuccess,
            let buffer = created
        else {
            throw TestMediaError.unwritable(path)
        }
        let colour = [
            kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_sRGB,
            kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ]
        for (key, value) in colour {
            CVBufferSetAttachment(buffer, key, value, .shouldPropagate)
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else {
            throw TestMediaError.unwritable(path)
        }
        let display = displaySize
        let displayFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: display.height)
        let storedFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        context.concatenate(displayFlip.concatenating(normalised(transform).inverted()).concatenating(storedFlip))
        drawing(Canvas(context: context, size: display))

        return buffer
    }

    // `transform` moved so the turned picture starts at the origin, as a player shows it.
    private func normalised(_ transform: CGAffineTransform) -> CGAffineTransform {
        let turned = CGRect(x: 0, y: 0, width: size.width, height: size.height).applying(transform)

        return transform.concatenating(CGAffineTransform(translationX: -turned.minX, y: -turned.minY))
    }

    // 16 bit mono samples of the tone from `start` to `end` media seconds.
    private func tone(
        from start: Double,
        to end: Double,
        path: String
    ) throws -> CMSampleBuffer {
        let first = Int((start * Double(Self.sampleRate)).rounded())
        let count = max(Int((end * Double(Self.sampleRate)).rounded()) - first, 1)
        var samples = (0..<count).map { offset in
            Int16(sin(2 * Double.pi * 440 * Double(first + offset) / Double(Self.sampleRate)) * 8_000)
        }
        var description = AudioStreamBasicDescription(
            mSampleRate: Double(Self.sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var format: CMAudioFormatDescription?
        var block: CMBlockBuffer?
        var sample: CMSampleBuffer?
        let length = count * 2
        guard
            CMAudioFormatDescriptionCreate(
                allocator: nil,
                asbd: &description,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &format
            ) == noErr,
            CMBlockBufferCreateWithMemoryBlock(
                allocator: nil,
                memoryBlock: nil,
                blockLength: length,
                blockAllocator: nil,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: length,
                flags: 0,
                blockBufferOut: &block
            ) == noErr,
            let format,
            let block,
            CMBlockBufferReplaceDataBytes(
                with: &samples,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: length
            ) == noErr,
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil,
                dataBuffer: block,
                formatDescription: format,
                sampleCount: count,
                presentationTimeStamp: CMTime(value: CMTimeValue(first), timescale: CMTimeScale(Self.sampleRate)),
                packetDescriptions: nil,
                sampleBufferOut: &sample
            ) == noErr,
            let sample
        else {
            throw TestMediaError.unwritable(path)
        }

        return sample
    }
}
