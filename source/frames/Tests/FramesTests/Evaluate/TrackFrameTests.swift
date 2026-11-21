//
//  TrackFrameTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` has a frame every 0.1 media seconds. Its storyline clip plays media [1, 3) over the edit range
// [0, 2), and a connected clip's `at` is in that media time, so at sequence time t it shows media time t + 1: the
// instant 0 shows media 1, and time 0.5 shows media 1.5, the frame `{"time": 1.5}` names. The tracker moves the target
// 10 pixels down per media second from the frame it is given, so the motion at media 1 moves 5 pixels up.
@Suite("TrackFrame Tests")
struct TrackFrameTests {
    // MARK: - Property
    private static let total = Rectangle(x: 100, y: 100, width: 200, height: 40)
    private static let moved = Rectangle(x: 100, y: 130, width: 200, height: 40)

    private let sut = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a static area written as numbers under a track's time is true on the frame the time names and is written as its value")
    func keepsWrittenStaticOnTrackFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "tracked", "shape": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3], "track": { "time": 1.5 } },
            { "id": "still", "shape": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3] }
            """#)

        // When
        let text = ResolvedDocumentWriter().write(sequence)
        let read = try ResolvedDocumentReader().read(text)
        let onTrackFrame = try boxes(in: sut.displayList(of: read, at: 0.5))
        let atInstant = try boxes(in: sut.displayList(of: read, at: 0))

        // Then
        #expect(read == sequence)
        #expect(text.contains(#""area": [100, 100, 200, 40]"#))
        #expect(onTrackFrame.tracked == onTrackFrame.still)
        #expect(abs(atInstant.tracked.y - (atInstant.still.y - 5 * atInstant.scale)) < 1e-9)
        #expect(atInstant.tracked.x == atInstant.still.x)
    }

    @Test("an own target found by text on the frame a track's time names is true there and is not brought back from the instant")
    func keepsFoundTargetOnTrackFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "tracked", "shape": "rect", "fill": "#FFFFFF", "parent": "screen", "area": { "text": "Total" }, "at": [1, 3], "track": { "time": 1.5 } },
            { "id": "still", "shape": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 130, 200, 40], "at": [1, 3] }
            """#)

        // When
        let onTrackFrame = try boxes(in: sut.displayList(of: sequence, at: 0.5))
        let atInstant = try boxes(in: sut.displayList(of: sequence, at: 0))

        // Then
        let clip = try #require(sequence.clips.first { $0.id == "tracked" })
        guard case let .shape(shape) = clip.content, case let .area(area, _, _) = shape.geometry else {
            Issue.record("the tracked clip is not a shape placed by its area")
            return
        }
        #expect(area == .onTrackFrame(.rectangle(Self.moved)))
        #expect(onTrackFrame.tracked == onTrackFrame.still)
        #expect(abs(atInstant.tracked.y - (atInstant.still.y - 5 * atInstant.scale)) < 1e-9)
    }

    @Test("a mask with keyframes keeps each geometry leaf written without keyframes true on the track's frame, and a leaf one keyframe writes at its time")
    func keepsStaticMaskLeavesOnTrackFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "tracked", "shape": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3], "track": { "time": 1.5, "area": [100, 100, 200, 40] },
              "mask": [ { "shape": "rect", "area": [110, 110, 50, 20] } ], "keyframes": [ { "at": 1, "mask": [ { "radius": 4 } ] } ] },
            { "id": "still", "shape": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3] }
            """#)

        // When
        let read = try ResolvedDocumentReader().read(ResolvedDocumentWriter().write(sequence))

        // Then
        let clip = try #require(read.clips.first { $0.id == "tracked" })
        guard case let .rect(.area(area), radius) = clip.mask?.first?.geometry else {
            Issue.record("the tracked clip's mask is not a rect placed by its area")
            return
        }
        #expect(read == sequence)
        #expect(area == .onTrackFrame(.rectangle(Rectangle(x: 110, y: 110, width: 50, height: 20))))
        #expect(radius.keyframeTimes.count == 1)
    }

    // MARK: - Private
    private func resolved(_ connected: String) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: OCRTable(["/abs/screen.mp4": [
                (from: 0, lines: [RecognisedLine(text: "Total", rectangle: Self.total)]),
                (from: 1.5, lines: [RecognisedLine(text: "Total", rectangle: Self.moved)])
            ]]),
            languages: nil,
            tracker: TrackerTable(frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes], drift: Point(x: 0, y: 10)),
            shaper: Fixture.shaper,
            library: Fixture.library
        )
        let document = #"""
            { "kind": "sequence", "storyline": [
                { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [ \#(connected) ] } ] }
            """#

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // The rectangle of each clip's path carried by its item's transform to output pixels, and the vertical scale of
    // the still clip's transform, which is its parent's.
    private func boxes(in list: DisplayList) throws -> (tracked: Rectangle, still: Rectangle, scale: Double) {
        let box = { (id: String) throws -> (Rectangle, Double) in
            let item = try #require(list.items.first { $0.origin?.id == id })
            let rectangle: Rectangle? = if case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry {
                rectangle
            } else {
                nil
            }

            return (Rectangle(bounding: item.transform.apply(toCornersOf: try #require(rectangle))), item.transform.d)
        }
        let tracked = try box("tracked")
        let still = try box("still")

        return (tracked.0, still.0, still.1)
    }
}
