//
//  CoreTextTypesetterTests.swift
//  FramesCoreTextTests
//
//  Created by JSilver on 11/22/26.
//

import FramesCoreText
import Testing

@testable import Frames

// CoreText's font matching can stop answering when many tasks ask it at once, so the tests run one at a time.
@Suite("CoreText Typesetter Tests", .serialized)
struct CoreTextTypesetterTests {
    // MARK: - Property
    private let shaper = CoreTextShaper()
    private let sut = Typesetter(shaper: CoreTextShaper())
    private let place = Place.root.appending(key: "title")

    // MARK: - Initializer
    // MARK: - Test
    @Test("an Arabic word is placed right to left with its letters joined, and `lam` with `alef` one group of glyphs")
    func setsArabicWord() throws {
        // Given
        let face = try #require(shaper.installedFaces(family: "Geeza Pro").first { $0.name == "GeezaPro" })
        let style = CharacterStyle(families: ["Geeza Pro"], weight: .regular, size: 48)
        let text = "\u{628}\u{644}\u{627}"
        let alone = try shape("\u{628}", face)
        let shaped = try shape(text, face)

        // When
        let layout = try sut.layout(
            [TextRun(text: text, style: style, faces: [face])],
            paragraph: ParagraphStyle(lineHeight: 60, background: nil, align: nil, lines: nil),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        // The provider gives `lam` `alef` as one glyph left of `beh`. The pen starts at the line's left end and moves
        // by their advances, `beh` owns its glyph, `lam` the ligature and `alef`, a later character of its group, none.
        let glyphs = layout.runs.flatMap(\.glyphs)
        #expect(layout.direction == .rtl)
        #expect(shaped.map(\.offset) == [1, 0])
        #expect(glyphs.map(\.id) == shaped.map(\.id))
        #expect(!alone.map(\.id).contains(glyphs[1].id))
        #expect(glyphs.map(\.x) == [0, shaped[0].advance])
        #expect(layout.lines.map(\.width) == [shaped[0].advance + shaped[1].advance])
        #expect(layout.lines.flatMap(\.clusters) == [
            cluster(1, 1, 0..<1, shaped[1].advance),
            cluster(0, 1, 1..<2, shaped[0].advance),
            cluster(1, 0, 2..<3, 0)
        ])
    }

    // MARK: - Private
    private func shape(
        _ text: String,
        _ face: FontFace
    ) throws -> [ShapedGlyph] {
        try shaper.shape(text, direction: .rtl, faces: [face], size: 48, features: [], weight: .regular, italic: false)
            .flatMap(\.glyphs)
    }

    private func cluster(
        _ first: Int,
        _ count: Int,
        _ range: Range<Int>,
        _ advance: Double
    ) -> PlacedCluster {
        PlacedCluster(glyphs: GlyphRange(run: 0, first: first, count: count), range: range, advance: advance, level: 1)
    }
}
