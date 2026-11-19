//
//  FontWeightTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("FontWeight Tests")
struct FontWeightTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a weight is read from a whole number from 100 to 900 or a weight name",
        arguments: [(JSONValue.number(100), 100), (.number(450), 450), (.number(900), 900), (.string("semibold"), 600)]
    )
    func readsWrittenWeight(written: JSONValue, value: Int) {
        // When
        let sut = FontWeight(written: written)

        // Then
        #expect(sut == FontWeight(value))
    }

    @Test(
        "any other number or name reads as no weight",
        arguments: [JSONValue.number(50), .number(950), .number(450.5), .string("heavy"), .bool(true)]
    )
    func refusesOtherValue(written: JSONValue) {
        // When
        let sut = FontWeight(written: written)

        // Then
        #expect(sut == nil)
    }

    // MARK: - Private
}
