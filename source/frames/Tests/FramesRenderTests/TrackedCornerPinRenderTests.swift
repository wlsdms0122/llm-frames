//
//  TrackedCornerPinRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import FramesTracker
import Testing

@testable import Frames

// Tracked clips with corner pins over a real video, given track data written or followed by the `point` tracker as the
// `track` command does, resolved on the real providers, and evaluated or drawn by the real renderer (FRAMES-12,
// FRAMES-27). Serialized, since AVAssetReader needs a free thread
// of the shared pool.
@Suite("Tracked Corner Pin Render Tests", .serialized, .blockingLimit)
struct TrackedCornerPinRenderTests {
    // MARK: - Property
    private static let frameCount = 10
    private static let times = (0..<frameCount).map { Double($0) / 10 }
    // The patch on the video's first frame, before it moves and turns.
    private static let patch = Rectangle(x: 60, y: 80, width: 96, height: 48)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a child of a pinned clip tracked by track data is drawn moved by the track's motion on each frame")
    func drawsChildFollowingTrackedMotion() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = try await video(in: directory)
        // The target moves 8 media pixels right a frame, so the motion is that move.
        let frames = Self.times.enumerated()
            .map { index, time in
                let quad = Quad(Rectangle(x: 100 + 8 * Double(index), y: 40, width: 60, height: 40))
                return #"{ "time": \#(time), "quad": \#(written(quad)) }"#
            }
            .joined(separator: ", ")
        let document = try DocumentResolver().resolve(##"""
            { "kind": "sequence", "format": { "size": [320, 240], "fps": 10 },
              "storyline": [ { "id": "shot", "kind": "media", "media": "\##(path)", "in": 0, "out": 1, "connected": [
                { "id": "card", "kind": "rect", "width": 100, "height": 60, "fill": "#0000FF", "parent": "shot", "at": [0, 1],
                  "cornerPin": [[20, 20], [120, 30], [110, 90], [30, 80]], "track": { "time": 0, "frames": [ \##(frames) ] } },
                { "id": "dot", "kind": "rect", "area": [200, 150, 30, 20], "fill": "#FF0000", "parent": "card", "at": [0, 1] } ] } ] }
            """##)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let first = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.05))
        let sixth = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.55))

        // Then
        for (bitmap, move) in [(first, 0), (sixth, 40)] {
            let left = 200 + move
            #expect(isRed(bitmap, x: left + 2, y: 152), "left \(left)")
            #expect(isRed(bitmap, x: left + 27, y: 167), "left \(left)")
            #expect(!isRed(bitmap, x: left - 3, y: 160), "left \(left)")
            #expect(!isRed(bitmap, x: left + 33, y: 160), "left \(left)")
        }
    }

    @Test("a clip and a pinned clip given the track data the point tracker gives on their target agree on its corners on every frame followed")
    func agreesWithPointTrackerMotion() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = try await video(in: directory)
        let patch = Quad(Self.patch)
        let decoder = AVFoundationDecoder()
        let report = try TrackReporter(mediaFacts: decoder, tracker: PointTracker(decoder: decoder))
            .report(of: path, target: .area("[60, 80, 96, 48]"), at: 0)
        let document = try DocumentResolver().resolve(##"""
            { "kind": "sequence", "format": { "size": [320, 240], "fps": 10 },
              "storyline": [ { "id": "shot", "kind": "media", "media": "\##(path)", "in": 0, "out": 1, "connected": [
                { "id": "area", "kind": "rect", "area": [60, 80, 96, 48], "fill": "#FF0000", "parent": "shot", "at": [0, 1], "track": \##(report.trackData) },
                { "id": "pinned", "kind": "rect", "width": 96, "height": 48, "fill": "#00FF00", "parent": "shot", "at": [0, 1],
                  "cornerPin": \##(written(patch)), "track": \##(report.trackData) } ] } ] }
            """##)

        // When
        let corners = try Self.times.map { time in
            let list = Evaluator().displayList(of: document, at: time + 0.05)
            return (area: try areaCorners(in: list), pinned: try pinnedCorners(in: list))
        }

        // Then
        // The `point` tracker reports similarity images of the target, so the homography of each frame is its motion
        // and the two agree to rounding, far inside the tracker's own corner tolerance of a pixel.
        for (index, pair) in corners.enumerated() {
            let largest = zip(pair.area, pair.pinned).map { area, pinned in
                ((area.x - pinned.x) * (area.x - pinned.x) + (area.y - pinned.y) * (area.y - pinned.y)).squareRoot()
            }
            .max() ?? .infinity
            #expect(largest <= 1e-6, "frame \(index): \(largest) px apart, \(pair.area) and \(pair.pinned)")
        }
        // The patch moved, so the two followed it and did not stay where it was.
        let last = try #require(corners.last)
        #expect(abs(last.area[0].x - Self.patch.x) > 50)
    }

    // MARK: - Private
    // A video of 10 frames at 10 a second, 320 × 240, of a yellow patch with a pattern that does not repeat on a grey
    // background with still marks of its own. The patch moves 8 pixels right and 4 down and turns 2 degrees clockwise
    // about its centre each frame.
    private func video(in directory: TemporaryDirectory) async throws -> String {
        let path = directory.file("patch.mov")
        let bits: UInt32 = 0b1011_0110_0101_1100_1101_0011_1000_1110
        let writer = MovieWriter(size: Size(width: 320, height: 240), frameTimes: Self.times, end: 1)
        try await writer.write(to: path) { canvas, index in
            canvas.fill(red: 90, green: 110, blue: 130)
            for column in 0..<8 {
                canvas.fill(Rectangle(x: Double(column) * 40 + 10, y: 210, width: 20, height: 15), red: 60, green: 70, blue: 80)
            }
            let box = Rectangle(
                x: Self.patch.x + 8 * Double(index),
                y: Self.patch.y + 4 * Double(index),
                width: Self.patch.width,
                height: Self.patch.height
            )
            canvas.turned(by: 2 * Double(index), about: Point(x: box.x + box.width / 2, y: box.y + box.height / 2)) {
                canvas.fill(box, red: 240, green: 200, blue: 40)
                for row in 0..<4 {
                    for column in 0..<8 where bits >> UInt32(row * 8 + column) & 1 == 1 {
                        let cell = Rectangle(x: box.x + Double(column) * 12, y: box.y + Double(row) * 12, width: 12, height: 12)
                        canvas.fill(cell, red: 30, green: 30, blue: 30)
                    }
                }
            }
        }

        return path
    }

    // The corners of the area clip's rect carried by its item's transform to output pixels.
    private func areaCorners(in list: DisplayList) throws -> [Point] {
        let item = try #require(list.drawnItems.first { $0.origin?.id == "area" })
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("the area clip is not a rect")
            return []
        }

        return item.transform.apply(toCornersOf: rectangle)
    }

    // The pinned clip's corner pin carried by its group's transform to output pixels.
    private func pinnedCorners(in list: DisplayList) throws -> [Point] {
        let item = try #require(list.drawnItems.first { $0.origin?.id == "pinned" })
        guard case let .picture(picture) = item.content else {
            Issue.record("the pinned clip's group is not a picture")
            return []
        }

        return try #require(picture.cornerPin).corners.map(item.transform.apply(to:))
    }

    private func isRed(
        _ bitmap: Bitmap,
        x: Int,
        y: Int
    ) -> Bool {
        let pixel = bitmap.pixel(x: x, y: y)
        return pixel[0] > 0.95 && pixel[1] < 0.05 && pixel[2] < 0.05
    }

    private func written(_ quad: Quad) -> String {
        "[" + quad.corners.map { "[\($0.x), \($0.y)]" }.joined(separator: ", ") + "]"
    }
}
