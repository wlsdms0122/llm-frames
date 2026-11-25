//
//  ReaderBoundTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

@testable import FramesAVFoundation
import Frames
import Testing

// The bound on the readers the decoder keeps open, and the turns of the videos past it (FRAMES-21 Rules).
@Suite("ReaderBound Tests")
struct ReaderBoundTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a video read after others are shown no more closes the reader read longest ago, and takes no turn")
    func closesStaleReader() throws {
        // Given
        let sut = ReaderBound(count: 2, budget: MemoryBudget(limit: .unlimited))

        // When
        _ = try sut.admit("a", cost: 1) { _ in false }
        _ = try sut.admit("b", cost: 1) { _ in false }
        let third = try sut.admit("c", cost: 1) { _ in false }
        let fourth = try sut.admit("d", cost: 1) { _ in false }

        // Then
        #expect(third.closing == ["a"] && !third.isTurn)
        #expect(fourth.closing == ["b"] && !fourth.isTurn)
    }

    @Test("videos read in turn past the count close at most one reader more than the videos past it each round, each a turn")
    func keepsReadersInCycle() throws {
        // Given
        let sut = ReaderBound(count: 4, budget: MemoryBudget(limit: .unlimited))
        let videos = ["a", "b", "c", "d", "e", "f"]
        var closed: [[String]] = []
        var turns: [[String]] = []

        // When
        for _ in 0..<4 {
            var closing: [String] = []
            var turning: [String] = []
            for video in videos {
                let admitted = try sut.admit(video, cost: 1) { _ in false }
                closing += admitted.closing
                if admitted.isTurn { turning.append(video) }
            }
            closed.append(closing)
            turns.append(turning)
        }

        // Then
        #expect(closed.dropFirst().allSatisfy { (2...3).contains($0.count) }, "\(closed)")
        #expect(zip(closed, turns).dropFirst().allSatisfy { $0.count == $1.count }, "\(turns)")
    }

    @Test("a reader holding frames read in a turn is closed first")
    func closesHolderFirst() throws {
        // Given
        let sut = ReaderBound(count: 2, budget: MemoryBudget(limit: .unlimited))
        _ = try sut.admit("a", cost: 1) { _ in false }
        _ = try sut.admit("b", cost: 1) { _ in false }

        // When
        let admitted = try sut.admit("c", cost: 1) { $0 == "b" }

        // Then
        #expect(admitted.closing == ["b"])
    }

    @Test("readers open hold no more than the budget grants them, and the first lies within the floor")
    func boundsMemory() throws {
        // Given
        let budget = MemoryBudget(limit: try #require(MemorySize("10MB")))
        let sut = ReaderBound(count: 48, budget: budget)

        // When
        let first = try sut.admit("a", cost: 6 * megabyte) { _ in false }
        let second = try sut.admit("b", cost: 6 * megabyte) { _ in false }
        let small = try sut.admit("c", cost: 4 * megabyte) { _ in false }

        // Then
        #expect(first.closing.isEmpty)
        #expect(second.closing == ["a"])
        #expect(small.closing.isEmpty)
        #expect(budget.usage.holders.first { $0.holder == .readers }?.refused == 1)
        #expect(budget.usage.peak == 10 * megabyte)
    }

    @Test("a reader that raises the floor of readers above the limit is refused, naming the limit")
    func refusesUnderFloor() throws {
        // Given
        let sut = ReaderBound(count: 48, budget: MemoryBudget(limit: try #require(MemorySize("10MB"))))

        // When, Then
        #expect(throws: MemoryError.self) { try sut.admit("a", cost: 11 * megabyte) { _ in false } }
    }

    // MARK: - Private
    private var megabyte: Int {
        MemorySize.megabyte
    }
}
