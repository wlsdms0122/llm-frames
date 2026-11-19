//
//  ScaleTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("Scale Tests")
struct ScaleTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a number is the same factor on both axes, and a pair a factor along each")
    func readsNumberOrPair() {
        // Given
        let number = JSONValue.number(2)
        let pair = JSONValue.array([.number(-1), .number(0.5)])

        // When
        let uniform = Scale(value: number)
        let perAxis = Scale(value: pair)

        // Then
        #expect(uniform == Scale(x: 2, y: 2))
        #expect(perAxis == Scale(x: -1, y: 0.5))
    }

    @Test(
        "a list of another length or of anything but numbers is no scale",
        arguments: [
            JSONValue.array([.number(1)]),
            JSONValue.array([.number(1), .number(2), .number(3)]),
            JSONValue.array([.number(1), .string("2")]),
            JSONValue.string("2")
        ]
    )
    func refusesOtherValues(value: JSONValue) {
        // Given
        // When
        let sut = Scale(value: value)

        // Then
        #expect(sut == nil)
    }

    @Test("the scale factor is the geometric mean of the factors' sizes, so a mirror keeps it")
    func takesGeometricMean() {
        // Given
        let sut = Scale(x: -2, y: 8)

        // When
        let factor = sut.factor

        // Then
        #expect(factor == 4)
    }
}
