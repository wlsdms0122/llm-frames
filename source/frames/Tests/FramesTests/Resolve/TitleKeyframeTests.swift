//
//  TitleKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Titles are sequence clips over `/abs/screen.mp4` in a 1920 by 1080 frame, so theme lengths are output pixels, and each
// is checked by the key tables before it is planned. The theme holds the style `caption`, 40 in `#000000` with a stroke
// 4 wide in `#000000`, and `small`, 20 in `#FF0000`.
@Suite("Title keyframe Tests")
struct TitleKeyframeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a keyframe of `character.color` times every run's colour, a theme colour's name read through the theme")
    func timesRunColours() throws {
        // When
        let title = try title(#"""
            { "title": [ { "text": "a " }, { "text": "b", "style": "small" } ], "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "color": "accent" } }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#)

        // Then
        let colors = { (time: Double) in
            title.characters.map { $0.sampled(at: time, as: LookStructureTable.character)["color"]?.color }
        }
        #expect(colors(0) == [Color(written: "#FFD43BFF"), Color(written: "#FFD43BFF")])
        #expect(colors(1) == [Color(written: "#FFFFFFFF"), Color(written: "#FFFFFFFF")])
    }

    @Test("a keyframe that writes only `character.stroke.width` keeps each run's stroke colour from its own style")
    func keepsRunStrokeColour() throws {
        // When
        let title = try title(#"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "stroke": { "width": 2 } } }, { "at": 1, "character": { "stroke": { "width": 6 } } } ] }
            """#)

        // Then
        let stroke = title.characters[0].sampled(at: 0.5, as: LookStructureTable.character)["stroke"]
        #expect(stroke?["width"]?.number == 4)
        #expect(stroke?["color"]?.color == Color(written: "#000000FF"))
    }

    @Test(
        "an attribute that decides faces, shaping or line breaks stops in a keyframe, naming the keyframe",
        arguments: [
            (#""character": { "size": 60 }"#, "clips[0].keyframes[0].character.size"),
            (#""character": { "font": ["Inter"] }"#, "clips[0].keyframes[0].character.font[0]"),
            (#""character": { "weight": "bold" }"#, "clips[0].keyframes[0].character.weight"),
            (#""character": { "italic": true }"#, "clips[0].keyframes[0].character.italic"),
            (#""character": { "kerning": "none" }"#, "clips[0].keyframes[0].character.kerning"),
            (#""character": { "features": { "tnum": 1 } }"#, "clips[0].keyframes[0].character.features.tnum"),
            (#""paragraph": { "align": "right" }"#, "clips[0].keyframes[0].paragraph.align")
        ]
    )
    func refusesStaticAttributeInKeyframe(
        keyframe: String,
        place: String
    ) throws {
        // Given
        let clip = #"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, \#(keyframe) }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#

        // When, Then
        let message = place + " (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"
        let error = #expect(throws: (any Error).self) { try title(clip) }
        #expect(error.map(String.init(describing:)) == message)
    }

    @Test("`null` for a title's `character` in a keyframe stops, since it stands for a leaf")
    func refusesNullCharacter() throws {
        // Given
        let clip = #"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": null }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try title(clip) }
        #expect(error.map(String.init(describing:)) == #"clips[0].keyframes[0].character (keyframe): null stands for a leaf, not for an object or a list"#)
    }

    @Test("a resolved run carries its colour, stroke, baseline shift, highlight and underline timed, and reads back as written")
    func roundTripsRuns() throws {
        // Given
        let text = try resolvedText(##"""
            { "title": "a b", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "padding": [2, 4] }, "underline": true },
              "keyframes": [ { "at": 0, "character": { "color": "accent", "baselineShift": 0, "highlight": { "radius": 0 } }, "ease": "ease-in" },
                             { "at": 1, "character": { "color": "#FFFFFF", "baselineShift": 10, "highlight": { "radius": 6 } } } ] }
            """##)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()

        // When
        let read = try reader.runs(PlacedJSONValue(writer.runs(text.runs), place: .root, kind: "title"))

        // Then
        let run = try #require(text.runs.first)
        #expect(run.color == .track([
            Keyframe(at: 0, value: .color(Color(written: "#FFD43B")), ease: .easeIn),
            Keyframe(at: 1, value: .color(Color(written: "#FFFFFF")))
        ]))
        #expect(run.highlight?.rects.count == 1)
        #expect(run.highlight?.padding == .track([Keyframe(at: 0, value: .numbers([2, 4]))]))
        #expect(read == text.runs)
    }

    @Test("`underline: true` takes its width and offset from the face's `post` underline at the run's size, and the run's colour")
    func takesUnderlineFromFace() throws {
        // When
        let text = try resolvedText(#"""
            { "title": "a", "style": "caption", "position": [400, 225], "character": { "underline": true },
              "keyframes": [ { "at": 0, "character": { "color": "#FF0000" } }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#)

        // Then
        let underline = try #require(text.runs.first?.underline)
        #expect(underline.width == .track([Keyframe(at: 0, value: .number(2))]))
        #expect(underline.offset == .track([Keyframe(at: 0, value: .number(4))]))
        #expect(underline.color == text.runs.first?.color)
        #expect(underline.rects.map(\.width) == [20])
    }

    @Test("a stroke without a colour takes the `text` colour, and a highlight without one the `background` colour, no padding and no radius")
    func defaultsStrokeAndHighlight() throws {
        // When
        let title = try title(#"""
            { "title": "a", "style": "small", "position": [400, 225],
              "character": { "stroke": { "width": 2 }, "highlight": { "radius": 0 } } }
            """#)

        // Then
        let character = title.characters[0].sampled(at: 0, as: LookStructureTable.character)
        #expect(character["stroke"]?["color"]?.color == MergedTheme.base.color("text"))
        #expect(character["highlight"]?["color"]?.color == MergedTheme.base.color("background"))
        #expect(character["highlight"]?["padding"]?.numbers == [0, 0])
        #expect(character["baselineShift"]?.number == 0)
    }

    @Test("evaluation raises a run's glyphs by its baseline shift at each instant")
    func raisesGlyphsByBaselineShift() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "baselineShift": 0 } }, { "at": 1, "character": { "baselineShift": 10 } } ] }
            """#)
        let run = try #require(text.runs.first)

        // When
        let sut = DrawnGlyphRun(run: run, at: 0.5)

        // Then
        #expect(sut.glyphs.map(\.y) == run.glyphs.map { $0.y - 5 })
    }

    // MARK: - Private
    private func resolvedText(_ clip: String) throws -> ResolvedText {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))
        let clips = try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips
        guard case let .title(text) = clips.first?.content else {
            Issue.record("the clip is a title")
            return ResolvedText(size: Size(width: 0, height: 0), background: nil, runs: [])
        }

        return text
    }

    private func title(_ clip: String) throws -> TitlePlan {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))

        return try #require(plan.clips[0].title)
    }

    private func document(_ clip: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "colors": { "accent": "#FFD43B" },
                         "styles": { "caption": { "size": 40, "color": "#000000", "stroke": { "width": 4, "color": "#000000" } },
                                     "small": { "size": 20, "color": "#FF0000" } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip.dropLast(1)), "at": [0, 2] } ] }
            """#
    }
}
