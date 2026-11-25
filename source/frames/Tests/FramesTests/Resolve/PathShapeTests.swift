//
//  PathShapeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

// Path shapes are sequence clips over `/abs/screen.mp4` in a 960 by 540 frame. The curve from (0, 0) to (100, 0) with
// an out tangent of [0, 40] and an in tangent of [0, 40] has y(t) = 120 t (1 - t), so its box is 100 by 30, where the
// box of its control points is 100 by 40.
@Suite("PathShape Tests")
struct PathShapeTests {
    // MARK: - Property
    private static let curve = #"[{ "vertex": [0, 0], "outTangent": [0, 40] }, { "vertex": [100, 0], "inTangent": [0, 40] }]"#
    private static let zero = Point(x: 0, y: 0)

    private let sut = Fixture.sequencePlanner

    // MARK: - Initializer
    // MARK: - Test
    @Test("a static vertex written as a point has its point as a value and both its tangents [0, 0]")
    func splitsPointVertex() throws {
        // Given
        let property = PathProperty(written: [try Fixture.json("[1, 2]")], keyframes: [])

        // When
        let vertices = property.vertices

        // Then
        #expect(vertices == [PathVertex(vertex: .value(.point(Point(x: 1, y: 2))), inTangent: .value(Self.zero), outTangent: .value(Self.zero))])
    }

