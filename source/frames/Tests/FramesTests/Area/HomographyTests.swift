//
//  HomographyTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("Homography Tests")
struct HomographyTests {
    // MARK: - Property
    private let box = Quad(Rectangle(x: 0, y: 0, width: 1920, height: 1080))
    private let mild = Quad(
        topLeft: Point(x: 190, y: 164),
        topRight: Point(x: 840, y: 124),
        bottomRight: Point(x: 880, y: 854),
        bottomLeft: Point(x: 150, y: 904)
    )
    private let steep = Quad(
        topLeft: Point(x: 462, y: 24),
        topRight: Point(x: 562, y: 24),
        bottomRight: Point(x: 1012, y: 1004),
        bottomLeft: Point(x: 12, y: 1004)
    )
    private let unitSquare = Quad(Rectangle(x: 0, y: 0, width: 1, height: 1))

    // MARK: - Initializer
    // MARK: - Test
    @Test("the unit square onto a parallelogram is its affine map, with g and h exactly 0")
    func squareOntoParallelogramIsAffine() throws {
        // Given
        let parallelogram = Quad(
            topLeft: Point(x: 10, y: 20),
            topRight: Point(x: 110, y: 40),
            bottomRight: Point(x: 130, y: 90),
            bottomLeft: Point(x: 30, y: 70)
        )

        // When
        let sut = try #require(Homography(unitSquareTo: parallelogram))

        // Then
        #expect(sut.g == 0)
        #expect(sut.h == 0)
        #expect(sut.i == 1)
        #expect([sut.a, sut.b, sut.c, sut.d, sut.tx, sut.ty] == [100, 20, 20, 50, 10, 20])
    }

    @Test("the unit square goes onto each corner of a quad in order, with w 1 at the square's origin")
    func squareOntoQuadTakesCorners() throws {
        // Given
        let sut = try #require(Homography(unitSquareTo: mild))

        // When
        let corners = try #require(sut.apply(to: unitSquare))

        // Then
        #expect(sut.i == 1)
        #expect(sut.tx == 190 && sut.ty == 164)
        expectClose(corners, mild)
    }

    @Test("the steep trapezoid's parallel sides give g 0 and h -0.9 on the unit square")
    func squareOntoSteepTrapezoid() throws {
        // Given
        let quad = steep

        // When
        let sut = try #require(Homography(unitSquareTo: quad))

        // Then
        #expect(sut.g == 0)
        #expect(abs(sut.h + 0.9) < 1e-15)
    }

    @Test("a box onto the steep corner pin takes its corners to the four points and its centre to where the diagonals cross")
    func boxOntoSteepCornerPin() throws {
        // Given
        let sut = try #require(Homography(from: box, to: steep))

        // When
        let corners = try #require(sut.apply(to: box))
        let center = try #require(sut.apply(to: Point(x: 960, y: 540)))

        // Then
        expectClose(corners, steep)
        expectClose(center, Point(x: 512, y: 24 + 980.0 / 11))
    }

    @Test("w is above 0 inside the source, and a point past the horizon is not in front and is not carried")
    func pointPastHorizonIsNotInFront() throws {
        // Given
        let sut = try #require(Homography(from: box, to: steep))
        let pastHorizon = Point(x: 960, y: 2160)

        // When
        let carried = sut.apply(to: pastHorizon)

        // Then
        #expect(box.corners.allSatisfy { sut.isInFront($0) })
        #expect(sut.isInFront(Point(x: 960, y: 540)))
        #expect(!sut.isInFront(pastHorizon))
        #expect(carried == nil)
    }

    @Test("a quad with one corner past the horizon is not carried, and one wholly in front is carried corner by corner")
    func quadPastHorizonIsNotCarried() throws {
        // Given
        let sut = try #require(Homography(from: box, to: steep))
        let reaching = Quad(
            topLeft: Point(x: 0, y: 0),
            topRight: Point(x: 1920, y: 0),
            bottomRight: Point(x: 1920, y: 2160),
            bottomLeft: Point(x: 0, y: 1080)
        )
        let inside = Quad(Rectangle(x: 480, y: 270, width: 960, height: 540))

        // When
        let reachingCarried = sut.apply(to: reaching)
        let insideCarried = try #require(sut.apply(to: inside))
        let topLeft = try #require(sut.apply(to: inside.topLeft))

        // Then
        #expect(reachingCarried == nil)
        #expect(insideCarried.orientation == .clockwise)
        expectClose(insideCarried.topLeft, topLeft)
    }

