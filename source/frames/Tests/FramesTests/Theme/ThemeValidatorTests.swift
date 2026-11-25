//
//  ThemeValidatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("ThemeValidator Tests")
struct ThemeValidatorTests {
    // MARK: - Property
    private let sut = ThemeValidator()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a default naming a preset that is not there stops at its place in the theme",
        arguments: [
            (
                #"{ "defaults": { "transition": "dissolve" } }"#,
                #"defaults.transition (defaults): unknown transition preset "dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "transition": { "preset": "dissolve", "seconds": 1 } } }"#,
                #"defaults.transition (defaults): unknown transition preset "dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "filter": "grain" } }"#,
                #"defaults.filter (defaults): unknown filter preset "grain". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "filter": ["frames/warm", "grain"] } }"#,
                #"defaults.filter[1] (defaults): unknown filter preset "grain". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "animation": { "media": "mine/spin" } } }"#,
                #"defaults.animation.media (animation defaults): unknown animation preset "mine/spin". The pack "mine" holds the animation presets mine/wipe-in"#
            ),
            (
                #"{ "defaults": { "animation": { "adjustment": { "entrance": "frames/pop", "exit": "mine/spin" } } } }"#,
                #"defaults.animation.adjustment (animation defaults): unknown animation preset "mine/spin". The pack "mine" holds the animation presets mine/wipe-in"#
            ),
            (
                #"{ "defaults": { "animation": { "title": { "subtitle": "mine/spin" } } } }"#,
                #"defaults.animation.title.subtitle (title animations): unknown animation preset "mine/spin". The pack "mine" holds the animation presets mine/wipe-in"#
            ),
            (
                #"{ "shapes": { "pointer": { "stroke": { "width": 4, "end": "arrow" } } } }"#,
                #"shapes.pointer.stroke.end (shape style): unknown head preset "arrow". Did you mean "frames/arrow"? A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "shapes": { "pointer": { "stroke": { "width": 4, "start": { "preset": "mine/hook", "scale": 2 } } } } }"#,
                #"shapes.pointer.stroke.start (shape style): unknown head preset "mine/hook". The pack "mine" holds no head presets"#
            )
        ]
    )
    func refusesUnknownPreset(
        layer: String,
        message: String
    ) throws {
        // Given
        let theme = try ThemeMerger().merge([ThemeLayer(value: Fixture.json(layer), place: .root)])

        // When, Then
        let error = #expect(throws: ThemeError.self) { try sut.defaults(in: theme, presets: Fixture.presets) }
        #expect(error?.description == message)
    }

    @Test("defaults that name presets that are there, or none on a side, give their choices")
    func readsKnownPresets() throws {
        // Given
        let theme = try ThemeMerger().merge([
            ThemeLayer(value: Fixture.json(#"""
                { "defaults": { "transition": { "preset": "frames/flash", "seconds": 1 }, "filter": ["frames/warm"],
                                "animation": { "title": { "subtitle": "frames/fade" }, "shape": { "entrance": "frames/wipe", "exit": "none" } } } }
                """#), place: .root)
        ])

        // When
        let defaults = try sut.defaults(in: theme, presets: Fixture.presets)

        // Then
        let place = Place.root.appending(key: "defaults")
        #expect(defaults.transition == .preset(
            PresetInstance(name: "frames/flash", place: place.appending(key: "transition")),
            seconds: 1
        ))
        let animationPlace = place.appending(key: "animation")
        let fade = PresetInstance(name: "frames/fade", place: animationPlace.appending(key: "title").appending(key: "subtitle"))
        #expect(defaults.titleAnimations == [
            "subtitle": AnimationChoice(entrance: fade, loop: fade, exit: fade, by: nil, stagger: nil, order: nil)
        ])
        #expect(defaults.shapeAnimation == AnimationChoice(
            entrance: PresetInstance(name: "frames/wipe", place: animationPlace.appending(key: "shape").appending(key: "entrance")),
            loop: nil,
            exit: nil,
            by: nil,
            stagger: nil,
            order: nil
        ))
        #expect(defaults.mediaAnimation == AnimationChoice.none)
    }

    @Test(
        "a theme group the base theme does not hold is an unknown key",
        arguments: [
            #"{ "image": { "bannerPadding": 40 } }"#,
            #"{ "layout": { "gap": 40, "padding": 40 } }"#,
            #"{ "area": { "padding": 14, "cropPadding": 40 } }"#,
            ##"{ "shapes": { "box": { "width": 8, "radius": 18, "color": "#ED2929" } } }"##,
            #"{ "shapes": { "arrow": { "width": 10, "length": 160, "head": 32 } } }"#
        ]
    )
    func refusesRemovedGroup(_ layer: String) throws {
        // Given
        let theme = ThemeLayer(value: try Fixture.json(layer), place: .root)

        // When, Then
        #expect(throws: ModelError.self) { try sut.checkKeys(of: theme) }
    }

    @Test("a style that names a colour the base theme does not hold stops", arguments: ["onAccent", "border", "emphasis"])
    func refusesRemovedColor(_ name: String) throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "note": { "size": 20, "color": "\#(name)" } } }"#),
            place: .root
        )

        // When, Then
        let error = #expect(throws: ThemeError.self) { try ThemeMerger().merge([layer]) }
        #expect(error?.description == #"styles.note.color (style): colour "\#(name)" is not in colors"#)
    }

    @Test(
        "a style's lines that is not a whole number of 1 or more stops where it is written",
        arguments: ["0", "-1", "1.5"]
    )
    func refusesBadLines(_ lines: String) throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "note": { "size": 20, "lines": \#(lines) } } }"#),
            place: .root
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkKeys(of: layer) }
        #expect(error?.description == "styles.note.lines (style): expected a whole number, 1 or more, found \(lines)")
    }

    @Test(
        "a theme's length outside its domain stops where it is written",
        arguments: [
            (#"{ "border": { "width": 0 } }"#, "border.width (border): 0 is not above 0"),
            (#"{ "shadow": { "radius": -1 } }"#, "shadow.radius (shadow): -1 is not 0 or more"),
            (#"{ "styles": { "note": { "stroke": { "width": -2 } } } }"#, "styles.note.stroke.width (stroke): -2 is not above 0"),
            (#"{ "styles": { "note": { "highlight": { "radius": -4 } } } }"#, "styles.note.highlight.radius (highlight): -4 is not 0 or more"),
            (
                #"{ "styles": { "note": { "highlight": { "padding": [2, -4] } } } }"#,
                "styles.note.highlight.padding[1] (highlight): -4 is not 0 or more"
            ),
            (#"{ "baseWidth": 0 }"#, "baseWidth (theme): 0 is not above 0"),
            (#"{ "placement": { "padding": -8 } }"#, "placement.padding (placement): -8 is not 0 or more"),
            (#"{ "styles": { "note": { "size": 0 } } }"#, "styles.note.size (style): 0 is not above 0"),
            (#"{ "styles": { "note": { "lineHeight": -10 } } }"#, "styles.note.lineHeight (style): -10 is not above 0"),
            (#"{ "styles": { "note": { "offset": -1 } } }"#, "styles.note.offset (style): -1 is not 0 or more")
        ]
    )
    func refusesLookLengthOutsideDomain(theme: String, message: String) throws {
        // Given
        let layer = ThemeLayer(value: try Fixture.json(theme), place: .root)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkKeys(of: layer) }
        #expect(error?.description == message)
    }

    @Test("a theme's length that is not a number stops naming the domain it takes")
    func refusesLookLengthOfWrongType() throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "note": { "highlight": { "padding": [2, "wide"] } } } }"#),
            place: .root
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkKeys(of: layer) }
        #expect(error?.description == #"styles.note.highlight.padding[1] (highlight): expected a number 0 or more, found "wide""#)
    }

    @Test("a style's lines of 1 passes the key check")
    func acceptsOneLine() throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "note": { "size": 20, "lines": 1 } } }"#),
            place: .root
        )

        // When, Then
        try sut.checkKeys(of: layer)
    }

    @Test(
        "a style's feature that is not a four-character tag, `kern`, or a setting that is not a whole number 0 or more stops",
        arguments: [
            (#"{ "kern": 0 }"#, "styles.note.features.kern (features): `kern` is set by `kerning`"),
            (#"{ "lig": 1 }"#, "styles.note.features.lig (features): a feature tag is four printable ASCII characters"),
            (#"{ "ligaa": 1 }"#, "styles.note.features.ligaa (features): a feature tag is four printable ASCII characters"),
            (#"{ "liga": -1 }"#, "styles.note.features.liga (features): expected a whole number, 0 or more, found -1"),
            (#"{ "liga": 0.5 }"#, "styles.note.features.liga (features): expected a whole number, 0 or more, found 0.5")
        ]
    )
    func refusesBadFeatures(features: String, message: String) throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "note": { "size": 20, "features": \#(features) } } }"#),
            place: .root
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkKeys(of: layer) }
        #expect(error?.description == message)
    }

    @Test(
        "a style's weight is a whole number from 100 to 900 or a weight name",
        arguments: [
            ("50", "styles.note.weight (style): expected a whole number from 100 to 900 or a weight name, found 50"),
            ("950", "styles.note.weight (style): expected a whole number from 100 to 900 or a weight name, found 950"),
            ("450.5", "styles.note.weight (style): expected a whole number from 100 to 900 or a weight name, found 450.5"),
            (#""heavy""#, #"styles.note.weight (style): unknown value "heavy". Allowed: thin, extralight, light, regular, medium, semibold, bold, extrabold, black"#)
        ]
    )
    func refusesBadWeight(weight: String, message: String) throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"{ "styles": { "note": { "size": 20, "weight": \#(weight) } } }"#),
            place: .root
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkKeys(of: layer) }
        #expect(error?.description == message)
    }

    @Test(
        "a style's kerning, placement and align outside their names stop where they are written",
        arguments: [
            (#""kerning": "auto""#, #"styles.note.kerning (style): unknown value "auto". Allowed: metrics, none"#),
            (#""align": "justify""#, #"styles.note.align (style): unknown value "justify". Allowed: left, center, right"#)
        ]
    )
    func refusesUnknownName(key: String, message: String) throws {
        // Given
        let layer = ThemeLayer(value: try Fixture.json(#"{ "styles": { "note": { "size": 20, \#(key) } } }"#), place: .root)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkKeys(of: layer) }
        #expect(error?.description == message)
    }

    @Test("a style's typography keys pass the key check")
    func acceptsTypography() throws {
        // Given
        let layer = ThemeLayer(
            value: try Fixture.json(#"""
                { "styles": { "note": { "size": 20, "font": ["Inter"], "weight": 350, "italic": true, "tracking": -20,
                                        "kerning": "none", "features": { "ss01": 2 }, "baselineShift": -4,
                                        "highlight": false, "underline": { "offset": 3 } } } }
                """#),
            place: .root
        )

        // When, Then
        try sut.checkKeys(of: layer)
    }
}
