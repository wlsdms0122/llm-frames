//
//  HomographyTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
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

    @Test(
        "the stretch at a point is the largest factor by which the map grows a length there, in any direction",
        arguments: [Point(x: 512, y: 1024), Point(x: 0, y: 0), Point(x: 1024, y: 512), Point(x: 300, y: 700)]
    )
    func stretchesLengthAtPoint(point: Point) throws {
        // Given
        let sut = try #require(Homography(from: Quad(Rectangle(x: 0, y: 0, width: 1024, height: 1024)), to: steep))

        // When
        let stretch = try #require(sut.stretch(at: point))

        // Then
        // The largest length a short step in one of 3600 directions is carried to, over the step's length.
        let step = 1e-4
        let center = try #require(sut.apply(to: point))
        let largest = try (0..<3600).map { index in
            let angle = Double(index) * Double.pi / 1800
            let moved = try #require(
                sut.apply(to: Point(x: point.x + step * cos(angle), y: point.y + step * sin(angle)))
            )
            return ((moved.x - center.x) * (moved.x - center.x) + (moved.y - center.y) * (moved.y - center.y))
                .squareRoot() / step
        }
        .max() ?? 0
        #expect(abs(stretch - largest) <= 1e-3 * largest, "\(stretch) is not \(largest)")
    }

    @Test("an affine map stretches every point by its larger axis, and a point past the horizon has no stretch")
    func stretchesAffineAndNotPastHorizon() throws {
        // Given
        let affine = Homography(AffineTransform(a: 2, b: 0, c: 0, d: -3, tx: 5, ty: 7))
        let sut = try #require(Homography(from: box, to: steep))

        // When
        let affineStretch = affine.stretch(at: Point(x: -40, y: 90))
        let pastHorizon = sut.stretch(at: Point(x: 960, y: 2160))

        // Then
        #expect(affineStretch == 3)
        #expect(pastHorizon == nil)
    }

    @Test("a rectangle carried onto the steep corner pin lands on its four points, cut to an area")
    func carriesRectangleWithinArea() throws {
        // Given
        let source = Rectangle(x: 0, y: 0, width: 1024, height: 1024)
        let sut = try #require(Homography(from: Quad(source), to: steep))

        // When
        let whole = sut.corners(carrying: source, within: Rectangle(x: 0, y: 0, width: 1024, height: 1024))
        let cut = sut.corners(carrying: source, within: Rectangle(x: 0, y: 0, width: 1024, height: 500))

        // Then
        #expect(whole.count == 4)
        for corner in steep.corners {
            #expect(whole.contains { abs($0.x - corner.x) < 1e-9 && abs($0.y - corner.y) < 1e-9 }, "\(corner)")
        }
        #expect(!cut.isEmpty && cut.allSatisfy { $0.y <= 500 + 1e-9 })
    }

    @Test("a rectangle reaching past the horizon is carried only in front of it, and one wholly past it is not carried")
    func carriesRectangleInFrontOfHorizon() throws {
        // Given
        let source = Rectangle(x: 0, y: 0, width: 1024, height: 1024)
        let sut = try #require(Homography(from: Quad(source), to: steep))
        let area = Rectangle(x: -100_000, y: -100_000, width: 200_000, height: 200_000)

        // When
        let reaching = sut.corners(carrying: Rectangle(x: 0, y: 0, width: 1024, height: 3000), within: area)
        let past = sut.corners(carrying: Rectangle(x: 0, y: 1200, width: 1024, height: 100), within: area)

        // Then
        #expect(reaching.count >= 4 && reaching.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        // The near edge lies towards the horizon, so what lies past it goes down without bound and is cut by the area.
        #expect(reaching.allSatisfy { $0.y >= 24 - 1e-9 && $0.y <= 100_000 + 1e-6 })
        #expect(reaching.contains { $0.y > 10_000 })
        #expect(past.isEmpty)
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
