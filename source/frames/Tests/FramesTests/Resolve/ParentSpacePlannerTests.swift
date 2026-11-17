//
//  ParentSpacePlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// In `/abs/screen.mp4` "Total" starts as `Fixture.total` and moves 10 right and 40 down per second while it grows by
// `growth` of its size per second, and the tracker follows a target the same way. The screen fills the output, so its
// media pixels are output pixels.
@Suite("ParentSpacePlanner Tests")
struct ParentSpacePlannerTests {
    // MARK: - Property
    private static let drift = Point(x: 10, y: 40)
    private static let padding = 14.0

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a title at a point of text beside a tracked box lands beside the text on every frame, though its instant is not the box's",
        arguments: [
            (0.0, "box"),
            (0.25, "box"),
            (0.25, "inner")
        ]
    )
    func placesTextBesideTrackedBox(
        growth: Double,
        parent: String
    ) throws {
        // Given
        let sut = planner(growth: growth)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "box", "parent": "screen", "at": [0, 4], "area": { "text": "Total" }, "track": true },
                { "id": "inner", "shape": "box", "parent": "box", "at": [0, 4], "area": [0, 0, 10, 10] },
                { "title": "a", "style": "title", "parent": "\#(parent)", "at": [2, 4], "anchor": "left",
                  "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let title = try #require(resolved.clips.last)
        let box = try #require(title.box)
        let parents = ParentEvaluator(sequence: resolved)
        for time in [2.0, 2.5, 3.5] {
            let space = parents.space(of: title, at: time)
            let anchor = space.transform.apply(to: space.anchor(of: box, track: nil, at: time))
            // The padding is found at the title's instant and grows with the text from there.
            let text = Self.text(at: time, growth: growth)
            let padding = Self.padding * (1 + growth * time) / (1 + growth * 2)
            let beside = Point(x: text.x + text.width + padding, y: text.center.y)
            #expect(isClose(anchor, beside), "at \(time) the title is at \(anchor), the text's right at \(beside)")
        }
    }

    @Test(
        "a title whose instant or keyframe lies outside its tracked box's window lands where the same title under the screen does",
        arguments: [
            (
                #""at": [2, 4], "position": \#(Self.beside)"#,
                [2.0, 3.0, 3.5]
            ),
            (
                #""at": [0, 4], "keyframes": [ { "at": 1, "position": \#(Self.beside) }, { "at": 3, "position": \#(Self.beside) } ]"#,
                [1.0, 3.0, 3.5]
            )
        ]
    )
    func placesTextOutsideTrackedBoxWindow(
        title: String,
        times: [Double]
    ) throws {
        // Given
        let sut = planner(growth: 0.25)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "box", "parent": "screen", "at": [0, 2], "area": { "text": "Total" }, "track": true },
                { "title": "a", "style": "title", "parent": "box", "anchor": "left", \#(title) },
                { "title": "a", "style": "title", "parent": "screen", "anchor": "left", \#(title) } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let underBox = resolved.clips[1]
        let underScreen = resolved.clips[2]
        let parents = ParentEvaluator(sequence: resolved)
        for time in times {
            let anchor = Self.anchor(of: underBox, by: parents, at: time)
            let expected = Self.anchor(of: underScreen, by: parents, at: time)
            #expect(isClose(anchor, expected), "at \(time) the title is at \(anchor), the screen's title at \(expected)")
        }
    }

    @Test("numbers under a tracked box are kept as written, and a text keyframe beside them is brought into its space")
    func keepsNumbersUnderTrackedBox() throws {
        // Given
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "box", "parent": "screen", "at": [0, 4], "area": { "text": "Total" }, "track": true },
                { "shape": "box", "parent": "box", "at": [0, 4], "area": [300, 100, 50, 50] },
                { "title": "a", "style": "title", "parent": "box", "at": [0, 4], "anchor": "left", "keyframes": [
                    { "at": 2, "position": [300, 100] },
                    { "at": 3, "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } } ] } ] } ] }
            """#)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: document))

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Rectangle(x: 300, y: 100, width: 50, height: 50))
        guard case let .keyframes(positions) = plan.clips[2].position else {
            Issue.record("the position was not keyframed")
            return
        }
        let total = Fixture.total
        let beside = Point(x: total.x + total.width + Self.padding, y: total.center.y)
        let numbers = try #require(positions.first)
        let text = try #require(positions.last)
        #expect(numbers.value == Point(x: 300, y: 100))
        #expect(isClose(text.value, beside), "the text keyframe is at \(text.value), the text's right at \(beside)")
    }

    // MARK: - Private
    private static let beside = #"{ "area": { "text": "Total", "padding": 14 }, "point": "right" }"#

    private static func anchor(
        of clip: ResolvedClip,
        by parents: ParentEvaluator,
        at time: Double
    ) -> Point {
        guard let box = clip.box else { return Point(x: 0, y: 0) }

        let space = parents.space(of: clip, at: time)
        return space.transform.apply(to: space.anchor(of: box, track: nil, at: time))
    }

    // "Total" on the frame shown at a media time.
    private static func text(
        at time: Double,
        growth: Double
    ) -> Rectangle {
        let total = Fixture.total
        let size = 1 + growth * time

        return Rectangle(
            center: Point(x: total.center.x + drift.x * time, y: total.center.y + drift.y * time),
            width: total.width * size,
            height: total.height * size
        )
    }

    private func planner(growth: Double) -> SequencePlanner {
        let lines = Fixture.screenFrameTimes.map { time in
            (from: time, lines: [RecognisedLine(text: "Total", rectangle: Self.text(at: time, growth: growth))])
        }

        return SequencePlanner(
            ocr: OCRTable(["/abs/screen.mp4": lines]),
            tracker: TrackerTable(
                frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
                drift: Self.drift,
                growth: growth
            ),
            shaper: Fixture.shaper,
            presets: Fixture.presets,
            library: Fixture.library
        )
    }

    private func isClose(
        _ point: Point,
        _ other: Point
    ) -> Bool {
        abs(point.x - other.x) < 1e-6 && abs(point.y - other.y) < 1e-6
    }
}
