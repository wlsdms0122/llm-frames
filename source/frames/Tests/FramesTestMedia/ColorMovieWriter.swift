//
//  ColorMovieWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/20/26.
//

import AVFoundation
import CoreVideo
import Foundation
import Frames
import VideoToolbox

// Writes a one-frame video of one colour, its R'G'B' values encoded in `colorSpace` and tagged with that space's code
// points. `srgb` and `rec709` are H.264 from 8-bit 32BGRA, each value taken to the nearest code value; the other spaces
// are HEVC Main 10 from 64RGBAHalf.
package struct ColorMovieWriter {
    // MARK: - Property
    private static let timescale: Int32 = 600

    private let size: Size
    private let colorSpace: ColorSpace

    private var isEightBit: Bool {
        colorSpace == .srgb || colorSpace == .rec709
    }

    // The primaries, transfer function and Y'CbCr matrix as Core Video names them.
    private var tags: (primaries: CFString, transfer: CFString, matrix: CFString) {
        switch colorSpace {
        case .srgb:
            (kCVImageBufferColorPrimaries_ITU_R_709_2, kCVImageBufferTransferFunction_sRGB, kCVImageBufferYCbCrMatrix_ITU_R_709_2)

        case .rec709:
            (
                kCVImageBufferColorPrimaries_ITU_R_709_2,
                kCVImageBufferTransferFunction_ITU_R_709_2,
                kCVImageBufferYCbCrMatrix_ITU_R_709_2
            )

        case .displayP3:
            (kCVImageBufferColorPrimaries_P3_D65, kCVImageBufferTransferFunction_sRGB, kCVImageBufferYCbCrMatrix_ITU_R_709_2)

        case .rec2020:
            (
                kCVImageBufferColorPrimaries_ITU_R_2020,
                kCVImageBufferTransferFunction_ITU_R_2020,
                kCVImageBufferYCbCrMatrix_ITU_R_2020
            )

        case .rec2100PQ:
            (
                kCVImageBufferColorPrimaries_ITU_R_2020,
                kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ,
                kCVImageBufferYCbCrMatrix_ITU_R_2020
            )

        case .rec2100HLG:
            (
                kCVImageBufferColorPrimaries_ITU_R_2020,
                kCVImageBufferTransferFunction_ITU_R_2100_HLG,
                kCVImageBufferYCbCrMatrix_ITU_R_2020
            )
        }
    }

    // MARK: - Initializer
    package init(
        size: Size,
        colorSpace: ColorSpace
    ) {
        self.size = size
        self.colorSpace = colorSpace
    }

    // MARK: - Public
    package func write(
        to path: String,
        red: Double,
        green: Double,
        blue: Double
    ) async throws {
        let url = URL(fileURLWithPath: path)
        let writer = try AVAssetWriter(outputURL: url, fileType: url.pathExtension == "mp4" ? .mp4 : .mov)
        let tags = tags
        var compression: [String: Any] = [AVVideoAllowFrameReorderingKey: false]
        if !isEightBit {
            compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel as String
        }
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: isEightBit ? AVVideoCodecType.h264 : AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: tags.primaries as String,
                AVVideoTransferFunctionKey: tags.transfer as String,
                AVVideoYCbCrMatrixKey: tags.matrix as String
            ],
            AVVideoCompressionPropertiesKey: compression
        ])
        video.mediaTimeScale = Self.timescale
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: isEightBit ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(video)
        guard writer.startWriting() else { throw writer.error ?? TestMediaError.unwritable(path) }
        writer.startSession(atSourceTime: .zero)

        do {
            try await wait(for: video, of: writer, path: path)
            let buffer = try pixelBuffer(from: adaptor, path: path, red: red, green: green, blue: blue)
            guard adaptor.append(buffer, withPresentationTime: .zero) else {
                throw writer.error ?? TestMediaError.unwritable(path)
            }
        } catch {
            writer.cancelWriting()
            throw error
        }
        video.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(Self.timescale), timescale: Self.timescale))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? TestMediaError.unwritable(path) }
    }

    // MARK: - Private
    // Waits until `input` takes more data. A writer that has stopped writing is an error.
    private func wait(
        for input: AVAssetWriterInput,
        of writer: AVAssetWriter,
        path: String
    ) async throws {
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else {
                throw writer.error ?? TestMediaError.unwritable(path)
            }

            try await Task.sleep(nanoseconds: 1_000_000)
        }
        guard writer.status == .writing else { throw writer.error ?? TestMediaError.unwritable(path) }
    }

    private func pixelBuffer(
        from adaptor: AVAssetWriterInputPixelBufferAdaptor,
        path: String,
        red: Double,
        green: Double,
        blue: Double
    ) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        guard
            let pool = adaptor.pixelBufferPool,
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created) == kCVReturnSuccess,
            let buffer = created
        else {
            throw TestMediaError.unwritable(path)
        }
        let tags = tags
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, tags.primaries, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, tags.transfer, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, tags.matrix, .shouldPropagate)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw TestMediaError.unwritable(path) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let width = Int(size.width)
        for row in 0..<Int(size.height) {
            let line = base.advanced(by: row * bytesPerRow)
            if isEightBit {
                let bytes = line.bindMemory(to: UInt8.self, capacity: width * 4)
                let code = { (value: Double) in UInt8((min(max(value, 0), 1) * 255).rounded()) }
                for column in 0..<width {
                    bytes[column * 4] = code(blue)
                    bytes[column * 4 + 1] = code(green)
                    bytes[column * 4 + 2] = code(red)
                    bytes[column * 4 + 3] = 255
                }
            } else {
                let halves = line.bindMemory(to: Float16.self, capacity: width * 4)
                for column in 0..<width {
                    halves[column * 4] = Float16(red)
                    halves[column * 4 + 1] = Float16(green)
                    halves[column * 4 + 2] = Float16(blue)
                    halves[column * 4 + 3] = 1
                }
            }
        }

        return buffer
    }
}
