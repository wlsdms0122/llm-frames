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

    // MARK: - Private
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
