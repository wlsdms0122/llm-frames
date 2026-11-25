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
    private let sut = GeometryFinder()
    private let screen = Picture(
        name: "/abs/screen.mp4",
        size: Size(width: 1206, height: 2622)
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("each keyframe's area comes back in sequence time, with its index and ease")
    func findsKeyframesAtTheirTimes() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [1, 3],
              "keyframes": [ { "at": 1, "area": [100, 100, 200, 40], "ease": "ease-in-out" }, { "at": 2.5, "area": [100, 700, 200, 40] } ] }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let found = try find(clip.area, plan: plan)

        // Then
        guard case let .keyframes(keyframes) = found else {
            Issue.record("keyframes were not kept")
            return
        }
        #expect(keyframes.map(\.at) == [0, 1.5])
        #expect(keyframes.map(\.value.y) == [100, 700])
        #expect(keyframes.map(\.index) == [0, 1])
        #expect(keyframes.map(\.ease) == [.easeInOut, .linear])
    }

    @Test("a keyframe's crop that stops names the keyframe")
    func namesKeyframeInStop() throws {
        // Given
        let plan = try plan(
            nil,
            storylineKeys: #""keyframes": [ { "at": 1, "crop": [0, 0, 603, 1311] }, { "at": 2, "crop": { "clip": "screen" } } ],"#
        )

        // When, Then
        let error = #expect(throws: AreaError.self) {
            try crops(of: plan)
        }
        #expect(error == .clipAreaInPicture(place: plan.storyline[0].place.appending(key: "keyframes").appending(index: 1).appending(key: "crop"), kind: "video"))
    }

    @Test("a crop of {scale} is the centred region of 1/scale the picture, and a rectangle crop is kept as written")
    func findsCrops() throws {
        // Given
        let scalePlan = try plan(nil, storylineKeys: #""crop": { "scale": 2 },"#)
        let areaPlan = try plan(nil, storylineKeys: #""crop": [60, 60, 280, 120],"#)

        // When
        let scale = try crops(of: scalePlan)
        let area = try crops(of: areaPlan)

        // Then
        #expect(scale == .value(Rectangle(x: 301.5, y: 655.5, width: 603, height: 1311)))
        #expect(area == .value(Rectangle(x: 60, y: 60, width: 280, height: 120)))
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
        #expect(numeric.firstValue == Rectangle(x: -603, y: -1311, width: 2412, height: 5244))
    }

    @Test("a position by an area is the point it names on the area")
    func findsPositionOnArea() throws {
        // Given
        let plan = try plan(#"""
            { "title": "a", "style": "title", "parent": "screen", "position": { "area": [86, 86, 228, 68], "point": "right" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let position = try positions(of: clip, plan: plan, kind: "title")

        // Then
        #expect(position == .value(.point(Point(x: 314, y: 120))))
    }

    @Test(
        "a position by an area and a placement name is that point of the area",
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
            { "title": "a", "style": "title", "parent": "screen", "position": { "area": [90, 90, 220, 60], "point": "\#(name)" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let position = try positions(of: clip, plan: plan, kind: "title")

        // Then
        #expect(position == .value(.point(point)))
    }

    @Test("a point on an area past the picture's edge lies past the edge")
    func findsPointPastPicture() throws {
        // Given
        let plan = try plan(#"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [-50, -50, 500, 340],
              "position": { "area": [-50, -50, 500, 340], "point": "top-left" } }
            """#)
        let clip = plan.sequence.storyline[0].connected[0]

        // When
        let area = try find(clip.area, plan: plan)
        let position = try positions(of: clip, plan: plan, kind: "rect")

        // Then
        #expect(area == .value(Rectangle(x: -50, y: -50, width: 500, height: 340)))
        #expect(position == .value(.point(Point(x: -50, y: -50))))
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

    private func crops(of plan: TimePlan) throws -> PropertyValue<Rectangle> {
        try sut.crops(
            plan.sequence.storyline[0].crop ?? .value(.scale(1)),
            in: screen,
            clock: plan.storyline[0].map,
            place: plan.storyline[0].place,
            kind: "video"
        )
    }

    private func positions(
        of clip: Clip,
        plan: TimePlan,
        kind: String
    ) throws -> PropertyValue<GeometryPoint> {
        try sut.positions(
            clip.position ?? .value(.point(Point(x: 0, y: 0))),
            clock: plan.clips[0].clock,
            lengthScale: 1,
            place: clip.place,
            kind: kind
        )
    }

    private func find(
        _ property: PropertyValue<AreaForm>?,
        plan: TimePlan
    ) throws -> PropertyValue<Rectangle> {
        try sut.areas(
            property ?? .value(.rectangle(Rectangle(x: 0, y: 0, width: 1, height: 1))),
            key: "area",
            clock: plan.clips[0].clock,
            lengthScale: 1,
            place: plan.clips[0].place,
            kind: "rect"
        ).map { try #require($0.rectangle) }
    }
}
