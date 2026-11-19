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

    // MARK: - Private
}
