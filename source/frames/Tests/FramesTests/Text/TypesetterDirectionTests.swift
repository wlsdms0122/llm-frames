//
//  TypesetterDirectionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

@testable import Frames

// The fake shaper sets each scalar 0.5 em wide and a space 0.25 em, so at size 40 a letter is 20 wide and a space 10,
// and it sets a right-to-left run's glyphs from right to left, a bracket in its mirrored glyph.
@Suite("Typesetter Direction Tests")
struct TypesetterDirectionTests {
    // MARK: - Property
    private let sut = Typesetter(shaper: ShaperTable())
    private let face = ShaperTable.face("Apple SD Gothic Neo", .bold)
    private let place = Place.root.appending(key: "title")

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "`auto` takes the direction of the first paragraph that holds a strong character, and left to right without one",
        arguments: [
            ("אב c", TextDirection.rtl),
            ("c אב", .ltr),
            ("123\nאב c", .rtl),
            ("(123)", .ltr),
            ("\u{2067}a\u{2069}אב", .rtl)
        ]
    )
    func choosesDirectionByText(text: String, direction: TextDirection) throws {
        // Given
        let runs = [run(text)]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.direction == direction)
    }

    @Test("a `direction` written lays the text out in it whatever the text holds")
    func forcesDirection() throws {
        // Given
        let hebrew = [run("אב")]
        let latin = [run("ab")]

        // When
        let ltr = try sut.layout(hebrew, paragraph: paragraph(direction: .ltr), width: nil, place: place, kind: "title")
        let rtl = try sut.layout(latin, paragraph: paragraph(direction: .rtl), width: nil, place: place, kind: "title")

        // Then
        #expect(ltr.direction == .ltr)
        #expect(ltr.align == .left)
        #expect(rtl.direction == .rtl)
        #expect(rtl.align == .right)
    }

    @Test("a line with no `align` sits on the side its direction starts from, and one written keeps its side")
    func alignsOnStartSide() throws {
        // Given
        let runs = [run("ab")]

        // When
        let start = try sut.layout(runs, paragraph: paragraph(direction: .rtl), width: 100, place: place, kind: "title")
        let left = try sut.layout(
            runs,
            paragraph: paragraph(direction: .rtl, align: .left),
            width: 100,
            place: place,
            kind: "title"
        )

        // Then
        #expect(start.runs.map { $0.glyphs.map(\.x) } == [[60, 80]])
        #expect(left.align == .left)
        #expect(left.runs.map { $0.glyphs.map(\.x) } == [[0, 20]])
    }

    @Test("a right-to-left line is placed from its last character on the left to its first on the right")
    func placesHebrewLine() throws {
        // Given
        let runs = [run("אבג")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        // L2 reverses the line, so ג lies at 0, ב at 20 and א at 40, each 20 wide.
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0, 20, 40]])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("גבא")])
        #expect(layout.lines == [
            PlacedLine(
                width: 60,
                baseline: 32,
                ascent: 32,
                descent: 8,
                range: 0..<3,
                clusters: [
                    cluster(0, 2, 1, 0..<1, 20, level: 1),
                    cluster(0, 1, 1, 1..<2, 20, level: 1),
                    cluster(0, 0, 1, 2..<3, 20, level: 1)
                ],
                hanging: []
            )
        ])
    }

    @Test("a number in right-to-left text lies at the level above it and reads left to right inside it")
    func keepsNumberLeftToRight() throws {
        // Given
        let runs = [run("אב 12 גד")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        // The digits are EN, at level 2 by I2, and the spaces between R and EN are R by N1, at level 1. L2 gives
        // ד ג space 1 2 space ב א from left to right, letters and digits 20 wide and spaces 10.
        #expect(layout.lines.flatMap(\.clusters).map(\.level) == [1, 1, 1, 2, 2, 1, 1, 1])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0, 20, 40, 50, 70, 90, 100, 120]])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("דג 12 בא")])
        #expect(layout.lines.map(\.width) == [140])
    }

    @Test("a bracket at an odd level is set in its mirrored glyph, so it opens towards the text it encloses")
    func mirrorsBrackets() throws {
        // Given
        let runs = [run("א(ב)")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        // N0 sets the pair, which encloses R, at level 1, so L2 places `)` leftmost, set in the glyph of `(`.
        #expect(layout.lines.flatMap(\.clusters).map(\.level) == [1, 1, 1, 1])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0, 20, 40, 60]])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("(ב)א")])
    }

    @Test("the spaces ending a right-to-left line are set at its level by L1 and hang past its left edge untracked")
    func hangsSpacesOnTheLeft() throws {
        // Given
        let runs = [run("ab cd", style: character(tracking: 100))]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(direction: .rtl),
            width: 50,
            place: place,
            kind: "title"
        )

        // Then
        // Each line is 20 + 4 + 20 = 44 wide and starts at 50 - 44 = 6. The space after `ab` lies at level 2 between
        // two L, and L1 sets it at level 1, so it comes first as placed and ends at 6 untracked.
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[-4, 6, 30], [6, 30]])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids(" ab"), ids("cd")])
        #expect(layout.lines.first == PlacedLine(
            width: 44,
            baseline: 32,
            ascent: 32,
            descent: 8,
            range: 0..<2,
            clusters: [cluster(0, 1, 1, 0..<1, 20, level: 2), cluster(0, 2, 1, 1..<2, 20, level: 2)],
            hanging: [cluster(0, 0, 1, 2..<3, 10, level: 1)]
        ))
    }

    @Test("the spaces of a line with no character hang from its start towards the side the paragraph ends on")
    func hangsSpacesOfEmptyLine() throws {
        // Given
        let latin = [run("ab\n  ")]
        let hebrew = [run("אב\n  ")]

        // When
        let ltr = try sut.layout(latin, paragraph: paragraph(), width: nil, place: place, kind: "title")
        let rtl = try sut.layout(hebrew, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        // The second line is 0 wide, at 0 on the left and at 40 on the right. Left to right its spaces run from 0, and
        // right to left L2 reverses them to end at 40.
        #expect(ltr.runs.map { $0.glyphs.map(\.x) } == [[0, 20], [0, 10]])
        #expect(rtl.runs.map { $0.glyphs.map(\.x) } == [[0, 20], [20, 30]])
        #expect(rtl.lines.last?.hanging == [cluster(1, 1, 1, 3..<4, 10, level: 1), cluster(1, 0, 1, 4..<5, 10, level: 1)])
    }

    @Test("tracking between neighbours as placed is that of whichever of them comes first in the text, across levels")
    func tracksAcrossDirectionChange() throws {
        // Given
        let runs = [
            run("א", style: character(tracking: 100)),
            run("ב", style: character(size: 20, tracking: 100)),
            run("c")
        ]
        let style = paragraph(direction: .ltr)

        // When
        let layout = try sut.layout(runs, paragraph: style, width: nil, place: place, kind: "title")

        // Then
        // At levels 1 1 0 the line is placed ב א c. Both gaps take the tracking of א, 4, which comes first in the text
        // in each pair: ב at 0, 10 wide, א at 10 + 4, 20 wide, c at 34 + 4.
        #expect(layout.runs.map(\.source) == [1, 0, 2])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0], [14], [38]])
        #expect(layout.lines.map(\.width) == [58])
        #expect(layout.size.width == 58)
    }

    @Test("line breaking measures a candidate line as it would be placed")
    func breaksAtWidthAsPlaced() throws {
        // Given
        let runs = [
            run("א", style: character(tracking: 100)),
            run("ב", style: character(size: 20, tracking: 100)),
            run(" c")
        ]

        // When
        let fits = try sut.layout(runs, paragraph: paragraph(direction: .ltr), width: 68, place: place, kind: "title")
        let wraps = try sut.layout(runs, paragraph: paragraph(direction: .ltr), width: 67, place: place, kind: "title")

        // Then
        // Placed ב א space c, the line is 10 + 20 + 10 + 20 wide with gaps 4, 4 and 0, so 68. Its gaps in text order
        // would be 4, 2 and 0, 66, which fits 67.
        #expect(fits.lines.map(\.range) == [0..<4])
        #expect(wraps.lines.map(\.range) == [0..<2, 3..<4])
    }

    @Test("a highlight is one piece per stretch of its run that lies side by side, the pieces in text order")
    func splitsHighlightByReordering() throws {
        // Given
        let runs = [run("אa", style: character(isHighlighted: true)), run("b")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        // At levels 1 2 2 the line is placed a b א, so the highlighted run lies at 0 and at 40 with b between. The
        // piece of א comes first in the text, and the first glyph run of the run holds both.
        #expect(layout.runs.map(\.source) == [0, 1, 0])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0], [20], [40]])
        #expect(layout.runs.map(\.highlights) == [
            [Rectangle(x: 40, y: 0, width: 20, height: 40), Rectangle(x: 0, y: 0, width: 20, height: 40)],
            [],
            []
        ])
    }

    @Test("a word whose characters lie apart as placed has one glyph box over them and a part of the piece for each")
    func spansWordLyingApart() throws {
        // Given
        let runs = [run("aב ג", style: character(isHighlighted: true))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, unit: .word, place: place, kind: "title")

        // Then
        // At levels 0 1 1 1 the line is placed a ג space ב: a at 0, ג at 20, the space at 40 and ב at 50. The word
        // `aב` takes the space after it, and the piece from 0 to 70 is cut where neighbours go with different units.
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0, 20, 40, 50]])
        #expect(layout.runs.map(\.highlights) == [[Rectangle(x: 0, y: 0, width: 70, height: 40)]])
        #expect(layout.units?.map(\.characters) == [
            CharacterRange(line: 0, first: 0, count: 3),
            CharacterRange(line: 0, first: 3, count: 1)
        ])
        #expect(layout.units?.map(\.glyphBox) == [
            Rectangle(x: 0, y: 0, width: 70, height: 40),
            Rectangle(x: 20, y: 0, width: 20, height: 40)
        ])
        #expect(layout.units?.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...20), UnitPart(run: 0, piece: 0, span: 40...70)],
            [UnitPart(run: 0, piece: 0, span: 20...40)]
        ])
    }

    @Test("a right-to-left paragraph breaks in text order and each line is placed from the right")
    func wrapsRightToLeftParagraph() throws {
        // Given
        let runs = [run("אב גד הו")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: 100, place: place, kind: "title")

        // Then
        // `אב גד` is 90 wide and fits, and the first line, at 100 - 90 = 10, holds the first two words, its last space
        // hanging before 10. The second, `הו`, is 40 wide at 60.
        #expect(layout.lines.map(\.range) == [0..<5, 6..<8])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0, 10, 30, 50, 60, 80], [60, 80]])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids(" דג בא"), ids("וה")])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[32, 32, 32, 32, 32, 32], [82, 82]])
    }

    // MARK: - Private
    private func paragraph(
        direction: TextDirection? = nil,
        align: TextAlignment? = nil
    ) -> ParagraphStyle {
        ParagraphStyle(lineHeight: 50, background: nil, direction: direction, align: align, lines: nil)
    }

    private func character(
        size: Double = 40,
        tracking: Double = 0,
        isHighlighted: Bool = false
    ) -> CharacterStyle {
        CharacterStyle(
            families: ["Apple SD Gothic Neo"],
            weight: .bold,
            size: size,
            tracking: tracking,
            isHighlighted: isHighlighted
        )
    }

    private func run(
        _ text: String,
        style: CharacterStyle? = nil
    ) -> TextRun {
        TextRun(text: text, style: style ?? character(), faces: [face])
    }

    private func cluster(
        _ run: Int,
        _ first: Int,
        _ count: Int,
        _ range: Range<Int>,
        _ advance: Double,
        level: Int
    ) -> PlacedCluster {
        PlacedCluster(
            glyphs: GlyphRange(run: run, first: first, count: count),
            range: range,
            advance: advance,
            level: level
        )
    }

    private func ids(_ text: String) -> [Int] {
        text.unicodeScalars.map { Int($0.value) }
    }
}
