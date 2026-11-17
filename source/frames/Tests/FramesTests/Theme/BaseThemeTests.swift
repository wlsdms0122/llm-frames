//
//  BaseThemeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("BaseTheme Tests")
struct BaseThemeTests {
    // MARK: - Property
    private let sut = BaseTheme.value

    // MARK: - Initializer
    // MARK: - Test
    @Test("the base theme passes its own key table and references")
    func passesItsOwnRules() throws {
        // Given
        let validator = ThemeValidator()

        // When, Then
        try validator.checkKeys(of: ThemeLayer(value: sut, place: .root))
        try validator.checkReferences(in: MergedTheme(value: sut, layers: []))
    }

    @Test("the base theme holds the values the specification gives")
    func holdsSpecificationValues() throws {
        // Given
        let theme = try #require(sut.objectValue)

        // When
        let colors = theme["colors"]?.objectValue
        let subtitle = theme["styles"]?.objectValue?["subtitle"]?.objectValue
        let defaults = theme["defaults"]?.objectValue

        // Then
        #expect(theme["baseWidth"] == .number(1206))
        #expect(theme["font"] == .array([.string("Apple SD Gothic Neo")]))
        #expect(colors?.keys == ["accent", "onAccent", "background", "text", "border", "emphasis", "shadow"])
        #expect(colors?["shadow"] == .string("#00000059"))
        #expect(theme["styles"]?.objectValue?.keys == ["subtitle", "headline", "label", "banner", "bannerHead", "heading"])
        #expect(subtitle?["background"] == (try Fixture.json(##"{ "color": "#000000B8", "padding": [12, 24], "radius": 16 }"##)))
        #expect(theme["shapes"]?.objectValue?.keys == ["box", "fill", "dim", "arrow", "border", "shadow", "label"])
        #expect(theme["area"] == (try Fixture.json(#"{ "padding": 14, "cropPadding": 40 }"#)))
        #expect(defaults?["transition"] == .string("cut"))
        #expect(defaults?["animation"] == (try Fixture.json(#"{ "title": { "label": "frames/pop" }, "shape": "none", "media": "none", "adjust": "none" }"#)))
    }

    @Test("the theme key table holds every group of the base theme and nothing else")
    func matchesKeyTable() throws {
        // Given
        let theme = try #require(sut.objectValue)

        // When
        let tableKeys = ThemeKeyTable.theme.keys
        let shapeKeys = ThemeKeyTable.shapes.keys

        // Then
        #expect(tableKeys == theme.keys)
        #expect(shapeKeys == theme["shapes"]?.objectValue?.keys)
    }
}
