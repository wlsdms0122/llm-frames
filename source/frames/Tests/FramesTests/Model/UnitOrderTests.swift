//
//  UnitOrderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Testing

@testable import Frames

@Suite("Unit Order Tests")
struct UnitOrderTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "each order ranks an odd count, an even count and a single unit by the rule of its name",
        arguments: [
            (UnitOrder.forward, [0, 1, 2, 3, 4], [0, 1, 2, 3], [0]),
            (UnitOrder.backward, [4, 3, 2, 1, 0], [3, 2, 1, 0], [0]),
            (UnitOrder.center, [2, 1, 0, 1, 2], [1, 0, 0, 1], [0]),
            (UnitOrder.edges, [0, 1, 2, 1, 0], [0, 1, 1, 0], [0]),
            (UnitOrder.random, [4, 1, 2, 0, 3], [0, 3, 1, 2], [0])
        ]
    )
    func ranksUnits(
        order: UnitOrder,
        five: [Int],
        four: [Int],
        one: [Int]
    ) {
        // When
        let ranks = [5, 4, 1].map { order.ranks(count: $0) }

        // Then
        #expect(ranks == [five, four, one])
    }

    @Test("a title with no unit has no rank")
    func ranksNoUnit() {
        // When
        let ranks = UnitOrder.allCases.map { $0.ranks(count: 0) }

        // Then
        #expect(ranks.allSatisfy { $0.isEmpty })
    }

    @Test("`random` shuffles 0 to n - 1 by SplitMix64 seeded to n, so 1, 2 and 5 units take these ranks")
    func shufflesBySplitMix() {
        // When
        let ranks = [1, 2, 5].map { UnitOrder.random.ranks(count: $0) }

        // Then
        #expect(ranks == [[0], [1, 0], [4, 1, 2, 0, 3]])
    }

    @Test("`random` ranks are a permutation of 0 to n - 1 that is the same each time for the same n")
    func shufflesToPermutation() {
        // Given
        let counts = Array(1...64)

        // When
        let first = counts.map { UnitOrder.random.ranks(count: $0) }
        let second = counts.map { UnitOrder.random.ranks(count: $0) }

        // Then
        #expect(zip(counts, first).allSatisfy { count, ranks in ranks.sorted() == Array(0..<count) })
        #expect(first == second)
        #expect(first.contains { $0 != Array(0..<$0.count) })
    }

    @Test("SplitMix64 seeded to 0 gives the reference sequence in wrapping 64-bit arithmetic")
    func generatesSplitMix() {
        // Given
        var generator = SplitMix64(seed: 0)

        // When
        let values = (0..<3).map { _ in generator.next() }

        // Then
        #expect(values == [0xE220A8397B1DCDAF, 0x6E789E6AA1B965F4, 0x06C45D188009454F])
    }

    // MARK: - Private
}
