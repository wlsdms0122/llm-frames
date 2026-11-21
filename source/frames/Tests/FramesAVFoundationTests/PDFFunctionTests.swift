//
//  PDFFunctionTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
@testable import FramesAVFoundation
import Testing

// Tint transforms as ISO 32000-1 7.10 defines them.
@Suite("PDFFunction Tests")
struct PDFFunctionTests {
    // MARK: - Property
    private static let ramp = PDFValue.dictionary([
        "FunctionType": .integer(2),
        "Domain": .array([.integer(0), .integer(1)]),
        "C0": .array([.integer(0), .integer(1)]),
        "C1": .array([.integer(1), .integer(0)]),
        "N": .integer(2)
    ])

    // MARK: - Initializer
    // MARK: - Test
    @Test("an exponential function interpolates from C0 to C1 by x to the N, its input clipped to its domain")
    func evaluatesExponential() throws {
        // Given
        let sut = try #require(PDFFunction(Self.ramp))

        // When
        let half = sut(0.5)
        let past = sut(2)

        // Then
        #expect(half == [0.25, 0.75])
        #expect(past == [1, 0])
    }

    @Test("a stitching function maps each part of its domain through its encode range into its own function")
    func evaluatesStitching() throws {
        // Given
        let value = PDFValue.dictionary([
            "FunctionType": .integer(3),
            "Domain": .array([.integer(0), .integer(1)]),
            "Functions": .array([Self.ramp, Self.ramp]),
            "Bounds": .array([.real(0.5)]),
            "Encode": .array([.integer(0), .integer(1), .integer(1), .integer(0)])
        ])
        let sut = try #require(PDFFunction(value))

        // When
        let low = sut(0.25)
        let high = sut(0.75)

        // Then
        #expect(low == [0.25, 0.75])
        #expect(high == [0.25, 0.75])
    }

    @Test("a sampled or a PostScript calculator function is not read")
    func refusesOtherTypes() {
        // Given
        // When
        let sampled = PDFFunction(.dictionary(["FunctionType": .integer(0), "Domain": .array([.integer(0), .integer(1)])]))
        let calculator = PDFFunction(.stream(["FunctionType": .integer(4), "Domain": .array([.integer(0), .integer(1)])], Data()))

        // Then
        #expect(sampled == nil)
        #expect(calculator == nil)
    }
}
