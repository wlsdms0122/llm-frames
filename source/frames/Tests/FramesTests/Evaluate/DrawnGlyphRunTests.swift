//
//  DrawnGlyphRunTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("Drawn Glyph Run Tests")
struct DrawnGlyphRunTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a glyph is drawn at its pen with its placement offset added, and moved from there")
    func drawsAtPenWithPlacementOffset() {
        // Given
        let run = ResolvedGlyphRun(
            source: 0,
            font: PinnedFile(path: "/abs/font.ttf", sha256: String(repeating: "0", count: 64)),
            face: "Font-Regular",
            size: 40,
            color: .track([Keyframe(at: 0, value: .color(Color(written: "#FFFFFF")))]),
            stroke: .off,
            baselineShift: .off,
            isSideways: false,
            horizontalScale: 1,
            staticTracking: 0,
            tracking: .off,
            highlight: nil,
            underline: nil,
            glyphs: [
                PositionedGlyph(id: 1, x: 0, y: 32),
                PositionedGlyph(id: 2, x: 20, y: 32, placementOffset: Point(x: -10, y: -20))
            ]
        )
        let still = PieceMove(start: Point(x: 0, y: 0), end: Point(x: 0, y: 0))

        // When
        let sut = DrawnGlyphRun(
            run: run,
            writingMode: .horizontalTopToBottom,
            factor: 1,
            at: SampleTime(0),
            moves: [Point(x: 3, y: 4), Point(x: 3, y: 4)],
            pieceMoves: [still]
        )

        // Then
        #expect(sut.glyphs == [PositionedGlyph(id: 1, x: 3, y: 36), PositionedGlyph(id: 2, x: 13, y: 16)])
    }

    @Test("a drawn run is narrowed and turned as its resolved run is, and the run a unit carries keeps both")
    func carriesOrientationAndHorizontalScale() {
        // Given
        let run = ResolvedGlyphRun(
            source: 0,
            font: PinnedFile(path: "/abs/font.ttf", sha256: String(repeating: "0", count: 64)),
            face: "Font-Regular",
            size: 40,
            color: .track([Keyframe(at: 0, value: .color(Color(written: "#FFFFFF")))]),
            stroke: .off,
            baselineShift: .off,
            isSideways: true,
            horizontalScale: 0.5,
            staticTracking: 0,
            tracking: .off,
            highlight: nil,
            underline: nil,
            glyphs: [PositionedGlyph(id: 1, x: 0, y: 32)]
        )

        // When
        let sut = DrawnGlyphRun(
            run: run,
            writingMode: .verticalRightToLeft,
            factor: 1,
            at: SampleTime(0),
            moves: [Point(x: 0, y: 0)],
            pieceMoves: []
        )
        let carried = sut.carrying(
            glyphs: [GlyphRange(run: 0, first: 0, count: 1)],
            parts: [],
            writingMode: .verticalRightToLeft,
            factor: 1
        )

        // Then
        #expect(sut.isSideways)
        #expect(sut.horizontalScale == 0.5)
        #expect(carried.isSideways)
        #expect(carried.horizontalScale == 0.5)
    }
}
