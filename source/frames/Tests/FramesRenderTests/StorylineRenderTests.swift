//
//  StorylineRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Storyline pictures drawn by the real decoder and renderer from documents resolved on the real providers, read as
// frames before encoding. Serialized, since AVAssetReader needs a free thread of the shared pool.
@Suite("Storyline Render Tests", .serialized)
struct StorylineRenderTests {
    // MARK: - Property
    // A sixteen bit frame reproduces an eight bit colour to within one sixteen bit step.
    private let exact = 1.0 / 65535
    // Resampled and filtered colours keep to within one eight bit step.
    private let tolerance = 1.0 / 255
    private let presets = [
        "transition/inset-in": #"""
            { "description": "the incoming clip at half size over the outgoing one", "seconds": 1,
              "incoming": { "keys": [ { "t": 0, "scale": 0.5 }, { "t": 1, "scale": 0.5 } ] } }
            """#,
        "transition/inset-out": #"""
            { "description": "the outgoing clip at half size over the incoming one", "seconds": 1, "over": "outgoing",
              "outgoing": { "keys": [ { "t": 0, "scale": 0.5 }, { "t": 1, "scale": 0.5 } ] } }
            """#,
        "transition/grow": #"""
            { "description": "the incoming clip grows in from the right as the outgoing one leaves left", "seconds": 1,
              "ease": "linear",
              "incoming": { "keys": [ { "t": 0, "scale": 1.5, "x": 0.25 }, { "t": 1, "scale": 1, "x": 0 } ] },
              "outgoing": { "keys": [ { "t": 0, "x": 0 }, { "t": 1, "x": -0.5 } ] } }
            """#,
        "filter/grade": #"""
            { "description": "grain over a soft blur", "ops": [
              { "op": "saturation", "amount": 1.4 }, { "op": "blur", "radius": 2 }, { "op": "grain", "amount": 0.5, "size": 1 } ] }
            """#
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("nothing of a cropped, filled or moving storyline clip shows outside the content rect")
    func keepsInsideContentRect() throws {
        // Given
        let directory = try TemporaryDirectory()
        let square = try image(in: directory, named: "square.png", width: 200, height: 200, color: [0, 255, 0])
        let wide = try image(in: directory, named: "wide.png", width: 300, height: 100, color: [255, 255, 0])
        let document = try DocumentResolver(presets: presets).resolve(#"""
            { "kind": "sequence",
              "format": { "size": [160, 90], "fps": 10, "background": "#0000FF", "inset": [10, 20, 10, 20], "conform": "fill" },
              "storyline": [
                { "media": "\#(square)", "duration": 1,
                  "keyframes": [ { "at": 0, "crop": { "scale": 1 } }, { "at": 1, "crop": [150, 0, 50, 50] } ] },
                { "media": "\#(wide)", "duration": 1, "transition": "mine/grow" } ] }
            """#)
        let content = document.format.content
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frames = try (0..<20).map { index in
            try sut.frame(of: Evaluator().displayList(of: document, at: Double(index) / 10))
        }

        // Then
        for (index, frame) in frames.enumerated() {
            let leaks = outsidePixels(of: content, in: frame).filter { x, y in
                !frame.isPixel(x: x, y: y, [0, 0, 255], tolerance: exact)
            }
            #expect(leaks.isEmpty, "frame \(index) shows a clip at \(leaks.prefix(4)) outside \(content)")
            #expect(!frame.isPixel(x: 80, y: 45, [0, 0, 255], tolerance: tolerance), "frame \(index) shows no clip")
        }
    }

    @Test(
        "during a transition both units show, the incoming one above unless the preset puts the outgoing one there",
        arguments: [
            ("inset-in", [0.0, 255, 0], [255.0, 0, 0]),
            ("inset-out", [255.0, 0, 0], [0.0, 255, 0])
        ]
    )
    func stacksTransitionUnits(
        transition: String,
        middle: [Double],
        rim: [Double]
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let outgoing = try image(in: directory, named: "red.png", width: 160, height: 90, color: [255, 0, 0])
        let incoming = try image(in: directory, named: "green.png", width: 160, height: 90, color: [0, 255, 0])
        let document = try DocumentResolver(presets: presets).resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "media": "\#(outgoing)", "duration": 1 },
                             { "media": "\#(incoming)", "duration": 1, "transition": "mine/\#(transition)" } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.frame(of: Evaluator().displayList(of: document, at: 1))

        // Then
        // The unit at half size covers [40, 120) by [22.5, 67.5) around the centre of the content rect.
        #expect(frame.isPixel(x: 80, y: 45, middle, tolerance: tolerance), "\(frame.pixel(x: 80, y: 45))")
        #expect(frame.isPixel(x: 50, y: 30, middle, tolerance: tolerance), "\(frame.pixel(x: 50, y: 30))")
        #expect(frame.isPixel(x: 10, y: 45, rim, tolerance: tolerance), "\(frame.pixel(x: 10, y: 45))")
        #expect(frame.isPixel(x: 80, y: 10, rim, tolerance: tolerance), "\(frame.pixel(x: 80, y: 10))")
    }

    @Test("a storyline image at its own size on the output is drawn pixel for pixel")
    func drawsImageAtOwnSize() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("pattern.png")
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: file) { canvas in
            for y in 0..<90 {
                for x in 0..<160 {
                    let color = patternColor(x: x, y: y)
                    let pixel = Rectangle(x: Double(x), y: Double(y), width: 1, height: 1)
                    canvas.fill(pixel, red: color[0], green: color[1], blue: color[2])
                }
            }
        }
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "media": "\#(file)", "duration": 1 } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.frame(of: Evaluator().displayList(of: document, at: 0.5))

        // Then
        #expect(frame.width == 160 && frame.height == 90)
        var differences: [(Int, Int)] = []
        for y in 0..<90 {
            for x in 0..<160 where !frame.isPixel(x: x, y: y, patternColor(x: x, y: y), tolerance: exact) {
                differences.append((x, y))
            }
        }
        #expect(differences.isEmpty, "\(differences.count) pixels differ, first at \(differences.prefix(4))")
    }

    @Test("a document evaluated twice at one time gives one display list, and its frame rendered twice the same bytes")
    func rendersSameFrameTwice() throws {
        // Given
        let directory = try TemporaryDirectory()
        let outgoing = try image(in: directory, named: "red.png", width: 160, height: 90, color: [200, 40, 40])
        let incoming = try image(in: directory, named: "green.png", width: 160, height: 90, color: [40, 200, 40])
        let document = try DocumentResolver(presets: presets).resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "media": "\#(outgoing)", "duration": 1, "filter": "mine/grade" },
                             { "media": "\#(incoming)", "duration": 1, "filter": "mine/grade", "transition": "mine/grow" } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let lists = (0..<2).map { _ in Evaluator().displayList(of: document, at: 1.1) }
        let frames = try (0..<2).map { _ in try sut.frame(of: lists[0]) }
        let fresh = try QuartzRenderer(decoder: AVFoundationDecoder()).frame(of: lists[0])

        // Then
        #expect(lists[0] == lists[1])
        #expect(frames[0].pixels == frames[1].pixels)
        #expect(fresh.pixels == frames[0].pixels)
    }

    // MARK: - Private
    private func image(
        in directory: TemporaryDirectory,
        named name: String,
        width: Double,
        height: Double,
        color: [Double]
    ) throws -> String {
        let file = directory.file(name)
        try ImageWriter(size: Size(width: width, height: height)).write(to: file) { canvas in
            canvas.fill(red: color[0], green: color[1], blue: color[2])
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

    // The pixels wholly outside `content`.
    private func outsidePixels(
        of content: Rectangle,
        in frame: Bitmap
    ) -> [(Int, Int)] {
        (0..<frame.height).flatMap { y in
            (0..<frame.width).compactMap { x -> (Int, Int)? in
                let isOutside = Double(x + 1) <= content.x || Double(x) >= content.maxX
                    || Double(y + 1) <= content.y || Double(y) >= content.maxY

                return isOutside ? (x, y) : nil
            }
        }
    }
}
