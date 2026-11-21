//
//  CornerPinTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// The storyline is `/abs/screen.mp4`, 1206 by 2622. `/abs/card.png` is 1080 by 1350, so a card 300 wide is 375 high.
@Suite("CornerPin Tests")
struct CornerPinTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner
    private static let pin = "[[100, 100], [500, 120], [480, 400], [120, 380]]"
    private static let points = [
        Point(x: 100, y: 100), Point(x: 500, y: 120), Point(x: 480, y: 400), Point(x: 120, y: 380)
    ].map(GeometryPoint.point)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a corner pin places the clip's box by its four points, so the clip has no anchor point and no position")
    func placesByCornerPin() throws {
        // When
        let geometry = try geometry(of: #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300, "cornerPin": \#(Self.pin) }"#)

        // Then
        #expect(geometry.box == nil)
        #expect(geometry.cornerPin == ClipCornerPin(size: Size(width: 300, height: 375), points: .value(Self.points)))
    }

    @Test("a keyframed corner pin keeps its keyframes, in sequence time")
    func keepsKeyframes() throws {
        // Given
        let clip = #"""
            { "media": "/abs/card.png", "at": [1, 3], "width": 300,
              "keyframes": [ { "at": 1, "cornerPin": \#(Self.pin) }, { "at": 2, "cornerPin": [[0, 0], [10, 0], [10, 10], [0, 10]] } ] }
            """#

        // When
        let geometry = try geometry(of: clip)

        // Then
        guard case let .keyframes(keyframes) = geometry.cornerPin?.points else {
            Issue.record("expected keyframes")
            return
        }
        #expect(keyframes.map(\.at) == [1, 2])
        #expect(keyframes[0].value == Self.points)
    }

    @Test("a title whose style gives a placement is placed by its corner pin, its box its text box")
    func placesTitleByCornerPin() throws {
        // When
        let geometry = try geometry(of: #"{ "title": "Hello", "style": "subtitle", "at": [0, 3], "cornerPin": \#(Self.pin) }"#)

        // Then
        let size = try #require(geometry.title?.layout.size)
        #expect(geometry.box == nil)
        #expect(geometry.cornerPin?.size == size)
    }

    @Test("a rect given by its width and height takes its box from them, and a parented clip with a corner pin needs no position")
    func placesParentedRect() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [
              { "id": "card", "media": "/abs/card.png", "at": [0, 3], "width": 300, "position": [600, 600] },
              { "shape": "rect", "fill": "accent", "width": 40, "height": 20, "at": [0, 3], "parent": "card", "cornerPin": \#(Self.pin) } ] } ] }
            """#)

        // Then
        #expect(plan.clips[1].box == nil)
        #expect(plan.clips[1].cornerPin?.size == Size(width: 40, height: 20))
    }

    @Test(
        "a clip with a corner pin and a key that places it otherwise stops, naming both keys",
        arguments: [
            (#""placement": "top""#, "clips[0]", "placement"),
            (#""position": [10, 10]"#, "clips[0]", "position"),
            (#""anchor": "top-left""#, "clips[0]", "anchor"),
            (#""scale": 2"#, "clips[0]", "scale"),
            (#""rotation": 10"#, "clips[0]", "rotation"),
            (#""keyframes": [ { "at": 0, "opacity": 1 }, { "at": 1, "rotation": 10 } ]"#, "clips[0].keyframes[1]", "rotation")
        ]
    )
    func refusesPlacementKey(
        key: String,
        place: String,
        name: String
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300, "cornerPin": \#(Self.pin), \#(key) }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try geometry(of: clip) }
        #expect(error?.description == #"\#(place).\#(name) (image): a clip placed by "cornerPin" takes no "\#(name)", since its corner pin places it"#)
    }

    @Test(
        "a shape placed by its area takes no corner pin, since its outline is in its space already",
        arguments: [
            (#""cornerPin": PIN"#, "clips[0].cornerPin"),
            (#""keyframes": [ { "at": 0, "cornerPin": PIN } ]"#, "clips[0].keyframes[0].cornerPin")
        ]
    )
    func refusesShapeByArea(
        pin: String,
        place: String
    ) throws {
        // Given
        let clip = #"{ "shape": "rect", "fill": "accent", "area": [0, 0, 10, 10], "at": [0, 3], \#(pin) }"#
            .replacingOccurrences(of: "PIN", with: Self.pin)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try geometry(of: clip) }
        #expect(error?.description == #"\#(place) (rect): a shape placed by its area or points takes no "cornerPin", since its outline is in its space already"#)
    }

    @Test(
        "a corner pin that is not strictly convex stops, naming its place, and its time for a keyframe",
        arguments: [
            (
                #""cornerPin": [[0, 0], [10, 0], [0, 10], [10, 10]]"#,
                "clips[0].cornerPin (image): the corner pin is not strictly convex, so no homography takes the clip's box to it"
            ),
            (
                #""cornerPin": [[0, 0], [10, 0], [20, 0], [0, 10]]"#,
                "clips[0].cornerPin (image): the corner pin is not strictly convex, so no homography takes the clip's box to it"
            ),
            (
                #""keyframes": [ { "at": 0, "cornerPin": [[0, 0], [10, 0], [10, 10], [0, 10]] }, { "at": 2, "cornerPin": [[0, 0], [10, 0], [10, 10], [10, 10]] } ]"#,
                "clips[0].keyframes[1].cornerPin (image): the corner pin at 2 is not strictly convex, so no homography takes the clip's box to it"
            )
        ]
    )
    func refusesNonConvex(
        pin: String,
        message: String
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300, \#(pin) }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try geometry(of: clip) }
        #expect(error?.description == message)
    }

    @Test("a corner pin that runs counterclockwise is strictly convex, and places a mirrored picture")
    func takesMirroredCornerPin() throws {
        // When
        let geometry = try geometry(of: #"{ "media": "/abs/card.png", "at": [0, 3], "cornerPin": [[10, 0], [0, 0], [0, 10], [10, 10]] }"#)

        // Then
        #expect(geometry.cornerPin != nil)
    }

    @Test("a point of a clip area in a corner pin is kept as that clip area, for evaluation to take at each instant")
    func keepsClipAreaPoint() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [
              { "id": "card", "media": "/abs/card.png", "at": [0, 3], "width": 300, "position": [600, 600] },
              { "media": "/abs/card.png", "at": [0, 3],
                "cornerPin": [ { "area": { "clip": "card" }, "point": "top-left" }, [500, 120], [480, 400], [120, 380] ] } ] } ] }
            """#)

        // Then
        guard case let .value(points) = plan.clips[1].cornerPin?.points else {
            Issue.record("expected a static corner pin")
            return
        }
        #expect(points[0].clipArea?.clip == "card")
        #expect(Array(points[1...]) == Array(Self.points[1...]))
    }

    @Test("a storyline clip takes no clip area in its corner pin, since the storyline places it in output pixels")
    func refusesClipAreaOnStoryline() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4",
              "cornerPin": [ { "area": { "clip": "card" }, "point": "top-left" }, [500, 120], [480, 400], [120, 380] ],
              "connected": [ { "id": "card", "media": "/abs/card.png", "at": [0, 3], "width": 300 } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description.hasPrefix("storyline[0].cornerPin[0].area (video):") == true)
    }

    @Test("a storyline clip with a corner pin places its storyline picture's box, the frame, by its four points")
    func placesStorylineByCornerPin() throws {
        // When
        let plan = try plan(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "cornerPin": \#(Self.pin) } ] }"#)

        // Then
        let appearance = plan.storyline[0].appearance
        #expect(appearance.box == nil)
        #expect(appearance.cornerPin == ClipCornerPin(size: Size(width: 1206, height: 2622), points: .value(Self.points)))
    }

    @Test(
        "a storyline clip with a corner pin and a key that places it otherwise stops, naming both keys",
        arguments: [
            (#""position": [10, 10]"#, "storyline[0]", "position"),
            (#""anchor": "top-left""#, "storyline[0]", "anchor"),
            (#""scale": 2"#, "storyline[0]", "scale"),
            (#""keyframes": [ { "at": 0, "opacity": 1 }, { "at": 1, "rotation": 10 } ]"#, "storyline[0].keyframes[1]", "rotation")
        ]
    )
    func refusesStorylinePlacementKey(
        key: String,
        place: String,
        name: String
    ) throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "cornerPin": \#(Self.pin), \#(key) } ] }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"\#(place).\#(name) (video): a clip placed by "cornerPin" takes no "\#(name)", since its corner pin places it"#)
    }

    @Test("a storyline clip's corner pin that is not strictly convex stops, naming its place")
    func refusesStorylineNonConvex() throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "cornerPin": [[0, 0], [10, 0], [0, 10], [10, 10]] } ] }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == "storyline[0].cornerPin (video): the corner pin is not strictly convex, so no homography takes the clip's box to it")
    }

    @Test("a storyline clip's corner pin is in output pixels, so a text form in it stops")
    func refusesStorylineTextForm() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4",
              "cornerPin": [ { "area": { "text": "Total" }, "point": "top-left" }, [500, 120], [480, 400], [120, 380] ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description.hasPrefix("storyline[0].cornerPin[0] (video):") == true)
    }

    @Test("a storyline clip with a corner pin has no parent's media to follow, so track stops, naming the corner pin")
    func refusesTrackOnStorylineCornerPin() throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "cornerPin": \#(Self.pin), "track": { "text": "Total" } } ] }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"storyline[0].cornerPin (video): a storyline clip with a corner pin is placed in the frame, which has no media to follow, so it takes no "track""#)
    }

    @Test("a clip parented to a storyline clip with a corner pin is in output pixels, so a text form in it stops")
    func refusesTextUnderStorylineCornerPin() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "cornerPin": \#(Self.pin), "connected": [
              { "shape": "rect", "fill": "accent", "area": { "text": "Total" }, "at": [0, 3], "parent": "screen" } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description.hasPrefix("storyline[0]#screen.connected[0].area (rect): a text area is searched in the media of the clip's parent") == true)
    }

    @Test("a clip parented to a media clip with a corner pin searches text in that clip's parent's media, the space its corner pin is written in")
    func searchesTextUnderCornerPin() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
              { "id": "card", "media": "/abs/card.png", "at": [0, 3], "parent": "screen", "cornerPin": \#(Self.pin) },
              { "shape": "rect", "fill": "accent", "area": { "text": "Total" }, "at": [0, 3], "parent": "card" } ] } ] }
            """#

        // When
        let plan = try plan(document)

        // Then
        #expect(plan.clips[1].area?.firstValue.found?.rectangle == Fixture.total)
    }

    @Test("a clip parented to a clip whose corner pin holds a clip area takes no text form, since its parent's map moves with the named clip")
    func refusesTextUnderClipAreaCornerPin() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
              { "id": "bar", "shape": "rect", "fill": "accent", "area": [0, 0, 100, 100], "at": [0, 3], "parent": "screen" },
              { "id": "card", "media": "/abs/card.png", "at": [0, 3], "parent": "screen",
                "cornerPin": [ { "area": { "clip": "bar" }, "point": "top-left" }, [500, 120], [480, 400], [120, 380] ] },
              { "shape": "rect", "fill": "accent", "area": { "text": "Total" }, "at": [0, 3], "parent": "card" } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"storyline[0]#screen.connected[2].area (rect): text found under "card" is brought back through its transform when resolved, and its geometry, position or corner pin holds a clip area, whose box is known only when evaluated"#)
    }

    // MARK: - Private
    private func geometry(of clip: String) throws -> ClipGeometry {
        try plan(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip) ] }"#).clips[0]
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }
}
