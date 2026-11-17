//
//  CropConformerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("CropConformer Tests")
struct CropConformerTests {
    // MARK: - Property
    private let sut = CropConformer()
    private let box = Rectangle(x: 10, y: 20, width: 100, height: 200)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "fit grows a crop about its centre until the written region fits, and fill shrinks it until it lies inside",
        arguments: [
            (Rectangle(x: 0, y: 0, width: 100, height: 100), Conform.fit, Rectangle(x: 0, y: -50, width: 100, height: 200)),
            (Rectangle(x: 0, y: 0, width: 100, height: 100), .fill, Rectangle(x: 25, y: 0, width: 50, height: 100)),
            (Rectangle(x: 0, y: 0, width: 50, height: 200), .fit, Rectangle(x: -25, y: 0, width: 100, height: 200)),
            (Rectangle(x: 0, y: 0, width: 50, height: 200), .fill, Rectangle(x: 0, y: 50, width: 50, height: 100)),
            (Rectangle(x: 5, y: 5, width: 50, height: 100), .fit, Rectangle(x: 5, y: 5, width: 50, height: 100))
        ]
    )
    func conformsToContentAspect(
        crop: Rectangle,
        conform: Conform,
        conformed: Rectangle
    ) {
        // Given, When
        let result = sut.conformed(crop, to: box, by: conform)

        // Then
        #expect(result == conformed)
    }

    @Test("a rectangle of the media lands where the conformed crop puts it in the box")
    func placesMediaRectangle() {
        // Given
        let crop = Rectangle(x: 0, y: -50, width: 50, height: 100)

        // When
        let output = sut.output(of: Rectangle(x: 20, y: 30, width: 10, height: 10), crop: crop, box: box)

        // Then
        #expect(output == Rectangle(x: 50, y: 180, width: 20, height: 20))
    }
}
