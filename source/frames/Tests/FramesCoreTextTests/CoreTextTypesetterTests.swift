//
//  CoreTextTypesetterTests.swift
//  FramesCoreTextTests
//
//  Created by JSilver on 11/22/26.
//

import CoreText
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

    @Test("a vertical line in Hiragino Sans stands ideographs on their vertical origins and turns Latin onto its alphabetic baseline")
    func setsVerticalLine() throws {
        // Given
        let face = try #require(shaper.installedFaces(family: "Hiragino Sans").first { $0.name == "HiraginoSans-W3" })
        let size = 100.0
        let font = CTFontCreateWithName(face.name as CFString, size, nil)
        let text = "漢字、「Hi」ー2026。"

        // When
        let layout = try sut.layout(
            [TextRun(text: text, style: CharacterStyle(families: ["Hiragino Sans"], weight: .regular, size: size), faces: [face])],
            paragraph: ParagraphStyle(lineHeight: 150, background: nil, writingMode: .verticalRightToLeft, align: .left, lines: nil),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        // FRAMES-5: each extent is half the face's ascent plus descent, the alphabetic baseline lies half its ascent
        // less its descent toward line-under, left, of the central baseline, and the line is as wide as the face is tall.
        let extent = (face.ascent + face.descent) * size / 2
        let alphabetic = (face.ascent - face.descent) * size / 2
        let glyphs = layout.runs.flatMap { run in run.glyphs.map { (glyph: $0, isSideways: run.isSideways) } }
        #expect(layout.runs.map(\.isSideways) == [false, true, false, true, false])
        #expect(glyphs.count == text.count)
        #expect(layout.lines.map(\.baseline) == [extent])
        #expect(layout.textBox.x == 0 && layout.textBox.y == 0)
        #expect(abs(layout.textBox.width - 2 * extent) < 1e-9)
        var pen = 0.0
        for (glyph, isSideways) in glyphs {
            var id = CGGlyph(glyph.id)
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, isSideways ? .horizontal : .vertical, &id, &advance, 1)
            #expect(glyph.x == extent, "glyph \(glyph.id)")
            #expect(abs(glyph.y - pen) < 1e-9, "glyph \(glyph.id) at \(glyph.y), not \(pen)")
            if isSideways {
                #expect(abs(glyph.placementOffset.x + alphabetic) < 1e-9, "glyph \(glyph.id)")
                #expect(glyph.placementOffset.y == 0, "glyph \(glyph.id)")
            } else {
                // Core Text gives the move from a glyph's horizontal origin to its vertical one, y up.
                var translation = CGSize.zero
                CTFontGetVerticalTranslationsForGlyphs(font, &id, &translation, 1)
                #expect(abs(glyph.placementOffset.x - translation.width) < 1e-9, "glyph \(glyph.id)")
                #expect(abs(glyph.placementOffset.y + translation.height) < 1e-9, "glyph \(glyph.id)")
            }
            pen += hypot(advance.width, advance.height)
        }
        #expect(abs(layout.textBox.height - pen) < 1e-9)
    }

    @Test("a vertical line of styled runs in Hiragino Sans keeps each run's orientation, advances and baselines at its boundaries")
    func setsVerticalLineOfStyledRuns() throws {
        // Given
        let faces = shaper.installedFaces(family: "Hiragino Sans")
        let regular = try #require(faces.first { $0.name == "HiraginoSans-W4" })
        let bold = try #require(faces.first { $0.name == "HiraginoSans-W7" })
        let body = CharacterStyle(families: ["Hiragino Sans"], weight: .regular, size: 64)
        let mark = CharacterStyle(families: ["Hiragino Sans"], weight: .regular, size: 64, isHighlighted: true)
        let line = CharacterStyle(families: ["Hiragino Sans"], weight: .regular, size: 64, isUnderlined: true)
        let big = CharacterStyle(families: ["Hiragino Sans"], weight: .bold, size: 112)
        let runs = [
            TextRun(text: "縦書きの", style: body, faces: [regular]),
            TextRun(text: "見出し", style: mark, faces: [regular]),
            TextRun(text: "と", style: body, faces: [regular]),
            TextRun(text: "Underline", style: line, faces: [regular]),
            TextRun(text: "、", style: body, faces: [regular]),
            TextRun(text: "大", style: big, faces: [bold]),
            TextRun(text: "きな", style: body, faces: [regular]),
            TextRun(text: "字。", style: body, faces: [regular])
        ]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: ParagraphStyle(lineHeight: 150, background: nil, writingMode: .verticalRightToLeft, align: .left, lines: nil),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        // Each text run is a glyph run of its own, `と` upright between the upright `見出し` and the sideways
        // `Underline` of the same face. The line's baseline lies the largest extent, `大`'s, inside the text box, and
        // every glyph is placed by its own face at its own size: the pen moves by Core Text's vertical advance of an
        // upright glyph and horizontal advance of a sideways one, an upright glyph is set from its vertical origin and
        // a sideways one from its face's alphabetic baseline.
        let baseline = (bold.ascent + bold.descent) * 112 / 2
        #expect(layout.runs.map(\.source) == Array(runs.indices))
        #expect(layout.runs.map(\.isSideways) == [false, false, false, true, false, false, false, false])
        #expect(layout.runs.map(\.glyphs.count) == runs.map(\.text.count))
        #expect(layout.lines.count == 1)
        #expect(abs((layout.lines.first?.baseline ?? 0) - baseline) < 1e-9)
        var pen = 0.0
        var starts: [Double] = []
        for run in layout.runs {
            let font = CTFontCreateWithName(run.face.name as CFString, run.size, nil)
            let alphabetic = (run.face.ascent - run.face.descent) * run.size / 2
            starts.append(pen)
            for glyph in run.glyphs {
                var id = CGGlyph(glyph.id)
                var advance = CGSize.zero
                CTFontGetAdvancesForGlyphs(font, run.isSideways ? .horizontal : .vertical, &id, &advance, 1)
                #expect(abs(glyph.x - baseline) < 1e-9, "glyph \(glyph.id)")
                #expect(abs(glyph.y - pen) < 1e-9, "glyph \(glyph.id) at \(glyph.y), not \(pen)")
                if run.isSideways {
                    #expect(abs(glyph.placementOffset.x + alphabetic) < 1e-9, "glyph \(glyph.id)")
                    #expect(glyph.placementOffset.y == 0, "glyph \(glyph.id)")
                } else {
                    var translation = CGSize.zero
                    CTFontGetVerticalTranslationsForGlyphs(font, &id, &translation, 1)
                    #expect(abs(glyph.placementOffset.x - translation.width) < 1e-9, "glyph \(glyph.id)")
                    #expect(abs(glyph.placementOffset.y + translation.height) < 1e-9, "glyph \(glyph.id)")
                }
                pen += hypot(advance.width, advance.height)
            }
        }
        // The highlight of `見出し` and the underline of `Underline` read their own run's face at size 64.
        let extent = (regular.ascent + regular.descent) * 64 / 2
        let alphabetic = (regular.ascent - regular.descent) * 64 / 2
        let highlight = try #require(layout.runs[1].highlights.first)
        let underline = try #require(layout.runs[3].underlines.first)
        #expect(layout.runs.map(\.highlights.count) == [0, 1, 0, 0, 0, 0, 0, 0])
        #expect(layout.runs.map(\.underlines.count) == [0, 0, 0, 1, 0, 0, 0, 0])
        #expect(abs(highlight.x - (baseline - extent)) < 1e-9)
        #expect(abs(highlight.width - 2 * extent) < 1e-9)
        #expect(abs(highlight.y - starts[1]) < 1e-9)
        #expect(abs(highlight.maxY - starts[2]) < 1e-9)
        #expect(abs(underline.x - (baseline - alphabetic)) < 1e-9)
        #expect(abs(underline.y - starts[3]) < 1e-9)
        #expect(abs(underline.width - (starts[4] - starts[3])) < 1e-9)
    }

    @Test("an upright Latin run in Hiragino Sans stands letter under letter in its horizontal forms, each on its vertical origin at the line's baseline")
    func setsUprightLatinRun() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let font = CTFontCreateWithName(face.name as CFString, size, nil)
        let runs = [
            TextRun(text: "日本の", style: style(size), faces: [face]),
            TextRun(text: "NHK", style: style(size, textOrientation: .upright), faces: [face]),
            TextRun(text: "放送", style: style(size), faces: [face])
        ]
        let letters = try shaper.shape("NHK", direction: .ltr, upright: false, faces: [face], size: size, features: [], weight: .regular, italic: false)
            .flatMap(\.glyphs)

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        // FRAMES-5: an upright glyph is set with its vertical origin at the pen, so it stands centred on the line, and
        // the pen moves by its vertical advance.
        let extent = (face.ascent + face.descent) * size / 2
        let upright = try #require(layout.runs.first { $0.source == 1 })
        let clusters = try #require(layout.lines.first?.clusters)
        #expect(layout.runs.map(\.isSideways) == [false, false, false])
        #expect(upright.glyphs.map(\.id) == letters.map(\.id))
        for (index, glyph) in upright.glyphs.enumerated() {
            var id = CGGlyph(glyph.id)
            var advance = CGSize.zero
            var horizontal = CGSize.zero
            var translation = CGSize.zero
            var ink = CGRect.zero
            CTFontGetAdvancesForGlyphs(font, .vertical, &id, &advance, 1)
            CTFontGetAdvancesForGlyphs(font, .horizontal, &id, &horizontal, 1)
            CTFontGetVerticalTranslationsForGlyphs(font, &id, &translation, 1)
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, &id, &ink, 1)
            let cluster = clusters[3 + index]
            #expect(glyph.x == extent, "glyph \(glyph.id)")
            #expect(abs(glyph.y - (3 * size + clusters[3..<(3 + index)].map(\.advance).reduce(0, +))) < 1e-9)
            #expect(abs(cluster.advance - hypot(advance.width, advance.height)) < 1e-9, "glyph \(glyph.id)")
            #expect(abs(glyph.placementOffset.x - translation.width) < 1e-9, "glyph \(glyph.id)")
            #expect(abs(glyph.placementOffset.y + translation.height) < 1e-9, "glyph \(glyph.id)")
            // Core Text takes half the horizontal advance in whole font units, so the advance is centred on the line
            // to within half a unit, and the ink as the letter's side bearings place it.
            #expect(abs(glyph.placementOffset.x + horizontal.width / 2) < 0.001 * size, "glyph \(glyph.id)")
            #expect(ink.height > ink.width, "glyph \(glyph.id) is \(ink.size), not standing")
        }
    }

    @Test("an upright Latin run in Helvetica Neue, which has no vmtx, stands in its horizontal forms in the metrics made from its ascent and descent")
    func setsUprightLatinRunWithoutVerticalMetrics() throws {
        // Given
        let face = try #require(shaper.installedFaces(family: "Helvetica Neue").first { $0.name == "HelveticaNeue" })
        let size = 100.0
        let font = CTFontCreateWithName(face.name as CFString, size, nil)
        let style = CharacterStyle(families: ["Helvetica Neue"], weight: .regular, size: size, textOrientation: .upright)
        let runs = [TextRun(text: "NHK12", style: style, faces: [face])]
        let letters = try shaper.shape("NHK12", direction: .ltr, upright: false, faces: [face], size: size, features: [], weight: .regular, italic: false)
            .flatMap(\.glyphs)

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        // FRAMES-5: in a face without `vmtx` an upright glyph advances by its face's ascent plus its descent, and its
        // vertical origin lies its ascent above its horizontal origin and half its horizontal advance across.
        let glyphs = try #require(layout.runs.first?.glyphs)
        let clusters = try #require(layout.lines.first?.clusters)
        #expect(layout.runs.map(\.isSideways) == [false])
        #expect(glyphs.map(\.id) == letters.map(\.id))
        #expect(clusters.allSatisfy { abs($0.advance - (face.ascent + face.descent) * size) < 1e-9 })
        for glyph in glyphs {
            var id = CGGlyph(glyph.id)
            var advance = CGSize.zero
            var ink = CGRect.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &id, &advance, 1)
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, &id, &ink, 1)
            #expect(abs(glyph.placementOffset.x + advance.width / 2) < 1e-9, "glyph \(glyph.id)")
            #expect(abs(glyph.placementOffset.y - face.ascent * size) < 1e-9, "glyph \(glyph.id)")
            #expect(ink.height > ink.width, "glyph \(glyph.id) is \(ink.size), not standing")
        }
    }

    @Test("an upright run of kana, an ideographic comma and Latin in Hiragino Sans keeps the comma's vertical form and stands `fi` as two letters")
    func setsUprightRunOfKanaCommaAndLatin() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let runs = [TextRun(text: "あ、fi", style: style(size, textOrientation: .upright), faces: [face])]
        let horizontal = try shaper.shape("あ、fi", direction: .ltr, upright: false, faces: [face], size: size, features: [FontFeature(tag: "liga", value: 0)], weight: .regular, italic: false)
            .flatMap(\.glyphs)
        let verticalForms = try shaper.shape("あ、", direction: .ltr, upright: true, faces: [face], size: size, features: [], weight: .regular, italic: false)
            .flatMap(\.glyphs)

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        // `、` is Tu and is set in Hiragino's vertical form of it, and `f` and `i`, both R, in their own horizontal
        // glyphs, though Hiragino ligates them in horizontal text.
        let ids = layout.runs.flatMap { $0.glyphs.map(\.id) }
        #expect(layout.runs.allSatisfy { !$0.isSideways })
        #expect(verticalForms[1].id != horizontal[1].id)
        #expect(ids == verticalForms.map(\.id) + horizontal[2...].map(\.id))
        #expect(layout.lines.first?.clusters.count == 4)
    }

    @Test("an upright Hebrew run in a vertical right-to-left title is placed from the top down in the order it is read")
    func readsUprightHebrewTopDown() throws {
        // Given
        let face = try hiraginoSans()
        let text = "\u{5E9}\u{5DC}\u{5D5}\u{5DD}"
        let paragraph = vertical(direction: .rtl)
        let upright = [
            TextRun(text: "語", style: style(100), faces: [face]),
            TextRun(text: text, style: style(100, textOrientation: .upright), faces: [face]),
            TextRun(text: "だ", style: style(100), faces: [face])
        ]
        let mixed = [TextRun(text: "語" + text + "だ", style: style(100), faces: [face])]

        // When
        let layout = try sut.layout(upright, paragraph: paragraph, width: nil, place: place, kind: "title")
        let mixedLayout = try sut.layout(mixed, paragraph: paragraph, width: nil, place: place, kind: "title")

        // Then
        // Read as L, the Hebrew letters lie at the even level of the ideographs around them, so they are placed in
        // the order they are read, from the top down. Under `mixed` they keep class R, lie at level 1 and are placed
        // from the bottom up.
        let hebrew = 1..<5
        let clusters = try #require(layout.lines.first?.clusters)
        let mixedClusters = try #require(mixedLayout.lines.first?.clusters)
        let starts = clusters[hebrew].map { verticalStart(of: $0, in: layout) }
        let mixedStarts = mixedClusters[hebrew].map { verticalStart(of: $0, in: mixedLayout) }
        #expect(layout.direction == .rtl)
        #expect(clusters.map(\.level) == [2, 2, 2, 2, 2, 2])
        #expect(starts == starts.sorted() && Set(starts).count == 4)
        #expect(layout.runs.filter { $0.source == 1 }.allSatisfy { !$0.isSideways && $0.face != face })
        #expect(mixedClusters[hebrew].map(\.level) == [1, 1, 1, 1])
        #expect(mixedStarts == mixedStarts.sorted(by: >))
    }

    @Test("an upright Arabic run in a vertical line stands each letter in its isolated form, where a sideways one joins them")
    func setsUprightArabicInIsolatedForms() throws {
        // Given
        let face = try hiraginoSans()
        let letter = "\u{628}"
        let text = letter + letter + letter
        let paragraph = vertical()

        // When
        let upright = try sut.layout(
            [TextRun(text: text, style: style(100, textOrientation: .upright), faces: [face])],
            paragraph: paragraph,
            width: nil,
            place: place,
            kind: "title"
        )
        let isolated = try sut.layout(
            [TextRun(text: letter, style: style(100, textOrientation: .upright), faces: [face])],
            paragraph: paragraph,
            width: nil,
            place: place,
            kind: "title"
        )
        let sideways = try sut.layout(
            [TextRun(text: text, style: style(100), faces: [face])],
            paragraph: paragraph,
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        let form = try #require(isolated.runs.first?.glyphs.first?.id)
        #expect(isolated.runs.flatMap(\.glyphs).count == 1)
        #expect(upright.runs.flatMap(\.glyphs).map(\.id) == [form, form, form])
        #expect(upright.runs.allSatisfy { !$0.isSideways })
        #expect(Set(sideways.runs.flatMap(\.glyphs).map(\.id)).count == 3)
        #expect(!sideways.runs.flatMap(\.glyphs).map(\.id).contains(form))
    }

    @Test("a sideways run of ideographs in Hiragino Sans is turned onto its alphabetic baseline and advances by its horizontal advances")
    func setsSidewaysIdeographs() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let font = CTFontCreateWithName(face.name as CFString, size, nil)
        let runs = [
            TextRun(text: "これは", style: style(size), faces: [face]),
            TextRun(text: "横倒し", style: style(size, textOrientation: .sideways), faces: [face]),
            TextRun(text: "の字", style: style(size), faces: [face])
        ]

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        let alphabetic = (face.ascent - face.descent) * size / 2
        let sideways = try #require(layout.runs.first { $0.source == 1 })
        let clusters = try #require(layout.lines.first?.clusters)
        #expect(layout.runs.map(\.isSideways) == [false, true, false])
        #expect(sideways.glyphs.count == 3)
        for (index, glyph) in sideways.glyphs.enumerated() {
            var id = CGGlyph(glyph.id)
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &id, &advance, 1)
            #expect(abs(glyph.placementOffset.x + alphabetic) < 1e-9, "glyph \(glyph.id)")
            #expect(glyph.placementOffset.y == 0, "glyph \(glyph.id)")
            #expect(abs(clusters[3 + index].advance - advance.width) < 1e-9, "glyph \(glyph.id)")
        }
    }

    @Test("a composition `12` of half-width forms in Hiragino Sans is one glyph box of 1 em, unturned and unnarrowed, centred in its square")
    func setsCompositionInSquare() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let halfWidth = [FontFeature(tag: "hwid", value: 1)]
        let runs = [
            TextRun(text: "第", style: style(size), faces: [face]),
            TextRun(text: "12", style: style(size, textCombineUpright: .all, features: halfWidth), faces: [face]),
            TextRun(text: "回", style: style(size), faces: [face])
        ]
        let shaped = try shaper.shape("12", direction: .ltr, upright: false, faces: [face], size: size, features: halfWidth, weight: .regular, italic: false)
            .flatMap(\.glyphs)

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        // FRAMES-5: the half-width forms fill 1 em, so they are not narrowed. Both glyphs lie at the square's pen, the
        // text centred across the line from its left end and its alphabetic baseline half the face's ascent less its
        // descent past the middle of the square.
        let extent = (face.ascent + face.descent) * size / 2
        let alphabetic = (face.ascent - face.descent) * size / 2
        let composition = try #require(layout.runs.first { $0.source == 1 })
        let clusters = try #require(layout.lines.first?.clusters)
        #expect(abs(shaped.map(\.advance).reduce(0, +) - size) < 1e-9)
        #expect(layout.runs.map(\.isSideways) == [false, false, false])
        #expect(composition.horizontalScale == 1)
        #expect(composition.glyphs.map(\.id) == shaped.map(\.id))
        #expect(composition.glyphs.map(\.x) == [extent, extent])
        #expect(composition.glyphs.map(\.y) == [size, size])
        #expect(composition.glyphs.map(\.placementOffset.y).allSatisfy { abs($0 - (size / 2 + alphabetic)) < 1e-9 })
        #expect(abs(composition.glyphs[0].placementOffset.x + size / 2) < 1e-9)
        #expect(abs(composition.glyphs[1].placementOffset.x - (shaped[0].advance - size / 2)) < 1e-9)
        #expect(clusters.map(\.glyphs.count) == [1, 2, 0, 1])
        #expect(clusters.map(\.advance) == [size, size, 0, size])
        #expect(clusters[2].glyphs.run == clusters[1].glyphs.run)
        #expect(layout.lines.map(\.width) == [3 * size])
    }

    @Test("a composition `2026` in Hiragino Sans is narrowed by 1 em over its shaped width, its ink inside its square")
    func narrowsWideComposition() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let font = CTFontCreateWithName(face.name as CFString, size, nil)
        let runs = [
            TextRun(text: "西暦", style: style(size), faces: [face]),
            TextRun(text: "2026", style: style(size, textCombineUpright: .all), faces: [face]),
            TextRun(text: "年", style: style(size), faces: [face])
        ]
        let shaped = try shaper.shape("2026", direction: .ltr, upright: false, faces: [face], size: size, features: [], weight: .regular, italic: false)
            .flatMap(\.glyphs)

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        // A glyph is drawn from its pen plus its placement offset, narrowed across the line about that origin, and
        // its outline rises toward the top of the page, so its ink lies across from its origin by its outline's
        // horizontal extent narrowed, and along the line above its origin by its outline's vertical extent.
        let width = shaped.map(\.advance).reduce(0, +)
        let scale = size / width
        let extent = (face.ascent + face.descent) * size / 2
        let composition = try #require(layout.runs.first { $0.source == 1 })
        let pen = 2 * size
        #expect(width > size)
        #expect(composition.isSideways == false)
        #expect(abs(composition.horizontalScale - scale) < 1e-12)
        #expect(composition.glyphs.map(\.y) == [pen, pen, pen, pen])
        for glyph in composition.glyphs {
            var id = CGGlyph(glyph.id)
            var ink = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, &id, &ink, 1)
            let origin = Point(x: glyph.x + glyph.placementOffset.x, y: glyph.y + glyph.placementOffset.y)
            #expect(origin.x + ink.minX * scale >= extent - size / 2, "glyph \(glyph.id)")
            #expect(origin.x + ink.maxX * scale <= extent + size / 2, "glyph \(glyph.id)")
            #expect(origin.y - ink.maxY >= pen, "glyph \(glyph.id)")
            #expect(origin.y - ink.minY <= pen + size, "glyph \(glyph.id)")
        }
    }

    @Test("a combined run `12\\n34` is a composition on each of its two lines, and two neighbouring combined runs are two")
    func composesEachLineAndEachRun() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let combined = style(size, textCombineUpright: .all)
        let broken = [TextRun(text: "12\n34", style: combined, faces: [face])]
        let neighbouring = [TextRun(text: "12", style: combined, faces: [face]), TextRun(text: "34", style: combined, faces: [face])]

        // When
        let brokenLayout = try sut.layout(broken, paragraph: vertical(), width: nil, place: place, kind: "title")
        let neighbouringLayout = try sut.layout(neighbouring, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        let brokenGroups = brokenLayout.lines.map { line in line.clusters.filter { $0.glyphs.count > 0 }.map(\.glyphs.count) }
        let neighbouringLine = try #require(neighbouringLayout.lines.first)
        let compositions = neighbouringLine.clusters.filter { $0.glyphs.count > 0 }
        #expect(brokenGroups == [[2], [2]])
        #expect(brokenLayout.lines.map(\.width) == [size, size])
        #expect(brokenLayout.runs.map(\.glyphs.count) == [2, 2])
        #expect(neighbouringLayout.lines.count == 1)
        #expect(compositions.map(\.glyphs.count) == [2, 2])
        #expect(compositions.map { verticalStart(of: $0, in: neighbouringLayout) } == [0, size])
        #expect(neighbouringLine.width == 2 * size)
    }

    @Test("a composition whose second character Hiragino Sans lacks is one group across a glyph run of each face, at one pen")
    func setsCompositionInTwoFaces() throws {
        // Given
        let face = try hiraginoSans()
        let size = 100.0
        let runs = [
            TextRun(text: "第", style: style(size), faces: [face]),
            TextRun(text: "1\u{E52}", style: style(size, textCombineUpright: .all), faces: [face]),
            TextRun(text: "回", style: style(size), faces: [face])
        ]

        // When
        let layout = try sut.layout(runs, paragraph: vertical(), width: nil, place: place, kind: "title")

        // Then
        // The Thai digit two falls back to another face, so the composition's glyphs lie in a run of each face, and
        // the composition's group names them as one range from the first run on into the next.
        let clusters = try #require(layout.lines.first?.clusters)
        let composition = layout.runs.filter { $0.source == 1 }
        #expect(composition.count == 2)
        #expect(composition[0].face == face && composition[1].face != face)
        #expect(composition.map(\.horizontalScale) == [composition[0].horizontalScale, composition[0].horizontalScale])
        #expect(composition.flatMap { $0.glyphs.map(\.y) } == [size, size])
        #expect(clusters.map(\.glyphs.count) == [1, 2, 0, 1])
        #expect(clusters[1].glyphs.ranges(within: layout.runs.map(\.glyphs.count)).map(\.count) == [1, 1])
        #expect(clusters.map(\.advance) == [size, size, 0, size])
    }

    @Test("text orientation and text combine upright change nothing in a horizontal line")
    func ignoresVerticalAttributesInHorizontalLine() throws {
        // Given
        let face = try hiraginoSans()
        let texts = ["日本の", "NHK", "は", "12", "月", "横"]
        let styles = [
            style(64),
            style(64, textOrientation: .upright),
            style(64),
            style(64, textCombineUpright: .all),
            style(64),
            style(64, textOrientation: .sideways)
        ]
        let paragraph = ParagraphStyle(lineHeight: 90, background: nil, align: .left, lines: nil)

        // When
        let layout = try sut.layout(
            zip(texts, styles).map { TextRun(text: $0, style: $1, faces: [face]) },
            paragraph: paragraph,
            width: nil,
            place: place,
            kind: "title"
        )
        let plain = try sut.layout(
            texts.map { TextRun(text: $0, style: style(64), faces: [face]) },
            paragraph: paragraph,
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout == plain)
        #expect(layout.runs.allSatisfy { !$0.isSideways && $0.horizontalScale == 1 })
    }

    // MARK: - Private
    // Where a cluster's glyph box starts on its line: the pen at its first glyph.
    private func start(
        of cluster: PlacedCluster,
        in layout: TextLayout
    ) -> Double {
        layout.runs[cluster.glyphs.run].glyphs[cluster.glyphs.first].x
    }

    // Where a cluster's glyph box starts down a vertical line: the pen at its first glyph.
    private func verticalStart(
        of cluster: PlacedCluster,
        in layout: TextLayout
    ) -> Double {
        layout.runs[cluster.glyphs.run].glyphs[cluster.glyphs.first].y
    }

    private func hiraginoSans() throws -> FontFace {
        try #require(shaper.installedFaces(family: "Hiragino Sans").first { $0.name == "HiraginoSans-W4" })
    }

    private func style(
        _ size: Double,
        textOrientation: TextOrientation = .mixed,
        textCombineUpright: TextCombineUpright = .none,
        features: [FontFeature] = []
    ) -> CharacterStyle {
        CharacterStyle(
            families: ["Hiragino Sans"],
            weight: .regular,
            size: size,
            features: features,
            textOrientation: textOrientation,
            textCombineUpright: textCombineUpright
        )
    }

    private func vertical(direction: TextDirection? = nil) -> ParagraphStyle {
        ParagraphStyle(
            lineHeight: 150,
            background: nil,
            writingMode: .verticalRightToLeft,
            direction: direction,
            align: .left,
            lines: nil
        )
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
