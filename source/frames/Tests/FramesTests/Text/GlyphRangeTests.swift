//
//  GlyphRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

@testable import Frames

@Suite("GlyphRange Tests")
struct GlyphRangeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("its glyphs are the count from the first, in its run")
    func givesGlyphs() {
        // Given
        let sut = GlyphRange(run: 1, first: 2, count: 3)

        // When
        let glyphs = sut.glyphs

        // Then
        #expect(glyphs == 2..<5)
    }

    @Test("a range of count 0 holds no glyph, at its first")
    func givesEmptyGlyphs() {
        // Given
        let sut = GlyphRange(run: 0, first: 4, count: 0)

        // When
        let glyphs = sut.glyphs

        // Then
        #expect(glyphs == 4..<4)
    }

    // MARK: - Private
}
