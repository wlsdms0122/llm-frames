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
                #"{ "defaults": { "animation": { "title": { "headline": "mine/spin" } } } }"#,
                #"defaults.animation.title.headline (title animations): unknown animation preset "mine/spin". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
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
                                "animation": { "title": { "headline": "frames/fade" }, "shape": { "entrance": "frames/draw", "exit": "none" } } } }
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
        #expect(defaults.titleAnimations == ["label": .preset("frames/pop"), "headline": .preset("frames/fade")])
        #expect(defaults.shapeAnimation == .split(entrance: "frames/draw", exit: "none"))
        #expect(defaults.mediaAnimation == AnimationChoice.none)
    }
}
