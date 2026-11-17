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
        let style = sut.style(named: "caption", scale: 1)

        // Then
        #expect(style == TextStyle(
            families: ["Helvetica Neue", "Apple SD Gothic Neo"],
            pack: nil,
            size: 40,
            weight: .regular,
            color: Color(written: "#FFFFFF"),
            emphasis: Color(written: "#FFFFFF"),
            lineHeight: 50,
            stroke: nil,
            background: nil,
            align: .left,
            lines: nil
        ))
    }

    @Test("a background without colour, padding or radius, and a stroke without colour, take the plain values")
    func defaultsBackgroundAndStroke() throws {
        // Given
        let sut = try theme(#"""
            { "colors": { "background": "#112233", "text": "#445566" },
              "styles": { "caption": { "size": 40, "background": {}, "stroke": { "width": 4 } } } }
            """#)

        // When
        let style = sut.style(named: "caption", scale: 1)

        // Then
        #expect(style.background == TextBackground(
            color: Color(written: "#112233"),
            padding: Size(width: 0, height: 0),
            radius: 0
        ))
        #expect(style.stroke == TextStroke(width: 4, color: Color(written: "#445566")))
    }

    @Test("a written style keeps its values, colours by name or by value, with its lengths times the scale")
    func readsWrittenStyle() throws {
        // Given
        let sut = try theme(#"""
            { "styles": { "caption": { "size": 40, "weight": "bold", "color": "accent", "emphasis": "#00ff0080",
                                       "lineHeight": 60, "stroke": { "width": 4, "color": "shadow" },
                                       "background": { "color": "#000000", "padding": [10, 20], "radius": 8 },
                                       "align": "right", "lines": 1 } } }
            """#)

        // When
        let style = sut.style(named: "caption", scale: 0.5)

        // Then
        #expect(style == TextStyle(
            families: ["Helvetica Neue", "Apple SD Gothic Neo"],
            pack: nil,
            size: 20,
            weight: .bold,
            color: Color(written: "#FFFFFF"),
            emphasis: Color(written: "#00FF0080"),
            lineHeight: 30,
            stroke: TextStroke(width: 2, color: Color(written: "#00000080")),
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
        let style = sut.style(named: "subtitle", scale: 2)

        // Then
        #expect(style.background == nil)
        #expect(style.size == 96)
        #expect(style.lineHeight == 120)
    }

    @Test("a style's lines is the most lines its text may take, two for the base subtitle")
    func readsLines() throws {
        // Given
        let sut = try theme(#"{ "styles": { "caption": { "size": 40, "lines": 3 } } }"#)

        // When
        let caption = sut.style(named: "caption", scale: 1)
        let subtitle = sut.style(named: "subtitle", scale: 1)

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
        let style = sut.style(named: "subtitle", scale: 1)

        // Then
        #expect(style.stroke == nil)
    }

    @Test("a style's fonts are looked for in the pack of the theme that wrote the font list")
    func readsFontPack() throws {
        // Given
        let sut = try ThemeMerger().merge([
            ThemeLayer(value: Fixture.json(#"{ "font": ["Inter", "Apple SD Gothic Neo"] }"#), place: .root, pack: "shorts"),
            ThemeLayer(value: Fixture.json(#"{ "styles": { "label": { "size": 30 } } }"#), place: .root, pack: "other")
        ])

        // When
        let style = sut.style(named: "label", scale: 1)

        // Then
        #expect(style.families == ["Inter", "Apple SD Gothic Neo"])
        #expect(style.pack == "shorts")
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
        #expect(merged.style(named: "caption", scale: 1).size == 40)
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
