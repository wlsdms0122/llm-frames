//
//  PathVertexCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

@Suite("Path Vertex Check Tests")
struct PathVertexCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a path's and a path mask's points take a point or a vertex object, and a mask takes two vertices",
        arguments: [
            #"{ "shape": "path", "at": [0, 1], "points": [ [0, 0], { "vertex": [10, 0], "inTangent": [-4, 0], "outTangent": [4, 0] } ] }"#,
            #"{ "shape": "path", "at": [0, 1], "points": [ { "vertex": { "area": [0, 0, 10, 10], "point": "top" } }, [10, 10] ] }"#,
            #"{ "shape": "path", "at": [0, 1], "points": [ [0, 0], [10, 0] ], "keyframes": [ { "at": 0, "points": [ { "outTangent": [5, 5] }, {} ] } ] }"#,
            #"{ "shape": "rect", "width": 10, "height": 10, "at": [0, 1], "mask": { "shape": "path", "points": [ { "vertex": [0, 0], "outTangent": [5, -5] }, { "vertex": [10, 0], "outTangent": [-5, 5] } ] } }"#
        ]
    )
    func takesVertices(clip: String) throws {
        // Given
        let document = try Self.document(clip)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a tangent takes two numbers and no form of an area, a static vertex object writes its point, and a vertex object stops where a point is taken",
        arguments: [
            (
                #"{ "shape": "path", "at": [0, 1], "points": [ [0, 0], { "vertex": [10, 0], "inTangent": { "area": [0, 0, 1, 1], "point": "top" } } ] }"#,
                "storyline[0].connected[0].points[1].inTangent"
            ),
            (
                #"{ "shape": "path", "at": [0, 1], "points": [ [0, 0], { "inTangent": [1, 1] } ] }"#,
                "storyline[0].connected[0].points[1]"
            ),
            (
                #"{ "shape": "rect", "width": 10, "height": 10, "at": [0, 1], "position": { "vertex": [0, 0] } }"#,
                "storyline[0].connected[0].position"
            )
        ]
    )
    func stopsVertex(clip: String, message: String) throws {
        // Given
        let document = try Self.document(clip)

        // When
        let error = #expect(throws: (any Error).self) { try sut.check(document: document) }

        // Then
        #expect(error.map { "\($0)" }?.hasPrefix(message) == true, "\(error.map { "\($0)" } ?? "")")
    }

    @Test("a vertex leaf written statically and in a keyframe stops, while its other leaves may be keyframed")
    func stopsStaticAndKeyframedLeaf() throws {
        // Given
        let tangents = try Self.document(
            #"{ "shape": "path", "at": [0, 1], "points": [ [0, 0], [10, 0] ], "keyframes": [ { "at": 0, "points": [ { "outTangent": [1, 1] }, {} ] } ] }"#
        )
        let points = try Self.document(
            #"{ "shape": "path", "at": [0, 1], "points": [ [0, 0], [10, 0] ], "keyframes": [ { "at": 0, "points": [ [1, 1], {} ] } ] }"#
        )

        // When
        let error = #expect(throws: ModelError.self) { try sut.check(document: points) }

        // Then
        try sut.check(document: tangents)
        #expect(error.map { "\($0)" }?.hasPrefix("storyline[0].connected[0].points[0]") == true)
    }

    @Test("a keyframe's leaves name each vertex's point and tangents, a point naming its point alone")
    func namesVertexLeaves() throws {
        // Given
        let keyframe = try #require(try Fixture.json(
            #"{ "at": 0, "points": [ [0, 0], { "inTangent": [1, 1], "outTangent": [2, 2] } ] }"#
        ).objectValue)

        // When
        let leaves = KeyframeReader().leaves(of: keyframe).map(\.description)

        // Then
        #expect(leaves == ["points[0].vertex", "points[1].inTangent", "points[1].outTangent"])
    }

    // MARK: - Private
    private static func document(_ clip: String) throws -> JSONValue {
        try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ CLIP ] } ] }
            """#.replacingOccurrences(of: "CLIP", with: clip))
    }
}
