//
//  ColorReadingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

import Frames
import Testing

@Suite("ColorReading Tests")
struct ColorReadingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "fixed formulas convert a picture in a written colour space, or by its tags unless only the platform reads it",
        arguments: [
            (ColorReading.formulas(.srgb), nil as ColorSpace?, true),
            (ColorReading.formulas(nil), nil as ColorSpace?, true),
            (ColorReading.formulas(.rec2100PQ), ColorSpace.srgb, true),
            (ColorReading.platform, ColorSpace.srgb, true),
            (ColorReading.platform, nil as ColorSpace?, false)
        ]
    )
    func converts(
        reading: ColorReading,
        colorSpace: ColorSpace?,
        expected: Bool
    ) {
        // When
        let converts = reading.converts(in: colorSpace)

        // Then
        #expect(converts == expected)
    }

    // MARK: - Private
}
