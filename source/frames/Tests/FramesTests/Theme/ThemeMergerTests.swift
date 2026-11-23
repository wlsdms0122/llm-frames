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
          "shapes": { "outline": { "stroke": { "width": 10 } } },
          "defaults": { "transition": { "preset": "frames/push-up", "seconds": 0.3 },
                        "animation": { "title": { "subtitle": "frames/pop", "headline": "none", "label": "frames/pop" }, "shape": "frames/wipe", "media": "frames/pop" } } }
        """#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a form's theme merges key by key through the theme's structure")
    func mergesKeyByKey() throws {
        // Given
        let file = try Fixture.json(shorts)

        // When
        let theme = try #require(try sut.merge([ThemeLayer(value: file, place: .root)]).value.objectValue)

        // Then
        let colors = theme["colors"]?.objectValue
        let subtitle = theme["styles"]?.objectValue?["subtitle"]?.objectValue
        let outline = theme["shapes"]?.objectValue?["outline"]?.objectValue
        let defaults = theme["defaults"]?.objectValue
        let animation = defaults?["animation"]?.objectValue
        #expect(theme["baseWidth"] == .number(1080))
        #expect(colors?["accent"] == .string("#FF3B30"))
        #expect(colors?["text"] == .string("#FFFFFF"))
        #expect(subtitle?["size"] == .number(66))
        #expect(subtitle?["weight"] == .string("regular"))
        #expect(subtitle?["background"] == .bool(false))
        #expect(subtitle?["placement"] == .string("bottom"))
        #expect(outline?.keys == ["stroke"])
        #expect(outline?["stroke"] == (try Fixture.json(#"{ "width": 10 }"#)))
        #expect(defaults?["filter"] == .string("none"))
        #expect(defaults?["transition"] == (try Fixture.json(#"{ "preset": "frames/push-up", "seconds": 0.3 }"#)))
        #expect(animation?["title"] == (try Fixture.json(#"{ "subtitle": "frames/pop", "headline": "none", "label": "frames/pop" }"#)))
        #expect(animation?["adjust"] == .string("none"))
    }

    @Test("a list replaces the one under it whole, and an object merges key by key at every depth")
    func replacesListsAndMergesObjects() throws {
        // Given
        let file = try Fixture.json(##"{ "font": ["Inter"], "styles": { "subtitle": { "background": { "radius": 4 }, "stroke": { "color": "#FF0000" } } } }"##)

        // When
        let theme = try #require(try sut.merge([ThemeLayer(value: file, place: .root)]).value.objectValue)

        // Then
        let subtitle = theme["styles"]?.objectValue?["subtitle"]?.objectValue
        #expect(theme["font"] == .array([.string("Inter")]))
        #expect(subtitle?["background"] == (try Fixture.json(##"{ "radius": 4 }"##)))
        #expect(subtitle?["stroke"] == (try Fixture.json(##"{ "width": 3, "color": "#FF0000" }"##)))
    }

    @Test("a stronger theme writing a shape style's stroke colour keeps the weaker one's width")
    func keepsWeakerStrokeWidth() throws {
        // Given
        let weaker = ThemeLayer(value: try Fixture.json(##"{ "shapes": { "bar": { "stroke": { "width": 6, "cap": "round" } } } }"##), place: .root)
        let stronger = ThemeLayer(value: try Fixture.json(##"{ "shapes": { "bar": { "stroke": { "color": "#FF0000" } } } }"##), place: .root)

        // When
        let theme = try sut.merge([weaker, stronger])

        // Then
        #expect(theme.shapeStyle(named: "bar")?["stroke"] == (try Fixture.json(##"{ "width": 6, "cap": "round", "color": "#FF0000" }"##)))
    }

    @Test("a shadow of true in a style is the weaker theme's shadow for that style")
    func expandsShadowShorthand() throws {
        // Given
        let weaker = ThemeLayer(value: try Fixture.json(##"{ "shapes": { "bar": { "fill": "#FFFFFF", "shadow": { "radius": 5 } } } }"##), place: .root)
        let stronger = ThemeLayer(value: try Fixture.json(##"{ "shapes": { "bar": { "shadow": true } } }"##), place: .root)

        // When
        let theme = try sut.merge([weaker, stronger])

        // Then
        #expect(theme.shapeStyle(named: "bar")?["shadow"] == (try Fixture.json(##"{ "radius": 5 }"##)))
    }

    @Test("a default choice that names a preset replaces the weaker default whole, its arguments with it")
    func replacesDefaultChoice() throws {
        // Given
        let weaker = ThemeLayer(value: try Fixture.json(##"{ "defaults": { "transition": { "preset": "frames/push-up", "seconds": 0.3 } } }"##), place: .root)
        let stronger = ThemeLayer(value: try Fixture.json(##"{ "defaults": { "transition": "frames/fade" } }"##), place: .root)

        // When
        let defaults = try sut.merge([weaker, stronger]).value.objectValue?["defaults"]?.objectValue

        // Then
        #expect(defaults?["transition"] == .string("frames/fade"))
    }

    @Test("a stronger layer wins: base, then the theme file, then the document")
    func appliesPrecedence() throws {
        // Given
        let file = try Fixture.json(##"{ "colors": { "accent": "#111111", "text": "#222222" }, "styles": { "subtitle": { "color": "text" } } }"##)
        let document = try Fixture.json(##"{ "colors": { "accent": "#333333" } }"##)

        // When
        let documentTheme = try sut.merge([ThemeLayer(value: file, place: .root), ThemeLayer(value: document, place: .root)])

        // Then
        let colors = documentTheme.value.objectValue?["colors"]?.objectValue
        #expect(colors?["accent"] == .string("#333333"))
        #expect(colors?["text"] == .string("#222222"))
        #expect(colors?["background"] == .string("#000000"))
        let subtitle = documentTheme.value.objectValue?["styles"]?.objectValue?["subtitle"]?.objectValue
        #expect(subtitle?["color"] == .string("text"))
        #expect(subtitle?["size"] != nil)
    }

    @Test("a layer with an unknown key stops before anything is merged")
    func refusesUnknownKey() throws {
        // Given
        let file = try Fixture.json(#"{ "styles": { "caption": { "size": 30, "family": "Inter" } } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([ThemeLayer(value: file, place: .root)]) }
        #expect(error?.description == #"styles.caption (style): unknown key "family". Allowed: font, size, weight, italic, tracking, kerning, features, baselineShift, color, lineHeight, stroke, background, highlight, underline, textOrientation, textCombineUpright, placement, offset, writingMode, direction, align, lines"#)
    }

    @Test(
        "a merged style's weight, features and lines are checked by the rules the key check applies",
        arguments: [
            (#""weight": 950"#, "styles.note.weight: expected a whole number from 100 to 900 or a weight name"),
            (#""features": { "kern": 0 }"#, "styles.note.features.kern: `kern` is set by `kerning`"),
            (#""features": { "liga": 0.5 }"#, "styles.note.features.liga: expected a whole number, 0 or more"),
            (#""lines": 1.5"#, "styles.note.lines: expected a whole number, 1 or more")
        ]
    )
    func refusesBrokenStyleBelow(style: String, message: String) throws {
        // Given
        let base = try #require(MergedTheme.base.value.objectValue)
        let styles = try #require(base["styles"]?.objectValue)
        let note = try Fixture.json(#"{ "size": 20, \#(style) }"#)
        let theme = MergedTheme(value: .object(base.setting("styles", to: .object(styles.setting("note", to: note)))), layers: [])

        // When, Then
        let error = #expect(throws: LookError.self) {
            try sut.merge([], over: theme)
        }
        #expect(error?.description == message)
    }

    @Test("a stroke whose layers together give no width stops after the merge, naming the layer that writes it")
    func refusesStrokeWithoutWidth() throws {
        // Given
        let off = ThemeLayer(value: try Fixture.json(##"{ "styles": { "subtitle": { "stroke": false } } }"##), place: .root)
        let partial = ThemeLayer(value: try Fixture.json(##"{ "styles": { "subtitle": { "stroke": { "color": "#000000" } } } }"##), place: .root)

        // When, Then
        let error = #expect(throws: LookError.self) { try sut.merge([off, partial]) }
        #expect(error?.description == #"styles.subtitle.stroke: missing key "width", which no layer gives"#)
    }

    @Test("a reference to a colour or style that the merged theme lacks stops")
    func refusesMissingReference() throws {
        // Given
        let colour = try Fixture.json(#"{ "styles": { "caption": { "size": 30, "color": "brand" } } }"#)
        let style = try Fixture.json(#"{ "defaults": { "animation": { "title": { "caption": "frames/pop" } } } }"#)
        let defined = try Fixture.json(##"{ "colors": { "brand": "#123456" }, "styles": { "caption": { "size": 30, "color": "brand" } }, "defaults": { "animation": { "title": { "caption": "frames/pop" } } } }"##)

        // When, Then
        let colourError = #expect(throws: ThemeError.self) { try sut.merge([ThemeLayer(value: colour, place: .root)]) }
        let styleError = #expect(throws: ThemeError.self) { try sut.merge([ThemeLayer(value: style, place: .root)]) }
        #expect(colourError?.description == #"styles.caption.color (style): colour "brand" is not in colors"#)
        #expect(styleError?.description == #"defaults.animation.title.caption (title animations): style "caption" is not in styles, "#
            + #"which hold "subtitle", "title""#)
        _ = try sut.merge([ThemeLayer(value: defined, place: .root)])
    }

    @Test("a colour named by a weaker layer can be referred to by a stronger one")
    func resolvesReferencesAfterMerging() throws {
        // Given
        let file = try Fixture.json(##"{ "colors": { "brand": "#123456" } }"##)
        let document = try Fixture.json(#"{ "shapes": { "pointer": { "stroke": { "width": 4, "color": "brand" } } } }"#)

        // When, Then
        _ = try sut.merge([ThemeLayer(value: file, place: .root), ThemeLayer(value: document, place: .root)])
    }

    @Test(
        "a shape style takes only fill, stroke, radius, outset and shadow, and the colours it names are the theme's",
        arguments: [
            (#"{ "shapes": { "box": { "width": 8, "radius": 18 } } }"#, #"shapes.box (shape style): unknown key "width". Allowed: fill, stroke, radius, outset, shadow"#),
            (#"{ "shapes": { "outline": { "stroke": { "color": "accent" } } } }"#, #"shapes.outline.stroke: missing key "width", which no layer gives"#),
            (#"{ "shapes": { "outline": { "fill": "brand" } } }"#, #"shapes.outline.fill (shape style): colour "brand" is not in colors"#),
            (#"{ "shapes": { "outline": { "stroke": { "width": 2, "color": "brand" } } } }"#, #"shapes.outline.stroke.color (stroke): colour "brand" is not in colors"#),
            (#"{ "shapes": { "outline": { "shadow": { "color": "brand" } } } }"#, #"shapes.outline.shadow.color (shadow): colour "brand" is not in colors"#)
        ]
    )
    func checksShapeStyle(
        layer: String,
        message: String
    ) throws {
        // Given
        let file = try Fixture.json(layer)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.merge([ThemeLayer(value: file, place: .root)]) }
        #expect("\(error.map { "\($0)" } ?? "no error")" == message)
    }

    @Test("a colour in colors is written out, as a hex colour or a color() value")
    func refusesNamedColourInColors() throws {
        // Given
        let file = try Fixture.json(#"{ "colors": { "brand": "accent" } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([ThemeLayer(value: file, place: .root)]) }
        #expect(error?.description == #"colors.brand (colors): "accent" is not #RRGGBB, #RRGGBBAA or color(<space> r g b / a), with finite components and an alpha from 0 to 1, in srgb, srgb-linear, display-p3 or rec2020"#)
    }

    @Test("a default transition of 0 seconds or less stops at its place in the theme")
    func refusesNonPositiveDefaultTransition() throws {
        // Given
        let file = try Fixture.json(#"{ "defaults": { "transition": { "preset": "frames/flash", "seconds": 0 } } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([ThemeLayer(value: file, place: .root)]) }
        #expect(error?.description == "defaults.transition.seconds (transition choice): 0 is not above 0")
    }

    @Test(
        "a weaker layer's value outside its domain stops at that layer, naming it, though a stronger layer replaces it",
        arguments: [
            (
                ##"{ "styles": { "note": { "size": 20, "highlight": { "color": "#FF0000", "padding": [-4, 0] } } } }"##,
                #"{ "styles": { "note": { "highlight": { "padding": [4, 2] } } } }"#,
                "theme.json: styles.note.highlight.padding[0] (highlight): -4 is not 0 or more"
            ),
            (#"{ "baseWidth": 0 }"#, #"{ "baseWidth": 1080 }"#, "theme.json: baseWidth (theme): 0 is not above 0"),
            (
                #"{ "shapes": { "card": { "stroke": { "width": -2 } } } }"#,
                #"{ "shapes": { "card": { "stroke": { "width": 4 } } } }"#,
                "theme.json: shapes.card.stroke.width (stroke): -2 is not above 0"
            )
        ]
    )
    func refusesReplacedValueOutsideDomain(
        weaker: String,
        stronger: String,
        message: String
    ) throws {
        // Given
        let file = ThemeLayer(value: try Fixture.json(weaker), place: Place(file: "theme.json", components: []))
        let document = ThemeLayer(
            value: try Fixture.json(stronger),
            place: Place(file: "doc.json", components: [.key("theme")])
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.merge([file, document]) }
        #expect(error?.description == message)
    }
}
