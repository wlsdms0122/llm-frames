//
//  GlyphRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

@Suite("GlyphRange Tests")
struct GlyphRangeTests {
    // MARK: - Property
    private let glyphCounts = [3, 1, 0, 2]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a range that fits in its run is that run's glyphs alone")
    func liesInItsRun() {
        // Given
        let sut = GlyphRange(run: 0, first: 1, count: 2)

        // When
        let ranges = sut.ranges(within: glyphCounts)

        // Then
        #expect(ranges == [GlyphRange(run: 0, first: 1, count: 2)])
    }

    @Test("a range that runs past its run's end goes on from the first glyph of each run after it, an empty one holding none")
    func runsOnIntoNextRuns() {
        // Given
        let sut = GlyphRange(run: 0, first: 2, count: 3)

        // When
        let ranges = sut.ranges(within: glyphCounts)

        // Then
        #expect(ranges == [
            GlyphRange(run: 0, first: 2, count: 1),
            GlyphRange(run: 1, first: 0, count: 1),
            GlyphRange(run: 3, first: 0, count: 1)
        ])
    }

    @Test(
        "a range holds only the glyphs the runs have, none where its first glyph is not one of its run's or its count is 0",
        arguments: [
            (GlyphRange(run: 3, first: 1, count: 2), 1),
            (GlyphRange(run: 1, first: 1, count: 1), 0),
            (GlyphRange(run: 4, first: 0, count: 1), 0),
            (GlyphRange(run: 0, first: 3, count: 0), 0)
        ]
    )
    func holdsWhatRunsHave(
        sut: GlyphRange,
        count: Int
    ) {
        // When
        let ranges = sut.ranges(within: glyphCounts)

        // Then
        #expect(ranges.map(\.count).reduce(0, +) == count)
    }
}
