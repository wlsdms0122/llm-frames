//
//  TypesetterWritingModeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

// The fake shaper sets each scalar 0.5 em wide, and an upright one an em long, its face's ascent and descent, so at
// size 40 a character set as horizontal text or sideways is 20 long and an upright one 40. Its faces have an ascent of
// 0.8 em and a descent of 0.2 em, so at size 40 a vertical line's ascent and descent are 20 each, a sideways glyph lies
// 12 toward line-under of the baseline, on its alphabetic baseline, and an upright glyph is set from 32 down the line
// and 10 toward line-under of its pen.
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

    @Test("an upright text run of one character and the sideways text run after it in the same face keep their own glyph runs")
    func keepsUprightRunBeforeSidewaysRun() throws {
        // Given
        let runs = [run("漢", isHighlighted: true), run("ab", isUnderlined: true)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.source) == [0, 1])
        #expect(layout.runs.map(\.face) == [face, face])
        #expect(layout.runs.map(\.isSideways) == [false, true])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x61, 0x62]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [40, 60]])
        #expect(layout.runs.map { $0.glyphs.map(\.placementOffset) } == [
            [Point(x: -10, y: 32)],
            [Point(x: -12, y: 0), Point(x: -12, y: 0)]
        ])
        #expect(layout.runs.map(\.highlights) == [[Rectangle(x: 0, y: 0, width: 40, height: 40)], []])
        #expect(layout.runs.map(\.underlines) == [[], [UnderlinePiece(x: 8, y: 40, width: 40)]])
    }

    @Test("a sideways text run and the upright text run of one character after it in the same face keep their own glyph runs")
    func keepsSidewaysRunBeforeUprightRun() throws {
        // Given
        let runs = [run("ab", isUnderlined: true), run("漢", isHighlighted: true)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.source) == [0, 1])
        #expect(layout.runs.map(\.face) == [face, face])
        #expect(layout.runs.map(\.isSideways) == [true, false])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x61, 0x62], [0x6F22]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0, 20], [40]])
        #expect(layout.runs.map { $0.glyphs.map(\.placementOffset) } == [
            [Point(x: -12, y: 0), Point(x: -12, y: 0)],
            [Point(x: -10, y: 32)]
        ])
        #expect(layout.runs.map(\.highlights) == [[], [Rectangle(x: 0, y: 40, width: 40, height: 40)]])
        #expect(layout.runs.map(\.underlines) == [[UnderlinePiece(x: 8, y: 0, width: 40)], []])
    }

    @Test(
        "vertical lines stack from the block-start edge, each on its central baseline, and the text box turns",
        arguments: [
            (WritingMode.verticalRightToLeft, [70.0, 20.0]),
            (WritingMode.verticalLeftToRight, [20.0, 70.0])
        ]
    )
    func stacksVerticalLines(writingMode: WritingMode, baselines: [Double]) throws {
        // Given
        let runs = [run("漢A 字B")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(writingMode), width: 60, place: place, kind: "title")

        // Then
        // Each line is 60 long, its space hanging, and the lines lie 50 apart with 20 on each side of them.
        #expect(layout.lines.map(\.baseline) == baselines)
        #expect(layout.lines.map(\.width) == [60, 60])
        #expect(layout.size == Size(width: 90, height: 60))
        #expect(layout.textBox == Rectangle(x: 0, y: 0, width: 90, height: 60))
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x41, 0x20], [0x5B57], [0x42]])
        #expect(layout.runs.flatMap(\.glyphs).map { Point(x: $0.x, y: $0.y) } == [
            Point(x: baselines[0], y: 0),
            Point(x: baselines[0], y: 40),
            Point(x: baselines[0], y: 60),
            Point(x: baselines[1], y: 0),
            Point(x: baselines[1], y: 40)
        ])
        #expect(layout.runs.flatMap(\.glyphs).map(\.placementOffset) == [
            Point(x: -10, y: 32),
            Point(x: -12, y: 0),
            Point(x: -12, y: 0),
            Point(x: -10, y: 32),
            Point(x: -12, y: 0)
        ])
    }

    @Test(
        "a vertical line is placed by its `align` down the text box, `left` at the top and `right` at the bottom",
        arguments: [(TextAlignment.left, 0.0), (.center, 20.0), (.right, 40.0)]
    )
    func alignsDownTheLine(align: TextAlignment, start: Double) throws {
        // Given
        let runs = [run("漢A 字B")]
        let paragraph = ParagraphStyle(
            lineHeight: 50,
            background: nil,
            writingMode: .verticalRightToLeft,
            align: align,
            lines: nil
        )

        // When
        let layout = try sut.layout(runs, paragraph: paragraph, width: 100, place: place, kind: "title")

        // Then
        #expect(layout.textBox == Rectangle(x: 0, y: 0, width: 90, height: 100))
        #expect(layout.runs.map { $0.glyphs[0].y } == [start, start + 40, start, start + 40])
    }

    @Test("runs of different sizes on a vertical line share its central baseline, the largest extent setting its width")
    func centresRunsOfDifferentSizes() throws {
        // Given
        // At size 20 an upright glyph is 20 long and set from 16 down and 5 across, and a sideways one is 10 long and
        // lies 6 toward line-under, with 10 on each side of the baseline.
        let runs = [run("漢"), run("字A", size: 20, isHighlighted: true, isUnderlined: true)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.lines.map(\.baseline) == [20])
        #expect(layout.lines.map(\.ascent) == [20])
        #expect(layout.lines.map(\.descent) == [20])
        #expect(layout.size == Size(width: 40, height: 70))
        #expect(layout.runs.flatMap(\.glyphs).map { Point(x: $0.x, y: $0.y) } == [
            Point(x: 20, y: 0),
            Point(x: 20, y: 40),
            Point(x: 20, y: 60)
        ])
        #expect(layout.runs.flatMap(\.glyphs).map(\.placementOffset) == [
            Point(x: -10, y: 32),
            Point(x: -5, y: 16),
            Point(x: -6, y: 0)
        ])
        #expect(layout.runs[1].highlights == [Rectangle(x: 10, y: 40, width: 20, height: 30)])
        #expect(layout.runs[1].underlines == [UnderlinePiece(x: 14, y: 40, width: 30)])
    }

    @Test(
        "a unit's box runs down its characters and across its vertical line, and its parts down the line",
        arguments: [
            (WritingMode.verticalRightToLeft, [50.0, 50.0, 0.0, 0.0]),
            (WritingMode.verticalLeftToRight, [0.0, 0.0, 50.0, 50.0])
        ]
    )
    func boxesUnitsOfVerticalLines(writingMode: WritingMode, lefts: [Double]) throws {
        // Given
        let runs = [run("漢A 字B", isHighlighted: true)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(writingMode),
            width: 60,
            unit: .character,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.units?.map(\.glyphBox) == [
            Rectangle(x: lefts[0], y: 0, width: 40, height: 40),
            Rectangle(x: lefts[1], y: 40, width: 40, height: 20),
            Rectangle(x: lefts[2], y: 0, width: 40, height: 40),
            Rectangle(x: lefts[3], y: 40, width: 40, height: 20)
        ])
        #expect(layout.units?.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...40)],
            [UnitPart(run: 0, piece: 0, span: 40...60)],
            [UnitPart(run: 2, piece: 0, span: 0...40)],
            [UnitPart(run: 2, piece: 0, span: 40...60)]
        ])
        #expect(layout.runs.map(\.highlights) == [
            [Rectangle(x: lefts[0], y: 0, width: 40, height: 60)],
            [],
            [Rectangle(x: lefts[2], y: 0, width: 40, height: 60)],
            []
        ])
    }

    @Test("Hebrew in a vertical line is set sideways and placed from the bottom up, between ideographs set upright")
    func placesHebrewInVerticalLine() throws {
        // Given
        let runs = [run("漢\u{5D0}\u{5D1}字")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            unit: .character,
            place: place,
            kind: "title"
        )

        // Then
        let line = try #require(layout.lines.first)
        #expect(line.clusters.map(\.level) == [0, 1, 1, 0])
        #expect(line.placedOrder == [0, 2, 1, 3])
        #expect(layout.runs.map(\.isSideways) == [false, true, false])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x5D1, 0x5D0], [0x5B57]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [40, 60], [80]])
        #expect(layout.units?.map(\.glyphBox.y) == [0, 60, 40, 80])
        #expect(layout.units?.map(\.glyphBox.height) == [40, 20, 20, 40])
    }

    @Test("a background's first padding value pads a vertical text box on its block axis and its second down its lines")
    func padsVerticalTextBox() throws {
        // Given
        let runs = [run("漢A")]
        let background = TextBackground(color: Color(written: "#000000"), padding: Size(width: 12, height: 8), radius: 4)
        let paragraph = ParagraphStyle(
            lineHeight: 50,
            background: background,
            writingMode: .verticalRightToLeft,
            align: .left,
            lines: nil
        )

        // When
        let layout = try sut.layout(runs, paragraph: paragraph, width: nil, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 56, height: 84))
        #expect(layout.textBox == Rectangle(x: 8, y: 12, width: 40, height: 60))
        #expect(layout.lines.map(\.baseline) == [28])
        #expect(layout.runs.flatMap(\.glyphs).map(\.y) == [12, 52])
    }

    // MARK: - Private
    private func paragraph(_ writingMode: WritingMode) -> ParagraphStyle {
        ParagraphStyle(lineHeight: 50, background: nil, writingMode: writingMode, align: .left, lines: nil)
    }

    private func run(
        _ text: String,
        size: Double = 40,
        isHighlighted: Bool = false,
        isUnderlined: Bool = false
    ) -> TextRun {
        TextRun(
            text: text,
            style: CharacterStyle(
                families: ["Apple SD Gothic Neo"],
                weight: .bold,
                size: size,
                isHighlighted: isHighlighted,
                isUnderlined: isUnderlined
            ),
            faces: [face]
        )
    }
}
