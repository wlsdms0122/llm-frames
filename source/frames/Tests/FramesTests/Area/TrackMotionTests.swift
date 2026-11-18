//
//  TrackMotionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("TrackMotion Tests")
struct TrackMotionTests {
    // MARK: - Property
    private let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 50))

    // MARK: - Initializer
    // MARK: - Test
    @Test("the target's own quad is the identity, exactly")
    func fitsIdentity() {
        // Given
        let target = Quad(Rectangle(x: 13.7, y: 291.3, width: 412.9, height: 61.1))

        // When
        let sut = TrackMotion(from: target, to: target)

        // Then
        #expect(sut.transform == .identity)
    }

    @Test("a quad moved, scaled and turned is fitted as that similarity, clockwise positive in y-down pixels")
    func fitsSimilarity() {
        // Given
        let moved = AffineTransform(scale: 1.5, rotation: 30, about: Point(x: 50, y: 25), offset: Point(x: 200, y: -40))

        // When
        let sut = TrackMotion(from: target, to: target.applying(moved))

        // Then
        #expect(abs(sut.scale - 1.5) < 1e-12)
        #expect(abs(sut.rotation - 30) < 1e-12)
        expectClose(sut.carry(Point(x: 100, y: 0)), moved.apply(to: Point(x: 100, y: 0)))
        expectClose(sut.carry(target.centroid), Point(x: 250, y: -15))
    }

    @Test("a quarter turn clockwise takes the top edge's direction from right to down")
    func fitsQuarterTurn() {
        // Given
        let turned = Quad(
            topLeft: Point(x: 75, y: -25),
            topRight: Point(x: 75, y: 75),
            bottomRight: Point(x: 25, y: 75),
            bottomLeft: Point(x: 25, y: -25)
        )

        // When
        let sut = TrackMotion(from: target, to: turned)

        // Then
        #expect(abs(sut.rotation - 90) < 1e-12)
        #expect(abs(sut.scale - 1) < 1e-12)
        expectClose(sut.carry(Point(x: 100, y: 25)), Point(x: 50, y: 75))
    }

    @Test("a quad that is no similarity of the target is fitted by least squares, by the sums FRAMES-12 writes")
    func fitsLeastSquares() {
        // Given
        let frame = Quad(
            topLeft: Point(x: 10, y: 0),
            topRight: Point(x: 110, y: 10),
            bottomRight: Point(x: 100, y: 60),
            bottomLeft: Point(x: 0, y: 40)
        )

        // When
        let sut = TrackMotion(from: target, to: frame)

        // Then
        // Centroids (50, 25) and (55, 27.5); a = 12250, b = 2000, Σ |pᵢ'|² = 12500.
        expectClose(Point(x: sut.transform.a, y: sut.transform.b), Point(x: 0.98, y: 0.16))
        #expect(sut.transform.c == -sut.transform.b)
        #expect(sut.transform.d == sut.transform.a)
        expectClose(sut.carry(Point(x: 50, y: 25)), Point(x: 55, y: 27.5))
    }

    @Test("bringing a point or a rectangle back through the motion undoes carrying it")
    func bringsBack() {
        // Given
        let moved = AffineTransform(scale: 2, rotation: -40, about: Point(x: 50, y: 25), offset: Point(x: 30, y: 70))
        let sut = TrackMotion(from: target, to: target.applying(moved))
        let point = Point(x: 13, y: -7)
        let rectangle = Rectangle(x: 10, y: 20, width: 30, height: 40)

        // When
        let brought = sut.bringBack(sut.carry(point))
        let back = sut.bringBack(sut.carry(rectangle))

        // Then
        expectClose(brought, point)
        expectClose(back.center, rectangle.center)
        #expect(abs(back.width - 30) < 1e-9 && abs(back.height - 40) < 1e-9)
    }

    @Test("a rectangle is carried with its centre and scaled, keeping its shape in the space the motion turns")
    func carriesRectangle() {
        // Given
        let moved = AffineTransform(scale: 2, rotation: 90, about: Point(x: 50, y: 25), offset: Point(x: 0, y: 0))
        let sut = TrackMotion(from: target, to: target.applying(moved))

        // When
        let carried = sut.carry(Rectangle(x: 40, y: 20, width: 20, height: 10))

        // Then
        expectClose(carried.center, Point(x: 50, y: 25))
        #expect(abs(carried.width - 40) < 1e-9 && abs(carried.height - 20) < 1e-9)
    }

    @Test("the upright motion keeps the move and the scale and leaves out the turn, as a crop takes it")
    func keepsUpright() {
        // Given
        let moved = AffineTransform(scale: 2, rotation: 25, about: Point(x: 50, y: 25), offset: Point(x: 100, y: 10))
        let sut = TrackMotion(from: target, to: target.applying(moved))

        // When
        let upright = sut.upright

        // Then
        #expect(upright.rotation == 0)
        #expect(abs(upright.scale - 2) < 1e-12)
        expectClose(upright.carry(target.centroid), sut.carry(target.centroid))
        expectClose(upright.carry(Point(x: 60, y: 25)), Point(x: 170, y: 35))
    }

    // MARK: - Private
    private func expectClose(
        _ point: Point,
        _ expected: Point,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(point.x - expected.x) < 1e-9, "\(point) is not \(expected)", sourceLocation: sourceLocation)
        #expect(abs(point.y - expected.y) < 1e-9, "\(point) is not \(expected)", sourceLocation: sourceLocation)
    }
}
