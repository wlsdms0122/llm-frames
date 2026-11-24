//
//  PathItemTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Testing

@testable import Frames

// A rect and an ellipse in the box [10, 10, 40, 20], stroked 4 wide with miter joins.
@Suite("PathItem Tests")
struct PathItemTests {
    // MARK: - Property
    private static let box = Rectangle(x: 10, y: 10, width: 40, height: 20)
    private static let black = Color(written: "#000000")

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a stroke's drawn bounds reach nothing past an inside stroke's outline, half its width past a centred one's and its width past an outside one's",
        arguments: [
            (StrokeAlign.inside, Rectangle(x: 10, y: 10, width: 40, height: 20)),
            (.center, Rectangle(x: 8, y: 8, width: 44, height: 24)),
            (.outside, Rectangle(x: 6, y: 6, width: 48, height: 28))
        ]
    )
    func boundsFollowAlign(
        align: StrokeAlign,
        expected: Rectangle
    ) {
        // Given
        let rect = stroked(.rect(Self.box, radius: 0), align: align)
        let ellipse = stroked(.ellipse(Self.box), align: align)

        // When
        let bounds = [rect, ellipse].map { $0.drawnBounds(carriedBy: .identity) }

        // Then
        // An outside stroke's square corners are the miters of the stroke 8 wide it is cut from, which reach the
        // corners of the box grown by 4 and no further.
        #expect(bounds == [expected, expected])
    }

    @Test(
        "a stroke's width is in output pixels, so under a transform at scale 2 its drawn bounds reach half as far in the item's own coordinates",
        arguments: [
            (StrokeAlign.inside, Rectangle(x: 10, y: 10, width: 40, height: 20)),
            (.center, Rectangle(x: 9, y: 9, width: 42, height: 22)),
            (.outside, Rectangle(x: 8, y: 8, width: 44, height: 24))
        ]
    )
    func boundsFollowAlignInOutputPixels(
        align: StrokeAlign,
        expected: Rectangle
    ) {
        // Given
        let sut = stroked(.ellipse(Self.box), align: align)
        let scale = AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0)

        // When
        let bounds = sut.drawnBounds(carriedBy: scale)

        // Then
        #expect(bounds == expected)
    }

    @Test(
        "a line's drawn bounds hold each head as drawn, reaching as far across the line as its width and no further along it than its tip",
        arguments: [
            (StrokeEnd.arrow, 4.0),
            (StrokeEnd(shape: .lineArrow, scale: 2), 8.0),
            (StrokeEnd(shape: .circle), 4.0),
            (StrokeEnd(shape: .square, scale: 0.5), 2.0),
            (StrokeEnd(shape: .diamond), 4.0),
            (StrokeEnd(shape: .bar, scale: 2), 8.0)
        ]
    )
    func boundsHoldHeads(
        end: StrokeEnd,
        half: Double
    ) {
        // Given
        // A line 2 wide from (0, 50) to (100, 50), whose heads are 4 units of 2 wide across it at scale 1.
        let sut = line(from: Point(x: 0, y: 50), to: Point(x: 100, y: 50), end: end)

        // When
        let bounds = sut.drawnBounds(carriedBy: .identity)

        // Then
        // The line's own reach of 1 past its outline holds its ends, and no head reaches past the tip at x = 100.
        #expect(bounds == Rectangle(x: -1, y: 50 - max(half, 1), width: 102, height: 2 * max(half, 1)))
    }

    @Test("a circle head's drawn bounds are the circle's, not the square it is inscribed in, on a line at 45 degrees")
    func boundsHoldTurnedCircle() {
        // Given
        let sut = line(from: Point(x: 0, y: 0), to: Point(x: 100, y: 100), end: StrokeEnd(shape: .circle))

        // When
        let bounds = sut.drawnBounds(carriedBy: .identity)

        // Then
        // The circle is 8 across, centred 4 back from the tip along the line, so it reaches 4 - 4 / √2 past the tip
        // along each axis, and the line's own reach of 1 past its outline holds its start.
        let far = 100 - 4 / 2.0.squareRoot() + 4
        let near = -1.0
        #expect(abs(bounds.maxX - far) < 1e-9 && abs(bounds.maxY - far) < 1e-9)
        #expect(abs(bounds.x - near) < 1e-9 && abs(bounds.y - near) < 1e-9)
    }

    // MARK: - Private
    private func line(
        from start: Point,
        to end: Point,
        end head: StrokeEnd
    ) -> PathItem {
        PathItem(
            geometry: .polyline([start, end], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 2, paint: .color(Self.black), join: .miter, cap: .butt, start: .none, end: head)
        )
    }

    private func stroked(
        _ geometry: PathGeometry,
        align: StrokeAlign
    ) -> PathItem {
        PathItem(
            geometry: geometry,
            fill: nil,
            stroke: PathStroke(
                width: 4,
                paint: .color(Self.black),
                align: align,
                join: .miter,
                cap: .butt,
                start: .none,
                end: .none
            )
        )
    }
}
