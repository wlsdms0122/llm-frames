//
//  DrawnStrokeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// A stroke 2 wide with an arrowhead at both ends, whose heads are 8 long, along an outline 100 long.
@Suite("DrawnStroke Tests")
struct DrawnStrokeTests {
    // MARK: - Property
    private static let stroke = PathStroke(
        width: 2,
        color: Color(written: "#FF0000"),
        join: .round,
        cap: .butt,
        start: .arrow,
        end: .arrow
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a stroke draws from the smaller trim to the larger, with an arrowhead at each end it has, shrunk to share a short stroke",
        arguments: [
            // An open outline drawn whole has two ends.
            (Trim.whole, false, 0.0, 100.0, true, 8.0),
            // A closed outline drawn whole has none.
            (Trim.whole, true, 0.0, 100.0, false, 0.0),
            // A trim leaves part of a closed outline undrawn, which gives it ends.
            (Trim(start: 0, end: 0.5), true, 0.0, 50.0, true, 8.0),
            (Trim(start: 0.75, end: 0.25), true, 25.0, 75.0, true, 8.0),
            // The two heads share a stroke 10 long.
            (Trim(start: 0, end: 0.1), false, 0.0, 10.0, true, 5.0)
        ]
    )
    func laysStrokeAndHeads(
        trim: Trim,
        isClosed: Bool,
        start: Double,
        end: Double,
        hasHeads: Bool,
        headLength: Double
    ) throws {
        // When
        let sut = DrawnStroke(stroke: Self.stroke, trim: trim, isClosed: isClosed)

        // Then
        #expect(sut.isDrawn)
        #expect(abs(sut.start(along: 100) - start) < 1e-9)
        #expect(abs(sut.end(along: 100) - end) < 1e-9)
        #expect(sut.isWhole == (isClosed && !hasHeads))
        #expect(sut.hasStartHead == hasHeads)
        #expect(sut.hasEndHead == hasHeads)
        #expect(abs(sut.headLength(along: 100) - headLength) < 1e-9)
        #expect(abs(sut.lineStart(along: 100) - (start + headLength)) < 1e-9)
        #expect(abs(sut.lineEnd(along: 100) - (end - headLength)) < 1e-9)
    }

    @Test("a stroke with no width or no part of its outline draws nothing")
    func drawsNothing() {
        // Given
        let thin = PathStroke(width: 0, color: Self.stroke.color, join: .round, cap: .butt, start: .none, end: .none)

        // When
        let empty = DrawnStroke(stroke: Self.stroke, trim: Trim(start: 0.5, end: 0.5), isClosed: false)
        let unstroked = DrawnStroke(stroke: thin, trim: .whole, isClosed: false)

        // Then
        #expect(!empty.isDrawn)
        #expect(!empty.hasArrowhead)
        #expect(!unstroked.isDrawn)
    }

    @Test(
        "a path item's stroke ends in an arrowhead only where its drawn stroke has an end",
        arguments: [
            (PathGeometry.rect(Rectangle(x: 0, y: 0, width: 10, height: 10), radius: 0), Trim.whole, false),
            (PathGeometry.rect(Rectangle(x: 0, y: 0, width: 10, height: 10), radius: 0), Trim(start: 0, end: 0.5), true),
            (PathGeometry.polyline([Point(x: 0, y: 0), Point(x: 10, y: 0)], isClosed: false), Trim.whole, true)
        ]
    )
    func knowsArrowhead(
        geometry: PathGeometry,
        trim: Trim,
        hasArrowhead: Bool
    ) throws {
        // Given
        let sut = PathItem(geometry: geometry, fill: nil, stroke: Self.stroke, trim: trim)

        // When
        let result = try #require(sut.drawnStroke)

        // Then
        #expect(result.hasArrowhead == hasArrowhead)
    }

    // MARK: - Private
}
