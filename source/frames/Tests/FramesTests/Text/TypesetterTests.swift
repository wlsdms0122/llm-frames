//
//  TypesetterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// The fake shaper sets each scalar 0.5 em wide and a space 0.25 em, with an ascent of 0.8 em and a descent of 0.2 em,
// so at size 40 a letter is 20 wide, a space 10, and a line reaches 32 above its baseline and 8 below.
@Suite("Typesetter Tests")
struct TypesetterTests {
    // MARK: - Property
    private let sut = Typesetter(shaper: ShaperTable(missing: ["✓"]))
    private let face = ShaperTable.face("Apple SD Gothic Neo", .bold)
    private let place = Place.root.appending(key: "title")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a line is set in the style's size, its glyphs placed on the baseline")
    func setsOneLine() throws {
        // Given
        let runs = [run("ab")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout == TextLayout(
            text: "ab",
            size: Size(width: 40, height: 40),
            textBox: Rectangle(x: 0, y: 0, width: 40, height: 40),
            width: nil,
            lines: [
                PlacedLine(
                    width: 40,
                    baseline: 32,
                    ascent: 32,
                    descent: 8,
                    range: 0..<2,
                    clusters: [cluster(0, 0, 1, 0..<1, 20), cluster(0, 1, 1, 1..<2, 20)],
                    hanging: []
                )
            ],
            runs: [
                GlyphRun(
                    source: 0,
                    line: 0,
                    face: face,
                    size: 40,
                    glyphs: [glyph("a", 0, 32), glyph("b", 20, 32)]
                )
            ],
            background: nil,
            align: .left,
            lineHeight: 50
        ))
    }

    @Test("each run is set in its own size, and text written with markup is set as written")
    func setsRunsInTheirStyles() throws {
        // Given
        let runs = [run("a "), run("**b**", style: character(size: 20))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs == [
            GlyphRun(source: 0, line: 0, face: face, size: 40, glyphs: [glyph("a", 0, 32), glyph(" ", 20, 32)]),
            GlyphRun(
                source: 1,
                line: 0,
                face: face,
                size: 20,
                glyphs: [
                    glyph("*", 30, 32), glyph("*", 40, 32), glyph("b", 50, 32), glyph("*", 60, 32), glyph("*", 70, 32)
                ]
            )
        ])
    }

