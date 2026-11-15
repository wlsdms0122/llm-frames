//
//  EngineRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("EngineRange Tests")
struct EngineRangeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a range holds the version written, with missing parts 0, up to the next major version",
        arguments: [
            ("^1", "1.0.0", true),
            ("^1.2", "1.2.0", true),
            ("^1.2", "1.9.3", true),
            ("^1.2", "1.1.9", false),
            ("^1.2", "2.0.0", false),
            ("^1.2.3", "1.2.3", true),
            ("^1.2.3", "1.2.2", false),
            ("^2", "1.0.0", false)
        ]
    )
    func holdsVersions(text: String, version: String, isHeld: Bool) throws {
        // Given
        let sut = try #require(EngineRange(text))

        // When
        let held = sut.contains(version)

        // Then
        #expect(held == isHeld)
    }

    @Test("only ^major, ^major.minor and ^major.minor.patch are ranges", arguments: ["1.0", "^", "^1.", "^1.2.3.4", "^+1", "^1.x", ">=1", "^ 1"])
    func refusesOtherSpellings(text: String) {
        // Given, When
        let sut = EngineRange(text)

        // Then
        #expect(sut == nil)
    }
}
