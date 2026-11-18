//
//  ConnectedClipRenderTests.swift
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

// Connected and sequence clips drawn by the real decoder and renderer from documents resolved on the real providers,
// read as frames before encoding. Serialized, since AVAssetReader needs a free thread of the shared pool.
@Suite("Connected Clip Render Tests", .serialized)
struct ConnectedClipRenderTests {
    // MARK: - Property
    // Pixels and their colours at the middle of each transition into the green picture, whose magenta stripe covers
    // rows 30 to 60: above the white cover, whole while the picture is wiped in on the left half, and slid half way in
    // from the right with the picture.
    private static let transitionProbes: [(String, [(Int, Int, [Double])])] = [
        ("dip", [(40, 45, [255, 0, 255]), (120, 45, [255, 0, 255]), (80, 15, [255, 255, 255])]),
        ("wipe", [(40, 45, [255, 0, 255]), (120, 45, [255, 0, 255]), (40, 15, [0, 255, 0]), (120, 15, [255, 0, 0])]),
        ("slide", [(40, 45, [255, 0, 0]), (120, 45, [255, 0, 255]), (120, 15, [0, 255, 0]), (40, 15, [255, 0, 0])])
    ]

    // Resampled colours keep to within one eight bit step, and a picture decoded from H.264 to within a few.
    private let tolerance = 1.0 / 255
    private let decodedTolerance = 6.0 / 255
    private let presets = [
        "transition/dip": #"""
            { "description": "a dip to white", "seconds": 1, "ease": "linear",
              "cover": { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
            """#,
        "transition/wipe": #"""
            { "description": "the incoming clip wiped in from the left", "seconds": 1, "ease": "linear",
              "incoming": { "revealFrom": "left", "keys": [ { "t": 0, "reveal": 0 }, { "t": 1, "reveal": 1 } ] } }
            """#,
        "transition/slide": #"""
            { "description": "the incoming clip slides in from the right", "seconds": 1, "ease": "linear",
              "incoming": { "keys": [ { "t": 0, "x": 1 }, { "t": 1, "x": 0 } ] } }
            """#
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a connected clip plays its whole window across the edit point and stops at its end")
    func playsAcrossEditPoint() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let outgoing = try image(in: directory, named: "red.png", width: 160, height: 90, color: [255, 0, 0])
        let incoming = try image(in: directory, named: "green.png", width: 160, height: 90, color: [0, 255, 0])
        let code = directory.file("code.mov")
        let codeTimes = (0..<6).map { Double($0) / 5 }
        let writer = MovieWriter(size: Size(width: 128, height: 32), frameTimes: codeTimes, end: 1.2)
        try await writer.write(to: code) { canvas, index in
            canvas.drawCode(index, bits: 4, side: 32)
        }
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "media": "\#(outgoing)", "duration": 1,
                               "connected": [ { "at": [0.5, 1.5], "media": "\#(code)", "width": 128 } ] },
                             { "media": "\#(incoming)", "duration": 1 } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let lists = (0..<20).map { index in Evaluator().displayList(of: document, at: Double(index) / 10) }
        let frames = try lists.map { list in try sut.frame(of: list) }

        // Then
        let box = try #require(lists[5].placedPictures(named: "code.mov").first)
        for (index, frame) in frames.enumerated() {
            let isInWindow = (5..<15).contains(index)
            #expect(lists[index].placedPictures(named: "code.mov").isEmpty == !isInWindow, "frame \(index)")
            guard isInWindow else {
                let below: [Double] = index < 10 ? [255, 0, 0] : [0, 255, 0]
                let x = Int(box.x + box.width / 2)
                let y = Int(box.y + box.height / 2)
                #expect(frame.isPixel(x: x, y: y, below, tolerance: tolerance), "frame \(index) shows the clip")
                continue
            }

            // Media second (t - 0.5) at 5 frames a second. At frame 7 that is 0.7 - 0.5, which comes out a hair
            // under 0.2 and still picks the frame at 0.2.
            #expect(self.code(in: frame, box: box) == (index - 5) / 2, "frame \(index)")
        }
    }

    @Test(
        "a clip parented to a storyline clip moves with its transition, but the cover and the wipe do not reach it",
        arguments: Self.transitionProbes
    )
    func movesWithTransition(
        transition: String,
        probes: [(Int, Int, [Double])]
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let outgoing = try image(in: directory, named: "red.png", width: 160, height: 90, color: [255, 0, 0])
        let incoming = try image(in: directory, named: "green.png", width: 160, height: 90, color: [0, 255, 0])
        let document = try DocumentResolver(presets: presets).resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "media": "\#(outgoing)", "duration": 1 },
                             { "id": "green", "media": "\#(incoming)", "duration": 1, "transition": "mine/\#(transition)",
                               "connected": [ { "shape": "rect", "area": [0, 30, 160, 30], "parent": "green", "fill": "#FF00FF" } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        // The middle of the transition, which runs from 0.5 to 1.5.
        let frame = try sut.frame(of: Evaluator().displayList(of: document, at: 1))

        // Then
        for (x, y, color) in probes {
            #expect(
                frame.isPixel(x: x, y: y, color, tolerance: tolerance),
                "(\(x), \(y)) is \(frame.pixel(x: x, y: y))"
            )
        }
    }

    @Test("a shape parented to its storyline clip stays on the part of its picture it covers while the crop zooms")
    func followsCrop() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("marked.png")
        let marker = Rectangle(x: 200, y: 100, width: 40, height: 20)
        try ImageWriter(size: Size(width: 320, height: 180)).write(to: file) { canvas in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.fill(marker, red: 255, green: 0, blue: 0)
        }
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
              "storyline": [ { "id": "marked", "media": "\#(file)", "duration": 1,
                               "keyframes": [ { "at": 0, "crop": { "scale": 1 } }, { "at": 1, "crop": { "scale": 2 } } ],
                               "connected": [ { "shape": "rect", "area": [200, 100, 40, 20], "parent": "marked", "fill": "#0000FF" } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let lists = [0, 3, 6, 9].map { index in Evaluator().displayList(of: document, at: Double(index) / 10) }
        let frames = try lists.map { list in try sut.frame(of: list) }

        // Then
        for (list, frame) in zip(lists, frames) {
            let crop = try #require(list.mediaPictures(named: "marked.png").first?.rectangle)
            let scale = 160 / crop.width
            let shown = Rectangle(
                x: (marker.x - crop.x) * scale,
                y: (marker.y - crop.y) * scale,
                width: marker.width * scale,
                height: marker.height * scale
            )
            let centre = (Int(shown.center.x), Int(shown.center.y))
            let beside = [
                (Int(shown.x) - 2, centre.1),
                (Int(shown.maxX) + 2, centre.1),
                (centre.0, Int(shown.y) - 2),
                (centre.0, Int(shown.maxY) + 2)
            ]
            #expect(frame.isPixel(x: centre.0, y: centre.1, [0, 0, 255], tolerance: tolerance), "at crop \(crop)")
            for (x, y) in beside {
                #expect(
                    frame.isPixel(x: x, y: y, [128, 128, 128], tolerance: tolerance),
                    "(\(x), \(y)) at crop \(crop)"
                )
            }
        }
    }

    @Test("a tracked box stays on its scrolling line on every frame while the crop zooms")
    func staysOnTrackedTarget() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("screen.mov")
        let drawn = try await ScreenRecording(scale: 0.5).write(to: file)
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [180, 320] },
              "storyline": [ { "id": "screen", "media": "\#(file)",
                               "keyframes": [ { "at": 0, "crop": { "scale": 1 } }, { "at": 0.9, "crop": { "scale": 1.25 } } ],
                               "connected": [ { "shape": "rect", "stroke": { "width": 40, "color": "#ED2929" }, "area": { "text": "Total", "padding": 4 }, "parent": "screen", "track": true } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let lists = ScreenRecording.frameTimes.map { time in Evaluator().displayList(of: document, at: time) }
        let frames = try lists.map { list in try sut.frame(of: list) }

        // Then
        // The found line box lies within a few media pixels of the drawn one, which is a few output pixels here.
        let slack = 3.0
        let width = ScreenRecording(scale: 0.5).size.width
        for (index, (list, frame)) in zip(lists, frames).enumerated() {
            let crop = try #require(list.mediaPictures(named: "screen.mov").first?.rectangle)
            let scale = 180 / crop.width
            #expect(crop.width < width || index == 0, "frame \(index) is not zoomed")
            let line = Rectangle(
                x: (drawn[index].x - crop.x) * scale,
                y: (drawn[index].y - crop.y) * scale,
                width: drawn[index].width * scale,
                height: drawn[index].height * scale
            )
            let box = try #require(redBox(in: frame), "frame \(index) has no box")
            #expect(
                box.x <= line.x + slack && box.y <= line.y + slack
                    && box.maxX >= line.maxX - slack && box.maxY >= line.maxY - slack,
                "frame \(index): box \(box) does not hold the line \(line)"
            )
            #expect(abs(box.center.y - line.center.y) <= slack, "frame \(index): box \(box), line \(line)")
        }
    }

    @Test("outlined text keeps every fill above every stroke, and its strokes go round the corners")
    func outlinesText() throws {
        // Given
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [320, 180], "fps": 10 },
              "theme": { "baseWidth": 320,
                         "styles": { "headline": { "size": 80, "stroke": { "width": 12, "color": "#000000" }, "placement": "center", "offset": 0 } } },
              "storyline": [ { "solid": "#3366CC", "duration": 1 } ],
              "clips": [ { "title": "WAVE", "style": "headline", "width": 300 } ] }
            """#)
        let list = Evaluator().displayList(of: document, at: 0.5)
        let unstroked = DisplayList(
            size: list.size,
            background: list.background,
            seed: list.seed,
            items: list.items.map { item in
                guard case let .glyphs(glyphs) = item.content else { return item }

                return DisplayItem(
                    transform: item.transform,
                    opacity: item.opacity,
                    blend: item.blend,
                    mask: item.mask,
                    reveal: item.reveal,
                    content: .glyphs(GlyphsItem(
                        size: glyphs.size,
                        runs: glyphs.runs,
                        stroke: nil,
                        background: glyphs.background
                    )),
                    origin: item.origin
                )
            }
        )
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let stroked = try sut.frame(of: list)
        let filled = try sut.frame(of: unstroked)

        // Then
        let background = [51.0, 102, 204]
        let isGlyph = { (x: Int, y: Int) in !filled.isPixel(x: x, y: y, background, tolerance: 2 * self.tolerance) }
        let isInked = { (x: Int, y: Int) in !stroked.isPixel(x: x, y: y, background, tolerance: 2 * self.tolerance) }
        let pixels = (2..<178).flatMap { y in (2..<318).map { x in (x, y) } }

        // The interior: wholly white with every neighbour, so no edge blends into it.
        let interior = pixels.filter { x, y in
            (-1...1).allSatisfy { dy in
                (-1...1).allSatisfy { dx in
                    filled.isPixel(x: x + dx, y: y + dy, [255, 255, 255], tolerance: tolerance)
                }
            }
        }
        let covered = interior.filter { x, y in !stroked.isPixel(x: x, y: y, [255, 255, 255], tolerance: tolerance) }
        #expect(interior.count > 500)
        #expect(covered.isEmpty, "a stroke covers the fill at \(covered.prefix(4)) of \(interior.count)")

        // A round join reaches half the stroke width from the glyph, and a mitre at the point of a V much further.
        let reach = 6 + 1.5
        let far = pixels.filter { x, y in
            isInked(x, y) && !(-8...8).contains { dy in
                (-8...8).contains { dx in
                    Double(dx * dx + dy * dy) <= reach * reach && isGlyph(x + dx, y + dy)
                }
            }
        }
        #expect(pixels.contains { x, y in isInked(x, y) && !isGlyph(x, y) })
        #expect(far.isEmpty, "the stroke reaches past a round join at \(far.prefix(4))")
    }

    // The picture is 40 wide, as the theme's base width, so the stroke is 10 output pixels. Each shape reaches past
    // the outline grown by half its width further right and down than anything else measured: the polyline's miter,
    // 3.16 widths long under the limit of 4, to x = 135.8, and the diagonal's square cap to (107.07, 100) and
    // (100, 107.07). The frame is the content with a margin of 4 round it.
    @Test(
        "a frame that fits its content holds a sharp miter join and a square cap on a diagonal end whole, its margin left clear",
        arguments: [
            ##"{ "shape": "path", "points": [[60, 40], [120, 60], [60, 80]], "stroke": { "width": 10, "color": "#FF0000", "join": "miter" }, "at": [0, 1] }"##,
            ##"{ "shape": "path", "points": [[60, 60], [100, 100]], "stroke": { "width": 10, "color": "#FF0000", "cap": "square" }, "at": [0, 1] }"##
        ]
    )
    func fitsJoinAndCap(shape: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = try image(in: directory, named: "grey.png", width: 40, height: 40, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": { "fit": "content", "margin": 4 }, "fps": 10 },
              "theme": { "baseWidth": 40 },
              "storyline": [ { "media": "\#(file)", "duration": 1 } ],
              "clips": [ \#(shape) ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.frame(of: Evaluator().displayList(of: document, at: 0.5))

        // Then
        let isBlank = { (x: Int, y: Int) in frame.isPixel(x: x, y: y, [0, 0, 0], tolerance: self.tolerance) }
        let pixels = (0..<frame.height).flatMap { y in (0..<frame.width).map { x in (x, y) } }
        let margin = pixels.filter { x, y in x < 4 || y < 4 || x >= frame.width - 4 || y >= frame.height - 4 }
        let drawn = margin.filter { x, y in !isBlank(x, y) }
        #expect(drawn.isEmpty, "\(drawn.count) pixels of the margin are drawn, first \(drawn.prefix(4))")
        let edge = (4..<frame.height - 4).filter { y in !isBlank(frame.width - 5, y) || !isBlank(frame.width - 6, y) }
        #expect(!edge.isEmpty, "the shape reaches the frame's right edge inside the margin")
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

    // The value `Canvas.drawCode` drew in four squares across `box`.
    private func code(
        in frame: Bitmap,
        box: Rectangle
    ) -> Int {
        (0..<4).reduce(0) { value, bit in
            let x = Int(box.x + (Double(bit) + 0.5) * box.width / 4)
            let y = Int(box.y + box.height / 2)
            let isWhite = frame.pixel(x: x, y: y)[1] > 0.5 + decodedTolerance

            return isWhite ? value | 1 << bit : value
        }
    }

    // The bounds of the pixels in the accent colour, which only the box is drawn in.
    private func redBox(in frame: Bitmap) -> Rectangle? {
        var columns: [Int] = []
        var rows: [Int] = []
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let pixel = frame.pixel(x: x, y: y)
                if pixel[0] > 0.6 && pixel[1] < 0.45 && pixel[2] < 0.45 {
                    columns.append(x)
                    rows.append(y)
                }
            }
        }
        guard let left = columns.min(), let right = columns.max(), let top = rows.min(), let bottom = rows.max() else {
            return nil
        }

        return Rectangle(
            x: Double(left),
            y: Double(top),
            width: Double(right - left + 1),
            height: Double(bottom - top + 1)
        )
    }
}
