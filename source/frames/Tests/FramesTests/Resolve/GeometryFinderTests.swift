//
//  GeometryFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("GeometryFinder Tests")
struct GeometryFinderTests {
    // MARK: - Property
    // "Total" moves down at media second 2.
    private let sut = GeometryFinder(ocr: OCRTable([
        "/abs/screen.mp4": [
            (from: 0, lines: [RecognisedLine(text: "Total", rectangle: Rectangle(x: 100, y: 100, width: 200, height: 40))]),
            (from: 2, lines: [RecognisedLine(text: "Total", rectangle: Rectangle(x: 100, y: 700, width: 200, height: 40))])
        ]
    ]))
    private let screen = Picture(
        name: "/abs/screen.mp4",
        source: .mediaFile(MediaFile(path: "/abs/screen.mp4")),
        size: Size(width: 1206, height: 2622)
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a static area is found at the clip's instant, in the media time of the storyline clip it is on")
    func findsStaticAreaAtInstant() throws {
        // Given
        let plan = try plan(#"{ "shape": "box", "parent": true, "area": "Total" }"#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let found = try find(clip.area, plan: plan, instant: plan.clips[0].window.start)

        // Then
        #expect(found == .value(FoundArea(
            rectangle: Rectangle(x: 86, y: 86, width: 228, height: 68),
            target: Rectangle(x: 100, y: 100, width: 200, height: 40),
            isBand: false,
            mediaTime: 1,
            lines: [RecognisedLine(text: "Total", rectangle: Rectangle(x: 100, y: 100, width: 200, height: 40))]
        )))
    }

    @Test("each keyframe's area is found at its own time and comes back in sequence time")
    func findsKeyframesAtTheirTimes() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "box", "parent": true, "at": [1, 3],
              "keyframes": [ { "at": 1, "area": "Total", "ease": "ease-in-out" }, { "at": 2.5, "area": "Total" } ] }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let found = try find(clip.area, plan: plan, instant: plan.clips[0].window.start)

        // Then
        guard case let .keyframes(keyframes) = found else {
            Issue.record("keyframes were not kept")
            return
        }
        #expect(keyframes.map(\.at) == [0, 1.5])
        #expect(keyframes.map(\.value.mediaTime) == [1, 2.5])
        #expect(keyframes.map(\.value.target.y) == [100, 700])
        #expect(keyframes.map(\.index) == [0, 1])
        #expect(keyframes.map(\.ease) == [.easeInOut, .linear])
    }

    @Test("a found area's media time is its storyline clip's media time at the keyframe's sequence time, or at the instant")
    func findsAtStorylineMediaTime() throws {
        // Given
        let keyframed = try plan(#"""
            { "shape": "box", "at": [1.5, 3], "keyframes": [ { "at": 1.5, "area": "Total" }, { "at": 3, "area": "Total" } ] }
            """#, storylineKeys: #""speed": 2,"#)
        let still = try plan(#"{ "shape": "box", "at": [2, 3], "area": "Total" }"#, storylineKeys: #""speed": 2,"#)
        let storyline = keyframed.storyline[0]

        // When
        let keyframes = try find(keyframed.sequence.storyline[0].connected[0].area, plan: keyframed, instant: keyframed.clips[0].instant)
        let value = try find(still.sequence.storyline[0].connected[0].area, plan: still, instant: still.clips[0].instant)

        // Then
        guard case let .keyframes(keyframes) = keyframes, case let .value(value) = value else {
            Issue.record("the areas were not found as written")
            return
        }
        #expect(keyframes.map(\.at) == [0.25, 1])
        #expect(keyframes.map(\.value.mediaTime) == [1.5, 3])
        #expect(keyframes.map(\.value.mediaTime) == keyframes.map { storyline.mediaTime(atSequenceTime: $0.at) })
        #expect(value.mediaTime == 2)
        #expect(value.mediaTime == still.storyline[0].mediaTime(atSequenceTime: still.clips[0].instant))
    }

    @Test("a keyframe's area that stops names the keyframe")
    func namesKeyframeInStop() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "box", "parent": true, "keyframes": [ { "at": 1, "area": "Total" }, { "at": 2, "area": "Cart" } ] }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When, Then
        let error = #expect(throws: AreaError.self) {
            try find(clip.area, plan: plan, instant: plan.clips[0].window.start)
        }
        #expect(error?.description == #"""
            storyline[0].connected[0].keyframes[1].area (box): no line of "/abs/screen.mp4" at media second 2 \#
            contains "Cart"
            """#)
    }

    @Test("a crop of {scale} is the centred region of 1/scale the picture, and an area crop takes the crop padding")
    func findsCrops() throws {
        // Given
        let scalePlan = try plan(nil, storylineKeys: #""crop": { "scale": 2 },"#)
        let areaPlan = try self.plan(nil, storylineKeys: #""crop": "Total","#)

        // When
        let scale = try sut.crops(
            scalePlan.sequence.storyline[0].crop ?? .value(.scale(1)),
            in: screen,
            pictureClock: .storyline(scalePlan.storyline[0]),
            clock: scalePlan.storyline[0].map,
            instant: scalePlan.storyline[0].edit.start,
            padding: 40,
            place: scalePlan.storyline[0].place,
            kind: "video"
        )
        let area = try sut.crops(
            areaPlan.sequence.storyline[0].crop ?? .value(.scale(1)),
            in: screen,
            pictureClock: .storyline(areaPlan.storyline[0]),
            clock: areaPlan.storyline[0].map,
            instant: areaPlan.storyline[0].edit.start,
            padding: 40,
            place: areaPlan.storyline[0].place,
            kind: "video"
        )

        // Then
        #expect(scale == .value(FoundArea(
            rectangle: Rectangle(x: 301.5, y: 655.5, width: 603, height: 1311),
            target: Rectangle(x: 301.5, y: 655.5, width: 603, height: 1311),
            isBand: false,
            mediaTime: 1,
            lines: []
        )))
        #expect(area.first == nil)
        guard case let .value(found) = area else { return }
        #expect(found.rectangle == Rectangle(x: 60, y: 60, width: 280, height: 120))
    }

    @Test("a position by an area is the point it names on the area, padding included")
    func findsPositionOnArea() throws {
        // Given
        let plan = try plan(#"""
            { "title": "a", "style": "title", "parent": true, "position": { "area": "Total", "point": "right" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let position = try sut.positions(
            clip.position ?? .value(.point(Point(x: 0, y: 0))),
            in: screen,
            pictureClock: .storyline(plan.storyline[0]),
            clock: plan.clips[0].clock,
            instant: plan.clips[0].window.start,
            padding: 14,
            place: clip.place,
            kind: "title"
        )

        // Then
        #expect(position == .value(Point(x: 314, y: 120)))
    }

    // MARK: - Private
    private func plan(
        _ connected: String?,
        storylineKeys: String = ""
    ) throws -> TimePlan {
        let clips = connected.map { #", "connected": [ \#($0) ]"# } ?? ""
        return try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { \#(storylineKeys) "media": "/abs/screen.mp4", "in": 1\#(clips) } ] }
            """#))
    }

    private func find(
        _ property: PropertyValue<AreaForm>?,
        plan: TimePlan,
        instant: Double
    ) throws -> PropertyValue<FoundArea> {
        try sut.areas(
            property ?? .value(.rectangle(Rectangle(x: 0, y: 0, width: 1, height: 1))),
            key: "area",
            in: screen,
            pictureClock: .storyline(plan.storyline[0]),
            clock: plan.clips[0].clock,
            instant: instant,
            padding: 14,
            place: plan.clips[0].place,
            kind: "box"
        )
    }
}
