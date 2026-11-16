//
//  AffineTransformTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("AffineTransform Tests")
struct AffineTransformTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the identity leaves a point where it is")
    func identityKeepsPoint() {
        // Given
        let sut = AffineTransform.identity

        // When
        let point = sut.apply(to: Point(x: 3, y: 4))

        // Then
        #expect(point == Point(x: 3, y: 4))
    }

    @Test("a translation moves a point by its offset")
    func translationMovesPoint() {
        // Given
        let sut = AffineTransform(translation: Point(x: 10, y: -5))

        // When
        let point = sut.apply(to: Point(x: 3, y: 4))

        // Then
        #expect(point == Point(x: 13, y: -1))
    }

    @Test("a scale about a point keeps that point and moves others away from it")
    func scaleKeepsCenter() {
        // Given
        let sut = AffineTransform(scale: 2, about: Point(x: 10, y: 10))

        // When
        let center = sut.apply(to: Point(x: 10, y: 10))
        let point = sut.apply(to: Point(x: 12, y: 7))

        // Then
        #expect(center == Point(x: 10, y: 10))
        #expect(point == Point(x: 14, y: 4))
    }

    @Test("a positive rotation with y down turns clockwise about its point")
    func rotationTurnsClockwise() {
        // Given
        let sut = AffineTransform(rotation: 90, about: Point(x: 10, y: 10))

        // When
        let right = sut.apply(to: Point(x: 20, y: 10))
        let below = sut.apply(to: Point(x: 10, y: 20))

        // Then
        expectClose(right, Point(x: 10, y: 20))
        expectClose(below, Point(x: 0, y: 10))
    }

    @Test("concatenating applies the receiver first and the argument after it")
    func concatenatesInOrder() {
        // Given
        let translation = AffineTransform(translation: Point(x: 10, y: 0))
        let scale = AffineTransform(scale: 2, about: Point(x: 0, y: 0))

        // When
        let translatedThenScaled = translation.concatenating(scale).apply(to: Point(x: 1, y: 0))
        let scaledThenTranslated = scale.concatenating(translation).apply(to: Point(x: 1, y: 0))

        // Then
        #expect(translatedThenScaled == Point(x: 22, y: 0))
        #expect(scaledThenTranslated == Point(x: 12, y: 0))
    }

    @Test("a rectangle's corners are carried clockwise from its top left")
    func carriesCorners() {
        // Given
        let sut = AffineTransform(scale: 2, about: Point(x: 0, y: 0))

        // When
        let corners = sut.apply(toCornersOf: Rectangle(x: 1, y: 2, width: 3, height: 4))

        // Then
        #expect(corners == [Point(x: 2, y: 4), Point(x: 8, y: 4), Point(x: 8, y: 12), Point(x: 2, y: 12)])
    }

    @Test("the inverse undoes the transform")
    func inverseUndoes() throws {
        // Given
        let sut = AffineTransform(scale: 2, about: Point(x: 10, y: 10))
            .concatenating(AffineTransform(rotation: 30, about: Point(x: 0, y: 0)))
            .concatenating(AffineTransform(translation: Point(x: 5, y: 7)))
        let point = Point(x: 3, y: -8)

        // When
        let inverse = try #require(sut.inverse)

        // Then
        expectClose(inverse.apply(to: sut.apply(to: point)), point)
        #expect(AffineTransform(translation: Point(x: 10, y: -5)).inverse == AffineTransform(translation: Point(x: -10, y: 5)))
    }

    @Test("a transform that flattens the plane has no inverse")
    func flatHasNoInverse() {
        // Given
        let sut = AffineTransform(scale: 0, about: Point(x: 4, y: 4))

        // When
        let inverse = sut.inverse

        // Then
        #expect(inverse == nil)
    }

    @Test("a track's motion as a matrix carries a point as the motion does")
    func carriesTrackMotion() {
        // Given
        let motion = TrackMotion(
            from: Rectangle(x: 0, y: 0, width: 100, height: 50),
            to: Rectangle(x: 50, y: -50, width: 200, height: 400)
        )
        let sut = AffineTransform(carrying: motion)

        // When
        let point = sut.apply(to: Point(x: 60, y: 25))

        // Then
        #expect(point == Point(x: 190, y: 150))
    }

    // MARK: - Private
    private func expectClose(
        _ point: Point,
        _ expected: Point
    ) {
        #expect(abs(point.x - expected.x) < 1e-9)
        #expect(abs(point.y - expected.y) < 1e-9)
    }
}
