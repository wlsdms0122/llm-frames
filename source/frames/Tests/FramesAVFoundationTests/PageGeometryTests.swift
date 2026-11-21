//
//  PageGeometryTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Frames
@testable import FramesAVFoundation
import Testing

// The table of FRAMES-3 PDF pages on a crop box [50 30 550 330] of a media box [0 0 600 400]: W 500, H 300.
@Suite("PageGeometry Tests")
struct PageGeometryTests {
    // MARK: - Property
    private let mediaBox = CGRect(x: 0, y: 0, width: 600, height: 400)
    private let cropBox = CGRect(x: 50, y: 30, width: 500, height: 300)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "each rotation puts the crop box's displayed top left at media pixel (0, 0) and its opposite corner at (w, h)",
        arguments: [
            (0, CGPoint(x: 50, y: 330), CGPoint(x: 550, y: 30), Size(width: 500, height: 300)),
            (90, CGPoint(x: 50, y: 30), CGPoint(x: 550, y: 330), Size(width: 300, height: 500)),
            (180, CGPoint(x: 550, y: 30), CGPoint(x: 50, y: 330), Size(width: 500, height: 300)),
            (270, CGPoint(x: 550, y: 330), CGPoint(x: 50, y: 30), Size(width: 300, height: 500))
        ]
    )
    func mapsCorners(
        rotation: Int,
        origin: CGPoint,
        opposite: CGPoint,
        size: Size
    ) throws {
        // Given
        let sut = try PageGeometry(mediaBox: mediaBox, cropBox: cropBox, rotation: rotation, userUnit: 1)

        // When
        let mappedOrigin = origin.applying(sut.toMediaPixels)
        let mappedOpposite = opposite.applying(sut.toMediaPixels)

        // Then
        #expect(sut.size == size)
        #expect(mappedOrigin == .zero)
        #expect(mappedOpposite == CGPoint(x: size.width, y: size.height))
    }

    @Test("the user unit multiplies the size and the map, and the sides swap at 90")
    func appliesUserUnit() throws {
        // Given
        let sut = try PageGeometry(mediaBox: mediaBox, cropBox: cropBox, rotation: 90, userUnit: 2)

        // When
        let mapped = CGPoint(x: 550, y: 330).applying(sut.toMediaPixels)

        // Then
        #expect(sut.size == Size(width: 600, height: 1000))
        #expect(mapped == CGPoint(x: 600, y: 1000))
    }

    @Test("Rotate is taken modulo 360 into 0 to 359", arguments: [(450, 90), (-90, 270), (360, 0), (-180, 180)])
    func takesRotationModulo(
        written: Int,
        rotation: Int
    ) throws {
        // Given
        // When
        let sut = try PageGeometry(mediaBox: mediaBox, cropBox: cropBox, rotation: written, userUnit: 1)

        // Then
        #expect(sut.rotation == rotation)
    }

    @Test("a Rotate that is not a multiple of 90 has no geometry")
    func refusesRotation() {
        // Given
        // When
        // Then
        #expect(throws: PageFault.rotation(45)) {
            try PageGeometry(mediaBox: mediaBox, cropBox: cropBox, rotation: 45, userUnit: 1)
        }
    }

    @Test("the crop box is intersected with the media box, its corners in order")
    func intersectsCropBox() throws {
        // Given
        let reversed = CGRect(x: 200, y: 200, width: -250, height: -250)

        // When
        let sut = try PageGeometry(
            mediaBox: CGRect(x: 0, y: 0, width: 200, height: 200),
            cropBox: reversed,
            rotation: 0,
            userUnit: 1
        )

        // Then
        #expect(sut.cropBox == CGRect(x: 0, y: 0, width: 200, height: 200))
        #expect(sut.size == Size(width: 200, height: 200))
    }

    @Test("a page under 1 media pixel on a side, or whose crop box misses its media box, has no geometry")
    func refusesSmallPage() {
        // Given
        let thin = CGRect(x: 0, y: 0, width: 100, height: 0.5)
        let outside = CGRect(x: 700, y: 0, width: 100, height: 100)

        // When
        // Then
        #expect(throws: PageFault.size(Size(width: 100, height: 0.5))) {
            try PageGeometry(mediaBox: mediaBox, cropBox: thin, rotation: 0, userUnit: 1)
        }
        #expect(throws: PageFault.size(Size(width: 0, height: 0))) {
            try PageGeometry(mediaBox: mediaBox, cropBox: outside, rotation: 0, userUnit: 1)
        }
    }

    @Test("a region at a scale moves media pixel (x / s, y / s) to the region's top left")
    func placesRegion() throws {
        // Given
        let sut = try PageGeometry(mediaBox: mediaBox, cropBox: cropBox, rotation: 0, userUnit: 1)
        let region = PageRegion(x: 30, y: 60, width: 100, height: 50)

        // When
        let topLeft = CGPoint(x: 50 + 30.0 / 1.5, y: 330 - 60.0 / 1.5).applying(sut.transform(for: region, scale: 1.5))

        // Then
        #expect(abs(topLeft.x) < 1e-9)
        #expect(abs(topLeft.y - 50) < 1e-9)
    }
}
