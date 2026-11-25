//
//  DisplacementRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// A `displace` filter op (FRAMES-15 Displacement) on a clip's picture and on an adjustment clip, its map a PNG file,
// resolved on the real providers and drawn by the real decoder and renderer. Serialized, since AVAssetReader needs a
// free thread of the shared pool.
@Suite("Displacement Render Tests", .serialized)
struct DisplacementRenderTests {
    // MARK: - Property
    // A half float lies within 2^-11 of a value from 0.5 to 1, and Core Graphics takes an eight bit colour into it to
    // within that step.
    private let exact = 1.0 / 2048
    // Theme lengths at the default base width of 1920 on a frame 160 wide, so 12 of them are one output pixel.
    private let lengthsPerPixel = 12.0

    // MARK: - Initializer
    // MARK: - Test
    @Test("a clip's picture at its own size is moved by amount output pixels, the edge pixels extended outward")
    func movesClipPicture() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("pattern.png")
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: file) { canvas in
            for y in 0..<90 {
                for x in 0..<160 {
                    let color = patternColor(x: x, y: y)
                    canvas.fill(Rectangle(x: Double(x), y: Double(y), width: 1, height: 1), red: color[0], green: color[1], blue: color[2])
                }
            }
        }
        let map = try uniformMap(in: directory, red: 65535, green: 0)
        let document = try DocumentResolver(presets: ["filter/shift": shift(map, amount: 3 * lengthsPerPixel)]).resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 1, "filter": "mine/shift" } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.5))

        // Then
        // Red 1 reads from 3 pixels to the right and green 0 from 3 above.
        var differences: [(Int, Int)] = []
        for y in 0..<90 {
            for x in 0..<160 {
                let read = patternColor(x: min(x + 3, 159), y: max(y - 3, 0)).map { Double(Float16($0 / 255)) * 255 }
                if !frame.isPixel(x: x, y: y, read, tolerance: exact) {
                    differences.append((x, y))
                }
            }
        }
        #expect(differences.isEmpty, "\(differences.count) pixels differ, first at \(differences.prefix(4))")
    }

    @Test("a clip shown at half size moves by half its amount in output pixels, as its lengths are in its box's pixels")
    func scalesMoveWithClip() throws {
        // Given
        let directory = try TemporaryDirectory()
        let halves = try halvesImage(in: directory)
        let map = try uniformMap(in: directory, red: 65535, green: 32768)
        let document = try DocumentResolver(presets: ["filter/shift": shift(map, amount: 8 * lengthsPerPixel)]).resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(halves)", "duration": 1, "filter": "mine/shift", "scale": 0.5 } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.5))

        // Then
        // The picture covers [40, 120) by [22.5, 67.5), its halves meeting at 80, which a move of 8 pixels of the
        // frame at half size takes to 76.
        #expect(frame.isPixel(x: 75, y: 45, [255, 0, 0], tolerance: exact), "\(frame.pixel(x: 75, y: 45))")
        #expect(frame.isPixel(x: 76, y: 45, [0, 255, 0], tolerance: exact), "\(frame.pixel(x: 76, y: 45))")
        #expect(frame.isPixel(x: 115, y: 45, [0, 255, 0], tolerance: exact), "\(frame.pixel(x: 115, y: 45))")
    }

    @Test("an adjustment clip moves the backdrop it filters by its map")
    func movesAdjustedBackdrop() throws {
        // Given
        let directory = try TemporaryDirectory()
        let halves = try halvesImage(in: directory)
        let map = try uniformMap(in: directory, red: 0, green: 32768)
        let document = try DocumentResolver(presets: ["filter/shift": shift(map, amount: 5 * lengthsPerPixel)]).resolve(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(halves)", "duration": 1 } ],
              "clips": [ { "kind": "adjustment", "adjust": "mine/shift", "at": [0, 1] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.5))

        // Then
        // Red 0 reads from 5 pixels to the left, so the halves meet at 85.
        #expect(frame.isPixel(x: 84, y: 45, [255, 0, 0], tolerance: exact), "\(frame.pixel(x: 84, y: 45))")
        #expect(frame.isPixel(x: 85, y: 45, [0, 255, 0], tolerance: exact), "\(frame.pixel(x: 85, y: 45))")
        #expect(frame.isPixel(x: 2, y: 45, [255, 0, 0], tolerance: exact), "\(frame.pixel(x: 2, y: 45))")
    }

    // MARK: - Private
    private func shift(
        _ map: String,
        amount: Double
    ) -> String {
        #"{ "description": "moves the picture", "ops": [ { "kind": "displace", "file": "\#(map)", "amount": \#(amount) } ] }"#
    }

    // A 16-bit map of one value, 2 by 2.
    private func uniformMap(
        in directory: TemporaryDirectory,
        red: Int,
        green: Int
    ) throws -> String {
        let file = directory.file("map.png")
        try DisplacementMapWriter(size: Size(width: 2, height: 2)).write(to: file) { _, _ in (red, green) }

        return file
    }

    // A 160 by 90 image, red left of 80 and green from it.
    private func halvesImage(in directory: TemporaryDirectory) throws -> String {
        let file = directory.file("halves.png")
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: file) { canvas in
            canvas.fill(Rectangle(x: 0, y: 0, width: 80, height: 90), red: 255, green: 0, blue: 0)
            canvas.fill(Rectangle(x: 80, y: 0, width: 80, height: 90), red: 0, green: 255, blue: 0)
        }

        return file
    }

    // A colour for every pixel, so a pixel moved, blended or resampled shows.
    private func patternColor(
        x: Int,
        y: Int
    ) -> [Double] {
        [Double((x * 37 + y * 11) % 256), Double((x * 5 + y * 53) % 256), Double((x * y + 17) % 256)]
    }
}
