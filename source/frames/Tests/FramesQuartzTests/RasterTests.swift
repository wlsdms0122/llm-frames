//
//  RasterTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Foundation
import Frames
@testable import FramesQuartz
import Testing

@Suite("Raster Tests")
struct RasterTests {
    // MARK: - Property
    private static let size = Size(width: 100, height: 100)
    private static let whole = CGRect(x: 0, y: 0, width: 100, height: 100)
    private static let area = CGRect(x: 0, y: 0, width: 64, height: 48)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a list shown at a huge scale is drawn only over the area it lands in, at that scale")
    func coversShownAreaAtHugeScale() throws {
        // Given
        let map = CGAffineTransform(a: 100_000, b: 0, c: 0, d: 100_000, tx: -5_000_000.5, ty: -5_000_000.5)

        // When
        let sut = try #require(Raster(showing: Self.size, region: Self.whole, through: map, within: Self.area))

        // Then
        #expect(sut.width <= 65 && sut.height <= 49)
        #expect(sut.transform.a == 100_000 && sut.transform.d == 100_000)
    }

    @Test("a list turned and stretched at a huge scale holds at most twice the pixels of the area it lands in")
    func capsTurnedRaster() throws {
        // Given
        // The list's centre lands on the area's.
        let turned = CGAffineTransform(scaleX: 100_000, y: 10).concatenating(CGAffineTransform(rotationAngle: .pi / 4))
        let centre = CGPoint(x: 50, y: 50).applying(turned)
        let map = turned.concatenating(CGAffineTransform(translationX: 32 - centre.x, y: 24 - centre.y))

        // When
        let sut = try #require(Raster(showing: Self.size, region: Self.whole, through: map, within: Self.area))

        // Then
        // Rounding out to whole pixels adds at most a pixel at each edge.
        #expect(sut.width * sut.height <= 2 * 64 * 48 + 2 * (sut.width + sut.height) + 4)
    }

    @Test("a list shown smaller than its size is drawn at the smaller size")
    func drawsSmallerList() throws {
        // Given
        let map = CGAffineTransform(a: 0.5, b: 0, c: 0, d: 0.25, tx: 3, ty: 7)

        // When
        let sut = try #require(Raster(showing: Self.size, region: Self.whole, through: map, within: Self.area))

        // Then
        #expect(sut.width == 50 && sut.height == 25)
        #expect(sut.frame == CGRect(x: 0, y: 0, width: 50, height: 25))
    }

    @Test("a list whose region lands outside the area has no raster")
    func skipsListOutsideArea() {
        // Given
        let map = CGAffineTransform(translationX: 200, y: 0)

        // When
        let sut = Raster(showing: Self.size, region: Self.whole, through: map, within: Self.area)

        // Then
        #expect(sut == nil)
    }

    @Test("a list carried larger by an affine homography is drawn at its larger axis scale, the same along both axes")
    func drawsCarriedListAtStretch() throws {
        // Given
        let map = Homography(CGAffineTransform(a: 1.5, b: 0, c: 0, d: 2, tx: 10, ty: 20))

        // When
        let sut = try #require(
            Raster(
                showing: Self.size,
                through: map,
                within: CGRect(x: 0, y: 0, width: 400, height: 400),
                reading: 0,
                holdingPixels: true
            )
        )

        // Then
        #expect(sut.transform.a == 2 && sut.transform.d == 2)
        #expect(sut.width == 200 && sut.height == 200)
    }

    @Test("a list holding a picture of pixels carried towards a horizon past the pixel limit is drawn at its own size")
    func drawsPicturesTowardsHorizonAtOwnSize() throws {
        // Given
        let map = try Self.steep()
        let area = CGRect(x: 0, y: 0, width: 1024, height: 1024)

        // When
        let sut = try #require(
            Raster(showing: Size(width: 1024, height: 1400), through: map, within: area, reading: 0, holdingPixels: true)
        )

        // Then
        // Its near edge stretches rows about tenfold, past the limit, so the list is drawn at its own size.
        let stretch = try #require(map.stretch(at: Point(x: 512, y: 1024)))
        #expect(stretch > 9)
        #expect(sut.transform.a == 1 && sut.transform.d == 1)
        #expect(sut.width * sut.height <= 2 * 1024 * 1024 + 2 * (sut.width + sut.height) + 4)
    }

    @Test("a list of shapes carried towards a horizon past the pixel limit is drawn at the largest scale the limit allows")
    func drawsShapesTowardsHorizonAtLimit() throws {
        // Given
        let map = try Self.steep()
        let area = CGRect(x: 0, y: 0, width: 1024, height: 1024)

        // When
        let sut = try #require(
            Raster(showing: Size(width: 1024, height: 1024), through: map, within: area, reading: 0, holdingPixels: false)
        )

        // Then
        let pixels = Double(sut.width * sut.height)
        #expect(sut.transform.a > 1.4 && sut.transform.a == sut.transform.d)
        #expect(pixels <= 2 * 1024 * 1024 + 2 * Double(sut.width + sut.height) + 4)
        #expect(pixels > 1.9 * 1024 * 1024)
    }

    @Test("a list carried smaller by a homography is drawn at its own size")
    func drawsShrunkCarriedListAtOwnSize() throws {
        // Given
        let map = Homography(CGAffineTransform(a: 0.5, b: 0, c: 0, d: 0.4, tx: 10, ty: 20))

        // When
        let sut = try #require(
            Raster(
                showing: Self.size,
                through: map,
                within: CGRect(x: 0, y: 0, width: 200, height: 200),
                reading: 0,
                holdingPixels: false
            )
        )

        // Then
        #expect(sut.transform == .identity)
        #expect(sut.width == 100 && sut.height == 100)
    }

    @Test("a list carried wholly outside the area has no raster")
    func skipsCarriedListOutsideArea() {
        // Given
        let map = Homography(CGAffineTransform(translationX: 200, y: 0))

        // When
        let sut = Raster(showing: Self.size, through: map, within: Self.area, reading: 0, holdingPixels: true)

        // Then
        #expect(sut == nil)
    }

    // MARK: - Private
    // FRAMES-24's steep corner pin of a 1024 x 1024 box.
    private static func steep() throws -> Homography {
        let box = Quad(Rectangle(x: 0, y: 0, width: 1024, height: 1024))
        let steep = Quad(
            topLeft: Point(x: 462, y: 24),
            topRight: Point(x: 562, y: 24),
            bottomRight: Point(x: 1012, y: 1004),
            bottomLeft: Point(x: 12, y: 1004)
        )

        return try #require(Homography(from: box, to: steep))
    }
}
