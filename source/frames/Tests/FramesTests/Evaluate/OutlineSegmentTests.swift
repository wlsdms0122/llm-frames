//
//  OutlineSegmentTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation
import Testing

@testable import Frames

// Curves whose numbers follow by hand: a straight cubic, whose control points sit on its ends; the cubic of a quarter
// circle of radius 100, whose control points lie 4/3 (√2 - 1) of the radius along its end tangents; an S curve and a
// cusp, each symmetric about its middle, so its middle lies at half its length.
@Suite("OutlineSegment Tests")
struct OutlineSegmentTests {
    // MARK: - Property
    private static let kappa = 4.0 / 3 * (2.0.squareRoot() - 1) * 100
    private static let quarter = OutlineSegment.cubic(
        from: Point(x: 100, y: 0),
        first: Point(x: 100, y: kappa),
        second: Point(x: kappa, y: 100),
        to: Point(x: 0, y: 100)
    )
    private static let curve = OutlineSegment.cubic(
        from: Point(x: 0, y: 0),
        first: Point(x: 50, y: 0),
        second: Point(x: 50, y: 100),
        to: Point(x: 100, y: 100)
    )
    private static let cusp = OutlineSegment.cubic(
        from: Point(x: 0, y: 0),
        first: Point(x: 100, y: 100),
        second: Point(x: 0, y: 100),
        to: Point(x: 100, y: 0)
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a cubic whose control points sit on its ends is a straight segment, measured and walked by its arc length")
    func measuresStraightCubic() {
        // Given
        let sut = OutlineSegment.cubic(
            from: Point(x: 0, y: 0),
            first: Point(x: 0, y: 0),
            second: Point(x: 30, y: 40),
            to: Point(x: 30, y: 40)
        )

        // When
        let length = sut.length
        let middle = sut.point(at: 25)
        let directions = [sut.direction(at: 0), sut.direction(at: 25), sut.direction(at: 50)]

        // Then
        #expect(abs(length - 50) < 1e-9)
        #expect(close(middle, Point(x: 15, y: 20), within: 1e-9))
        #expect(directions.allSatisfy { close($0, Point(x: 0.6, y: 0.8), within: 1e-9) })
        #expect(sut.cusps.isEmpty)
    }

    @Test("the quarter circle's cubic is a quarter of the circle long, and halfway along it lies on the diagonal")
    func measuresQuarterCircle() {
        // Given
        let sut = Self.quarter

        // When
        let length = sut.length
        let middle = sut.point(at: length / 2)

        // Then
        // The cubic strays from the circle by less than 2.73e-4 of its radius, so its length by as little.
        #expect(abs(length - 50 * .pi) < 0.05)
        #expect(abs(middle.x - middle.y) < 1e-6)
        #expect(abs(hypot(middle.x, middle.y) - 100) < 0.03)
        #expect(close(sut.direction(at: 0), Point(x: 0, y: 1), within: 1e-12))
        #expect(close(sut.direction(at: length / 2), Point(x: -0.5.squareRoot(), y: 0.5.squareRoot()), within: 1e-6))
        #expect(close(sut.direction(at: length), Point(x: -1, y: 0), within: 1e-12))
    }

    @Test("at an end where a control point sits on the end, the direction is toward the next control point that differs")
    func takesLimitDirectionAtEnds() {
        // Given
        let sut = OutlineSegment.cubic(
            from: Point(x: 0, y: 0),
            first: Point(x: 0, y: 0),
            second: Point(x: 100, y: 0),
            to: Point(x: 100, y: 100)
        )

        // When
        let start = sut.direction(at: 0)
        let end = sut.direction(at: sut.length)

        // Then
        #expect(close(start, Point(x: 1, y: 0), within: 1e-12))
        #expect(close(end, Point(x: 0, y: 1), within: 1e-12))
    }

    @Test("an S curve symmetric about its middle passes it at half its length, heading along its velocity there")
    func walksSymmetricCurve() {
        // Given
        let sut = Self.curve

        // When
        let middle = sut.point(at: sut.length / 2)
        let direction = sut.direction(at: sut.length / 2)

        // Then
        // At t = 1/2 the velocity is 3 (1/4 (50, 0) + 1/2 (0, 100) + 1/4 (50, 0)) = (75, 150).
        #expect(close(middle, Point(x: 50, y: 50), within: 1e-6))
        #expect(close(direction, Point(x: 1 / 5.0.squareRoot(), y: 2 / 5.0.squareRoot()), within: 1e-6))
        #expect(sut.cusps.isEmpty)
    }

    @Test("a cubic whose velocity is 0 inside it has a cusp there, where it turns back")
    func findsCusp() throws {
        // Given
        let sut = Self.cusp

        // When
        let cusp = try #require(sut.cusps.first)

        // Then
        // Its velocity is 300 ((1 - 2t)², 1 - 2t), 0 at t = 1/2, where it is at (50, 75) and its acceleration (0, -600).
        #expect(sut.cusps.count == 1)
        #expect(abs(cusp.distance - sut.length / 2) < 1e-6)
        #expect(cusp.point == Point(x: 50, y: 75))
        #expect(cusp.leaving == Point(x: 0, y: -1))
        #expect(close(sut.direction(at: cusp.distance - 1), Point(x: 0, y: 1), within: 0.15))
        #expect(close(sut.direction(at: cusp.distance + 1), Point(x: 0, y: -1), within: 0.15))
    }

    @Test("a piece of a cubic between two lengths is the cubic de Casteljau's split gives, as long as the lengths' gap")
    func splitsAtLengths() throws {
        // Given
        let sut = Self.curve
        let half = sut.length / 2

        // When
        let head = sut.piece(from: 0, to: half)
        let tail = sut.piece(from: half, to: sut.length)
        let whole = sut.piece(from: 0, to: sut.length)

        // Then
        // Split at t = 1/2, the first half's control points are (25, 0) and (37.5, 25).
        guard case let .cubic(from, first, second, to) = head else { Issue.record("not a cubic"); return }
        #expect(close(from, Point(x: 0, y: 0), within: 1e-9))
        #expect(close(first, Point(x: 25, y: 0), within: 1e-6))
        #expect(close(second, Point(x: 37.5, y: 25), within: 1e-6))
        #expect(close(to, Point(x: 50, y: 50), within: 1e-6))
        #expect(abs(head.length - half) < 1e-6)
        #expect(abs(tail.length - half) < 1e-6)
        #expect(whole == sut)
    }

    // The arc length is measured independently by a polyline of 200000 chords, each under 0.003 long, and the point
    // at a distance found between the two samples around it.
    @Test(
        "the point at a distance along a cubic is where that much of its arc length runs out, its cusp's kink included",
        arguments: [
            OutlineSegment.cubic(
                from: Point(x: 0, y: 0),
                first: Point(x: 30, y: 120),
                second: Point(x: 200, y: -40),
                to: Point(x: 240, y: 80)
            ),
            Self.cusp
        ]
    )
    func walksByArcLength(sut: OutlineSegment) {
        // Given
        guard case let .cubic(from, first, second, to) = sut else { Issue.record("not a cubic"); return }
        let count = 200_000
        let samples = (0...count).map { index in
            let t = Double(index) / Double(count)
            let rest = 1 - t
            let weights = (rest * rest * rest, 3 * rest * rest * t, 3 * rest * t * t, t * t * t)
            return Point(
                x: weights.0 * from.x + weights.1 * first.x + weights.2 * second.x + weights.3 * to.x,
                y: weights.0 * from.y + weights.1 * first.y + weights.2 * second.y + weights.3 * to.y
            )
        }
        var lengths = [0.0]
        for (point, next) in zip(samples, samples.dropFirst()) {
            lengths.append(lengths[lengths.count - 1] + hypot(next.x - point.x, next.y - point.y))
        }
        let total = lengths[count]

        // When
        let length = sut.length
        let points = (1..<10).map { tenth in sut.point(at: total * Double(tenth) / 10) }

        // Then
        #expect(abs(length - total) < 1e-4, "\(length) against \(total)")
        for (tenth, point) in zip(1..., points) {
            let distance = total * Double(tenth) / 10
            let index = max(lengths.firstIndex { $0 >= distance } ?? count, 1)
            let part = (distance - lengths[index - 1]) / (lengths[index] - lengths[index - 1])
            let expected = Point.interpolate(from: samples[index - 1], to: samples[index], progress: part)
            #expect(close(point, expected, within: 1e-3), "\(point) against \(expected) at \(tenth) tenths")
        }
    }

    @Test("a cubic carried by an affine map keeps its parameter, so a length on it maps to the carried one's")
    func carriesCubic() {
        // Given
        let sut = Self.curve
        let transform = AffineTransform(scale: 2, about: Point(x: 0, y: 0))

        // When
        let carried = sut.carried(by: transform)

        // Then
        #expect(carried == .cubic(
            from: Point(x: 0, y: 0),
            first: Point(x: 100, y: 0),
            second: Point(x: 100, y: 200),
            to: Point(x: 200, y: 200)
        ))
        #expect(abs(carried.length - 2 * sut.length) < 1e-6)
        #expect(abs(carried.distance(sut.length / 2, from: sut) - sut.length) < 1e-6)
    }

    @Test(
        "a path's segment is straight where both its tangents are 0 and a cubic through the tangents' ends otherwise",
        arguments: [
            (Point(x: 0, y: 0), Point(x: 0, y: 0), OutlineSegment.line(from: Point(x: 0, y: 0), to: Point(x: 100, y: 0))),
            (
                Point(x: 0, y: 50),
                Point(x: 0, y: 0),
                OutlineSegment.cubic(
                    from: Point(x: 0, y: 0),
                    first: Point(x: 0, y: 50),
                    second: Point(x: 100, y: 0),
                    to: Point(x: 100, y: 0)
                )
            )
        ]
    )
    func joinsVertices(
        outTangent: Point,
        inTangent: Point,
        segment: OutlineSegment
    ) {
        // Given
        let start = PathVertex(vertex: Point(x: 0, y: 0), inTangent: Point(x: 9, y: 9), outTangent: outTangent)
        let end = PathVertex(vertex: Point(x: 100, y: 0), inTangent: inTangent, outTangent: Point(x: 9, y: 9))

        // When
        let result = OutlineSegment.joining(start, end)

        // Then
        #expect(result == segment)
    }

    // MARK: - Private
    private func close(
        _ point: Point,
        _ other: Point,
        within tolerance: Double
    ) -> Bool {
        abs(point.x - other.x) <= tolerance && abs(point.y - other.y) <= tolerance
    }
}
