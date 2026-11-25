//
//  ReaderBoundTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

@testable import FramesAVFoundation
import Testing

// The bound on the readers the decoder keeps open, and the turns of the videos past it (FRAMES-21 Rules).
@Suite("ReaderBound Tests")
struct ReaderBoundTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a video read after others are shown no more closes the reader read longest ago, and takes no turn")
    func closesStaleReader() {
        // Given
        let sut = ReaderBound(count: 2, memory: .max)

        // When
        _ = sut.admit("a", cost: 1) { _ in false }
        _ = sut.admit("b", cost: 1) { _ in false }
        let third = sut.admit("c", cost: 1) { _ in false }
        let fourth = sut.admit("d", cost: 1) { _ in false }

        // Then
        #expect(third.closing == ["a"] && !third.isTurn)
        #expect(fourth.closing == ["b"] && !fourth.isTurn)
    }

    @Test("videos read in turn past the count close at most one reader more than the videos past it each round, each a turn")
    func keepsReadersInCycle() {
        // Given
        let sut = ReaderBound(count: 4, memory: .max)
        let videos = ["a", "b", "c", "d", "e", "f"]
        var closed: [[String]] = []
        var turns: [[String]] = []

        // When
        for _ in 0..<4 {
            var closing: [String] = []
            var turning: [String] = []
            for video in videos {
                let admitted = sut.admit(video, cost: 1) { _ in false }
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
    func closesHolderFirst() {
        // Given
        let sut = ReaderBound(count: 2, memory: .max)
        _ = sut.admit("a", cost: 1) { _ in false }
        _ = sut.admit("b", cost: 1) { _ in false }

        // When
        let admitted = sut.admit("c", cost: 1) { $0 == "b" }

        // Then
        #expect(admitted.closing == ["b"])
    }

    @Test("readers open hold at most the memory, and one is open whatever its cost")
    func boundsMemory() {
        // Given
        let sut = ReaderBound(count: 48, memory: 10)

        // When
        let first = sut.admit("a", cost: 6) { _ in false }
        let second = sut.admit("b", cost: 6) { _ in false }
        let large = sut.admit("c", cost: 20) { _ in false }

        // Then
        #expect(first.closing.isEmpty)
        #expect(second.closing == ["a"])
        #expect(large.closing == ["b"])
    }
}
