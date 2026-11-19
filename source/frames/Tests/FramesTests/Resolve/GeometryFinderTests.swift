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
    ]), languages: nil)
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
        let plan = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total", "padding": 14 } }"#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let found = try find(clip.area, plan: plan, instant: plan.clips[0].window.start)

        // Then
        #expect(found == .value(FoundArea(
            rectangle: Rectangle(x: 86, y: 86, width: 228, height: 68),
            target: Rectangle(x: 100, y: 100, width: 200, height: 40),
            mediaTime: 1,
            lines: [RecognisedLine(text: "Total", rectangle: Rectangle(x: 100, y: 100, width: 200, height: 40))]
        )))
    }

    @Test("each keyframe's area is found at its own time and comes back in sequence time")
    func findsKeyframesAtTheirTimes() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [1, 3],
              "keyframes": [ { "at": 1, "area": { "text": "Total" }, "ease": "ease-in-out" }, { "at": 2.5, "area": { "text": "Total" } } ] }
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
            { "shape": "rect", "stroke": { "width": 8 }, "at": [1.5, 3], "keyframes": [ { "at": 1.5, "area": { "text": "Total" } }, { "at": 3, "area": { "text": "Total" } } ] }
            """#, storylineKeys: #""speed": 2,"#)
        let still = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "at": [2, 3], "area": { "text": "Total" } }"#, storylineKeys: #""speed": 2,"#)
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
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "keyframes": [ { "at": 1, "area": { "text": "Total" } }, { "at": 2, "area": { "text": "Cart" } } ] }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When, Then
        let error = #expect(throws: AreaError.self) {
            try find(clip.area, plan: plan, instant: plan.clips[0].window.start)
        }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0].keyframes[1].area (rect): no line of "/abs/screen.mp4" at media second 2 \#
            contains "Cart"
            """#)
    }

    @Test("a crop of {scale} is the centred region of 1/scale the picture, and a text crop grows by its padding")
    func findsCrops() throws {
        // Given
        let scalePlan = try plan(nil, storylineKeys: #""crop": { "scale": 2 },"#)
        let areaPlan = try self.plan(nil, storylineKeys: #""crop": { "text": "Total", "padding": 40 },"#)

        // When
        let scale = try sut.crops(
            scalePlan.sequence.storyline[0].crop ?? .value(.scale(1)),
            in: screen,
            pictureClock: .storyline(scalePlan.storyline[0]),
            clock: scalePlan.storyline[0].map,
            instant: scalePlan.storyline[0].edit.start,
            place: scalePlan.storyline[0].place,
            kind: "video"
        )
        let area = try sut.crops(
            areaPlan.sequence.storyline[0].crop ?? .value(.scale(1)),
            in: screen,
            pictureClock: .storyline(areaPlan.storyline[0]),
            clock: areaPlan.storyline[0].map,
            instant: areaPlan.storyline[0].edit.start,
            place: areaPlan.storyline[0].place,
            kind: "video"
        )

        // Then
        #expect(scale == .value(FoundArea(
            rectangle: Rectangle(x: 301.5, y: 655.5, width: 603, height: 1311),
            target: Rectangle(x: 301.5, y: 655.5, width: 603, height: 1311),
            mediaTime: 1,
            lines: []
        )))
        #expect(area.first == nil)
        guard case let .value(found) = area else { return }
        #expect(found.rectangle == Rectangle(x: 60, y: 60, width: 280, height: 120))
    }

    @Test("a numeric crop past the picture is the same region as the {scale} crop that names it")
    func findsNumericCropAsScale() throws {
        // Given
        let numericPlan = try plan(nil, storylineKeys: #""crop": [-603, -1311, 2412, 5244],"#)
        let scalePlan = try plan(nil, storylineKeys: #""crop": { "scale": 0.5 },"#)

        // When
        let numeric = try crops(of: numericPlan)
        let scale = try crops(of: scalePlan)

        // Then
        #expect(numeric == scale)
        #expect(numeric.firstValue.rectangle == Rectangle(x: -603, y: -1311, width: 2412, height: 5244))
    }

    @Test("a text area at the picture's edge grows by its padding on every side, and a point on it lies past the edge")
    func growsTextAreaPastPicture() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total", "padding": 150 },
              "position": { "area": { "text": "Total", "padding": 150 }, "point": "top-left" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let area = try find(clip.area, plan: plan, instant: plan.clips[0].window.start)
        let position = try sut.positions(
            clip.position ?? .value(.point(Point(x: 0, y: 0))),
            in: screen,
            pictureClock: .storyline(plan.storyline[0]),
            clock: plan.clips[0].clock,
            instant: plan.clips[0].window.start,
            place: clip.place,
            kind: "rect"
        )

        // Then
        #expect(area.firstValue.rectangle == Rectangle(x: -50, y: -50, width: 500, height: 340))
        #expect(position == .value(Point(x: -50, y: -50)))
    }

    @Test("a position by an area is the point it names on the area, padding included")
    func findsPositionOnArea() throws {
        // Given
        let plan = try plan(#"""
            { "title": "a", "style": "title", "parent": "screen", "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let position = try sut.positions(
            clip.position ?? .value(.point(Point(x: 0, y: 0))),
            in: screen,
            pictureClock: .storyline(plan.storyline[0]),
            clock: plan.clips[0].clock,
            instant: plan.clips[0].window.start,
            place: clip.place,
            kind: "title"
        )

        // Then
        #expect(position == .value(Point(x: 314, y: 120)))
    }

    @Test(
        "a position by an area and a placement name is that point of the area, padding included",
        arguments: [
            ("top-left", Point(x: 90, y: 90)),
            ("top", Point(x: 200, y: 90)),
            ("top-right", Point(x: 310, y: 90)),
            ("left", Point(x: 90, y: 120)),
            ("center", Point(x: 200, y: 120)),
            ("right", Point(x: 310, y: 120)),
            ("bottom-left", Point(x: 90, y: 150)),
            ("bottom", Point(x: 200, y: 150)),
            ("bottom-right", Point(x: 310, y: 150))
        ]
    )
    func findsEveryPointOfArea(
        name: String,
        point: Point
    ) throws {
        // Given
        let plan = try plan(#"""
            { "title": "a", "style": "title", "parent": "screen", "position": { "area": { "text": "Total", "padding": 10 }, "point": "\#(name)" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let position = try sut.positions(
            clip.position ?? .value(.point(Point(x: 0, y: 0))),
            in: screen,
            pictureClock: .storyline(plan.storyline[0]),
            clock: plan.clips[0].clock,
            instant: plan.clips[0].window.start,
            place: clip.place,
            kind: "title"
        )

        // Then
        #expect(position == .value(point))
    }

    @Test("an area under a remapped storyline clip is searched at the media time its instant maps to through the remap")
    func findsUnderRemappedClip() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" } }
            """#, storylineKeys: #""out": 3, "keyframes": [ { "at": 1, "timeRemap": 2.5 }, { "at": 3, "timeRemap": 3.5 } ],"#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let found = try find(clip.area, plan: plan, instant: plan.clips[0].window.start)

        // Then
        #expect(found.firstValue.mediaTime == 2.5)
        #expect(found.firstValue.target.y == 700)
    }

    @Test("a crop on a remapped media clip is searched at the media time its instant maps to through the remap")
    func findsOnRemappedClip() throws {
        // Given
        let plan = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 4 } ],
              "clips": [ { "media": "/abs/screen.mp4", "at": [1, 3], "crop": { "text": "Total" },
                "keyframes": [ { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 0 } ] } ] }
            """#))
        let clock = try #require(plan.clips[0].mediaClock)

        // When
        let found = try sut.crops(
            plan.sequence.clips[0].crop ?? .value(.scale(1)),
            in: screen,
            pictureClock: .media(clock),
            clock: plan.clips[0].clock,
            instant: plan.clips[0].instant,
            place: plan.clips[0].place,
            kind: "video"
        )

        // Then
        #expect(found.firstValue.mediaTime == 3)
        #expect(found.firstValue.target.y == 700)
    }

    // MARK: - Private
    private func plan(
        _ connected: String?,
        storylineKeys: String = ""
    ) throws -> TimePlan {
        let clips = connected.map { #", "connected": [ \#($0) ]"# } ?? ""
        return try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { \#(storylineKeys) "id": "screen", "media": "/abs/screen.mp4", "in": 1\#(clips) } ] }
            """#))
    }

    private func crops(of plan: TimePlan) throws -> PropertyValue<FoundArea> {
        try sut.crops(
            plan.sequence.storyline[0].crop ?? .value(.scale(1)),
            in: screen,
            pictureClock: .storyline(plan.storyline[0]),
            clock: plan.storyline[0].map,
            instant: plan.storyline[0].edit.start,
            place: plan.storyline[0].place,
            kind: "video"
        )
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
            place: plan.clips[0].place,
            kind: "rect"
        )
    }
}
