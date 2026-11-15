//
//  ThemeMergerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("ThemeMerger Tests")
struct ThemeMergerTests {
    // MARK: - Property
    private let sut = ThemeMerger()
    private let shorts = #"""
        { "baseWidth": 1080,
          "colors": { "accent": "#FF3B30", "emphasis": "#FFE14D" },
          "styles": {
            "subtitle": { "size": 66, "background": false, "stroke": { "width": 7, "color": "#000000" }, "offset": 330 },
            "headline": { "size": 84, "offset": 110 },
            "label":    { "size": 40 } },
          "shapes": { "box": { "width": 10 } },
          "defaults": { "transition": { "preset": "push-up", "seconds": 0.3 },
                        "animation": { "title": { "subtitle": "pop", "headline": "none", "label": "pop" }, "shape": "draw", "media": "pop" } } }
        """#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a form's theme merges key by key through the theme's structure")
    func mergesKeyByKey() throws {
        // Given
        let file = try Fixture.json(shorts)

        // When
        let theme = try #require(try sut.merge([file]).objectValue)

        // Then
        let colors = theme["colors"]?.objectValue
        let subtitle = theme["styles"]?.objectValue?["subtitle"]?.objectValue
        let box = theme["shapes"]?.objectValue?["box"]?.objectValue
        let defaults = theme["defaults"]?.objectValue
        let animation = defaults?["animation"]?.objectValue
        #expect(theme["baseWidth"] == .number(1080))
        #expect(colors?["accent"] == .string("#FF3B30"))
        #expect(colors?["onAccent"] == .string("#FFFFFF"))
        #expect(subtitle?["size"] == .number(66))
        #expect(subtitle?["weight"] == .string("bold"))
        #expect(subtitle?["background"] == .bool(false))
        #expect(subtitle?["placement"] == .string("bottom"))
        #expect(box?["width"] == .number(10))
        #expect(box?["radius"] == .number(18))
        #expect(defaults?["filter"] == .string("none"))
        #expect(defaults?["transition"] == (try Fixture.json(#"{ "preset": "push-up", "seconds": 0.3 }"#)))
        #expect(animation?["title"] == (try Fixture.json(#"{ "label": "pop", "subtitle": "pop", "headline": "none" }"#)))
        #expect(animation?["adjust"] == .string("none"))
    }

    @Test("below the theme's structure a value replaces the one under it whole")
    func replacesBelowStructure() throws {
        // Given
        let file = try Fixture.json(#"{ "font": ["Inter"], "styles": { "subtitle": { "background": { "radius": 4 } } } }"#)

        // When
        let theme = try #require(try sut.merge([file]).objectValue)

        // Then
        #expect(theme["font"] == .array([.string("Inter")]))
        #expect(theme["styles"]?.objectValue?["subtitle"]?.objectValue?["background"] == (try Fixture.json(#"{ "radius": 4 }"#)))
    }

    @Test("a stronger layer wins: base, then the theme file, then the document, then the clip")
    func appliesPrecedence() throws {
        // Given
        let file = try Fixture.json(##"{ "colors": { "accent": "#111111", "text": "#222222" }, "shapes": { "box": { "color": "text" } } }"##)
        let document = try Fixture.json(##"{ "colors": { "accent": "#333333" } }"##)
        let clip = ClipThemeLayer.layer(forClip: try Fixture.object(##"{ "shape": "box", "color": "#444444" }"##), kind: .shape("box"))

        // When
        let documentTheme = try sut.merge([file, document])
        let clipTheme = try sut.merge([clip], over: documentTheme)

        // Then
        let colors = documentTheme.objectValue?["colors"]?.objectValue
        #expect(colors?["accent"] == .string("#333333"))
        #expect(colors?["text"] == .string("#222222"))
        #expect(colors?["border"] == .string("#D9D9D9"))
        #expect(documentTheme.objectValue?["shapes"]?.objectValue?["box"]?.objectValue?["color"] == .string("text"))
        #expect(clipTheme.objectValue?["shapes"]?.objectValue?["box"]?.objectValue?["color"] == .string("#444444"))
        #expect(clipTheme.objectValue?["shapes"]?.objectValue?["box"]?.objectValue?["width"] == .number(8))
    }

    @Test("a layer with an unknown key stops before anything is merged")
    func refusesUnknownKey() throws {
        // Given
        let file = try Fixture.json(#"{ "styles": { "caption": { "size": 30, "font": "Inter" } } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([file]) }
        #expect(error?.description == #"styles.caption (style): unknown key "font". Allowed: size, weight, color, emphasis, lineHeight, stroke, background, placement, offset, align, lines"#)
    }

    @Test("a reference to a colour or style that the merged theme lacks stops")
    func refusesMissingReference() throws {
        // Given
        let colour = try Fixture.json(#"{ "styles": { "caption": { "size": 30, "color": "brand" } } }"#)
        let style = try Fixture.json(#"{ "defaults": { "animation": { "title": { "caption": "pop" } } } }"#)
        let defined = try Fixture.json(##"{ "colors": { "brand": "#123456" }, "styles": { "caption": { "color": "brand" } }, "defaults": { "animation": { "title": { "caption": "pop" } } } }"##)

        // When, Then
        let colourError = #expect(throws: ThemeError.self) { try sut.merge([colour]) }
        let styleError = #expect(throws: ThemeError.self) { try sut.merge([style]) }
        #expect(colourError?.description == #"styles.caption.color (style): colour "brand" is not in colors"#)
        #expect(styleError?.description == #"defaults.animation.title.caption (title animations): style "caption" is not in styles"#)
        try sut.merge([defined])
    }

    @Test("a colour named by a weaker layer can be referred to by a stronger one")
    func resolvesReferencesAfterMerging() throws {
        // Given
        let file = try Fixture.json(##"{ "colors": { "brand": "#123456" } }"##)
        let document = try Fixture.json(#"{ "shapes": { "arrow": { "color": "brand" } } }"#)

        // When, Then
        try sut.merge([file, document])
    }

    @Test("a colour in colors is written in hexadecimal")
    func refusesNamedColourInColors() throws {
        // Given
        let file = try Fixture.json(#"{ "colors": { "brand": "accent" } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([file]) }
        #expect(error?.description == #"colors.brand (colors): "accent" is not #RRGGBB or #RRGGBBAA"#)
    }

    @Test("a default transition of 0 seconds or less stops at its place in the theme")
    func refusesNonPositiveDefaultTransition() throws {
        // Given
        let file = try Fixture.json(#"{ "defaults": { "transition": { "preset": "flash", "seconds": 0 } } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([file]) }
        #expect(error?.description == "defaults.transition.seconds (transition choice): expected a number above 0, found 0")
    }
}
