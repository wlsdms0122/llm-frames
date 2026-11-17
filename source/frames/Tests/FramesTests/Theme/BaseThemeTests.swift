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
        let styles = theme["styles"]?.objectValue
        let defaults = theme["defaults"]?.objectValue

        // Then
        #expect(theme["baseWidth"] == .number(1920))
        #expect(theme["font"] == .array([.string("Helvetica Neue"), .string("Apple SD Gothic Neo")]))
        #expect(theme["colors"] == (try Fixture.json(
            ##"{ "text": "#FFFFFF", "background": "#000000", "accent": "#FFFFFF", "shadow": "#00000080" }"##
        )))
        #expect(styles?["title"] == (try Fixture.json(
            #"{ "size": 96, "weight": "bold", "placement": "center", "align": "center" }"#
        )))
        #expect(styles?["subtitle"] == (try Fixture.json(
            ##"""
            { "size": 48, "weight": "regular", "stroke": { "width": 3, "color": "#000000" },
              "placement": "bottom", "offset": 108, "align": "center", "lines": 2 }
            """##
        )))
        #expect(theme["placement"] == (try Fixture.json(#"{ "padding": 96 }"#)))
        #expect(theme["border"] == (try Fixture.json(#"{ "width": 4, "color": "accent" }"#)))
        #expect(theme["shadow"] == (try Fixture.json(#"{ "radius": 32, "offset": [0, 12], "color": "shadow" }"#)))
        #expect(defaults?["transition"] == .string("cut"))
        #expect(defaults?["filter"] == .string("none"))
        #expect(defaults?["animation"] == (try Fixture.json(
            #"{ "title": {}, "shape": "none", "media": "none", "adjust": "none" }"#
        )))
    }

    @Test("the base theme holds no image, layout or area group, no banner, heading, headline or label style and no shape label")
    func holdsNoRemovedGroup() throws {
        // Given
        let theme = try #require(sut.objectValue)

        // When
        let styles = theme["styles"]?.objectValue?.keys ?? []
        let shapes = theme["shapes"]?.objectValue?.keys ?? []

        // Then
        #expect(theme["image"] == nil)
        #expect(theme["layout"] == nil)
        #expect(theme["area"] == nil)
        #expect(styles == ["title", "subtitle"])
        #expect(shapes == ["box", "fill", "dim", "arrow"])
    }

    @Test("theme lengths scale by the frame width over 1920", arguments: [(1920.0, 1.0), (1080.0, 0.5625)])
    func scalesLengthsByFrameWidth(_ width: Double, _ scale: Double) {
        // Given
        let theme = MergedTheme(value: sut, layers: [])

        // When
        let lengthScale = theme.lengthScale(at: width)

        // Then
        #expect(lengthScale == scale)
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