    @Test("a vertex object's tangents are its own, and one it leaves out is [0, 0]")
    func splitsVertexObject() throws {
        // Given
        let property = PathProperty(written: [try Fixture.json(#"{ "vertex": [1, 2], "outTangent": [3, 4] }"#)], keyframes: [])

        // When
        let vertex = try #require(property.vertices.first)

        // Then
        #expect(vertex.vertex == .value(.point(Point(x: 1, y: 2))))
        #expect(vertex.inTangent == .value(Self.zero))
        #expect(vertex.outTangent == .value(Point(x: 3, y: 4)))
    }

    @Test("keyframes that write only tangents time the tangents and leave the static points as values")
    func timesTangentsBesideStaticPoints() throws {
        // Given
        let property = PathProperty(
            written: [try Fixture.json("[0, 0]"), try Fixture.json("[100, 0]")],
            keyframes: [
                PropertyKeyframe(index: 0, at: 0, value: [try Fixture.json(#"{ "outTangent": [0, 40] }"#), try Fixture.json("{}")], ease: .easeIn),
                PropertyKeyframe(index: 2, at: 1, value: [try Fixture.json(#"{ "outTangent": [0, 80] }"#), try Fixture.json("{}")], ease: .linear)
            ]
        )

        // When
        let vertices = property.vertices

        // Then
        #expect(vertices.map(\.vertex) == [.value(.point(Self.zero)), .value(.point(Point(x: 100, y: 0)))])
        #expect(vertices[0].outTangent == .keyframes([
            PropertyKeyframe(index: 0, at: 0, value: Point(x: 0, y: 40), ease: .easeIn),
            PropertyKeyframe(index: 2, at: 1, value: Point(x: 0, y: 80), ease: .linear)
        ]))
        #expect(vertices[0].inTangent == .value(Self.zero))
        #expect(vertices[1].outTangent == .value(Self.zero))
    }

    @Test("keyframes that move only the points keep the static tangents, and a point each keyframe writes alone names no tangent")
    func keepsTangentsUnderMovedPoints() throws {
        // Given
        let property = PathProperty(
            written: [try Fixture.json(#"{ "outTangent": [5, 0] }"#)],
            keyframes: [PropertyKeyframe(index: 0, at: 0, value: [try Fixture.json("[1, 1]")], ease: .linear)]
        )

        // When
        let vertex = try #require(property.vertices.first)

        // Then
        #expect(vertex.vertex == .keyframes([PropertyKeyframe(index: 0, at: 0, value: .point(Point(x: 1, y: 1)), ease: .linear)]))
        #expect(vertex.outTangent == .value(Point(x: 5, y: 0)))
    }

    @Test("a vertex's point is placed where the document writes it, under `vertex` for a vertex object")
    func placesVertexPoint() throws {
        // Given
        let clip = Place(components: [.key("clips"), .index(0, id: nil)])
        let property = PathProperty(
            written: [try Fixture.json("[0, 0]"), try Fixture.json(#"{ "vertex": [1, 1] }"#)],
            keyframes: [PropertyKeyframe(index: 3, at: 0, value: [try Fixture.json(#"{ "vertex": [2, 2] }"#), try Fixture.json("[3, 3]")], ease: .linear)]
        )

        // When
        let places = property.points(in: clip).map(\.place.description)

        // Then
        #expect(places == [
            "clips[0].points[0]", "clips[0].points[1].vertex", "clips[0].keyframes[3].points[0].vertex", "clips[0].keyframes[3].points[1]"
        ])
    }

    @Test("a resolved path holds each vertex's point and tangents, each timed on its own in sequence time")
    func resolvesVertexLeaves() throws {
        // When
        let shape = try resolvedShape(#"""
            { "shape": "path", "stroke": { "width": 4 }, "points": [[0, 0], [100, 0]], "at": [0, 1],
              "keyframes": [ { "at": 0.25, "points": [{ "outTangent": [0, 40] }, {}], "ease": "ease-in" },
                             { "at": 0.75, "points": [{ "outTangent": [0, 80] }, { "vertex": [200, 0] }] } ] }
            """#)

        // Then
        guard case let .points(vertices, _, _) = shape.geometry else {
            Issue.record("the path is placed by its points")
            return
        }
        #expect(vertices[0].vertex == .keyframes([Keyframe(at: 0, value: .point(Self.zero))]))
        #expect(vertices[0].outTangent == .keyframes([
            Keyframe(at: 0.25, value: Point(x: 0, y: 40), ease: .easeIn),
            Keyframe(at: 0.75, value: Point(x: 0, y: 80))
        ]))
        #expect(vertices[0].inTangent == .keyframes([Keyframe(at: 0, value: Self.zero)]))
        #expect(vertices[1].vertex == .keyframes([Keyframe(at: 0.75, value: .point(Point(x: 200, y: 0)))]))
        #expect(vertices[1].outTangent == .keyframes([Keyframe(at: 0, value: Self.zero)]))
    }

    @Test("a curved path's named anchor is a point of the curve's box, not of its control points' box")
    func anchorsOnCurveBox() throws {
        // When
        let shape = try resolvedShape(#"{ "shape": "path", "stroke": { "width": 4 }, "points": \#(Self.curve), "anchor": "bottom", "position": [500, 300], "at": [0, 1] }"#)

        // Then
        guard case let .point(anchor) = shape.geometry.placement?.anchor else {
            Issue.record("the anchor is a point")
            return
        }
        #expect(isClose(anchor, Point(x: 50, y: 30)), "the anchor is \(anchor)")
    }

    @Test("a clip area in a vertex object's point names a clip and stays a clip area")
    func keepsClipAreaInVertex() throws {
        // When
        let clips = try resolvedClips(#"""
            { "id": "box", "shape": "rect", "area": [10, 20, 30, 40], "fill": "accent", "at": [0, 1] },
            { "shape": "path", "stroke": { "width": 4 }, "points": [[0, 0], { "vertex": { "area": { "clip": "box" }, "point": "right" }, "inTangent": [5, 0] }], "at": [0, 1] }
            """#)

        // Then
        guard case let .picture(.shape(shape), _) = clips[1].content, case let .points(vertices, _, _) = shape.geometry else {
            Issue.record("the second clip is a path")
            return
        }
        #expect(vertices[1].vertex.values.first?.clipArea != nil)
        #expect(vertices[1].inTangent.values == [Point(x: 5, y: 0)])
    }

    @Test("a clip area naming a vertex object's clip that does not exist stops at the vertex's area")
    func stopsOnUnknownClipInVertex() throws {
        // Given
        let document = document(#"{ "shape": "path", "points": [[0, 0], { "vertex": { "area": { "clip": "none" }, "point": "right" } }], "fill": "accent", "at": [0, 1] }"#)

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(document) }
        #expect("\(error.map { "\($0)" } ?? "")".hasPrefix("clips[0].points[1].vertex.area"), "\(error.map { "\($0)" } ?? "no error")")
    }

    @Test("a shape parent placed by a curved path gives its children the space of the curve's box, its centre kept under its scale")
    func scalesParentAboutCurveBox() throws {
        // Given
        let sequence = try ResolvedSequence(plan: plan(document(#"""
            { "id": "curve", "shape": "path", "stroke": { "width": 4 }, "points": \#(Self.curve), "scale": 2, "at": [0, 1] },
            { "shape": "rect", "parent": "curve", "area": [0, 0, 10, 10], "fill": "accent", "at": [0, 1] }
            """#)), hashes: FileHashTable())
        let sut = ParentEvaluator(sequence: sequence)

        // When
        let transform = sut.space(of: sequence.clips[1], at: SampleTime(0)).transform

        // Then
        #expect(isClose(transform.apply(to: Point(x: 50, y: 15)), Point(x: 50, y: 15)))
        #expect(isClose(transform.apply(to: Self.zero), Point(x: -50, y: -15)))
    }

    @Test("a clip area naming a curved path is the curve's box")
    func takesCurveBoxAsClipArea() throws {
        // Given
        let sequence = try ResolvedSequence(plan: plan(document(#"""
            { "id": "curve", "shape": "path", "stroke": { "width": 4 }, "points": \#(Self.curve), "at": [0, 1] },
            { "shape": "rect", "area": { "clip": "curve" }, "fill": "accent", "at": [0, 1] }
            """#)), hashes: FileHashTable())
        let rect = sequence.clips[1]
        guard case let .picture(.shape(shape), _) = rect.content, case let .area(area, _, _) = shape.geometry, let value = area.values.first else {
            Issue.record("the rect is placed by its area")
            return
        }

        // When
        let box = ClipAreaSampler(sequence: sequence, clip: rect).rectangle(of: value, at: SampleTime(0))

        // Then
        #expect(isClose(Point(x: box.x, y: box.y), Self.zero) && isClose(Point(x: box.maxX, y: box.maxY), Point(x: 100, y: 30)), "the box is \(box)")
    }

    @Test("content fit moves a path's points with the content and keeps its tangents, which are offsets")
    func movesPointsAndKeepsTangentsUnderContentFit() throws {
        // When
        let plan = try sut.plan(Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "format": { "size": { "fit": "content", "margin": 0 } },
              "storyline": [ { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ],
              "clips": [ { "shape": "path", "stroke": { "width": 2 }, "points": [{ "vertex": [-50, 0], "outTangent": [0, 40] }, [0, 0]], "at": [0, 1] } ] }
            """#)))

        // Then
        let vertices = try #require(plan.clips[0].points)
        let first = try #require(vertices[0].vertex.values.first).fixed
        #expect(first.x > -50)
        #expect(vertices[1].vertex.values == [.point(Point(x: first.x + 50, y: first.y))])
        #expect(vertices[0].outTangent.values == [Point(x: 0, y: 40)])
    }

    // MARK: - Private
    private func document(_ clips: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [960, 540] }, "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clips) ] }
            """#
    }

    private func isClose(
        _ point: Point,
        _ other: Point
    ) -> Bool {
        abs(point.x - other.x) < 1e-9 && abs(point.y - other.y) < 1e-9
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    private func resolvedClips(_ clips: String) throws -> [ResolvedClip] {
        try ResolvedSequence(plan: plan(document(clips)), hashes: FileHashTable()).clips
    }

    private func resolvedShape(_ clip: String) throws -> ResolvedShape {
        guard case let .picture(.shape(shape), _) = try resolvedClips(clip).first?.content else {
            Issue.record("the clip is a shape")
            return ResolvedShape(area: [], fill: nil)
        }

        return shape
    }
}
