//
//  ArrayChainTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("Array+Chain Tests")
struct ArrayChainTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a chain that ends holds no cycle, however deep")
    func endsChain() {
        // Given
        // 0 names 1, 1 names 2, and 2 names nothing among the clips.
        let sut: [Int?] = [1, 2, nil]

        // When
        let cycles = sut.indices.map { sut.cycle(from: $0) }

        // Then
        #expect(cycles == [nil, nil, nil])
    }

    @Test(
        "a chain that comes back to itself gives its cycle from the clip that comes first",
        arguments: [
            ([0] as [Int?], 0, [0]),
            ([2, 3, 3, 1] as [Int?], 0, [1, 3]),
            ([2, 3, 3, 1] as [Int?], 3, [1, 3]),
            ([nil, 2, 3, 1] as [Int?], 3, [1, 2, 3])
        ]
    )
    func findsCycle(
        sut: [Int?],
        start: Int,
        cycle: [Int]
    ) {
        // When
        let found = sut.cycle(from: start)

        // Then
        #expect(found == cycle)
    }

    // MARK: - Private
}
