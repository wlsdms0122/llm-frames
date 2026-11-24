//
//  CornerRadiiTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Testing

@testable import Frames

// A box's corner radii: one number for every corner or four, and the one factor that keeps the corners of a side from
// overlapping (FRAMES-11 Shapes, FRAMES-20).
@Suite("CornerRadii Tests")
struct CornerRadiiTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("one radius for every corner is cut to half the box's shorter side, as one radius always was")
    func cutsOneRadiusToHalfTheShorterSide() {
        // Given
        let sut = CornerRadii(80)

        // When
        let fitted = sut.fitted(to: Size(width: 100, height: 60))

        // Then
        #expect(fitted == CornerRadii(30))
    }

    @Test("radii whose corners overlap along a side are all scaled by the least of each side's length over their sum")
    func scalesOverlappingRadiiByOneFactor() {
        // Given
        let sut = CornerRadii(topLeft: 60, topRight: 60, bottomRight: 10, bottomLeft: 20)

        // When
        let fitted = sut.fitted(to: Size(width: 100, height: 200))

        // Then
        // The top side holds 120 in 100, so every radius takes 100 / 120, and the other sides then fit.
        let factor = 100.0 / 120
        #expect(fitted == CornerRadii(topLeft: 60 * factor, topRight: 60 * factor, bottomRight: 10 * factor, bottomLeft: 20 * factor))
    }

    @Test("radii that fit their sides are kept, a negative radius is a square corner")
    func keepsRadiiThatFit() {
        // Given
        let sut = CornerRadii(topLeft: 10, topRight: 0, bottomRight: -4, bottomLeft: 40)

        // When
        let fitted = sut.fitted(to: Size(width: 100, height: 50))

        // Then
        #expect(fitted == CornerRadii(topLeft: 10, topRight: 0, bottomRight: 0, bottomLeft: 40))
    }

    @Test("a box with no width or height has square corners")
    func squaresCornersOfAnEmptyBox() {
        // Given
        let sut = CornerRadii(topLeft: 10, topRight: 20, bottomRight: 30, bottomLeft: 40)

        // When
        let fitted = sut.fitted(to: Size(width: 0, height: 50))

        // Then
        #expect(fitted.isZero)
    }

    @Test("corners interpolate one by one")
    func interpolatesEachCorner() {
        // Given
        let start = CornerRadii(4)
        let end = CornerRadii(topLeft: 0, topRight: 8, bottomRight: 4, bottomLeft: 12)

        // When
        let sut = CornerRadii.interpolate(from: start, to: end, progress: 0.5)

        // Then
        #expect(sut == CornerRadii(topLeft: 2, topRight: 6, bottomRight: 4, bottomLeft: 8))
    }

    @Test("a written radius is one number for every corner or four in the order top left, top right, bottom right, bottom left")
    func readsWrittenForms() {
        // When
        let one = CornerRadii(written: .number(6))
        let four = CornerRadii(written: .array([.number(1), .number(2), .number(3), .number(4)]))

        // Then
        #expect(one == CornerRadii(6))
        #expect(four == CornerRadii(topLeft: 1, topRight: 2, bottomRight: 3, bottomLeft: 4))
    }
}