    @Test("a small run and a big run on one line share its baseline, which lies the big run's ascent below the top")
    func setsMixedSizesOnOneBaseline() throws {
        // Given
        let runs = [run("a", style: character(size: 20)), run("B"), run("c", style: character(size: 20))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 40, height: 40))
        #expect(layout.runs.map(\.glyphs) == [[glyph("a", 0, 32)], [glyph("B", 10, 32)], [glyph("c", 30, 32)]])
    }

    @Test("the first baseline follows the first line's largest ascent and the box ends the last line's largest descent")
    func measuresLinesByTheirRuns() throws {
        // Given
        let runs = [run("a\n", style: character(size: 20)), run("B")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 20, height: 16 + 50 + 8))
        #expect(layout.runs.map(\.glyphs) == [[glyph("a", 0, 16)], [glyph("B", 0, 66)]])
    }

    // At size 20 a line reaches 16 above its baseline and 4 below, and at 40 32 and 8, and lines lie 50 apart.
    @Test(
        "a line with no text takes the extent of the run it begins in",
        arguments: [
            (["a\n", "\nb"], [20, 40], 124),
            (["a", "\n"], [40, 20], 86),
            (["\n", "b"], [20, 40], 74)
        ] as [([String], [Double], Double)]
    )
    func measuresEmptyLines(
        texts: [String],
        sizes: [Double],
        height: Double
    ) throws {
        // Given
        let runs = zip(texts, sizes).map { text, size in run(text, style: character(size: size)) }

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.size.height == height)
    }

    @Test("a run boundary is no break opportunity, so a word split over two runs stays whole on its line")
    func keepsWordWholeAcrossRuns() throws {
        // Given
        let runs = [run("go iPhone"), run("에서", style: character(size: 40))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: 170, place: place, kind: "title")

        // Then
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("go "), ids("iPhone"), ids("에서")])
        #expect(layout.runs.map { $0.glyphs.map(\.y) } == [[32, 32, 32], Array(repeating: 82, count: 6), [82, 82]])
        #expect(layout.runs[2].glyphs.first?.x == 120)
    }

    @Test("lines align on the advances of every run on them")
    func alignsAcrossRuns() throws {
        // Given
        let runs = [run("aa\nb"), run("b", style: character(size: 20))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(align: .right), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0, 20], [10], [30]])
    }

    @Test("lines wrap where UAX #14 allows at the width, and spaces at a line's end hang outside it")
    func wrapsAtWidth() throws {
        // Given
        let runs = [run("aa bb cc")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: 110, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 110, height: 90))
        #expect(layout.lineCount == 2)
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("aa bb "), ids("cc")])
        #expect(layout.runs[1].glyphs.first == glyph("c", 0, 82))
    }

    @Test("a piece wider than the width alone overflows on its own line, and \\n always breaks")
    func breaksAtNewlineAndOverflows() throws {
        // Given
        let style = paragraph()

        // When
        let long = try sut.layout([run("a bbbbbb")], paragraph: style, width: 50, place: place, kind: "title")
        let newline = try sut.layout([run("a\n\nb")], paragraph: style, width: nil, place: place, kind: "title")

        // Then
        #expect(long.lineCount == 2)
        #expect(long.size.width == 120)
        #expect(newline.lineCount == 3)
        #expect(newline.runs.map { $0.glyphs.map(\.y) } == [[32], [132]])
    }

    @Test(
        "words are kept whole as keep-all keeps them, so Korean and a word of letters and Hangul wrap at spaces",
        arguments: [
            ("결제하기 버튼을 누르세요", 190.0, ["결제하기 버튼을 ", "누르세요"]),
            ("go iPhone에서", 170.0, ["go ", "iPhone에서"])
        ]
    )
    func keepsWordsWhole(
        text: String,
        width: Double,
        lines: [String]
    ) throws {
        // Given
        let runs = [run(text)]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: width, place: place, kind: "title")

        // Then
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == lines.map(ids))
    }

    @Test("a Korean word wider than its line starts a line and breaks inside it, where UAX #14 allows")
    func breaksWideWordInside() throws {
        // Given
        let runs = [run("가 결제하기버튼")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: 100, place: place, kind: "title")

        // Then
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("가 "), ids("결제하기버"), ids("튼")])
        #expect(layout.size.width == 100)
    }

    @Test(
        "a width wider than the text is the box, its lines aligned inside it and the background round it",
        arguments: [(TextAlignment.left, [16.0, 16]), (.center, [96, 106]), (.right, [176, 196])]
    )
    func alignsLinesInWidth(
        align: TextAlignment,
        xs: [Double]
    ) throws {
        // Given
        let background = TextBackground(color: Color(written: "#000000"), padding: Size(width: 16, height: 8), radius: 4)
        let style = paragraph(background: background, align: align)

        // When
        let layout = try sut.layout([run("aa\nb")], paragraph: style, width: 200, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 232, height: 106))
        #expect(layout.runs.compactMap { $0.glyphs.first?.x } == xs)
        #expect(layout.background == background)
    }

    @Test("without a width the text does not wrap, lines break only at \\n, and the box is as wide as the widest line")
    func keepsLinesWithoutWidth() throws {
        // Given
        let runs = [run("aa bb cc dd ee\nf")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.lineCount == 2)
        #expect(layout.size == Size(width: 240, height: 90))
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("aa bb cc dd ee"), ids("f")])
    }

    @Test("a background's padding grows the box and moves the text in, and the line height spaces the baselines")
    func padsBackground() throws {
        // Given
        let background = TextBackground(color: Color(written: "#000000"), padding: Size(width: 16, height: 8), radius: 4)
        let style = paragraph(lineHeight: 64, background: background)

        // When
        let layout = try sut.layout([run("a\nb")], paragraph: style, width: nil, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 52, height: 120))
        #expect(layout.runs.map(\.glyphs) == [[glyph("a", 16, 40)], [glyph("b", 16, 104)]])
        #expect(layout.background == background)
    }

    @Test("characters the face lacks are set in the face the shaper falls back to, in a run of their own")
    func keepsFallbackFace() throws {
        // Given
        let runs = [run("a✓b")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.face) == [face, ShaperTable.fallback, face])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0], [20], [40]])
    }

    @Test("tracking follows every grapheme cluster but the last on its line, so a centred line keeps its place")
    func tracksBetweenClusters() throws {
        // Given
        let runs = [run("ab", style: character(tracking: 100))]

        // When
        let left = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")
        let centred = try sut.layout(runs, paragraph: paragraph(align: .center), width: 100, place: place, kind: "title")

        // Then
        #expect(left.size.width == 44)
        #expect(left.runs.flatMap(\.glyphs).map(\.x) == [0, 24])
        #expect(centred.runs.flatMap(\.glyphs).map(\.x) == [28, 52])
    }

    @Test("a cluster of several scalars takes the tracking once")
    func tracksClustersOnce() throws {
        // Given
        let runs = [run("e\u{301}b", style: character(tracking: 100))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.flatMap(\.glyphs).map(\.x) == [0, 20, 44])
    }

    @Test("a glyph keeps its placement offset apart from its pen, and the pen moves by advances alone")
    func keepsPlacementOffsetApart() throws {
        // Given
        let shaper = ShaperTable(
            advances: [" ": 0.25, "\u{303}": 0],
            placements: ["\u{303}": Point(x: -0.25, y: -0.5)]
        )
        let sut = Typesetter(shaper: shaper)

        // When
        let layout = try sut.layout([run("q\u{303}x")], paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.flatMap(\.glyphs) == [
            glyph("q", 0, 32),
            PositionedGlyph(id: 0x303, x: 20, y: 32, placementOffset: Point(x: -10, y: -20)),
            glyph("x", 20, 32)
        ])
        #expect(layout.lines.map(\.clusters) == [[cluster(0, 0, 2, 0..<2, 20), cluster(0, 2, 1, 2..<3, 20)]])
        #expect(layout.lines.map(\.width) == [40])
    }

    @Test("glyphs set out of text order are one group, owned by its first character, and the later one has no glyph")
    func groupsReorderedGlyphs() throws {
        // Given
        let sut = Typesetter(shaper: ShaperTable(prebase: ["r"]))
        let runs = [run("arb", style: character(tracking: 100))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, unit: .character, place: place, kind: "title")

        // Then
        #expect(layout.runs.flatMap(\.glyphs) == [glyph("r", 0, 32), glyph("a", 20, 32), glyph("b", 44, 32)])
        #expect(layout.lines == [
            PlacedLine(
                width: 64,
                baseline: 32,
                ascent: 32,
                descent: 8,
                range: 0..<3,
                clusters: [cluster(0, 0, 2, 0..<1, 40), cluster(0, 2, 0, 1..<2, 0), cluster(0, 2, 1, 2..<3, 20)],
                hanging: []
            )
        ])
        #expect(layout.units?.map(\.glyphBox.x) == [0, 44])
        #expect(layout.units?.map(\.glyphBox.width) == [40, 20])
    }

    @Test("a ligature kept under tracking is followed by one tracking, and its later character has no glyph")
    func tracksLigatureOnce() throws {
        // Given
        let style = character(tracking: 100, features: [FontFeature(tag: "liga", value: 1)])

        // When
        let layout = try sut.layout([run("fia", style: style)], paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.flatMap(\.glyphs).map(\.x) == [0, 44])
        #expect(layout.lines.map(\.width) == [64])
        #expect(layout.lines.map(\.clusters) == [
            [cluster(0, 0, 1, 0..<1, 40), cluster(0, 1, 0, 1..<2, 0), cluster(0, 1, 1, 2..<3, 20)]
        ])
    }

    @Test("a space is a cluster whose first scalar is white space, and the spaces ending a line hang past it untracked")
    func hangsSpacesUntracked() throws {
        // Given
        let runs = [run("ab \u{301} ", style: character(tracking: 100))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.flatMap(\.glyphs).map(\.x) == [0, 24, 44, 54, 74])
        #expect(layout.lines == [
            PlacedLine(
                width: 44,
                baseline: 32,
                ascent: 32,
                descent: 8,
                range: 0..<2,
                clusters: [cluster(0, 0, 1, 0..<1, 20), cluster(0, 1, 1, 1..<2, 20)],
                hanging: [cluster(0, 2, 2, 2..<4, 30), cluster(0, 4, 1, 4..<5, 10)]
            )
        ])
    }

    @Test(
        "a line's range runs over its characters in the text of all runs, and a line with no character has the empty range where it starts",
        arguments: [
            (["\nab"], [0..<0, 1..<3]),
            (["a b\n", "\ncd"], [0..<3, 4..<4, 5..<7]),
            (["ab  \n", "  "], [0..<2, 5..<5])
        ] as [([String], [Range<Int>])]
    )
    func measuresLineRanges(
        texts: [String],
        ranges: [Range<Int>]
    ) throws {
        // Given
        let runs = texts.map { run($0) }

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.text == texts.joined())
        #expect(layout.lines.map(\.range) == ranges)
    }

    @Test("a grapheme cluster a run boundary falls inside is set whole in the run of its first scalar")
    func keepsClusterInOneRun() throws {
        // Given
        let runs = [run("a"), run("\u{301}b", style: character(size: 20))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.text == "a\u{301}b")
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [[97, 0x301], [98]])
        #expect(layout.runs.map(\.size) == [40, 20])
        #expect(layout.lines.map(\.clusters) == [[cluster(0, 0, 2, 0..<2, 40), cluster(1, 0, 1, 2..<3, 10)]])
    }

    @Test("lines break at the widest tracking a run takes and its glyphs are placed at its static tracking")
    func breaksAtWidestTracking() throws {
        // Given
        let widest = TextRun(text: "aa aa", style: character(), faces: [face], widestTracking: 500)

        // When
        let still = try sut.layout([run("aa aa")], paragraph: paragraph(), width: 120, place: place, kind: "title")
        let moving = try sut.layout([widest], paragraph: paragraph(), width: 120, place: place, kind: "title")

        // Then
        #expect(still.lineCount == 1)
        #expect(moving.lineCount == 2)
        #expect(moving.runs.map { $0.glyphs.map(\.x) } == [[0, 20, 40], [0, 20]])
    }

    @Test("the optional ligatures are off in a tracked run unless its features turn them on, and on otherwise")
    func turnsLigaturesOffUnderTracking() throws {
        // Given
        let plain = run("fi")
        let tracked = run("fi", style: character(tracking: 50))
        let ligated = run("fi", style: character(tracking: 50, features: [FontFeature(tag: "liga", value: 1)]))

        // When
        let counts = try [plain, tracked, ligated].map { run in
            try sut.layout([run], paragraph: paragraph(), width: nil, place: place, kind: "title").runs.flatMap(\.glyphs).count
        }

        // Then
        #expect(counts == [1, 2, 1])
    }

    @Test("kerning off sets each glyph at its own advance")
    func turnsKerningOff() throws {
        // Given
        let kerned = run("AV")
        let unkerned = run("AV", style: character(isKerned: false))

        // When
        let widths = try [kerned, unkerned].map { run in
            try sut.layout([run], paragraph: paragraph(), width: nil, place: place, kind: "title").size.width
        }

        // Then
        #expect(widths == [36, 40])
    }

    @Test("characters a run's face lacks are set in the later faces of its font list before the provider's fallback")
    func fallsBackThroughFontList() throws {
        // Given
        let sut = Typesetter(shaper: ShaperTable(lacks: ["Apple SD Gothic Neo": ["b"]]))
        let other = ShaperTable.face("Inter", .bold)
        let runs = [TextRun(text: "ab", style: character(), faces: [face, other])]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.face) == [face, other])
    }

    @Test("a highlight is one piece per line from the run's ascent to its descent, the spaces ending a line left out")
    func cutsHighlightPerLine() throws {
        // Given
        let runs = [run("aa bb", style: character(isHighlighted: true))]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: 60, place: place, kind: "title")
        let plain = try sut.layout([run("aa bb")], paragraph: paragraph(), width: 60, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.highlights) == [
            [Rectangle(x: 0, y: 0, width: 40, height: 40)],
            [Rectangle(x: 0, y: 50, width: 40, height: 40)]
        ])
        #expect(layout.size == plain.size)
        #expect(layout.runs.map(\.glyphs) == plain.runs.map(\.glyphs))
    }

    @Test("an underline piece spans its run's glyphs on the baseline, spaces inside the line included")
    func cutsUnderlineOnBaseline() throws {
        // Given
        let runs = [run("a"), run(" bb ", style: character(isUnderlined: true)), run("c")]

        // When
        let layout = try sut.layout(runs, paragraph: paragraph(), width: nil, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.underlines) == [[], [UnderlinePiece(x: 20, y: 32, width: 60)], []])
    }

    @Test("a one-line style never wraps, and without a width takes a line of any length")
    func keepsOneLine() throws {
        // Given
        let style = paragraph(lines: 1)

        // When
        let fits = try sut.layout([run("aa bb cc")], paragraph: style, width: 150, place: place, kind: "title")
        let unbounded = try sut.layout([run("aa bb cc")], paragraph: style, width: nil, place: place, kind: "title")

        // Then
        #expect(fits.lineCount == 1)
        #expect(fits.size.width == 150)
        #expect(unbounded.lineCount == 1)
        #expect(unbounded.size.width == 140)
    }

    @Test(
        "a one-line style stops on text wider than its room, a word it would break inside too, and on a line break",
        arguments: [
            (
                "aa bb cc",
                "title (title): the text is 140 wide on one line, wider than its room of 100, and a cut line would "
                    + "say something else"
            ),
            ("a\nb", "title (title): the text takes 2 lines, and its style allows at most 1"),
            (
                "결제하기버튼",
                "title (title): the text is 120 wide on one line, wider than its room of 100, and a cut line would "
                    + "say something else"
            )
        ]
    )
    func refusesOneLineOverflow(
        text: String,
        message: String
    ) throws {
        // Given
        let style = paragraph(lines: 1)

        // When, Then
        let error = #expect(throws: TextError.self) {
            try sut.layout([run(text)], paragraph: style, width: 100, place: place, kind: "title")
        }
        #expect(error?.description == message)
    }

    @Test(
        "a style of two lines takes text that wraps or breaks to two lines",
        arguments: [("aa bb cc", 100.0), ("aa\nbb", nil)] as [(String, Double?)]
    )
    func keepsLineLimit(
        text: String,
        width: Double?
    ) throws {
        // Given
        let style = paragraph(lines: 2)

        // When
        let layout = try sut.layout([run(text)], paragraph: style, width: width, place: place, kind: "title")

        // Then
        #expect(layout.lineCount == 2)
    }

    @Test(
        "a style of two lines stops on text that needs a third line, by wrapping or at a line break",
        arguments: [("aa bb cc", 50.0), ("aa bb cc\ndd", 100.0), ("a\nb\nc", nil)] as [(String, Double?)]
    )
    func refusesLinesPastLimit(
        text: String,
        width: Double?
    ) throws {
        // Given
        let style = paragraph(lines: 2)

        // When, Then
        let error = #expect(throws: TextError.self) {
            try sut.layout([run(text)], paragraph: style, width: width, place: place, kind: "title")
        }
        #expect(error?.description == "title (title): the text takes 3 lines, and its style allows at most 2")
    }

    @Test("a unit runs across its glyphs and down its line, and one spaced apart sets no ligature")
    func findsUnits() throws {
        // Given
        let joined = [run("fi x\nab")]
        let apart = [TextRun(text: "fi", style: character(), faces: [face], isSpacedApart: true)]

        // When
        let layout = try sut.layout(joined, paragraph: paragraph(), width: nil, unit: .word, place: place, kind: "title")
        let spaced = try sut.layout(apart, paragraph: paragraph(), width: nil, unit: .character, place: place, kind: "title")

        // Then
        // "fi" is one glyph, and its unit draws the space after it.
        #expect(layout.units?.map(\.characters) == [
            CharacterRange(line: 0, first: 0, count: 3),
            CharacterRange(line: 0, first: 3, count: 1),
            CharacterRange(line: 1, first: 0, count: 2)
        ])
        #expect(layout.units?.map(\.glyphs) == [
            [GlyphRange(run: 0, first: 0, count: 2)],
            [GlyphRange(run: 0, first: 2, count: 1)],
            [GlyphRange(run: 1, first: 0, count: 2)]
        ])
        #expect(layout.units?.map(\.glyphBox) == [
            Rectangle(x: 0, y: 0, width: 40, height: 40),
            Rectangle(x: 50, y: 0, width: 20, height: 40),
            Rectangle(x: 0, y: 50, width: 40, height: 40)
        ])
        #expect(layout.units?.map(\.box) == layout.units?.map(\.glyphBox))
        #expect(spaced.units?.map(\.glyphs) == [
            [GlyphRange(run: 0, first: 0, count: 1)],
            [GlyphRange(run: 0, first: 1, count: 1)]
        ])
    }

    // MARK: - Private
    private func paragraph(
        lineHeight: Double = 50,
        background: TextBackground? = nil,
        align: TextAlignment = .left,
        lines: Int? = nil
    ) -> ParagraphStyle {
        ParagraphStyle(lineHeight: lineHeight, background: background, align: align, lines: lines)
    }

    private func character(
        size: Double = 40,
        tracking: Double = 0,
        isKerned: Bool = true,
        features: [FontFeature] = [],
        isHighlighted: Bool = false,
        isUnderlined: Bool = false
    ) -> CharacterStyle {
        CharacterStyle(
            families: ["Apple SD Gothic Neo"],
            weight: .bold,
            size: size,
            tracking: tracking,
            isKerned: isKerned,
            features: features,
            isHighlighted: isHighlighted,
            isUnderlined: isUnderlined
        )
    }

    private func run(
        _ text: String,
        style: CharacterStyle? = nil
    ) -> TextRun {
        TextRun(text: text, style: style ?? character(), faces: [face])
    }

    private func glyph(
        _ character: Unicode.Scalar,
        _ x: Double,
        _ y: Double
    ) -> PositionedGlyph {
        PositionedGlyph(id: Int(character.value), x: x, y: y)
    }

    private func cluster(
        _ run: Int,
        _ first: Int,
        _ count: Int,
        _ range: Range<Int>,
        _ advance: Double
    ) -> PlacedCluster {
        PlacedCluster(glyphs: GlyphRange(run: run, first: first, count: count), range: range, advance: advance)
    }

    private func ids(_ text: String) -> [Int] {
        text.unicodeScalars.map { Int($0.value) }
    }
}
