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

    @Test("a title pinned onto its box enlarged 4 times has edges as sharp as the title scaled 4 times without a pin")
    func drawsEnlargedTitleSharp() throws {
        // Given
        let resolver = try DocumentResolver()
        let placeholder = try resolver.resolve(title(#""cornerPin": [[0, 0], [100, 0], [100, 100], [0, 100]]"#))
        guard case let .picture(.title(text), _) = try #require(placeholder.clips.first).content else {
            Issue.record("the clip is not a title")
            return
        }
        let (width, height) = (text.size.width * 4, text.size.height * 4)
        let enlarged = Quad(Rectangle(x: 320 - width / 2, y: 320 - height / 2, width: width, height: height))
        let pinned = try resolver.resolve(title(#""cornerPin": \#(written(enlarged))"#))
        let scaled = try resolver.resolve(title(#""placement": "center", "scale": 4"#))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let pinnedBitmap = try sut.frame(of: Evaluator().displayList(of: pinned, at: 0))
        let scaledBitmap = try sut.frame(of: Evaluator().displayList(of: scaled, at: 0))

        // Then
        // The title scaled without a pin is drawn at its scale, an edge at most one pixel of partial coverage. The
        // warp's area mean over the bilinear reconstruction of the raster spreads an edge over at most one pixel more,
        // so each edge is within 2 pixels, while a title drawn at its own size and enlarged 4 times after would spread
        // it over 5 or 6.
        let pinnedEdges = partialPixels(in: pinnedBitmap)
        let scaledEdges = partialPixels(in: scaledBitmap)
        #expect(scaledEdges.allSatisfy { $0 <= 1 }, "\(scaledEdges)")
        #expect(pinnedEdges.allSatisfy { $0 <= 2 }, "\(pinnedEdges) against \(scaledEdges)")
    }

    @Test("a page of a PDF pinned onto its box enlarged 4 times has edges as sharp as the pinned title's bound")
    func drawsEnlargedPageSharp() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("square.pdf")
        try PageWriter().write(width: 100, height: 100, content: "0 g 20 20 60 60 re f", to: path)
        let resolver = try DocumentResolver()
        let placeholder = try resolver.resolve(page(at: path, #""cornerPin": [[0, 0], [100, 0], [100, 100], [0, 100]]"#))
        let size = try #require(placeholder.clips.first?.cornerPin?.size)
        let (width, height) = (size.width * 4, size.height * 4)
        let enlarged = Quad(Rectangle(x: 320 - width / 2, y: 320 - height / 2, width: width, height: height))
        let pinned = try resolver.resolve(page(at: path, #""cornerPin": \#(written(enlarged))"#))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let bitmap = try sut.frame(of: Evaluator().displayList(of: pinned, at: 0))

        // Then
        // The page is asked for at the scale its pinned list is drawn at, so its square's edges spread over at most
        // the one pixel the warp adds to a sharp edge, as the pinned title's, where a page drawn at its own size and
        // enlarged 4 times after would spread them over 5 or 6.
        let edges = partialPixels(in: bitmap)
        #expect(edges.allSatisfy { $0 <= 2 }, "\(edges)")
        #expect(bitmap.pixel(x: 320, y: 320)[3] > 0.999)
    }

    // MARK: - Private
    // A 640 × 640 sequence on a transparent background holding the page of a PDF at `path` with the given keys.
    private func page(
        at path: String,
        _ keys: String
    ) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [640, 640], "fps": 10, "background": "#00000000", "colorSpace": "srgb" },
              "storyline": [ { "solid": "#00000000", "duration": 1 } ],
              "clips": [ { "media": { "file": "\#(path)", "page": 1 }, "at": [0, 1], \#(keys) } ] }
            """#
    }

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

    // A 640 × 640 sequence on a transparent background holding a white "I" with the given keys.
    private func title(_ keys: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [640, 640], "fps": 10, "background": "#00000000", "colorSpace": "srgb" },
              "theme": { "baseWidth": 640, "styles": { "headline": { "size": 100, "color": "#FFFFFF" } } },
              "storyline": [ { "solid": "#00000000", "duration": 1 } ],
              "clips": [ { "title": "I", "style": "headline", "at": [0, 1], \#(keys) } ] }
            """#
    }

    // The number of pixels whose alpha lies between 0.1 and 0.9 at each of the four edges the middle row and the
    // middle column of what is drawn cross: left, right, top, bottom.
    private func partialPixels(in bitmap: Bitmap) -> [Int] {
        let alpha = { (x: Int, y: Int) in bitmap.pixel(x: x, y: y)[3] }
        let drawn = (0..<bitmap.height).flatMap { y in (0..<bitmap.width).map { x in (x, y) } }
            .filter { x, y in alpha(x, y) > 0.5 }
        let columns = drawn.map { $0.0 }
        let rows = drawn.map { $0.1 }
        let column = ((columns.min() ?? 0) + (columns.max() ?? 0)) / 2
        let row = ((rows.min() ?? 0) + (rows.max() ?? 0)) / 2
        let isPartial = { (value: Double) in value > 0.1 && value < 0.9 }
        let across = (0..<bitmap.width).filter { isPartial(alpha($0, row)) }
        let down = (0..<bitmap.height).filter { isPartial(alpha(column, $0)) }

        return [
            across.filter { $0 < column }.count,
            across.filter { $0 > column }.count,
            down.filter { $0 < row }.count,
            down.filter { $0 > row }.count
        ]
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
