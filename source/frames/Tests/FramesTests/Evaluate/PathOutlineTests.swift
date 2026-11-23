//
//  PathOutlineTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation
import Testing

@testable import Frames

// A path's outline, its corners and its arrowheads (FRAMES-20 Direction at a point, Arrowheads).
@Suite("PathOutline Tests")
struct PathOutlineTests {
    // MARK: - Property
    private static let zero = Point(x: 0, y: 0)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a path whose tangents are all 0 is the straight segments through its vertices")
    func drawsStraightPath() {
        // Given
        let geometry = PathGeometry.path(
            [Point(x: 0, y: 0), Point(x: 30, y: 40), Point(x: 30, y: 0)].map { point in
                PathVertex(vertex: point, inTangent: Self.zero, outTangent: Self.zero)
            },
            isClosed: true
        )

        // When
        let sut = PathOutline(geometry)

        // Then
        #expect(sut.segments == [
            .line(from: Point(x: 0, y: 0), to: Point(x: 30, y: 40)),
            .line(from: Point(x: 30, y: 40), to: Point(x: 30, y: 0)),
            .line(from: Point(x: 30, y: 0), to: Point(x: 0, y: 0))
        ])
        #expect(sut.length == 120)
    }

    @Test("a closed path's last segment runs from its last vertex's out tangent to its first vertex's in tangent")
    func closesWithTangents() {
        // Given
        let geometry = PathGeometry.path(
            [
                PathVertex(vertex: Point(x: 0, y: 0), inTangent: Point(x: 0, y: 20), outTangent: Self.zero),
                PathVertex(vertex: Point(x: 100, y: 0), inTangent: Self.zero, outTangent: Point(x: 0, y: 20))
            ],
            isClosed: true
        )

        // When
        let sut = PathOutline(geometry)

        // Then
        #expect(sut.segments == [
            .line(from: Point(x: 0, y: 0), to: Point(x: 100, y: 0)),
            .cubic(from: Point(x: 100, y: 0), first: Point(x: 100, y: 20), second: Point(x: 0, y: 20), to: Point(x: 0, y: 0))
        ])
    }

    @Test(
        "a vertex is a corner where the directions arriving and leaving differ, and smooth where they agree",
        arguments: [
            // The out tangent continues the in tangent's line, so the vertex is smooth.
            (Point(x: 0, y: 50), false),
            (Point(x: -50, y: 0), true)
        ]
    )
    func findsVertexCorner(
        outTangent: Point,
        isCorner: Bool
    ) {
        // Given
        let geometry = PathGeometry.path(
            [
                PathVertex(vertex: Point(x: 0, y: 0), inTangent: Self.zero, outTangent: Point(x: 50, y: 0)),
                PathVertex(vertex: Point(x: 100, y: 50), inTangent: Point(x: 0, y: -50), outTangent: outTangent),
                PathVertex(vertex: Point(x: 0, y: 100), inTangent: Point(x: 50, y: 0), outTangent: Self.zero)
            ],
            isClosed: false
        )
        let sut = PathOutline(geometry)

        // When
        let corners = sut.corners(drawnBy: drawn(width: 2, trim: .whole, isClosed: false))

        // Then
        // Arriving at (100, 50) from its in tangent's end at (100, 0), the outline heads down.
        #expect(corners.count == (isCorner ? 1 : 0))
        if isCorner {
            #expect(corners[0].point == Point(x: 100, y: 50))
            #expect(corners[0].arriving == Point(x: 0, y: 1))
            #expect(corners[0].leaving == Point(x: -1, y: 0))
        }
    }

    @Test("a cusp inside a segment is a corner, where the outline turns back")
    func findsCuspCorner() throws {
        // Given
        let geometry = PathGeometry.path(
            [
                PathVertex(vertex: Point(x: 0, y: 0), inTangent: Self.zero, outTangent: Point(x: 100, y: 100)),
                PathVertex(vertex: Point(x: 100, y: 0), inTangent: Point(x: -100, y: 100), outTangent: Self.zero)
            ],
            isClosed: false
        )
        let sut = PathOutline(geometry)

        // When
        let corners = sut.corners(drawnBy: drawn(width: 2, trim: .whole, isClosed: false))

        // Then
        let corner = try #require(corners.first)
        #expect(corners.count == 1)
        #expect(abs(corner.point.x - 50) < 1e-6 && abs(corner.point.y - 75) < 1e-6)
        #expect(abs(corner.arriving.y - 1) < 1e-6)
        #expect(abs(corner.leaving.y + 1) < 1e-6)
    }

    @Test("a straight end's arrowhead lies along the outline, its base 4 widths back, as long as it is wide")
    func laysStraightArrowhead() throws {
        // Given
        let sut = PathOutline(.polyline([Point(x: 0, y: 0), Point(x: 100, y: 0)], isClosed: false))

        // When
        let head = try #require(sut.arrowheads(of: drawn(width: 2, trim: .whole, isClosed: false, end: .arrow)).first)

        // Then
        #expect(head.tip == Point(x: 100, y: 0))
        #expect(abs(head.base.x - 92) < 1e-9 && head.base.y == 0)
        #expect(head.axis == Point(x: 1, y: 0))
        #expect(abs(head.length - 8) < 1e-9)
        #expect(head.width == 8)
    }

    @Test("a curved end's arrowhead runs along the chord from its base on the stroke to its tip")
    func laysCurvedArrowhead() throws {
        // Given
        // A circle of radius 100 about (100, 100) trimmed to its first quarter ends at (200, 100). A stroke 100π/24 wide
        // puts the base 100π/6 back along it, at 60 degrees from the top, (100 + 50√3, 50).
        let sut = PathOutline(.ellipse(Rectangle(x: 0, y: 0, width: 200, height: 200)))
        let width = 100 * Double.pi / 24

        // When
        let head = try #require(
            sut.arrowheads(of: drawn(width: width, trim: Trim(start: 0, end: 0.25), isClosed: true, end: .arrow)).first
        )

        // Then
        // The chord spans 30 degrees, 200 sin 15° long.
        let base = Point(x: 100 + 50 * 3.0.squareRoot(), y: 50)
        let chord = 200 * sin(Double.pi / 12)
        #expect(abs(head.tip.x - 200) < 1e-9 && abs(head.tip.y - 100) < 1e-9)
        #expect(abs(head.base.x - base.x) < 1e-9 && abs(head.base.y - base.y) < 1e-9)
        #expect(abs(head.length - chord) < 1e-9)
        #expect(abs(head.width - 4 * width) < 1e-9)
        #expect(abs(head.axis.x - (200 - base.x) / chord) < 1e-9)
        #expect(abs(head.axis.y - 50 / chord) < 1e-9)
    }

    @Test("a path's box is its curve's, carried with its tangents by a map's linear part")
    func boundsCarriedCurve() {
        // Given
        // The segment bulges to y = 75 at its middle, and the map doubles x and moves everything 10 right.
        let sut = PathGeometry.path(
            [
                PathVertex(vertex: Point(x: 0, y: 0), inTangent: Self.zero, outTangent: Point(x: 0, y: 100)),
                PathVertex(vertex: Point(x: 100, y: 0), inTangent: Point(x: 0, y: 100), outTangent: Self.zero)
            ],
            isClosed: false
        )
        let transform = AffineTransform(a: 2, b: 0, c: 0, d: 1, tx: 10, ty: 0)

        // When
        let box = sut.bounds(carriedBy: transform)

        // Then
        #expect(box == Rectangle(x: 10, y: 0, width: 200, height: 75))
    }

    // MARK: - Private
    private func drawn(
        width: Double,
        trim: Trim,
        isClosed: Bool,
        end: StrokeEnd = .none
    ) -> DrawnStroke {
        DrawnStroke(
            stroke: PathStroke(
                width: width,
                paint: .color(Color(written: "#FF0000")),
                join: .miter,
                cap: .butt,
                start: .none,
                end: end
            ),
            trim: trim,
            isClosed: isClosed
        )
    }
}
