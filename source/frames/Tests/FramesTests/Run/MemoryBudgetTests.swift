//
//  MemoryBudgetTests.swift
//  FramesTests
//
//  Created by JSilver on 11/26/26.
//

import Testing

@testable import Frames

// A run's budget counts each holder at the larger of its floor and what it holds, grants more only within the limit,
// and refuses a limit under the floors (FRAMES-30 The budget).
@Suite("MemoryBudget Tests")
struct MemoryBudgetTests {
    // MARK: - Property
    private let megabyte = MemorySize.megabyte

    // MARK: - Initializer
    // MARK: - Test
    @Test("a holder is granted more while the total stays within the limit, and a refusal is counted")
    func grantsWithinLimit() throws {
        // Given
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")))
        sut.require(3 * megabyte, for: .frames)

        // When
        let first = sut.take(4 * megabyte, for: .readAhead)
        let second = sut.take(4 * megabyte, for: .readAhead)
        sut.give(4 * megabyte, for: .readAhead)
        let third = sut.take(3 * megabyte, for: .readAhead)

        // Then
        #expect(first && !second && third)
        let readAhead = try #require(sut.usage.holders.first { $0.holder == .readAhead })
        #expect(readAhead.refused == 1)
        #expect(readAhead.peak == 4 * megabyte)
        #expect(sut.usage.peak == 7 * megabyte)
    }

    @Test("what a holder holds within its floor is always granted and counts as its floor")
    func countsFloor() throws {
        // Given
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")))
        sut.require(6 * megabyte, for: .readers)
        #expect(sut.take(4 * megabyte, for: .readAhead))

        // When
        let within = sut.take(5 * megabyte, for: .readers)
        let past = sut.take(2 * megabyte, for: .readers)

        // Then
        #expect(within && !past)
        #expect(sut.usage.floor == 6 * megabyte)
        #expect(sut.usage.peak == 10 * megabyte)
    }

    @Test("a limit under the sum of the floors is refused, naming the limit, the floor and each holder's")
    func refusesUnderFloor() throws {
        // Given
        let sut = MemoryBudget(limit: try #require(MemorySize("1.5GB")))
        sut.require(1_288_490_189, for: .readers)
        sut.require(805_306_368, for: .frames)
        sut.require(512 * megabyte / 10, for: .sound)

        // When
        let error = #expect(throws: MemoryError.self) { try sut.checkFloor() }

        // Then
        #expect(error?.description == """
            memory limit 1.5GB is under the 2 GB this run needs: readers 1.2 GB, readAhead 0 MB, frames 768 MB, \
            sound 51.2 MB
            """)
    }

    @Test("a limit at the floor is kept")
    func keepsLimitAtFloor() throws {
        // Given
        let sut = MemoryBudget(limit: try #require(MemorySize("1MB")))
        sut.require(megabyte, for: .frames)

        // When, Then
        try sut.checkFloor()
    }

    @Test("the default limit is a fraction of the machine's memory rounded down to a whole MB")
    func makesDefault() {
        // Given, When
        let half = MemorySize(fraction: 0.5, of: 17_179_869_184)
        let odd = MemorySize(fraction: 0.5, of: 17_179_869_184 + 3 * 1_048_576)

        // Then
        #expect(half.bytes == 8 << 30 && half.written == "8GB")
        #expect(odd.bytes == 8193 << 20 && odd.written == "8193MB")
    }
}
