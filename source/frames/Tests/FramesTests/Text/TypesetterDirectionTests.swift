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
}
