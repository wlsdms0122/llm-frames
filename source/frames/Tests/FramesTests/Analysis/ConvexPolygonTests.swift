//
//  ConvexPolygonTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("ConvexPolygon Tests")
struct ConvexPolygonTests {
    // MARK: - Property
    private let square = Rectangle(x: 0, y: 0, width: 10, height: 10)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a polygon holds the points inside it and on its edge whichever way its corners turn",
        arguments: [AffineTransform.identity, AffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 10, ty: 0)]
    )
    func containsEitherWayRound(transform: AffineTransform) {
        // Given
        let sut = ConvexPolygon(rectangle: square, transform: transform)

        // When
        let held = [Point(x: 5, y: 5), Point(x: 10, y: 5), Point(x: 11, y: 5)].map(sut.contains)

        // Then
        #expect(held == [true, true, false])
    }

    @Test("clipping by a mirrored polygon keeps what lies inside both, and by one apart from it leaves nothing")
    func clipsByEitherWayRound() throws {
        // Given
        let sut = ConvexPolygon(rectangle: square)
        let mirrored = ConvexPolygon(
            rectangle: Rectangle(x: 5, y: 5, width: 10, height: 10),
            transform: AffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 20, ty: 0)
        )
        let apart = ConvexPolygon(rectangle: Rectangle(x: 20, y: 0, width: 5, height: 5))

        // When
        let clipped = sut.clipped(to: mirrored)
        let none = sut.clipped(to: apart)

        // Then
        #expect(clipped.bounds == Rectangle(x: 5, y: 5, width: 5, height: 5))
        #expect(none.isEmpty)
        #expect(none.bounds == nil)
    }

    @Test("a polygon flattened to a line by a scale of 0 covers nothing")
    func flattensToNothing() {
        // Given
        let sut = ConvexPolygon(rectangle: square, transform: AffineTransform(a: 0, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // When
        let bounds = sut.bounds

        // Then
        #expect(bounds == nil)
        #expect(!sut.contains(Point(x: 0, y: 5)))
    }

    // MARK: - Private
}
