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

    @Test(
        "a run's text orientation sets its characters in a vertical line, `mixed` by their Vertical_Orientation",
        arguments: [WritingMode.verticalRightToLeft, .verticalLeftToRight]
    )
    func setsCharactersByTextOrientation(writingMode: WritingMode) throws {
        // Given
        let runs = [run("AB", textOrientation: .upright), run("漢字", textOrientation: .sideways), run("A漢")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(writingMode), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.source) == [0, 1, 2, 2])
        #expect(layout.runs.map(\.isSideways) == [false, true, true, false])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x41, 0x42], [0x6F22, 0x5B57], [0x41], [0x6F22]])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [40, 40, 20, 20, 20, 40])
        #expect(layout.runs.flatMap(\.glyphs).map(\.placementOffset) == [
            Point(x: -10, y: 32),
            Point(x: -10, y: 32),
            Point(x: -12, y: 0),
            Point(x: -12, y: 0),
            Point(x: -12, y: 0),
            Point(x: -10, y: 32)
        ])
    }

    @Test("under `upright` and `sideways` a grapheme cluster takes its run's orientation, an enclosing mark's included")
    func orientsClustersByTextOrientation() throws {
        // Given
        let runs = [run("A\u{301}", textOrientation: .upright), run("漢\u{20DD}", textOrientation: .sideways)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.isSideways) == [false, true])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x41, 0x301], [0x6F22, 0x20DD]])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [80, 40])
    }

    @Test(
        "under `upright` a character whose Vertical_Orientation is R is shaped apart in its horizontal form, each in glyphs of its own",
        arguments: [[FontFeature](), [FontFeature(tag: "vert", value: 1), FontFeature(tag: "liga", value: 1)]]
    )
    func setsRotatedCharactersUprightInHorizontalForms(features: [FontFeature]) throws {
        // Given
        let shaper = ShaperTable(verticalForms: ["、": 0xFE11, "f": 0xE066, "N": 0xE04E, "A": 0xE041])
        let sut = Typesetter(shaper: shaper)
        let runs = [
            run("、fiNA\u{20DD}", textOrientation: .upright, features: features),
            run("、fiN", features: features)
        ]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        // In the `upright` run `、` and the cluster `A⃝`, whose Vertical_Orientation is U, keep their vertical forms,
        // and `f`, `i` and `N`, whose value is R, stand unligated in their horizontal forms. Under `mixed` `、` stands
        // in its vertical form and `fiN` is sideways, ligated as horizontal text.
        let glyphs = layout.runs.flatMap { run in run.glyphs.map { (id: $0.id, isSideways: run.isSideways) } }
        #expect(glyphs.map(\.id) == [0xFE11, 0x66, 0x69, 0x4E, 0xE041, 0x20DD, 0xFE11, ShaperTable.ligature, 0x4E])
        #expect(glyphs.map(\.isSideways) == [false, false, false, false, false, false, false, true, true])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [40, 40, 40, 40, 80, 40, 40, 0, 20])
    }

    @Test("a horizontal line turns no character and reads every one by its own class, whatever its run's attributes")
    func ignoresTextOrientationInHorizontalLine() throws {
        // Given
        let runs = [run("\u{5D0}\u{5D1}", textOrientation: .upright), run("12", textCombineUpright: .all)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.horizontalTopToBottom),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.direction == .rtl)
        #expect(layout.runs.map(\.isSideways) == [false, false])
        #expect(layout.lines.flatMap(\.clusters).map(\.level) == [1, 1, 2, 2])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [20, 20, 20, 20])
    }

    @Test("an upright run of Hebrew in a vertical line is read left to right, so its letters are placed from the top down")
    func readsUprightRunLeftToRight() throws {
        // Given
        let runs = [run("漢"), run("\u{5D0}\u{5D1}", textOrientation: .upright), run("字")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        let line = try #require(layout.lines.first)
        #expect(line.clusters.map(\.level) == [0, 0, 0, 0])
        #expect(line.placedOrder == [0, 1, 2, 3])
        #expect(layout.runs.map(\.isSideways) == [false, false, false])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x5D0, 0x5D1], [0x5B57]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [40, 80], [120]])
    }

    @Test(
        "an explicit formatting character of an upright run is read as left to right in a vertical line alone",
        arguments: [(WritingMode.verticalRightToLeft, [0, 0, 0]), (.horizontalTopToBottom, [0, 1, 1])]
    )
    func readsFormattingCharacterOfUprightRun(writingMode: WritingMode, levels: [Int]) throws {
        // Given
        let runs = [run("\u{202E}AB", textOrientation: .upright)]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(writingMode), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.lines.flatMap(\.clusters).map(\.level) == levels)
    }

    @Test("the characters of a combined run in a vertical line are read left to right")
    func readsCombinedRunLeftToRight() throws {
        // Given
        let runs = [run("\u{5D0}\u{5D1}", textCombineUpright: .all), run("\u{5D2}")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.direction == .ltr)
        #expect(layout.lines.flatMap(\.clusters).map(\.level) == [0, 0, 1])
    }

    @Test(
        "`auto` takes a vertical title's direction from the classes its characters are read as",
        arguments: [(TextOrientation.upright, TextDirection.ltr, [0, 1]), (.mixed, .rtl, [1, 1])]
    )
    func takesDirectionFromClassesReadAs(
        textOrientation: TextOrientation,
        direction: TextDirection,
        levels: [Int]
    ) throws {
        // Given
        let runs = [run("\u{5D0}", textOrientation: textOrientation), run("\u{5D1}")]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.direction == direction)
        #expect(layout.lines.flatMap(\.clusters).map(\.level) == levels)
    }

    @Test("an upright letter of a cursive script stands apart from its neighbours, so tracking lies between two of them")
    func tracksUprightCursiveLetters() throws {
        // Given
        // A tracking of 100 is 4 at size 40.
        let text = "\u{628}\u{628}"
        let upright = [run("漢"), run(text, tracking: 100, textOrientation: .upright), run("字")]
        let mixed = [run("漢"), run(text, tracking: 100), run("字")]

        // When
        let paragraph = paragraph(.verticalRightToLeft)
        let layout = try sut.layout(upright, paragraph: paragraph, width: nil, place: place, kind: "title")
        let mixedLayout = try sut.layout(mixed, paragraph: paragraph, width: nil, place: place, kind: "title")

        // Then
        let line = try #require(layout.lines.first)
        let mixedLine = try #require(mixedLayout.lines.first)
        #expect(line.clusters.map(\.cursiveScripts) == [[], [], [], []])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [40, 84], [128]])
        #expect(line.width == 168)
        #expect(mixedLine.clusters.map(\.cursiveScripts) == [[], ["Arab"], ["Arab"], []])
        #expect(mixedLine.width == 124)
    }

    @Test("an upright run in a right-to-left vertical line lies where its level places it, its letters in reading order")
    func placesUprightRunInRightToLeftLine() throws {
        // Given
        let runs = [run("\u{5D0}"), run("\u{5D1}\u{5D2}", textOrientation: .upright)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        let line = try #require(layout.lines.first)
        #expect(layout.direction == .rtl)
        #expect(line.clusters.map(\.level) == [1, 2, 2])
        #expect(line.placedOrder == [1, 2, 0])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x5D1, 0x5D2], [0x5D0]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0, 40], [80]])
    }

    @Test(
        "a combined run in a vertical line is one composition, its glyphs set side by side at one pen in a square 1 em long",
        arguments: [WritingMode.verticalRightToLeft, .verticalLeftToRight]
    )
    func setsCompositionInOneSquare(writingMode: WritingMode) throws {
        // Given
        // "12" is 40 wide as horizontal text, 1 em at size 40, so it is not narrowed: its glyphs start 20 left of the
        // baseline, and their alphabetic baseline lies 12 past the middle of the square, 32 down from its start.
        let runs = [run("漢"), run("12", textCombineUpright: .all), run("字")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(writingMode), width: nil, place: place, kind: "title")

        // Then
        let line = try #require(layout.lines.first)
        #expect(layout.runs.map(\.isSideways) == [false, false, false])
        #expect(layout.runs.map(\.horizontalScale) == [1, 1, 1])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x31, 0x32], [0x5B57]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [40, 40], [80]])
        #expect(layout.runs[1].glyphs.map(\.placementOffset) == [Point(x: -20, y: 32), Point(x: 0, y: 32)])
        #expect(line.clusters.map(\.glyphs.count) == [1, 2, 0, 1])
        #expect(line.clusters.map(\.advance) == [40, 40, 0, 40])
        #expect(line.width == 120)
    }

    @Test(
        "a composition one of whose characters falls back to another face is one group, its glyphs one range from its first face's glyph run on into the fallback face's"
    )
    func setsCompositionInTwoFaces() throws {
        // Given
        let sut = Typesetter(shaper: ShaperTable(missing: ["2"]))
        let runs = [run("漢"), run("12", textCombineUpright: .all), run("字")]

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
        #expect(layout.runs.map(\.face) == [face, face, ShaperTable.fallback, face])
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[0x6F22], [0x31], [0x32], [0x5B57]])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [40], [40], [80]])
        #expect(line.clusters.map(\.glyphs) == [
            GlyphRange(run: 0, first: 0, count: 1),
            GlyphRange(run: 1, first: 0, count: 2),
            GlyphRange(run: 2, first: 1, count: 0),
            GlyphRange(run: 3, first: 0, count: 1)
        ])
        #expect(line.clusters.map(\.advance) == [40, 40, 0, 40])
        #expect(layout.units?.map(\.glyphs) == [
            [GlyphRange(run: 0, first: 0, count: 1)],
            [GlyphRange(run: 1, first: 0, count: 1), GlyphRange(run: 2, first: 0, count: 1)],
            [GlyphRange(run: 3, first: 0, count: 1)]
        ])
        #expect(layout.units?.map(\.glyphBox) == [
            Rectangle(x: 0, y: 0, width: 40, height: 40),
            Rectangle(x: 0, y: 40, width: 40, height: 40),
            Rectangle(x: 0, y: 80, width: 40, height: 40)
        ])
    }

    @Test("a composition wider than 1 em is narrowed to it with its placement offsets, and a narrower one is not widened")
    func narrowsWideComposition() throws {
        // Given
        // "2026" is 80 wide, so it is narrowed by 0.5 to 40, and its "0" is placed 4 right and 2 down of its pen.
        let sut = Typesetter(shaper: ShaperTable(placements: ["0": Point(x: 0.1, y: 0.05)]))
        let runs = [run("2026", textCombineUpright: .all), run("1", textCombineUpright: .all)]

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
        #expect(layout.runs.map(\.horizontalScale) == [0.5, 1])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0, 0, 0, 0], [40]])
        #expect(layout.runs.map { $0.glyphs.map(\.placementOffset) } == [
            [Point(x: -20, y: 32), Point(x: -8, y: 34), Point(x: 0, y: 32), Point(x: 10, y: 32)],
            [Point(x: -10, y: 32)]
        ])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [40, 0, 0, 0, 40])
        #expect(layout.lines.map(\.width) == [80])
    }

    @Test("a combined run whose text holds `\\n` is a composition on each of its lines")
    func composesEachLine() throws {
        // Given
        let runs = [run("12\n345", textCombineUpright: .all)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.lines.map { $0.clusters.map(\.advance) } == [[40, 0], [40, 0, 0]])
        #expect(layout.runs.map(\.line) == [0, 1])
        #expect(layout.runs.map(\.horizontalScale) == [1, 2.0 / 3.0])
    }

    @Test("no line breaks inside a composition, and its spaces are set in it and do not hang")
    func keepsCompositionWhole() throws {
        // Given
        // "1 2 " is 60 wide as horizontal text, and its composition 40 long.
        let runs = [run("漢 "), run("1 2 ", textCombineUpright: .all)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: 40,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.lines.map(\.range) == [0..<1, 2..<6])
        #expect(layout.lines.map(\.clusters.count) == [1, 4])
        #expect(layout.lines.map(\.hanging.count) == [1, 0])
        #expect(layout.lines.map(\.width) == [40, 40])
    }

    @Test("a composition is tracked from its neighbours, highlighted, underlined and moved by a unit as one character")
    func spacesCompositionAsOneCharacter() throws {
        // Given
        // A tracking of 100 is 4 at size 40.
        let runs = [
            run("漢", tracking: 100),
            run("12", tracking: 100, isHighlighted: true, isUnderlined: true, textCombineUpright: .all),
            run("字")
        ]

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
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[0], [44, 44], [88]])
        #expect(layout.lines.map(\.width) == [128])
        #expect(layout.runs[1].highlights == [Rectangle(x: 0, y: 44, width: 40, height: 40)])
        #expect(layout.runs[1].underlines == [UnderlinePiece(x: 8, y: 44, width: 40)])
        #expect(layout.units?.map(\.characters) == [
            CharacterRange(line: 0, first: 0, count: 1),
            CharacterRange(line: 0, first: 1, count: 2),
            CharacterRange(line: 0, first: 3, count: 1)
        ])
        #expect(layout.units?.map(\.glyphBox) == [
            Rectangle(x: 0, y: 0, width: 40, height: 40),
            Rectangle(x: 0, y: 44, width: 40, height: 40),
            Rectangle(x: 0, y: 88, width: 40, height: 40)
        ])
    }

    @Test(
        "a composition is shaped as horizontal text and turned by nothing, whatever its run's text orientation",
        arguments: [TextOrientation.upright, .sideways]
    )
    func ignoresTextOrientationOfComposition(textOrientation: TextOrientation) throws {
        // Given
        let runs = [run("12", textOrientation: textOrientation, textCombineUpright: .all)]

        // When
        let layout = try sut.layout(
            runs,
            paragraph: paragraph(.verticalRightToLeft),
            width: nil,
            place: place,
            kind: "title"
        )

        // Then
        #expect(layout.runs.map(\.isSideways) == [false])
        #expect(layout.runs.flatMap(\.glyphs).map(\.placementOffset) == [Point(x: -20, y: 32), Point(x: 0, y: 32)])
        #expect(layout.lines.flatMap(\.clusters).map(\.advance) == [40, 0])
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
        tracking: Double = 0,
        isHighlighted: Bool = false,
        isUnderlined: Bool = false,
        textOrientation: TextOrientation = .mixed,
        textCombineUpright: TextCombineUpright = .none,
        features: [FontFeature] = []
    ) -> TextRun {
        TextRun(
            text: text,
            style: CharacterStyle(
                families: ["Apple SD Gothic Neo"],
                weight: .bold,
                size: size,
                tracking: tracking,
                features: features,
                isHighlighted: isHighlighted,
                isUnderlined: isUnderlined,
                textOrientation: textOrientation,
                textCombineUpright: textCombineUpright
            ),
            faces: [face]
        )
    }
}
