//
//  PDFFunctionTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
@testable import FramesAVFoundation
import Testing

// Tint transforms as ISO 32000-1 7.10 defines them: types 0, 2, 3 and 4.
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
        let half = sut([0.5])
        let past = sut([2])

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
        let low = sut([0.25])
        let high = sut([0.75])

        // Then
        #expect(low == [0.25, 0.75])
        #expect(high == [0.25, 0.75])
    }

    @Test("a sampled function interpolates linearly between its samples, the first input varying fastest")
    func evaluatesSampled() throws {
        // Given
        let oneInput = try #require(PDFFunction(.stream([
            "FunctionType": .integer(0),
            "Domain": .array([.integer(0), .integer(1)]),
            "Range": .array([.integer(0), .integer(1), .integer(0), .integer(1)]),
            "Size": .array([.integer(3)]),
            "BitsPerSample": .integer(8)
        ], Data([0, 255, 51, 0, 255, 102]))))
        let twoInputs = try #require(PDFFunction(.stream([
            "FunctionType": .integer(0),
            "Domain": .array([.integer(0), .integer(1), .integer(0), .integer(1)]),
            "Range": .array([.integer(0), .integer(1)]),
            "Size": .array([.integer(2), .integer(2)]),
            "BitsPerSample": .integer(12)
        ], Data([0x00, 0x0F, 0xFF, 0xFF, 0xF0, 0x00]))))

        // When
        let start = try #require(oneInput([0]))
        let quarter = try #require(oneInput([0.25]))
        let half = try #require(oneInput([0.5]))
        let past = try #require(oneInput([2]))
        let corner = try #require(twoInputs([1, 0]))
        let middle = try #require(twoInputs([0.5, 0.5]))
        let edge = try #require(twoInputs([0.25, 0]))

        // Then
        #expect(start == [0, 1])
        #expect(Self.isClose(quarter, [0.1, 0.5]))
        #expect(Self.isClose(half, [0.2, 0]))
        #expect(past == [1, 0.4])
        #expect(corner == [1])
        #expect(Self.isClose(middle, [0.5]))
        #expect(Self.isClose(edge, [0.25]))
    }

    @Test("a sampled function maps its inputs through Encode and its samples through Decode")
    func evaluatesSampledEncodeAndDecode() throws {
        // Given
        let sut = try #require(PDFFunction(.stream([
            "FunctionType": .integer(0),
            "Domain": .array([.integer(0), .integer(1)]),
            "Range": .array([.integer(0), .integer(1)]),
            "Size": .array([.integer(3)]),
            "BitsPerSample": .integer(8),
            "Encode": .array([.integer(2), .integer(0)]),
            "Decode": .array([.integer(1), .integer(0)])
        ], Data([0, 51, 255]))))

        // When
        let start = try #require(sut([0]))
        let half = try #require(sut([0.5]))

        // Then
        #expect(start == [0])
        #expect(Self.isClose(half, [0.8]))
    }

    @Test("a sampled function of cubic spline interpolation, or with too few samples, is not read")
    func refusesSampled() {
        // Given
        let entries: [String: PDFValue] = [
            "FunctionType": .integer(0),
            "Domain": .array([.integer(0), .integer(1)]),
            "Range": .array([.integer(0), .integer(1)]),
            "Size": .array([.integer(2)]),
            "BitsPerSample": .integer(8)
        ]

        // When
        let cubic = PDFFunction(.stream(entries.merging(["Order": .integer(3)]) { $1 }, Data([0, 255])))
        let short = PDFFunction(.stream(entries, Data([0])))

        // Then
        #expect(cubic == nil)
        #expect(short == nil)
    }

    @Test("a PostScript calculator function runs on its clipped inputs and clips its outputs to its range")
    func evaluatesCalculator() throws {
        // Given
        let sut = try #require(PDFFunction(.stream([
            "FunctionType": .integer(4),
            "Domain": .array([.integer(0), .integer(1), .integer(0), .integer(1)]),
            "Range": .array([.integer(0), .integer(1), .integer(0), .integer(1)])
        ], Data("{ 2 copy add 3 1 roll mul }".utf8))))

        // When
        let inside = try #require(sut([0.25, 0.5]))
        let clipped = try #require(sut([2, 0.75]))

        // Then
        #expect(inside == [0.75, 0.125])
        #expect(clipped == [1, 0.75])
    }

    @Test("a PostScript calculator function that leaves a number of outputs other than its range's gives none")
    func refusesCalculatorOutputs() throws {
        // Given
        let sut = try #require(PDFFunction(.stream([
            "FunctionType": .integer(4),
            "Domain": .array([.integer(0), .integer(1)]),
            "Range": .array([.integer(0), .integer(1), .integer(0), .integer(1)])
        ], Data("{ 0.5 mul }".utf8))))

        // When
        let outputs = sut([1])

        // Then
        #expect(outputs == nil)
    }

    @Test("a function whose output is no finite number gives none")
    func refusesNonFiniteOutputs() throws {
        // Given
        let sut = try #require(PDFFunction(.dictionary([
            "FunctionType": .integer(2),
            "Domain": .array([.integer(0), .integer(1)]),
            "N": .integer(-1)
        ])))

        // When
        let atZero = sut([0])
        let atHalf = sut([0.5])

        // Then
        #expect(atZero == nil)
        #expect(atHalf == [2])
    }

    // MARK: - Private
    private static func isClose(
        _ values: [Double],
        _ expected: [Double]
    ) -> Bool {
        values.count == expected.count && zip(values, expected).allSatisfy { abs($0 - $1) < 1e-12 }
    }
}
