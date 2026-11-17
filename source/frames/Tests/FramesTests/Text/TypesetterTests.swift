//
//  TypesetterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// The fake shaper sets each scalar 0.5 em wide and a space 0.25 em, with an ascent of 0.8 em and a descent of 0.2 em,
// so at size 40 a letter is 20 wide, a space 10, and a line 50 high has its baseline at 37.
@Suite("Typesetter Tests")
struct TypesetterTests {
    // MARK: - Property
    private let sut = Typesetter(shaper: ShaperTable(missing: ["✓"]))
    private let face = ShaperTable.face("Apple SD Gothic Neo", .bold)
    private let text = Color(written: "#FFFFFF")
    private let emphasis = Color(written: "#FFD43B")
    private let place = Place.root.appending(key: "title")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a line is set in the style's size and colour, its glyphs placed on the baseline")
    func setsOneLine() throws {
        // Given
        let style = style()

        // When
        let layout = try sut.layout("ab", style: style, face: face, width: 500, place: place, kind: "title")

        // Then
        #expect(layout == TextLayout(
            size: Size(width: 40, height: 50),
            lineCount: 1,
            runs: [
                GlyphRun(face: face, size: 40, color: text, glyphs: [glyph("a", 0, 37), glyph("b", 20, 37)])
            ],
            stroke: nil,
            background: nil
        ))
    }

    @Test("**text** takes the emphasis colour, and a last ** that nothing closes is text")
    func setsEmphasis() throws {
        // Given
        let style = style()

        // When
        let closed = try sut.layout("a **b** c", style: style, face: face, width: 500, place: place, kind: "title")
        let open = try sut.layout("a **b", style: style, face: face, width: 500, place: place, kind: "title")

        // Then
        #expect(closed.runs.map(\.color) == [text, emphasis, text])
        #expect(closed.runs.map { $0.glyphs.map(\.id) } == [ids("a "), ids("b"), ids(" c")])
        #expect(open.runs.map(\.color) == [text])
        #expect(open.runs.map { $0.glyphs.map(\.id) } == [ids("a **b")])
    }

    @Test("lines wrap where UAX #14 allows at the width, and spaces at a line's end hang outside it")
    func wrapsAtWidth() throws {
        // Given
        let style = style()

        // When
        let layout = try sut.layout("aa bb cc", style: style, face: face, width: 110, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 90, height: 100))
        #expect(layout.lineCount == 2)
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("aa bb "), ids("cc")])
        #expect(layout.runs[1].glyphs.first == glyph("c", 0, 87))
    }

    @Test("a piece wider than the width alone overflows on its own line, and \\n always breaks")
    func breaksAtNewlineAndOverflows() throws {
        // Given
        let style = style()

        // When
        let long = try sut.layout("a bbbbbb", style: style, face: face, width: 50, place: place, kind: "title")
        let newline = try sut.layout("a\n\nb", style: style, face: face, width: 500, place: place, kind: "title")

        // Then
        #expect(long.lineCount == 2)
        #expect(long.size.width == 120)
        #expect(newline.lineCount == 3)
        #expect(newline.runs.map { $0.glyphs.map(\.y) } == [[37], [137]])
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
        let style = style()

        // When
        let layout = try sut.layout(text, style: style, face: face, width: width, place: place, kind: "title")

        // Then
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == lines.map(ids))
    }

    @Test("a Korean word wider than its line starts a line and breaks inside it, where UAX #14 allows")
    func breaksWideWordInside() throws {
        // Given
        let style = style()

        // When
        let layout = try sut.layout("가 결제하기버튼", style: style, face: face, width: 100, place: place, kind: "title")

        // Then
        #expect(layout.runs.map { $0.glyphs.map(\.id) } == [ids("가 "), ids("결제하기버"), ids("튼")])
        #expect(layout.size.width == 100)
    }

    @Test(
        "lines align left, centre or right in the box of the widest",
        arguments: [(TextAlignment.left, 0.0), (.center, 35), (.right, 70)]
    )
    func alignsLines(
        align: TextAlignment,
        x: Double
    ) throws {
        // Given
        let style = style(align: align)

        // When
        let layout = try sut.layout("aa bb c ", style: style, face: face, width: 100, place: place, kind: "title")

        // Then
        #expect(layout.runs[1].glyphs.first?.x == x)
    }

    @Test("a background's padding grows the box and moves the text in, and the line height spaces the baselines")
    func padsBackground() throws {
        // Given
        let background = TextBackground(color: Color(written: "#000000"), padding: Size(width: 16, height: 8), radius: 4)
        let style = style(lineHeight: 64, background: background)

        // When
        let layout = try sut.layout("a\nb", style: style, face: face, width: 500, place: place, kind: "title")

        // Then
        #expect(layout.size == Size(width: 52, height: 144))
        #expect(layout.runs.map(\.glyphs) == [[glyph("a", 16, 52)], [glyph("b", 16, 116)]])
        #expect(layout.background == background)
    }

    @Test("characters the face lacks are set in the face the shaper falls back to, in a run of their own")
    func keepsFallbackFace() throws {
        // Given
        let style = style()

        // When
        let layout = try sut.layout("a✓b", style: style, face: face, width: 500, place: place, kind: "title")

        // Then
        #expect(layout.runs.map(\.face) == [face, ShaperTable.fallback, face])
        #expect(layout.runs.map { $0.glyphs.map(\.x) } == [[0], [20], [40]])
    }

    @Test("a one-line style never wraps, and has no width when none is given")
    func keepsOneLine() throws {
        // Given
        let style = style(lines: 1)

        // When
        let fits = try sut.layout("aa bb cc", style: style, face: face, width: 150, place: place, kind: "label")
        let unbounded = try sut.layout("aa bb cc", style: self.style(), face: face, width: nil, place: place, kind: "label")

        // Then
        #expect(fits.lineCount == 1)
        #expect(unbounded.lineCount == 1)
        #expect(unbounded.size.width == 140)
    }

    @Test(
        "a one-line style stops on text wider than its room, a word it would break inside too, and on a line break",
        arguments: [
            (
                "aa bb cc",
                "title (label): the text is 140 wide on one line, wider than its room of 100, and a cut line would "
                    + "say something else"
            ),
            ("a\nb", "title (label): the text takes 2 lines, and its style allows at most 1"),
            (
                "결제하기버튼",
                "title (label): the text is 120 wide on one line, wider than its room of 100, and a cut line would "
                    + "say something else"
            )
        ]
    )
    func refusesOneLineOverflow(
        text: String,
        message: String
    ) throws {
        // Given
        let style = style(lines: 1)

        // When, Then
        let error = #expect(throws: TextError.self) {
            try sut.layout(text, style: style, face: face, width: 100, place: place, kind: "label")
        }
        #expect(error?.description == message)
    }

    @Test(
        "a style of two lines takes text that wraps or breaks to two lines",
        arguments: [("aa bb cc", 100.0), ("aa\nbb", 500.0)]
    )
    func keepsLineLimit(
        text: String,
        width: Double
    ) throws {
        // Given
        let style = style(lines: 2)

        // When
        let layout = try sut.layout(text, style: style, face: face, width: width, place: place, kind: "title")

        // Then
        #expect(layout.lineCount == 2)
    }

    @Test(
        "a style of two lines stops on text that needs a third line, by wrapping or at a line break",
        arguments: [("aa bb cc", 50.0), ("aa bb cc\ndd", 100.0), ("a\nb\nc", 500.0)]
    )
    func refusesLinesPastLimit(
        text: String,
        width: Double
    ) throws {
        // Given
        let style = style(lines: 2)

        // When, Then
        let error = #expect(throws: TextError.self) {
            try sut.layout(text, style: style, face: face, width: width, place: place, kind: "title")
        }
        #expect(error?.description == "title (title): the text takes 3 lines, and its style allows at most 2")
    }

    // MARK: - Private
    private func style(
        lineHeight: Double = 50,
        background: TextBackground? = nil,
        align: TextAlignment = .left,
        lines: Int? = nil
    ) -> TextStyle {
        TextStyle(
            families: ["Apple SD Gothic Neo"],
            pack: nil,
            size: 40,
            weight: .bold,
            color: text,
            emphasis: emphasis,
            lineHeight: lineHeight,
            stroke: nil,
            background: background,
            align: align,
            lines: lines
        )
    }

    private func glyph(
        _ character: Unicode.Scalar,
        _ x: Double,
        _ y: Double
    ) -> PositionedGlyph {
        PositionedGlyph(id: Int(character.value), x: x, y: y)
    }

    private func ids(_ text: String) -> [Int] {
        text.unicodeScalars.map { Int($0.value) }
    }
}
