//
//  DrawnStrokeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames
import FramesTestMedia

// A stroke 2 wide with an arrowhead at both ends, whose heads are 8 long, along an outline 100 long.
@Suite("DrawnStroke Tests")
struct DrawnStrokeTests {
    // MARK: - Property
    private static let stroke = PathStroke(
        width: 2,
        paint: .color(Color(written: "#FF0000")),
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
        #expect(sut.startHead == (hasHeads ? .arrow : .none))
        #expect(sut.endHead == (hasHeads ? .arrow : .none))
        #expect(abs(4 * sut.unit(of: sut.endHead, along: 100) - headLength) < 1e-9)
        #expect(abs(sut.lineStart(along: 100) - (start + headLength)) < 1e-9)
        #expect(abs(sut.lineEnd(along: 100) - (end - headLength)) < 1e-9)
    }

    @Test(
        "each head's line stops where the head stops it, in units of the stroke's width times its scale",
        arguments: [
            (StrokeHead.arrow, 1.0, 8.0),
            (.arrow, 2.0, 16.0),
            (.lineArrow, 1.0, 2 * 5.0.squareRoot()),
            (.lineArrow, 2.0, 4 * 5.0.squareRoot()),
            (.circle, 1.0, 4.0),
            (.square, 2.0, 8.0),
            (.diamond, 1.0, 4.0),
            (.bar, 1.0, 1.0),
            (.bar, 2.0, 2.0),
            // A head of scale 0 draws nothing and stops no line.
            (.circle, 0.0, 0.0)
        ]
    )
    func stopsLineAtHead(
        shape: StrokeHead,
        scale: Double,
        inset: Double
    ) {
        // Given
        let stroke = PathStroke(
            width: 2,
            paint: Self.stroke.paint,
            join: .round,
            cap: .butt,
            start: .none,
            end: StrokeEnd(head: shape, scale: scale)
        )

        // When
        let sut = DrawnStroke(stroke: stroke, trim: .whole, isClosed: false)

        // Then
        #expect(sut.endHead.shape == (scale > 0 ? shape : .none))
        #expect(abs(sut.unit(of: sut.endHead, along: 100) - 2 * scale) < 1e-9)
        #expect(sut.lineStart(along: 100) == 0)
        #expect(abs(sut.lineEnd(along: 100) - (100 - inset)) < 1e-9)
    }

    @Test("heads of two lengths on a short stroke shrink by one factor so that their lengths add up to the stroke's")
    func shrinksHeadsTogether() {
        // Given
        // An arrow 8 long and a bar 4 long at scale 2, on a stroke 6 long: both shrink by a half.
        let stroke = PathStroke(
            width: 2,
            paint: Self.stroke.paint,
            join: .round,
            cap: .butt,
            start: StrokeEnd(head: .bar, scale: 2),
            end: .arrow
        )

        // When
        let sut = DrawnStroke(stroke: stroke, trim: Trim(start: 0, end: 0.06), isClosed: false)

        // Then
        #expect(abs(sut.unit(of: sut.startHead, along: 100) - 2) < 1e-9)
        #expect(abs(sut.unit(of: sut.endHead, along: 100) - 1) < 1e-9)
        #expect(abs(sut.lineStart(along: 100) - 1) < 1e-9)
        #expect(abs(sut.lineEnd(along: 100) - 2) < 1e-9)
    }

    @Test("a stroke with no width or no part of its outline draws nothing")
    func drawsNothing() {
        // Given
        let thin = PathStroke(width: 0, paint: Self.stroke.paint, join: .round, cap: .butt, start: .none, end: .none)

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
