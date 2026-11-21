//
//  CornerPinRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Clips with corner pins resolved on the real providers, evaluated, and drawn by the real decoder and renderer
// (FRAMES-24). Serialized, since the stills are large and the reference mean takes every processor.
@Suite("Corner Pin Render Tests", .serialized)
struct CornerPinRenderTests {
    // MARK: - Property
    private static let mild = Quad(
        topLeft: Point(x: 190, y: 164),
        topRight: Point(x: 840, y: 124),
        bottomRight: Point(x: 880, y: 854),
        bottomLeft: Point(x: 150, y: 904)
    )
    private static let steep = Quad(
        topLeft: Point(x: 462, y: 24),
        topRight: Point(x: 562, y: 24),
        bottomRight: Point(x: 1012, y: 1004),
        bottomLeft: Point(x: 12, y: 1004)
    )
    private static let box = Quad(Rectangle(x: 0, y: 0, width: 1024, height: 1024))

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a still drawn by a clip with a corner pin, through resolve, evaluation and the renderer, lies within FRAMES-24's bounds of the area mean",
        arguments: [
            (CornerPinStill.checkerboard, "mild"),
            (.checkerboard, "steep"),
            (.grid, "mild"),
            (.grid, "steep")
        ]
    )
    func samplesAreaThroughWholePath(
        still: CornerPinStill,
        pin: String
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("\(still).png")
        try still.write(to: path)
        let cornerPin = pin == "mild" ? Self.mild : Self.steep
        let document = try DocumentResolver().resolve(self.document(showing: path, cornerPin: written(cornerPin)))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let bitmap = try sut.frame(of: Evaluator().displayList(of: document, at: 0))

        // Then
        let homography = try #require(Homography(from: Self.box, to: cornerPin))
        let mean = AreaMean(
            carrying: still.pixels,
            width: CornerPinStill.side,
            height: CornerPinStill.side,
            through: homography,
            outputWidth: CornerPinStill.side,
            outputHeight: CornerPinStill.side
        )
        var largest = 0.0
        var sum = 0.0
        var count = 0
        for row in 0..<CornerPinStill.side {
            for column in 0..<CornerPinStill.side {
                let drawn = bitmap.pixel(x: column, y: row)
                let start = (row * CornerPinStill.side + column) * 4
                let expected = mean.pixels[start..<start + 4].map(Double.init)
                guard drawn.contains(where: { $0 != 0 }) || expected.contains(where: { $0 != 0 }) else { continue }

                for (value, reference) in zip(drawn, expected) {
                    largest = max(largest, abs(value - reference))
                    sum += abs(value - reference)
                    count += 4
                }
            }
        }
        #expect(count > 100_000)
        #expect(largest <= 0.1, "largest \(largest)")
        #expect(sum / Double(count) <= 0.005, "mean \(sum / Double(count))")
    }

    @Test("a clip whose corner pin is its own box draws as the clip without one, away from the pattern's edges")
    func drawsIdentityPinAsUnpinned() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("checkerboard.png")
        try CornerPinStill.checkerboard.write(to: path)
        let resolver = try DocumentResolver()
        let pinned = try resolver.resolve(document(showing: path, cornerPin: written(Self.box)))
        let unpinned = try resolver.resolve(document(showing: path, cornerPin: nil))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let pinnedBitmap = try sut.frame(of: Evaluator().displayList(of: pinned, at: 0))
        let unpinnedBitmap = try sut.frame(of: Evaluator().displayList(of: unpinned, at: 0))

        // Then
        // The mean over a pixel of the bilinear reconstruction is the pixel's value where its neighbours carry the
        // same colour, so only pixels next to a square's edge or the picture's may differ.
        var compared = 0
        for row in 0..<CornerPinStill.side where !isNearEdge(row) {
            for column in 0..<CornerPinStill.side where !isNearEdge(column) {
                let drawn = pinnedBitmap.pixel(x: column, y: row)
                let expected = unpinnedBitmap.pixel(x: column, y: row)
                compared += 1
                guard zip(drawn, expected).allSatisfy({ abs($0 - $1) <= 2e-3 }) else {
                    Issue.record("\(drawn) at \(column), \(row) is not \(expected)")
                    return
                }
            }
        }
        #expect(compared > 800_000)
    }

    @Test("a corner pin keyframed through a crossed quad draws nothing while it is crossed, and draws on either side")
    func drawsNothingWhileCrossed() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("grid.png")
        try CornerPinStill.grid.write(to: path)
        // The top corners pass each other at 0.5 and the bottom ones at 2 / 3, so at 0.6 the quad is crossed, its
        // horizon through the box.
        let document = try DocumentResolver().resolve(##"""
            { "kind": "sequence", "format": { "size": [1024, 1024], "fps": 10, "background": "#00000000", "colorSpace": "srgb" },
              "storyline": [ { "media": "\##(path)", "duration": 1,
                               "keyframes": [ { "at": 0, "cornerPin": [[100, 100], [900, 100], [900, 900], [100, 900]], "ease": "linear" },
                                              { "at": 1, "cornerPin": [[900, 100], [100, 100], [300, 900], [700, 900]] } ] } ] }
            """##)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let before = try sut.frame(of: Evaluator().displayList(of: document, at: 0.2))
        let crossed = try sut.frame(of: Evaluator().displayList(of: document, at: 0.6))
        let after = try sut.frame(of: Evaluator().displayList(of: document, at: 0.9))

        // Then
        #expect(before.pixel(x: 512, y: 500)[3] > 0.999)
        #expect(after.pixel(x: 512, y: 600)[3] > 0.999)
        #expect(crossed.pixels.allSatisfy { $0 == 0 })
    }

    @Test("a child of a clip with a corner pin is drawn in the space the corner pin is written in, not on its plane")
    func drawsChildInWrittenSpace() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("grid.png")
        try CornerPinStill.grid.write(to: path)
        let document = try DocumentResolver().resolve(##"""
            { "kind": "sequence", "format": { "size": [1024, 1024], "fps": 10, "background": "#00000000", "colorSpace": "srgb" },
              "storyline": [ { "media": "\##(path)", "duration": 1, "opacity": 0 } ],
              "clips": [ { "id": "card", "media": "\##(path)", "width": 1024, "at": [0, 1], "cornerPin": \##(written(Self.steep)) },
                         { "id": "dot", "shape": "rect", "area": [700, 100, 200, 100], "fill": "#FF0000", "parent": "card", "at": [0, 1] } ] }
            """##)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let bitmap = try sut.frame(of: Evaluator().displayList(of: document, at: 0.5))

        // Then
        // The dot lies to the right of the steep corner pin's far edge, as written in the frame.
        #expect(bitmap.pixel(x: 702, y: 102) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 897, y: 197) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 697, y: 150)[3] == 0)
        #expect(bitmap.pixel(x: 512, y: 512)[3] > 0.999)
    }

    // MARK: - Private
    // A 1024 × 1024 sequence on a transparent background whose storyline clip shows the still at its own pixels.
    private func document(
        showing path: String,
        cornerPin: String?
    ) -> String {
        let pin = cornerPin.map { #", "cornerPin": \#($0)"# } ?? ""

        return ##"""
            { "kind": "sequence", "format": { "size": [1024, 1024], "fps": 10, "background": "#00000000", "colorSpace": "srgb" },
              "storyline": [ { "media": "\##(path)", "duration": 1\##(pin) } ] }
            """##
    }

    private func written(_ quad: Quad) -> String {
        "[" + quad.corners.map { "[\($0.x), \($0.y)]" }.joined(separator: ", ") + "]"
    }

    // Within two pixels of a multiple of 32, where a square or the picture ends.
    private func isNearEdge(_ index: Int) -> Bool {
        let offset = index % 32
        return offset < 2 || offset >= 30
    }
}
