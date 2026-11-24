//
//  RoundedRectOutlineTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Testing

@testable import Frames

// A rect's outline with a radius for each corner: each corner an arc of its own radius, the radii cut by one factor
// where a side's two corners overlap (FRAMES-20).
@Suite("Rounded rect outline Tests")
struct RoundedRectOutlineTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("each corner is a quarter arc of its own radius, from the top edge after the top left corner clockwise")
    func roundsEachCornerByItsRadius() {
        // Given
        let radius = CornerRadii(topLeft: 4, topRight: 8, bottomRight: 0, bottomLeft: 16)

        // When
        let sut = PathOutline(.rect(Rectangle(x: 0, y: 0, width: 100, height: 50), radius: radius))

        // Then
        let quarter = Double.pi / 2
        let arc = { (x: Double, y: Double, radius: Double, start: Double) in
            OutlineSegment.arc(center: Point(x: x, y: y), radii: Size(width: radius, height: radius), start: start, sweep: quarter)
        }
        #expect(sut.start == Point(x: 4, y: 0))
        #expect(sut.segments == [
            .line(from: Point(x: 4, y: 0), to: Point(x: 92, y: 0)),
            arc(92, 8, 8, -quarter),
            .line(from: Point(x: 100, y: 8), to: Point(x: 100, y: 50)),
            .line(from: Point(x: 100, y: 50), to: Point(x: 16, y: 50)),
            arc(16, 34, 16, quarter),
            .line(from: Point(x: 0, y: 34), to: Point(x: 0, y: 4)),
            arc(4, 4, 4, .pi)
        ])
    }

    @Test("corners that would overlap along a side are all cut by one factor, and four equal radii by half the shorter side")
    func cutsOverlappingCorners() {
        // Given
        let box = Rectangle(x: 0, y: 0, width: 100, height: 40)

        // When
        let sut = PathOutline(.rect(box, radius: CornerRadii(topLeft: 30, topRight: 10, bottomRight: 30, bottomLeft: 50)))
        let equal = PathOutline(.rect(box, radius: 60))

        // Then
        // The left side holds 80 in 40, so every radius is halved.
        let factor = 40.0 / 80
        #expect(sut == PathOutline(.rect(box, radius: CornerRadii(
            topLeft: 30 * factor,
            topRight: 10 * factor,
            bottomRight: 30 * factor,
            bottomLeft: 50 * factor
        ))))
        #expect(equal == PathOutline(.rect(box, radius: 20)))
    }
}
