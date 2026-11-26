//
//  FrameCapturingEncoder.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import Frames
import FramesAVFoundation
import os

// An encoder that checks every target and writes every still as `avfoundation` does, and keeps the bytes of each video
// frame it is handed, row by row without what pads a row, in place of writing a video.
final class FrameCapturingEncoder: Encoder {
    // MARK: - Property
    private let encoder = AVFoundationEncoder()
    private let frames = OSAllocatedUnfairLock<[Data]>(initialState: [])

    // The bytes of every frame handed to a video writer, in the order handed.
    var captured: [Data] {
        frames.withLock { $0 }
    }

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func check(_ target: EncodeTarget) throws {
        try encoder.check(target)
    }

    func check(_ target: ImageTarget) throws {
        try encoder.check(target)
    }

    func check(_ target: SoundTarget) throws {
        try encoder.check(target)
    }

    func writeAnalysisPicture(
        of frame: Bitmap,
        in output: ColorConversion,
        to path: String
    ) throws {
        try encoder.writeAnalysisPicture(of: frame, in: output, to: path)
    }

    func writeImage(
        _ bitmap: Bitmap,
        for target: ImageTarget
    ) throws -> FileEncoding {
        try encoder.writeImage(bitmap, for: target)
    }

    func writeSound(
        _ sound: SoundBuffer,
        for target: SoundTarget
    ) throws {
        try encoder.writeSound(sound, for: target)
    }

    func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter {
        Writer(path: target.path, frames: frames)
    }

    // MARK: - Private
}

extension FrameCapturingEncoder {
    // Keeps each frame's rows in `frames`.
    private struct Writer: VideoWriter {
        // MARK: - Property
        let path: String
        let frames: OSAllocatedUnfairLock<[Data]>

        var encoding: FileEncoding {
            FileEncoding(path: path, codec: "none", usesHardware: false, device: .cpu, seconds: StageTimes())
        }

        // MARK: - Initializer
        // MARK: - Public
        func append(_ frame: Pixels) throws {
            let bitmap = frame.bitmap
            var rows = Data()
            let rowLength = bitmap.width * 8
            for y in 0..<bitmap.height {
                rows.append(bitmap.pixels.subdata(in: y * bitmap.bytesPerRow..<y * bitmap.bytesPerRow + rowLength))
            }
            frames.withLock { [rows] in $0.append(rows) }
        }

        func finish() throws { }

        // MARK: - Private
    }
}
