//
//  QuadTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("Quad Tests")
struct QuadTests {
    // MARK: - Property
    private let steep = Quad(
        topLeft: Point(x: 462, y: 24),
        topRight: Point(x: 562, y: 24),
        bottomRight: Point(x: 1012, y: 1004),
        bottomLeft: Point(x: 12, y: 1004)
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a box's four turns are its area, above 0, so it runs clockwise in y-down pixels")
    func boxRunsClockwise() {
        // Given
        let sut = Quad(Rectangle(x: 10, y: 20, width: 100, height: 50))

        // When
        let turns = sut.turns

        // Then
        #expect(turns == [5000, 5000, 5000, 5000])
        #expect(sut.orientation == .clockwise)
        #expect(sut.isStrictlyConvex)
    }

    @Test("a box mirrored as a negative scale mirrors it has its four turns below 0 and runs counterclockwise")
    func mirroredBoxRunsCounterclockwise() {
        // Given
        let sut = Quad(Rectangle(x: 10, y: 20, width: 100, height: 50)).applying(
            AffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        )

        // When
        let turns = sut.turns

        // Then
        #expect(turns == [-5000, -5000, -5000, -5000])
        #expect(sut.orientation == .counterclockwise)
    }

    @Test("the steep corner pin runs clockwise in y-down pixels and counterclockwise once y is flipped to y up")
    func flippingYReversesOrientation() {
        // Given
        let sut = steep
        let flipped = steep.applying(AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 1024))

        // When
        let orientation = sut.orientation
        let flippedOrientation = flipped.orientation

        // Then
        #expect(orientation == .clockwise)
        #expect(flippedOrientation == .counterclockwise)
    }

    @Test(
        "a quad with three corners on one line, two corners on one point, crossing edges or a reflex corner is not strictly convex",
        arguments: [
            [Point(x: 0, y: 0), Point(x: 50, y: 0), Point(x: 100, y: 0), Point(x: 0, y: 50)],
            [Point(x: 0, y: 0), Point(x: 0, y: 0), Point(x: 100, y: 50), Point(x: 0, y: 50)],
            [Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 0, y: 50), Point(x: 100, y: 50)],
            [Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 30, y: 20), Point(x: 0, y: 100)]
        ]
    )
    func refusesNotStrictlyConvex(corners: [Point]) {
        // Given
        let sut = Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])

        // When
        let orientation = sut.orientation

        // Then
        #expect(orientation == nil)
        #expect(!sut.isStrictlyConvex)
    }

    // z₀ = A B - C D with A = B = 1 + 2⁻²⁷, C = 1, D = 1 + 2⁻²⁶: A B is 1 + 2⁻²⁶ + 2⁻⁵⁴ and rounds to C D, so z₀ is 0,
    // where fusing A B - C D into one rounding gives 2⁻⁵⁴ and the other three turns, above 0, a clockwise quad.
    @Test("a turn is computed with each product rounded before the subtraction, so a product rounded to its pair gives 0")
    func roundsFirstProduct() {
        // Given
        let small = 1.0 / 134_217_728
        let sut = Quad(
            topLeft: Point(x: 0, y: 0),
            topRight: Point(x: 1 + small, y: 1),
            bottomRight: Point(x: 2 + 3 * small, y: 2 + small),
            bottomLeft: Point(x: 0, y: 2)
        )

        // When
        let turns = sut.turns

        // Then
        #expect(turns[0] == 0)
        #expect(turns[1] > 0 && turns[2] > 0 && turns[3] > 0)
        #expect(sut.orientation == nil)
    }

    // z₀ = A B - C D with A = 1, B = 1 + 2⁻²⁶, C = D = 1 + 2⁻²⁷: C D rounds to A B, so z₀ is 0, where fusing the
    // subtraction into C D gives -2⁻⁵⁴ and the other three turns, below 0, a counterclockwise quad.
    @Test("a turn is computed with each product rounded before the subtraction, so the second product rounded to the first gives 0")
    func roundsSecondProduct() {
        // Given
        let small = 1.0 / 134_217_728
        let sut = Quad(
            topLeft: Point(x: 0, y: 0),
            topRight: Point(x: 1, y: 1 + small),
            bottomRight: Point(x: 2 + small, y: 2 + 3 * small),
            bottomLeft: Point(x: 2, y: 0)
        )

        // When
        let turns = sut.turns

        // Then
        #expect(turns[0] == 0)
        #expect(turns[1] < 0 && turns[2] < 0 && turns[3] < 0)
        #expect(sut.orientation == nil)
    }

    // MARK: - Private
}
