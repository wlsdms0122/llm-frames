//
//  TitleUnitTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Titles are sequence clips over `/abs/screen.mp4` in a 1920 by 1080 frame, so theme lengths are output pixels. The
// style `caption` is 40 with a stroke 4 wide, so a glyph is 20 wide, a space 10, and a line reaches 32 above its
// baseline and 8 below.
@Suite("Title unit Tests")
struct TitleUnitTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a title by word carries its units, each with its glyph box and its box holding its stroke and its parts at their widest, read back whole")
    func resolvesUnits() throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "ab cd", "style": "caption", "position": [400, 225],
              "animation": { "preset": "frames/fade", "by": "word" },
              "character": { "highlight": { "color": "#FF0000" } },
              "keyframes": [ { "at": 0, "character": { "highlight": { "padding": [2, 3] } } },
                             { "at": 1, "character": { "highlight": { "padding": [8, 10] } } } ] }
            """#)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()

        // When
        let read = try reader.text(PlacedJSONValue(writer.text(text), place: .root, kind: "title"))

        // Then
        // "ab" draws the space after it.
        #expect(text.units?.map(\.characters) == [
            CharacterRange(line: 0, first: 0, count: 3),
            CharacterRange(line: 0, first: 3, count: 2)
        ])
        #expect(text.units?.map(\.hangingLines) == [[], []])
        #expect(text.units?.map(\.glyphs) == [
            [GlyphRange(run: 0, first: 0, count: 3)],
            [GlyphRange(run: 0, first: 3, count: 2)]
        ])
        #expect(text.units?.map(\.glyphBox) == [
            Rectangle(x: 0, y: 0, width: 40, height: 40),
            Rectangle(x: 50, y: 0, width: 40, height: 40)
        ])
        #expect(text.units?.map(\.box) == [
            Rectangle(x: -10, y: -8, width: 60, height: 56),
            Rectangle(x: 48, y: -8, width: 52, height: 56)
        ])
        #expect(text.units?.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...50)],
            [UnitPart(run: 0, piece: 0, span: 50...90)]
        ])
        #expect(read == text)
    }

    @Test("a highlighted line of spaces alone between two lines of words is set with no piece, so no unit carries one")
    func setsNoPieceOnLineOfSpaces() throws {
        // When
        let text = try resolvedText(#"""
            { "kind": "title", "text": "ab\n   \ncd", "style": "caption", "position": [400, 225],
              "animation": { "preset": "frames/fade", "by": "word" },
              "character": { "highlight": { "color": "#FF0000" } } }
            """#)

        // Then
        // The spaces end their line and hang outside it, so its run spans no glyph to highlight.
        let highlights = text.runs.map { $0.highlight?.rects.count ?? 0 }
        #expect(highlights == [1, 0, 1])
        #expect(text.units?.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...40)],
            [UnitPart(run: 2, piece: 0, span: 0...40)]
        ])
    }

    @Test("a title not animated by unit carries no units")
    func carriesNoUnitsWithoutBy() throws {
        // When
        let text = try resolvedText(#"""
            { "kind": "title", "text": "ab cd", "style": "caption", "position": [400, 225], "animation": "frames/fade" }
            """#)

        // Then
        #expect(text.units == nil)
    }

    @Test("by character the optional ligatures are off, unless the style's features turn them on")
    func setsCharactersApart() throws {
        // When
        let apart = try resolvedText(#"""
            { "kind": "title", "text": "fi", "style": "caption", "position": [400, 225],
              "animation": { "preset": "frames/fade", "by": "character" } }
            """#)
        let joined = try resolvedText(#"""
            { "kind": "title", "text": "fi", "style": "caption", "position": [400, 225],
              "animation": { "preset": "frames/fade", "by": "character" }, "character": { "features": { "liga": 1 } } }
            """#)

        // Then
        #expect(apart.units?.map(\.glyphs) == [
            [GlyphRange(run: 0, first: 0, count: 1)],
            [GlyphRange(run: 0, first: 1, count: 1)]
        ])
        #expect(joined.units?.map(\.glyphs) == [[GlyphRange(run: 0, first: 0, count: 1)]])
    }

    // MARK: - Private
    private func resolvedText(_ clip: String) throws -> ResolvedText {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))
        let clips = try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips
        guard case let .picture(.title(text), _, _) = clips.first?.content else {
            Issue.record("the clip is a title")
            return ResolvedText(size: Size(width: 0, height: 0), background: nil, runs: [])
        }

        return text
    }

    private func document(_ clip: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000", "stroke": { "width": 4, "color": "#000000" } } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [ \#(clip.dropLast(1)), "at": [0, 2] } ] }
            """#
    }
}
