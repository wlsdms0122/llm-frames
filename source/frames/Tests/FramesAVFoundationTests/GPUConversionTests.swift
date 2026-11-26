//
//  GPUConversionTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import Metal
import Testing

// Serialized, so that the tests running at once read far fewer files with AVFoundation than the 64 at once at which its
// reads stop finishing (FRAMES-21 Notes).
@Suite(
    "GPU Conversion Tests",
    .serialized,
    .ownThread,
    .enabled(if: MTLCreateSystemDefaultDevice() != nil, "the GPU conversion needs a Metal device")
)
struct GPUConversionTests {
    // MARK: - Property
    // The media time of each frame `writeGradient(to:colorSpace:)` writes, at 30 frames a second.
    private static let gradientFrameTimes = (0..<3).map { Double($0) / 30 }
    // The tolerance of a working value converted on the GPU against the same one converted on the CPU (FRAMES-24
    // Tolerances): each component within `largest` × max(1, |v|), and their mean difference within `mean`.
    private static let largest = 0x1p-10
    private static let mean = 0x1p-18

    private let size = Size(width: 640, height: 360)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a video's frames converted on the GPU lie within the tolerance of those converted on the CPU",
        arguments: [ColorSpace.displayP3, .rec2020, .rec709, .srgb]
    )
    func convertsWithinTolerance(colorSpace: ColorSpace) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("\(colorSpace.rawValue).mov")
        try await writeGradient(to: file, colorSpace: colorSpace)
        let media = MediaFile.video(file, frameTimes: Self.gradientFrameTimes)
        let sut = AVFoundationDecoder(conversion: .gpu)
        let reference = AVFoundationDecoder(conversion: .cpu)

        for frame in 0..<3 {
            // When
            let converted = try sut.picture(of: media, atFrame: frame, play: .file, reading: .tagged)
            let expected = try reference.picture(of: media, atFrame: frame, play: .file, reading: .tagged)

            // Then
            guard case .surface = converted else {
                Issue.record("frame \(frame) was not converted on the GPU")
                return
            }
            let difference = Self.difference(of: converted.bitmap, from: expected.bitmap)
            print("\(colorSpace.rawValue) frame \(frame): largest \(difference.largest), mean \(difference.mean)")
            #expect(difference.largest <= Self.largest, "\(difference.largest)")
            #expect(difference.mean <= Self.mean, "\(difference.mean)")
        }
    }

    @Test("a frame converted on the GPU twice gives the same bytes")
    func convertsDeterministically() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("p3.mov")
        try await writeGradient(to: file, colorSpace: .displayP3)
        let media = MediaFile.video(file, frameTimes: Self.gradientFrameTimes)

        // When
        let first = try AVFoundationDecoder(conversion: .gpu).picture(of: media, atFrame: 1, play: .file, reading: .tagged)
        let second = try AVFoundationDecoder(conversion: .gpu).picture(of: media, atFrame: 1, play: .file, reading: .tagged)

        // Then
        #expect(first.bitmap.pixels == second.bitmap.pixels)
    }

    @Test("a turned video's frames converted on the GPU are those converted on the CPU, turned the same way")
    func turnsAsTheCPUDoes() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("recording.mov")
        _ = try await ScreenRecording().write(to: file)
        let media = MediaFile.video(file, frameTimes: ScreenRecording.frameTimes)
        let sut = AVFoundationDecoder(conversion: .gpu)

        // When
        let converted = try sut.picture(of: media, atFrame: 3, play: .file, reading: .tagged)
        let expected = try AVFoundationDecoder(conversion: .cpu).picture(of: media, atFrame: 3, play: .file, reading: .tagged)

        // Then
        guard case .surface = converted else {
            Issue.record("the frame was not converted on the GPU")
            return
        }
        #expect(converted.width == expected.width && converted.height == expected.height)
        #expect(Self.difference(of: converted.bitmap, from: expected.bitmap).largest <= Self.largest)
    }

    @Test(
        "the report names the processor each medium was converted on",
        arguments: [(ConversionDevice.gpu, ConversionDevice.gpu), (.cpu, .cpu)]
    )
    func reportsDevice(
        conversion: ConversionDevice,
        device: ConversionDevice
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("p3.mov")
        try await writeGradient(to: file, colorSpace: .displayP3)
        let sut = AVFoundationDecoder(conversion: conversion)

        // When
        let media = MediaFile.video(file, frameTimes: Self.gradientFrameTimes)
        _ = try sut.picture(of: media, atFrame: 0, play: .file, reading: .tagged)
        _ = try sut.picture(of: media, atFrame: 0, play: .file, reading: .analysis(colorSpace: nil))

        // Then
        let devices = sut.readings().media.map { "\($0.conversion.name) \($0.device.name)" }
        #expect(devices == ["space \(device.name)", "space cpu"].uniqued())
    }

    // MARK: - Private
    // Three frames of a gradient, red across, green down and blue by frame, a little beyond 0 to 1 where the space is
    // written at ten bits from half floats.
    private func writeGradient(
        to file: String,
        colorSpace: ColorSpace
    ) async throws {
        let width = Double(size.width - 1)
        let height = Double(size.height - 1)
        try await ColorMovieWriter(size: size, colorSpace: colorSpace).write(to: file, frames: 3) { frame, x, y in
            (Double(x) / width * 1.1 - 0.05, Double(y) / height, Double(frame + 1) / 4)
        }
    }

    // The largest difference of a component from the reference's v, over max(1, |v|), and the mean difference of
    // every component, rows of each bitmap read at its own bytes per row.
    private static func difference(
        of bitmap: Bitmap,
        from reference: Bitmap
    ) -> (largest: Double, mean: Double) {
        var largest = 0.0
        var sum = 0.0
        let rowLength = bitmap.width * 4
        bitmap.pixels.withUnsafeBytes { converted in
            reference.pixels.withUnsafeBytes { expected in
                for row in 0..<bitmap.height {
                    let left = converted.baseAddress!.advanced(by: row * bitmap.bytesPerRow)
                        .assumingMemoryBound(to: Float16.self)
                    let right = expected.baseAddress!.advanced(by: row * reference.bytesPerRow)
                        .assumingMemoryBound(to: Float16.self)
                    for index in 0..<rowLength {
                        let value = Double(right[index])
                        let difference = abs(Double(left[index]) - value)
                        largest = max(largest, difference / max(1, abs(value)))
                        sum += difference
                    }
                }
            }
        }

        return (largest, sum / Double(rowLength * bitmap.height))
    }
}

extension [String] {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The strings in order with each one after its first dropped.
    fileprivate func uniqued() -> [String] {
        reduce(into: []) { kept, string in
            if !kept.contains(string) { kept.append(string) }
        }
    }

    // MARK: - Private
}
