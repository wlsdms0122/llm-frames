//
//  MergedThemeValueTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("MergedTheme Value Tests")
struct MergedThemeValueTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a style property that is not written takes the plain value")
    func defaultsUnwrittenProperties() throws {
        // Given
        let sut = try theme(#"{ "styles": { "caption": { "size": 40 } } }"#)

        // When
        let character = sut.characterStyle(named: "caption", scale: 1)
        let paragraph = sut.paragraphStyle(named: "caption", scale: 1)

        // Then
        #expect(character == CharacterStyle(
            families: ["Helvetica Neue", "Apple SD Gothic Neo"],
            weight: .regular,
            size: 40
        ))
        #expect(paragraph == ParagraphStyle(lineHeight: 50, background: nil, align: .left, lines: nil))
    }

    @Test("a background without colour, padding or radius takes the plain values")
    func defaultsBackground() throws {
        // Given
        let sut = try theme(#"""
            { "colors": { "background": "#112233" }, "styles": { "caption": { "size": 40, "background": {} } } }
            """#)

        // When
        let paragraph = sut.paragraphStyle(named: "caption", scale: 1)

        // Then
        #expect(paragraph.background == TextBackground(
            color: Color(written: "#112233"),
            padding: Size(width: 0, height: 0),
            radius: 0
        ))
    }

    @Test("a written style keeps its values, with its lengths times the scale")
    func readsWrittenStyle() throws {
        // Given
        let sut = try theme(#"""
            { "styles": { "caption": { "size": 40, "weight": "bold", "color": "accent",
                                       "lineHeight": 60, "stroke": { "width": 4, "color": "shadow" },
                                       "background": { "color": "#000000", "padding": [10, 20], "radius": 8 },
                                       "align": "right", "lines": 1 } } }
            """#)

        // When
        let character = sut.characterStyle(named: "caption", scale: 0.5)
        let paragraph = sut.paragraphStyle(named: "caption", scale: 0.5)

        // Then
        #expect(character == CharacterStyle(
            families: ["Helvetica Neue", "Apple SD Gothic Neo"],
            weight: .bold,
            size: 20
        ))
        #expect(paragraph == ParagraphStyle(
            lineHeight: 30,
            background: TextBackground(color: Color(written: "#000000"), padding: Size(width: 10, height: 5), radius: 4),
            align: .right,
            lines: 1
        ))
    }

    @Test("a background of false is none, and a line height left out follows the scaled size")
    func readsNoBackground() throws {
        // Given
        let sut = try theme(#"{ "styles": { "subtitle": { "background": false } } }"#)

        // When
        let character = sut.characterStyle(named: "subtitle", scale: 2)
        let paragraph = sut.paragraphStyle(named: "subtitle", scale: 2)

        // Then
        #expect(paragraph.background == nil)
        #expect(character.size == 96)
        #expect(paragraph.lineHeight == 120)
    }

    @Test("a style's lines is the most lines its text may take, two for the base subtitle")
    func readsLines() throws {
        // Given
        let sut = try theme(#"{ "styles": { "caption": { "size": 40, "lines": 3 } } }"#)

        // When
        let caption = sut.paragraphStyle(named: "caption", scale: 1)
        let subtitle = sut.paragraphStyle(named: "subtitle", scale: 1)

        // Then
        #expect(caption.lines == 3)
        #expect(subtitle.lines == 2)
    }

    @Test("a stroke of false in a stronger theme removes the stroke a weaker one gives")
    func readsNoStroke() throws {
        // Given
        let sut = try ThemeMerger().merge([
            ThemeLayer(value: Fixture.json(#"{ "styles": { "subtitle": { "stroke": { "width": 7 } } } }"#), place: .root),
            ThemeLayer(value: Fixture.json(#"{ "styles": { "subtitle": { "stroke": false } } }"#), place: .root)
        ])

        // When
        let style = sut.style(named: "subtitle")

        // Then
        #expect(style["stroke"] == .bool(false))
    }

    @Test("a style's fonts are looked for in the pack of the theme that wrote the font list")
    func readsFontPack() throws {
        // Given
        let sut = try ThemeMerger().merge([
            ThemeLayer(value: Fixture.json(#"{ "font": ["Inter", "Apple SD Gothic Neo"] }"#), place: .root, pack: "shorts"),
            ThemeLayer(value: Fixture.json(#"{ "styles": { "label": { "size": 30 } } }"#), place: .root, pack: "other")
        ])

        // When
        let style = sut.characterStyle(named: "label", scale: 1)
        let origin = sut.fontList(ofStyle: "label")

        // Then
        #expect(style.families == ["Inter", "Apple SD Gothic Neo"])
        #expect(origin == FontListOrigin(place: Place(components: [.key("font")]), kind: "theme", pack: "shorts"))
    }

    @Test("a style's typography is read with its size times the scale")
    func readsTypography() throws {
        // Given
        let sut = try theme(#"""
            { "styles": { "caption": { "size": 40, "font": ["Inter"], "weight": 300, "italic": true, "tracking": 40,
                                       "kerning": "none", "features": { "tnum": 1, "liga": 0 }, "baselineShift": 8,
                                       "highlight": { "padding": [2, 8], "radius": 4 },
                                       "underline": { "width": 2, "color": "accent" } } } }
            """#)

        // When
        let character = sut.characterStyle(named: "caption", scale: 0.5)

        // Then
        #expect(character == CharacterStyle(
            families: ["Inter"],
            weight: FontWeight(300),
            italic: true,
            size: 20,
            tracking: 40,
            isKerned: false,
            features: [FontFeature(tag: "tnum", value: 1), FontFeature(tag: "liga", value: 0)],
            isHighlighted: true,
            isUnderlined: true
        ))
        #expect(sut.fontList(ofStyle: "caption").place == Place(components: [.key("styles"), .key("caption"), .key("font")]))
    }

    @Test("`underline: true` is an underline, and a weight name is its number")
    func readsUnderlineOn() throws {
        // Given
        let sut = try theme(#"{ "styles": { "caption": { "size": 40, "weight": "semibold", "underline": true } } }"#)

        // When
        let character = sut.characterStyle(named: "caption", scale: 1)

        // Then
        #expect(character.isUnderlined)
        #expect(character.weight == FontWeight(600))
        #expect(character.italic == false)
        #expect(character.isKerned)
    }

    @Test("a style without a size stops when the theme is merged, unless a weaker theme gives it one")
    func refusesStyleWithoutSize() throws {
        // Given
        let sized = ThemeLayer(value: try Fixture.json(#"{ "styles": { "caption": { "size": 40 } } }"#), place: .root)
        let unsized = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "caption": { "weight": "bold" } } }"#),
            place: Place(file: "doc.json", components: [.key("theme")])
        )

        // When
        let merged = try ThemeMerger().merge([sized, unsized])

        // Then
        #expect(merged.characterStyle(named: "caption", scale: 1).size == 40)
        let error = #expect(throws: ThemeError.self) { try ThemeMerger().merge([unsized]) }
        #expect(error?.description == #"""
            doc.json: theme.styles.caption (style): style "caption" has no size, and text is set only in a style with one
            """#)
    }

    // MARK: - Private
    private func theme(_ text: String) throws -> MergedTheme {
        try ThemeMerger().merge([ThemeLayer(value: Fixture.json(text), place: .root)])
    }
}
