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

    @Test(
        "the rotation of a map is that of its polar decomposition, a horizontal flip read before it",
        arguments: [
            (Scale(x: 2, y: 0.5), 30.0, 30.0),
            (Scale(x: -1, y: 1), 30.0, 30.0),
            (Scale(x: 1, y: -1), 30.0, 210.0),
            (Scale(x: -2, y: -3), 0.0, 180.0)
        ]
    )
    func takesPolarRotation(
        scale: Scale,
        degrees: Double,
        expected: Double
    ) {
        // Given
        let sut = AffineTransform(scale: scale, rotation: degrees, about: Point(x: 5, y: 5), offset: Point(x: 1, y: 2))

        // When
        let rotation = sut.rotation

        // Then
        #expect(turn(from: rotation, to: expected) < 1e-9)
    }

    @Test("the same map written as a flip and a half turn or as the other flip gives the same rotation")
    func takesRotationFromMapAlone() {
        // Given
        let flipped = AffineTransform(scale: Scale(x: 1, y: -1), rotation: 0, about: Point(x: 0, y: 0), offset: Point(x: 0, y: 0))
        let sut = AffineTransform(scale: Scale(x: -1, y: 1), rotation: 180, about: Point(x: 0, y: 0), offset: Point(x: 0, y: 0))

        // When
        let rotation = sut.rotation

        // Then
        // Rounding may read one as 180 and the other as -180, the same turn.
        #expect(zip(sut.matrix, flipped.matrix).allSatisfy { abs($0 - $1) < 1e-9 })
        #expect(turn(from: rotation, to: flipped.rotation) < 1e-9)
    }

    @Test("a map that flattens the plane turns by 0 and has a length factor of 0")
    func flatTurnsByZero() {
        // Given
        let sut = AffineTransform(scale: 0, about: Point(x: 4, y: 4))

        // When
        let rotation = sut.rotation
        let factor = sut.lengthFactor

        // Then
        #expect(rotation == 0)
        #expect(factor == 0)
    }

    @Test("the length factor is the geometric mean of the scales a map applies")
    func takesLengthFactor() {
        // Given
        let sut = AffineTransform(scale: Scale(x: -2, y: 8), rotation: 40, about: Point(x: 3, y: 1), offset: Point(x: 0, y: 0))

        // When
        let factor = sut.lengthFactor

        // Then
        #expect(abs(factor - 4) < 1e-9)
    }

    // MARK: - Private
    // The smaller angle between two rotations in degrees, whatever whole turns they differ by.
    private func turn(
        from rotation: Double,
        to other: Double
    ) -> Double {
        let turn = abs((rotation - other).truncatingRemainder(dividingBy: 360))

        return min(turn, 360 - turn)
    }

    private func expectClose(
        _ point: Point,
        _ expected: Point
    ) {
        #expect(abs(point.x - expected.x) < 1e-9)
        #expect(abs(point.y - expected.y) < 1e-9)
    }
}
