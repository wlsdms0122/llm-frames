//
//  RegionSamplerTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
@testable import FramesVision
import Testing

@Suite("RegionSampler Tests")
struct RegionSamplerTests {
    // MARK: - Property
    // A 4 by 4 image whose pixel at column x and row y is x + 10y.
    private let image = GreyImage(
        width: 4,
        height: 4,
        values: (0..<16).map { Float($0 % 4 + 10 * ($0 / 4)) }
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a region on whole pixels at scale 1 reads the image's pixels as they are")
    func readsWholePixels() {
        // Given
        let sut = RegionSampler()

        // When
        let region = sut.sample(image, centre: CGPoint(x: 2, y: 2), size: CGSize(width: 4, height: 4), scale: 1)

        // Then
        #expect(region.values == image.values)
    }

    @Test("a region half a pixel over reads between the pixels either side")
    func interpolatesBetweenPixels() {
        // Given
        let sut = RegionSampler()

        // When
        let region = sut.sample(image, centre: CGPoint(x: 2, y: 2.5), size: CGSize(width: 2, height: 2), scale: 1)

        // Then
        #expect(region.values == [16, 17, 26, 27])
    }

    @Test("a region's pixels outside the image are NaN")
    func marksPixelsOutside() {
        // Given
        let sut = RegionSampler()

        // When
        let region = sut.sample(image, centre: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 2, height: 2), scale: 1)

        // Then
        #expect(region.values[0].isNaN)
        #expect(region.values[1].isNaN)
        #expect(region.values[2].isNaN)
        #expect(region.values[3] == 5.5)
    }

    @Test("a region at scale 2 reads the image halved, each pixel the mean of the four it spans")
    func readsHalvedAtScaleTwo() {
        // Given
        let sut = RegionSampler()

        // When
        let region = sut.sample(image, centre: CGPoint(x: 2, y: 2), size: CGSize(width: 2, height: 2), scale: 2)

        // Then
        #expect(region.values == [5.5, 7.5, 25.5, 27.5])
    }

    // MARK: - Private
}
