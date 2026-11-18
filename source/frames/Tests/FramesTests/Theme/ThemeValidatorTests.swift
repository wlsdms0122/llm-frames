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
                #"{ "defaults": { "filter": ["none", "grain"] } }"#,
                #"defaults.filter[1] (defaults): unknown filter preset "grain". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "animation": { "media": "mine/spin" } } }"#,
                #"defaults.animation.media (animation defaults): unknown animation preset "mine/spin". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "animation": { "adjust": { "entrance": "frames/pop", "exit": "mine/spin" } } } }"#,
                #"defaults.animation.adjust (animation defaults): unknown animation preset "mine/spin". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "defaults": { "animation": { "title": { "subtitle": "mine/spin" } } } }"#,
                #"defaults.animation.title.subtitle (title animations): unknown animation preset "mine/spin". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
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
                { "defaults": { "transition": { "preset": "frames/flash", "seconds": 1 }, "filter": ["frames/warm", "none"],
                                "animation": { "title": { "subtitle": "frames/fade" }, "shape": { "entrance": "frames/draw", "exit": "none" } } } }
                """#), place: .root)
        ])

        // When
        let defaults = try sut.defaults(in: theme, presets: Fixture.presets)

        // Then
        #expect(defaults.transition == .timed(preset: "frames/flash", seconds: 1))
        #expect(defaults.filter == [
            ThemeFilterPreset(
                preset: FilterPreset(description: "", operations: []),
                place: Place.root.appending(key: "defaults").appending(key: "filter").appending(index: 0)
            )
        ])
        #expect(defaults.titleAnimations == ["subtitle": .preset("frames/fade")])
        #expect(defaults.shapeAnimation == .split(entrance: "frames/draw", exit: "none"))
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

    @Test("a style that names a colour the base theme no longer holds stops", arguments: ["onAccent", "border", "emphasis"])
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
}
