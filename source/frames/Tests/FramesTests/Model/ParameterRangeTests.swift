//
//  ParameterRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("ParameterRange Tests")
struct ParameterRangeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "each op's ranges are its parameters' leaf domains",
        arguments: [
            ("exposure", [String]()),
            ("sepia", ["amount: within 0 to 1"]),
            ("levels", ["input: within 0 to 1 with black below white", "output: within 0 to 1 with black below white"]),
            ("lut", ["amount: within 0 to 1"]),
            ("blur", ["radius: above 0"]),
            ("sharpen", ["radius: above 0"]),
            ("bloom", ["radius: above 0"]),
            ("vignette", ["radius: within 0 to 1"]),
            ("pixelate", ["size: above 0"]),
            ("grain", ["amount: within 0 to 1", "size: above 0"])
        ]
    )
    func derivesRangesFromLeafDomains(
        operation: String,
        expected: [String]
    ) throws {
        // Given
        guard case let .object(structure) = LookStructureTable.filterOperation(operation) else {
            Issue.record("\(operation) declares no parameters")
            return
        }

        // When
        let ranges = structure.keys.compactMap { parameter -> String? in
            guard case let .leaf(kind) = parameter.structure, let sut = ParameterRange(kind: kind) else { return nil }

            return "\(parameter.name): \(sut.description)"
        }

        // Then
        #expect(ranges == expected)
    }

    @Test(
        "a range is worded by the domain its numbers lie in, as the key check and timing word a domain",
        arguments: [
            (LeafKind.number(.range(0...1)), NumberDomain.range(0...1).description),
            (LeafKind.length(.positive), NumberDomain.positive.description),
            (LeafKind.length(.nonNegative), NumberDomain.nonNegative.description),
            (LeafKind.numbers(count: 2, domain: .range(0...1)), NumberDomain.range(0...1).description + " with black below white")
        ]
    )
    func wordsRangeByDomain(
        kind: LeafKind,
        expected: String
    ) throws {
        // Given
        let sut = try #require(ParameterRange(kind: kind))

        // When
        let description = sut.description

        // Then
        #expect(description == expected)
    }

    @Test("a length a keyframe moves may be 0, and the other ranges stay as declared")
    func widensSampledLength() {
        // Given
        let sut = ParameterRange(kind: .length(.positive))

        // When
        let sampled = sut?.sampled

        // Then
        #expect(sampled?.contains(.number(0)) == true)
        #expect(ParameterRange(kind: .number(.range(0...1)))?.sampled.contains(.number(1.5)) == false)
        #expect(ParameterRange(kind: .number()) == nil)
    }
}