    @Test("a destination mirrored has w above 0 inside the source too, and its corners are taken in order")
    func mirroredDestinationKeepsFront() throws {
        // Given
        let mirrored = steep.applying(AffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 1024, ty: 0))

        // When
        let sut = try #require(Homography(from: box, to: mirrored))
        let corners = try #require(sut.apply(to: box))

        // Then
        #expect(mirrored.orientation == .counterclockwise)
        #expect(box.corners.allSatisfy { sut.isInFront($0) })
        expectClose(corners, mirrored)
    }

    @Test("y flipped to y up after the map is the map onto the corner pin with y flipped")
    func flippingYCommutesWithMap() throws {
        // Given
        let flip = AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 1024)
        let down = try #require(Homography(from: box, to: steep))
        let point = Point(x: 300, y: 800)
        let pointDown = try #require(down.apply(to: point))

        // When
        let sut = try #require(Homography(from: box, to: steep.applying(flip)))
        let pointUp = try #require(sut.apply(to: point))

        // Then
        expectClose(pointUp, flip.apply(to: pointDown))
    }

    @Test("a quad that is not strictly convex, or a box with no width, gives no homography")
    func refusesNotStrictlyConvex() {
        // Given
        let collinear = Quad(
            topLeft: Point(x: 0, y: 0),
            topRight: Point(x: 50, y: 0),
            bottomRight: Point(x: 100, y: 0),
            bottomLeft: Point(x: 0, y: 50)
        )
        let flat = Quad(Rectangle(x: 0, y: 0, width: 0, height: 1080))

        // When
        let toCollinear = Homography(from: box, to: collinear)
        let fromCollinear = Homography(from: collinear, to: box)
        let fromFlat = Homography(from: flat, to: steep)
        let square = Homography(unitSquareTo: collinear)

        // Then
        #expect(toCollinear == nil)
        #expect(fromCollinear == nil)
        #expect(fromFlat == nil)
        #expect(square == nil)
    }

    @Test("a quad onto itself leaves every point where it is")
    func quadOntoItselfIsIdentity() throws {
        // Given
        let sut = try #require(Homography(from: mild, to: mild))
        let point = Point(x: 3000, y: -700)

        // When
        let carried = try #require(sut.apply(to: point))

        // Then
        expectClose(carried, point, tolerance: 1e-8)
    }

    @Test("the inverse takes the destination's corners back to the source's, with w above 0 inside the destination")
    func inverseBringsBack() throws {
        // Given
        let homography = try #require(Homography(from: mild, to: steep))

        // When
        let sut = homography.inverse
        let corners = try #require(sut.apply(to: steep))
        let carried = try #require(homography.apply(to: Point(x: 500, y: 500)))
        let broughtBack = try #require(sut.apply(to: carried))

        // Then
        #expect(steep.corners.allSatisfy { sut.isInFront($0) })
        expectClose(corners, mild)
        expectClose(broughtBack, Point(x: 500, y: 500))
    }

    @Test("the identity's w is 1 everywhere and it leaves a point where it is")
    func identityKeepsPoint() throws {
        // Given
        let sut = Homography.identity

        // When
        let point = try #require(sut.apply(to: Point(x: -3, y: 4)))

        // Then
        #expect(sut.w(at: Point(x: -3, y: 4)) == 1)
        #expect(point == Point(x: -3, y: 4))
    }

    // MARK: - Private
    private func expectClose(
        _ quad: Quad,
        _ expected: Quad,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for (corner, expectedCorner) in zip(quad.corners, expected.corners) {
            expectClose(corner, expectedCorner, sourceLocation: sourceLocation)
        }
    }

    private func expectClose(
        _ point: Point,
        _ expected: Point,
        tolerance: Double = 1e-9,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(point.x - expected.x) < tolerance, "\(point) is not \(expected)", sourceLocation: sourceLocation)
        #expect(abs(point.y - expected.y) < tolerance, "\(point) is not \(expected)", sourceLocation: sourceLocation)
    }
}
