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
                #"defaults.transition (defaults): unknown transition preset "dissolve""#
            ),
            (
                #"{ "defaults": { "transition": { "preset": "dissolve", "seconds": 1 } } }"#,
                #"defaults.transition (defaults): unknown transition preset "dissolve""#
            ),
            (
                #"{ "defaults": { "filter": "grain" } }"#,
                #"defaults.filter (defaults): unknown filter preset "grain""#
            ),
            (
                #"{ "defaults": { "filter": ["none", "grain"] } }"#,
                #"defaults.filter[1] (defaults): unknown filter preset "grain""#
            ),
            (
                #"{ "defaults": { "animation": { "media": "spin" } } }"#,
                #"defaults.animation.media (animation defaults): unknown animation preset "spin""#
            ),
            (
                #"{ "defaults": { "animation": { "adjust": { "entrance": "pop", "exit": "spin" } } } }"#,
                #"defaults.animation.adjust (animation defaults): unknown animation preset "spin""#
            ),
            (
                #"{ "defaults": { "animation": { "title": { "headline": "spin" } } } }"#,
                #"defaults.animation.title.headline (title animations): unknown animation preset "spin""#
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
                { "defaults": { "transition": { "preset": "flash", "seconds": 1 }, "filter": ["warm", "none"],
                                "animation": { "title": { "headline": "fade" }, "shape": { "entrance": "draw", "exit": "none" } } } }
                """#), place: .root)
        ])

        // When
        let defaults = try sut.defaults(in: theme, presets: Fixture.presets)

        // Then
        #expect(defaults.transition == .timed(preset: "flash", seconds: 1))
        #expect(defaults.titleAnimations == ["label": .preset("pop"), "headline": .preset("fade")])
        #expect(defaults.shapeAnimation == .split(entrance: "draw", exit: "none"))
        #expect(defaults.mediaAnimation == AnimationChoice.none)
    }
}
