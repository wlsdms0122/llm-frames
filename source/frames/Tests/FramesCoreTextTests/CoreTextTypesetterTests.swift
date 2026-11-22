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

    @Test("a tracked Arabic word keeps its glyphs advance to advance and its width, and a Latin word beside it tracks")
    func keepsTrackedArabicWordJoined() throws {
        // Given
        let face = try #require(shaper.installedFaces(family: "Geeza Pro").first { $0.name == "GeezaPro" })
        let style = CharacterStyle(families: ["Geeza Pro"], weight: .regular, size: 48, tracking: 200)
        let word = "\u{645}\u{631}\u{62D}\u{628}\u{627}"
        let optionalLigaturesOff = ["liga", "clig", "dlig"].map { FontFeature(tag: $0, value: 0) }
        let shaped = try shaper.shape(
            word,
            direction: .rtl,
            upright: false,
            faces: [face],
            size: 48,
            features: optionalLigaturesOff,
            weight: .regular,
            italic: false
        )
        .flatMap(\.glyphs)

        // When
        let layout = try sut.layout(
            [TextRun(text: "Apple " + word, style: style, faces: [face])],
            paragraph: ParagraphStyle(lineHeight: 60, background: nil, align: nil, lines: nil),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        // The paragraph is left to right from `A`, and the line is placed `Apple`, the space and the Arabic word. A
        // tracking of 200 at size 48 puts 9.6 between the Latin letters, after `e` and after the space, and none
        // between the Arabic letters, so each Arabic letter starts where the one on its left ends, the word is as wide
        // as its glyphs shaped alone with the optional ligatures off, as a tracked run shapes them, and the line is its advances and six gaps wide.
        let tracking = 9.6
        let line = try #require(layout.lines.first)
        let latin = line.clusters.prefix(6)
        let arabic = line.clusters.dropFirst(6).filter { $0.glyphs.count > 0 }
            .sorted { start(of: $0, in: layout) < start(of: $1, in: layout) }
        let arabicWidth = arabic.map(\.advance).reduce(0, +)
        let shapedWidth = shaped.map(\.advance).reduce(0, +)
        let latinGaps = zip(latin, latin.dropFirst()).map { gap(between: $0, and: $1, in: layout) }
        let arabicGaps = zip(arabic, arabic.dropFirst()).map { gap(between: $0, and: $1, in: layout) }
        let spaceGap = gap(between: latin[5], and: arabic[0], in: layout)
        let scripts: [[String]] = Array(repeating: [], count: 6) + Array(repeating: ["Arab"], count: 5)
        #expect(line.clusters.map(\.cursiveScripts) == scripts)
        #expect(latinGaps.allSatisfy { abs($0 - tracking) < 1e-9 })
        #expect(arabicGaps.allSatisfy { abs($0) < 1e-9 })
        #expect(abs(spaceGap - tracking) < 1e-9)
        #expect(abs(arabicWidth - shapedWidth) < 1e-9)
        #expect(abs(line.width - line.clusters.map(\.advance).reduce(0, +) - 6 * tracking) < 1e-9)
    }

    @Test("a comma and the space after it in Hebrew text set in a fallback face are each a group, the comma beside its word")
    func placesCommaAndSpaceInHebrew() throws {
        // Given
        let face = try #require(shaper.installedFaces(family: "Helvetica Neue").first { $0.name == "HelveticaNeue" })
        let style = CharacterStyle(families: ["Helvetica Neue"], weight: .regular, size: 36)
        let text = "\u{5E7}\u{5D1}\u{5D5}\u{5E2}, \u{5DB}\u{5D3}\u{5D9}"

        // When
        let layout = try sut.layout(
            [TextRun(text: text, style: style, faces: [face])],
            paragraph: ParagraphStyle(lineHeight: 44, background: nil, align: nil, lines: nil),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        // Every character lies at level 1, the comma and the space by rule N1 between two Hebrew letters, so L2 places
        // `כ`, the space, the comma and `ע` from left to right side by side. The letters are set in a face found on the
        // machine and the comma and the space in Helvetica Neue, each with a glyph of its own, and no glyph is placed
        // against another, so each is drawn in its box.
        let clusters = layout.lines.flatMap(\.clusters)
        let ayin = try #require(clusters.first { $0.range == 3..<4 })
        let comma = try #require(clusters.first { $0.range == 4..<5 })
        let space = try #require(clusters.first { $0.range == 5..<6 })
        let kaf = try #require(clusters.first { $0.range == 6..<7 })
        #expect(clusters.allSatisfy { $0.level == 1 })
        try #require([ayin, comma, space, kaf].allSatisfy { $0.glyphs.count == 1 })
        #expect([comma, space].allSatisfy { layout.runs[$0.glyphs.run].face == face })
        #expect(comma.glyphs != space.glyphs)
        #expect(start(of: kaf, in: layout) + kaf.advance == start(of: space, in: layout))
        #expect(start(of: space, in: layout) + space.advance == start(of: comma, in: layout))
        #expect(start(of: comma, in: layout) + comma.advance == start(of: ayin, in: layout))
        #expect(layout.runs.flatMap(\.glyphs).allSatisfy { $0.placementOffset == Point(x: 0, y: 0) })
    }

    // MARK: - Private
    // Where a cluster's glyph box starts on its line: the pen at its first glyph.
    private func start(
        of cluster: PlacedCluster,
        in layout: TextLayout
    ) -> Double {
        layout.runs[cluster.glyphs.run].glyphs[cluster.glyphs.first].x
    }

    // The space between where `left`'s glyph box ends and `right`'s starts.
    private func gap(
        between left: PlacedCluster,
        and right: PlacedCluster,
        in layout: TextLayout
    ) -> Double {
        start(of: right, in: layout) - start(of: left, in: layout) - left.advance
    }

    private func shape(
        _ text: String,
        _ face: FontFace
    ) throws -> [ShapedGlyph] {
        try shaper.shape(
            text,
            direction: .rtl,
            upright: false,
            faces: [face],
            size: 48,
            features: [],
            weight: .regular,
            italic: false
        )
        .flatMap(\.glyphs)
    }

    private func cluster(
        _ first: Int,
        _ count: Int,
        _ range: Range<Int>,
        _ advance: Double
    ) -> PlacedCluster {
        PlacedCluster(
            glyphs: GlyphRange(run: 0, first: first, count: count),
            range: range,
            advance: advance,
            level: 1,
            cursiveScripts: ["Arab"]
        )
    }
}
