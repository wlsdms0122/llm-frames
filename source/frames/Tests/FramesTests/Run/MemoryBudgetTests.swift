//
//  MemoryBudgetTests.swift
//  FramesTests
//
//  Created by JSilver on 11/26/26.
//

import FramesTestMedia
import Testing

@testable import Frames

// A run's budget counts each holder at the larger of its floor and what it holds, grants more only within the limit
// with what the process holds past what it counts in it, and refuses a limit under the floors (FRAMES-30 The budget,
// What it measures).
@Suite("MemoryBudget Tests")
struct MemoryBudgetTests {
    // MARK: - Property
    private let megabyte = MemorySize.megabyte

    // MARK: - Initializer
    // MARK: - Test
    @Test("a holder is granted more while the total stays within the limit, and a refusal is counted")
    func grantsWithinLimit() throws {
        // Given
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")), meter: SettableMemoryMeter())
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
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")), meter: SettableMemoryMeter())
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

    @Test("a hold within its holder's floor leaves a holder that gives way the room beside the floors")
    func grantsHoldWithinFloor() throws {
        // Given
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")), meter: SettableMemoryMeter())
        sut.require(4 * megabyte, for: .readers)
        sut.require(4 * megabyte, for: .pictures)

        // When
        sut.hold(4 * megabyte, for: .pictures)
        let refused = sut.take(3 * megabyte, for: .readAhead)
        let granted = sut.take(2 * megabyte, for: .readAhead)

        // Then
        #expect(!refused && granted)
        let pictures = try #require(sut.usage.holders.first { $0.holder == .pictures })
        #expect(pictures.peak == 4 * megabyte && pictures.refused == 0)
        #expect(sut.usage.peak == 10 * megabyte)
    }

    @Test("a holder is granted more only where the process's footprint past what the budget counts in it leaves room")
    func correctsByFootprint() throws {
        // Given
        let meter = SettableMemoryMeter()
        let sut = MemoryBudget(limit: try #require(MemorySize("12MB")), meter: meter)
        sut.require(3 * megabyte, for: .readers)
        sut.require(2 * megabyte, for: .frames)
        meter.set(6 * megabyte)

        // When
        let refused = sut.take(4 * megabyte, for: .readAhead)
        let granted = sut.take(3 * megabyte, for: .readAhead)

        // Then
        #expect(!refused && granted)
        #expect(sut.usage.uncounted == 4 * megabyte)
        #expect(sut.usage.peak == 8 * megabyte)
    }

    @Test("a footprint within what the budget counts in the process adds nothing to the total")
    func addsNothingWithinCounted() throws {
        // Given
        let meter = SettableMemoryMeter()
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")), meter: meter)
        sut.require(4 * megabyte, for: .pictures)
        meter.set(3 * megabyte)

        // When
        let granted = sut.take(6 * megabyte, for: .readAhead)

        // Then
        #expect(granted)
        #expect(sut.usage.uncounted == 0)
    }

    @Test("a lower reading lowers the correction only once a second has passed since the higher one")
    func holdsCorrectionForWindow() throws {
        // Given
        let meter = SettableMemoryMeter()
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")), meter: meter)
        meter.set(6 * megabyte)
        #expect(sut.take(megabyte, for: .readAhead))
        meter.set(0)

        // When
        let withinWindow = sut.take(4 * megabyte, for: .readers)
        meter.advance(by: .milliseconds(999))
        let beforeWindowEnds = sut.take(4 * megabyte, for: .readers)
        meter.advance(by: .milliseconds(1))
        let afterWindow = sut.take(4 * megabyte, for: .readers)

        // Then
        #expect(!withinWindow && !beforeWindowEnds && afterWindow)
        #expect(sut.usage.holders.first { $0.holder == .readers }?.refused == 2)
        #expect(sut.usage.uncounted == 6 * megabyte)
    }

    @Test("what a holder holds within its floor is granted and the floors are checked whatever the process holds")
    func keepsFloorsWhateverFootprint() throws {
        // Given
        let meter = SettableMemoryMeter()
        let sut = MemoryBudget(limit: try #require(MemorySize("10MB")), meter: meter)
        sut.require(6 * megabyte, for: .readers)
        sut.require(4 * megabyte, for: .frames)
        meter.set(100 * megabyte)

        // When
        try sut.checkFloor()
        let withinFloor = sut.take(6 * megabyte, for: .readers)
        let pastFloor = sut.take(megabyte, for: .readAhead)

        // Then
        #expect(withinFloor && !pastFloor)
        #expect(sut.usage.peak == 10 * megabyte)
    }

    @Test("the budget gives the largest footprint the process has held")
    func reportsProcessPeak() throws {
        // Given
        let meter = SettableMemoryMeter()
        let sut = MemoryBudget(limit: .unlimited, meter: meter)

        // When
        meter.set(7 * megabyte)
        meter.set(3 * megabyte)

        // Then
        #expect(sut.usage.process == 7 * megabyte)
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
            memory limit 1.5GB is under the 2 GB this run needs: readers 1.2 GB, readAhead 0 MB, turns 0 MB, \
            pictures 0 MB, frames 768 MB, sound 51.2 MB
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
