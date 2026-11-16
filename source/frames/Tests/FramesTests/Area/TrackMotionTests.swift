//
//  TrackMotionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("TrackMotion Tests")
struct TrackMotionTests {
    // MARK: - Property
    // The target moves its centre from (50, 25) to (150, 150) and grows 2 times wider and 8 times taller.
    private let sut = TrackMotion(
        from: Rectangle(x: 0, y: 0, width: 100, height: 50),
        to: Rectangle(x: 50, y: -50, width: 200, height: 400)
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("the motion moves the target's centre and scales by the geometric mean of the width and height ratios")
    func scalesByGeometricMean() {
        // Given, When
        let carried = sut.carry(Rectangle(x: 0, y: 0, width: 100, height: 50))

        // Then
        #expect(sut.scale == 4)
        #expect(carried == Rectangle(x: -50, y: 50, width: 400, height: 200))
        #expect(sut.carry(Point(x: 60, y: 25)) == Point(x: 190, y: 150))
    }

    @Test("bringing a rectangle back through the motion undoes carrying it")
    func bringsBack() {
        // Given
        let rectangle = Rectangle(x: 10, y: 20, width: 30, height: 40)

        // When
        let roundTrip = sut.bringBack(sut.carry(rectangle))

        // Then
        #expect(roundTrip == rectangle)
        #expect(sut.bringBack(Point(x: 190, y: 150)) == Point(x: 60, y: 25))
    }

    @Test("a band keeps its full width and takes only the vertical part of the motion")
    func carriesBand() {
        // Given
        let band = Rectangle(x: 0, y: 20, width: 1206, height: 10)

        // When
        let carried = sut.carryBand(band)

        // Then
        #expect(carried == Rectangle(x: 0, y: 130, width: 1206, height: 40))
        #expect(sut.bringBackBand(carried) == band)
    }

    @Test("a band crop takes only the vertical move of the target's centre, so it keeps its size and ratio")
    func carriesBandCrop() {
        // Given
        let crop = Rectangle(x: 0, y: 20, width: 1206, height: 603)

        // When
        let carried = sut.carryBandCrop(crop)

        // Then
        // The target's centre moves down from 25 to 150.
        #expect(carried == Rectangle(x: 0, y: 145, width: 1206, height: 603))
        #expect(sut.bringBackBandCrop(carried) == crop)
    }
}
