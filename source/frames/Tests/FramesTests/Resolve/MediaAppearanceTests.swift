//
//  MediaAppearanceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// Each case is a media clip over `/abs/screen.mp4` and the same keys on a storyline clip, in a 960 by 540 frame, so
// theme lengths are half their written size. The theme `shadow` is radius 20, offset [0, 8] and `#00000080`.
@Suite("MediaAppearance Tests")
struct MediaAppearanceTests {
    // MARK: - Property
    private static let theme = ##"""
        { "colors": { "ink": "#101418" }, "shadow": { "radius": 20, "offset": [0, 8], "color": "#00000080" } }
        """##

    private let sut = Fixture.sequencePlanner

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a media clip's and a storyline clip's shadow is the theme's for true, none for false, and an object takes its missing keys from the theme's, lengths scaled",
        arguments: [
            (#""shadow": true"#, DropShadow(radius: 10, offset: Point(x: 0, y: 4), color: Color(written: "#00000080"))),
            (#""shadow": false"#, nil),
            (#""radius": 0"#, nil),
            (
                #""shadow": { "radius": 6 }"#,
                DropShadow(radius: 3, offset: Point(x: 0, y: 4), color: Color(written: "#00000080"))
            ),
            (
                #""shadow": { "offset": [10, -2], "color": "ink" }"#,
                DropShadow(radius: 10, offset: Point(x: 5, y: -1), color: Color(written: "#101418"))
            ),
            (
                ##""shadow": { "radius": 0, "offset": [4, 4], "color": "#FF000080" }"##,
                DropShadow(radius: 0, offset: Point(x: 2, y: 2), color: Color(written: "#FF000080"))
            )
        ] as [(String, DropShadow?)]
    )
    func plansDropShadow(
        keys: String,
        shadow: DropShadow?
    ) throws {
        // Given
        let document = document(keys)

        // When
        let plan = try plan(document)

        // Then
        #expect(plan.clips[0].appearance.media?.shadow.shadow() == shadow)
        #expect(plan.storyline[0].appearance.shadow.shadow() == shadow)
    }

    @Test("a media clip's and a storyline clip's radius is a theme length, scaled by the frame's width over baseWidth")
    func scalesRadius() throws {
        // Given
        let document = document(#""radius": 24"#)

        // When
        let plan = try plan(document)

        // Then
        #expect(plan.clips[0].appearance.media?.radius.cornerRadii() == 12)
        #expect(plan.storyline[0].appearance.radius.cornerRadii() == 12)
    }

    @Test("a shadow colour that is not a theme colour stops at the clip that writes it")
    func stopsOnUnknownShadowColor() throws {
        // Given
        let clip = #"""
            { "kind": "sequence", "format": { "size": [960, 540] }, "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "shadow": { "color": "ink" } } ] }
            """#
        let storyline = #"""
            { "kind": "sequence", "format": { "size": [960, 540] },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "shadow": { "color": "ink" } } ] }
            """#

        // When, Then
        let clipError = #expect(throws: ThemeError.self) { try plan(clip) }
        let storylineError = #expect(throws: ThemeError.self) { try plan(storyline) }
        #expect(clipError.map { "\($0)" } == #"clips[0].shadow.color (image): colour "ink" is not in colors, which hold "accent", "background", "shadow", "text""#)
        #expect(storylineError.map { "\($0)" } == #"storyline[0].shadow.color (video): colour "ink" is not in colors, which hold "accent", "background", "shadow", "text""#)
    }

    @Test("a border colour that is not a theme colour stops at the leaf it is, where the clip writes it")
    func stopsOnUnknownBorderColor() throws {
        // Given
        let clip = #"""
            { "kind": "sequence", "format": { "size": [960, 540] }, "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "border": "ink" } ] }
            """#
        let storyline = #"""
            { "kind": "sequence", "format": { "size": [960, 540] },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "border": "ink" } ] }
            """#

        // When, Then
        let clipError = #expect(throws: ThemeError.self) { try plan(clip) }
        let storylineError = #expect(throws: ThemeError.self) { try plan(storyline) }
        #expect(clipError.map { "\($0)" } == #"clips[0].border.color (image): colour "ink" is not in colors, which hold "accent", "background", "shadow", "text""#)
        #expect(storylineError.map { "\($0)" } == #"storyline[0].border.color (video): colour "ink" is not in colors, which hold "accent", "background", "shadow", "text""#)
    }

    // MARK: - Private
    private func document(_ keys: String) -> String {
        #"""
        { "kind": "sequence", "format": { "size": [960, 540] }, "theme": \#(Self.theme),
          "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", \#(keys) } ],
          "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], \#(keys) } ] }
        """#
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }
}
