//
//  CharacterRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

@testable import Frames

@Suite("CharacterRange Tests")
struct CharacterRangeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("its clusters are the count from the first, on its line")
    func givesClusters() {
        // Given
        let sut = CharacterRange(line: 1, first: 2, count: 3)

        // When
        let clusters = sut.clusters

        // Then
        #expect(clusters == 2..<5)
    }

    @Test("a range of count 0 holds no cluster, at its first")
    func givesEmptyClusters() {
        // Given
        let sut = CharacterRange(line: 0, first: 4, count: 0)

        // When
        let clusters = sut.clusters

        // Then
        #expect(clusters == 4..<4)
    }

    // MARK: - Private
}
