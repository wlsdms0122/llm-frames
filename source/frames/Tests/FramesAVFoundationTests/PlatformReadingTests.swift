//
//  PlatformReadingTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/20/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

// The decoder's colour reading of a file, and its `platform` reading: Core Image's colour management into a colour
// space, taken to working values by that space's formulas.
@Suite("Platform Reading Tests", .serialized)
struct PlatformReadingTests {
    // MARK: - Property
    private static let size = Size(width: 4, height: 2)
    private static let color = RGB(red: 0.6, green: 0.3, blue: 0.2)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a PNG the encoder writes in a colour space is read by the formulas of that space",
        arguments: ColorSpace.allCases
    )
    func readsWrittenSpace(space: ColorSpace) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.png")
        try AVFoundationEncoder().writeImage(
            picture(),
            for: .png(path: path, size: Self.size, depth: .sixteen, output: ColorConversion(space: space))
        )

        // When
        let reading = try AVFoundationDecoder().colorReading(of: MediaFile.still(path))

        // Then
        #expect(reading == .formulas(space))
    }

    @Test(
        "a platform reading into any colour space gives the working values of the picture",
        arguments: [ColorSpace.srgb, .displayP3, .rec709, .rec2100PQ]
    )
    func readsByPlatform(space: ColorSpace) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.png")
        try AVFoundationEncoder().writeImage(picture(), for: .png(path: path, size: Self.size, depth: .sixteen))

        // When
        let read = try AVFoundationDecoder().picture(
            of: MediaFile.still(path),
            atFrame: 0,
            reading: .platform(colorSpace: space)
        ).bitmap

        // Then
        #expect(read.depth == .halfFloat)
        let components = read.pixels.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            buffer.bindMemory(to: Float16.self).prefix(4).map(Double.init)
        }
        #expect(abs(components[0] - Self.color.red) < 0.005)
        #expect(abs(components[1] - Self.color.green) < 0.005)
        #expect(abs(components[2] - Self.color.blue) < 0.005)
        #expect(components[3] == 1)
    }

    // MARK: - Private
    private func picture() -> Bitmap {
        let count = Int(Self.size.width * Self.size.height)
        let components: [Float16] = (0..<count).flatMap { _ in
            [Float16(Self.color.red), Float16(Self.color.green), Float16(Self.color.blue), 1]
        }

        return Bitmap(
            width: Int(Self.size.width),
            height: Int(Self.size.height),
            depth: .halfFloat,
            bytesPerRow: Int(Self.size.width) * 8,
            pixels: components.withUnsafeBytes { Data($0) }
        )
    }
}
