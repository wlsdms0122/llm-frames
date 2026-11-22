//
//  TypesetterWritingModeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

// The fake shaper sets each scalar 0.5 em wide, and an upright one an em long, its face's ascent and descent, so at
// size 40 a character set as horizontal text or sideways is 20 long and an upright one 40.
@Suite("Typesetter Writing Mode Tests")
struct TypesetterWritingModeTests {
    // MARK: - Property
    private let sut = Typesetter(shaper: ShaperTable())
    private let face = ShaperTable.face("Apple SD Gothic Neo", .bold)
    private let place = Place.root.appending(key: "title")

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a vertical line is shaped in runs of one orientation, ideographs upright and Latin letters sideways",
        arguments: [WritingMode.verticalRightToLeft, .verticalLeftToRight]
    )
    func splitsByOrientation(writingMode: WritingMode) throws {
        // Given
        let runs = [run("漢A漢")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(writingMode), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.isSideways) == [false, true, false])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x41], [0x6F22]])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [40, 20, 40])
    }

    @Test("a horizontal line turns nothing, and its text is shaped in one run")
    func turnsNothingInHorizontalLine() throws {
        // Given
        let runs = [run("漢A漢")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.horizontalTopToBottom),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.isSideways) == [false])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [20, 20, 20])
    }

    @Test("a grapheme cluster takes the orientation of its first scalar, and one with an enclosing mark stands upright")
    func orientsClusters() throws {
        // Given
        let runs = [run("A\u{20DD}B\u{301}漢\u{301}")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.isSideways) == [false, true, false])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x41, 0x20DD], [0x42, 0x301], [0x6F22, 0x301]])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [80, 40, 80])
    }

    @Test("a glyph run is cut where the orientation changes, and the runs it is cut into keep their run's style")
    func cutsGlyphRunsByOrientation() throws {
        // Given
        let runs = [run("ab"), run("漢字c")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.source) == [0, 1, 1])
        #expect(layout.runs.map(\.isSideways) == [true, false, true])
        #expect(layout.runs.map(\.glyphs.count) == [2, 2, 1])
    }

    // MARK: - Private
    private func paragraph(_ writingMode: WritingMode) -> ParagraphStyle {
        ParagraphStyle(lineHeight: 50, background: nil, writingMode: writingMode, align: .left, lines: nil)
    }

    private func run(_ text: String) -> TextRun {
        TextRun(
            text: text,
            style: CharacterStyle(families: ["Apple SD Gothic Neo"], weight: .bold, size: 40),
            faces: [face]
        )
    }
}
