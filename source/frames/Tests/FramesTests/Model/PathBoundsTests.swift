//
//  PathBoundsTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

@Suite("Path Bounds Tests")
struct PathBoundsTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a path of straight segments is bounded by its points")
    func boundsStraightPath() {
        // Given
        let sut = [Self.vertex(0, 0), Self.vertex(100, 0), Self.vertex(50, 80)]

        // When
        let bounds = sut.bounds(isClosed: false)

        // Then
        #expect(bounds == Rectangle(x: 0, y: 0, width: 100, height: 80))
    }

    @Test("a curve is bounded where it reaches and not by its control points")
    func boundsCurve() {
        // Given
        let sut = [
            Self.vertex(0, 0, outTangent: Point(x: 0, y: 100)),
            Self.vertex(100, 0, inTangent: Point(x: 0, y: 100))
        ]

        // When
        let bounds = sut.bounds(isClosed: false)

        // Then
        #expect(abs(bounds.height - 75) < 1e-9)
        #expect(bounds.x == 0 && bounds.y == 0 && bounds.width == 100)
    }

    @Test("a closed path's closing segment takes the last vertex's out tangent and the first's in tangent")
    func boundsClosingSegment() {
        // Given
        let sut = [
            Self.vertex(0, 0, inTangent: Point(x: 0, y: -100)),
            Self.vertex(100, 0, outTangent: Point(x: 0, y: -100))
        ]

        // When
        let open = sut.bounds(isClosed: false)
        let closed = sut.bounds(isClosed: true)

        // Then
        #expect(open.height == 0)
        #expect(abs(closed.y + 75) < 1e-9)
    }

    // MARK: - Private
    private static func vertex(
        _ x: Double,
        _ y: Double,
        inTangent: Point = Point(x: 0, y: 0),
        outTangent: Point = Point(x: 0, y: 0)
    ) -> PathVertex<Point, Point> {
        PathVertex(vertex: Point(x: x, y: y), inTangent: inTangent, outTangent: outTangent)
    }
}
