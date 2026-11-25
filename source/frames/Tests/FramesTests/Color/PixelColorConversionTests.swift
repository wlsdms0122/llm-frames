//
//  PixelColorConversionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

@testable import Frames
import Testing

@Suite("Pixel Color Conversion Tests")
struct PixelColorConversionTests {
    // MARK: - Property
    // Premultiplied RGBA pixels in one row: runs of one colour, single pixels, alternating pixels, one colour at other
    // alphas, NaN of two payloads, negative and signed zero samples, and transparent pixels with and without colour.
    private static let row: [Float] = [
        0.2, 0.4, 0.6, 1, 0.2, 0.4, 0.6, 1, 0.2, 0.4, 0.6, 1, 0.2, 0.4, 0.6, 1,
        0.9, 0.1, 0.3, 1,
        0.05, 0.1, 0.15, 0.5, 0.05, 0.1, 0.15, 0.25, 0.05, 0.1, 0.15, 0.25,
        0.7, 0.7, 0.7, 1, 0.1, 0.1, 0.1, 1, 0.7, 0.7, 0.7, 1, 0.1, 0.1, 0.1, 1, 0.7, 0.7, 0.7, 1,
        .nan, 0.5, 0.5, 1, .nan, 0.5, 0.5, 1, Float(nan: 1, signaling: false), 0.5, 0.5, 1,
        0.5, .nan, 0.5, 0.75, 0.5, .nan, 0.5, 0.75,
        -0.25, 0.5, 1.5, 1, -0.25, 0.5, 1.5, 1, -0.25, 0.5, 1.5, 0.8,
        0, 0.3, 0.3, 1, -0.0, 0.3, 0.3, 1, -0.0, 0.3, 0.3, 1, 0, 0.3, 0.3, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0.3, 0.3, 0.3, 0, 0.3, 0.3, 0.3, -0.0, 0.3, 0.3, 0.3, .nan,
        0.2, 0.4, 0.6, 1, 0.2, 0.4, 0.6, 1,
        0.01, 0.02, 0.03, 0.04
    ]

    private static let colors: [MediaColor] = [
        .codePoints(CodePoints(colorPrimaries: 12, transferCharacteristics: 13, matrixCoefficients: 1)),
        .codePoints(CodePoints(colorPrimaries: 9, transferCharacteristics: 18, matrixCoefficients: 9)),
        .space(.rec2100PQ),
        .space(.displayP3)
    ]

    private static let spaces: [ColorSpace] = [.srgb, .displayP3, .rec2020, .rec2100PQ, .rec2100HLG]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a row converted to working values has the bits of each pixel converted alone", arguments: colors)
    func convertsWorkingAsPixelsAlone(color: MediaColor) {
        // Given
        let sut = MediaColorConversion(color)
        let toneMapping = sut.toneMapping(masteringDisplayPeak: nil, targetPeak: 400)
        let conversion = { (encoded: RGB) in sut.working(encoded, toneMapping: toneMapping) }

        // When
        let converted = Self.converted(Self.row, by: conversion)

        // Then
        #expect(converted.map(\.bitPattern) == Self.convertedAlone(Self.row, by: conversion).map(\.bitPattern))
    }

    @Test("a row converted to an output has the bits of each pixel converted alone", arguments: spaces)
    func convertsOutputAsPixelsAlone(space: ColorSpace) {
        // Given
        let sut = ColorConversion(space: space, peak: 1000)
        let conversion = { (working: RGB) in sut.output(working) }

        // When
        let converted = Self.converted(Self.row, by: conversion)

        // Then
        #expect(converted.map(\.bitPattern) == Self.convertedAlone(Self.row, by: conversion).map(\.bitPattern))
    }

    @Test("a run of one colour is converted once, and a pixel of other bits is converted again")
    func convertsRunOnce() {
        // Given
        let run: [Float] = [0.2, 0.4, 0.6, 1, 0.2, 0.4, 0.6, 1, 0.2, 0.4, 0.6, 1]
        let other: [Float] = [0.2, 0.4, 0.6, 0.5, -0.0, 0.4, 0.6, 1, 0, 0.4, 0.6, 1]
        var pixels = run + other + run
        var conversions = 0

        // When
        pixels.withUnsafeMutableBufferPointer { buffer in
            buffer.convertColors { encoded in
                conversions += 1
                return encoded
            }
        }

        // Then
        #expect(conversions == 5)
    }

    // MARK: - Private
    private static func converted(
        _ pixels: [Float],
        by conversion: (RGB) -> RGB
    ) -> [Float] {
        var converted = pixels
        converted.withUnsafeMutableBufferPointer { $0.convertColors(by: conversion) }

        return converted
    }

    // Each pixel converted in a buffer of its own, so no other pixel's result is taken.
    private static func convertedAlone(
        _ pixels: [Float],
        by conversion: (RGB) -> RGB
    ) -> [Float] {
        stride(from: 0, to: pixels.count, by: 4).flatMap { offset in
            converted(Array(pixels[offset..<offset + 4]), by: conversion)
        }
    }
}
