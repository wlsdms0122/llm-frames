//
//  ResolvedTextInstantTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

// Vertical titles at an instant. A title is a sequence clip over `/abs/screen.mp4` in a 1920 by 1080 frame, in the
// theme's style `caption`, 40 in the fake shaper's face, whose ascent is 32 and descent 8. So a vertical line is 40
// wide around its central baseline, its alphabetic baseline lies 12 left of it, an upright glyph advances 40 down the
// line with its origin 10 left of and 32 below its pen, and tracking 100 adds 4 between two characters.
@Suite("ResolvedText Instant Tests")
struct ResolvedTextInstantTests {
    // MARK: - Property
    private static let modes = [WritingMode.verticalRightToLeft, .verticalLeftToRight]

    // MARK: - Initializer
    // MARK: - Test
    @Test("animated tracking moves a vertical line's glyphs down it, and its text box grows down", arguments: modes)
    func tracksDownTheLine(writingMode: WritingMode) throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢字", "paragraph": { "writingMode": "\#(writingMode.rawValue)" },
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // When
        let moves = text.glyphMoves(at: SampleTime(1))
        let sut = GlyphsItem(text: text, factor: 1, at: SampleTime(1))

        // Then
        #expect(text.textBox == Rectangle(x: 0, y: 0, width: 40, height: 80))
        #expect(moves == [[Point(x: 0, y: 0), Point(x: 0, y: 4)]])
        #expect(text.textBox(at: SampleTime(1)) == Rectangle(x: 0, y: 0, width: 40, height: 84))
        #expect(sut.writingMode == writingMode)
        #expect(sut.size == Size(width: 40, height: 84))
        #expect(sut.extent == Rectangle(x: 0, y: 0, width: 40, height: 84))
        #expect(sut.runs[0].glyphs.map { Point(x: $0.x, y: $0.y) } == [Point(x: 10, y: 32), Point(x: 10, y: 76)])
    }

    @Test(
        "animated line height moves vertical lines toward block-end and keeps the block-start edge, moving none at the static value",
        arguments: [
            (WritingMode.verticalRightToLeft, -20.0, Rectangle(x: -20, y: 0, width: 110, height: 40), [80.0, 10], [90.0, 20]),
            (WritingMode.verticalLeftToRight, 20.0, Rectangle(x: 0, y: 0, width: 110, height: 40), [10.0, 80], [20.0, 90])
        ]
    )
    func movesVerticalLinesByLineHeight(
        writingMode: WritingMode,
        drop: Double,
        textBox: Rectangle,
        xs: [Double],
        baselines: [Double]
    ) throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢\n字", "paragraph": { "writingMode": "\#(writingMode.rawValue)" },
              "keyframes": [ { "at": 0, "paragraph": { "lineHeight": 50 } }, { "at": 1, "paragraph": { "lineHeight": 70 } } ] }
            """#)

        // When
        let sut = GlyphsItem(text: text, factor: 1, at: SampleTime(1))

        // Then
        #expect(text.lineDrops(at: SampleTime(0)) == [0, 0])
        #expect(text.textBox(at: SampleTime(0)) == text.textBox)
        #expect(text.lineDrops(at: SampleTime(1)) == [0, drop])
        #expect(text.textBox(at: SampleTime(1)) == textBox)
        #expect(sut.runs.flatMap(\.glyphs).map(\.x) == xs)
        #expect(sut.runs.flatMap(\.glyphs).map(\.y) == [32, 32])
        #expect(text.evaluationLines(at: SampleTime(1)).map(\.baseline) == baselines)
    }

    @Test("a vertical line with a width is placed again by `align` down that width as its tracking changes")
    func alignsDownTheLine() throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢字", "width": 200, "paragraph": { "writingMode": "vertical-rl", "align": "center" },
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // When
        let sut = GlyphsItem(text: text, factor: 1, at: SampleTime(1))

        // Then
        #expect(text.textBox == Rectangle(x: 0, y: 0, width: 40, height: 200))
        #expect(text.glyphMoves(at: SampleTime(1)) == [[Point(x: 0, y: -2), Point(x: 0, y: 2)]])
        #expect(text.textBox(at: SampleTime(1)) == text.textBox)
        #expect(sut.runs[0].glyphs.map(\.y) == [90, 134])
    }

    @Test("a highlight's and a background's padding take their first value across a vertical line and their second down it")
    func padsAcrossAndDown() throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢字", "paragraph": { "writingMode": "vertical-rl", "background": { "color": "#0000FF" } },
              "character": { "highlight": { "color": "#FF0000", "padding": [4, 6] } },
              "keyframes": [ { "at": 0, "paragraph": { "background": { "padding": [0, 0] } } },
                             { "at": 1, "paragraph": { "background": { "padding": [10, 20] } } } ] }
            """#)

        // When
        let sut = GlyphsItem(text: text, factor: 1, at: SampleTime(1))

        // Then
        #expect(text.box(at: SampleTime(1)) == Rectangle(x: -10, y: -20, width: 60, height: 120))
        #expect(sut.background?.rectangle == Rectangle(x: -10, y: -20, width: 60, height: 120))
        #expect(sut.runs[0].highlight?.rects == [Rectangle(x: -4, y: -6, width: 48, height: 92)])
    }

    @Test("an underline lies left of a vertical line's alphabetic baseline, its offset and width toward line-under", arguments: modes)
    func underlinesTowardLineUnder(writingMode: WritingMode) throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢字", "paragraph": { "writingMode": "\#(writingMode.rawValue)" },
              "character": { "underline": { "width": 2, "offset": 3 } } }
            """#)

        // When
        let sut = GlyphsItem(text: text, factor: 1, at: SampleTime(0))

        // Then
        #expect(text.lines.map(\.baseline) == [20])
        #expect(sut.runs[0].underline?.rects == [Rectangle(x: 3, y: 0, width: 2, height: 80)])
    }

    @Test("a baseline shift raises a vertical run's glyphs, pieces and glyph boxes toward line-over, to the right")
    func raisesTowardLineOver() throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢字", "paragraph": { "writingMode": "vertical-rl" },
              "character": { "highlight": { "color": "#FF0000" }, "underline": { "width": 2, "offset": 3 } },
              "keyframes": [ { "at": 0, "character": { "baselineShift": 0 } }, { "at": 1, "character": { "baselineShift": 10 } } ] }
            """#)

        // When
        let sut = GlyphsItem(text: text, factor: 1, at: SampleTime(1))

        // Then
        #expect(sut.runs[0].glyphs.map { Point(x: $0.x, y: $0.y) } == [Point(x: 20, y: 32), Point(x: 20, y: 72)])
        #expect(sut.runs[0].highlight?.rects == [Rectangle(x: 10, y: 0, width: 40, height: 80)])
        #expect(sut.runs[0].underline?.rects == [Rectangle(x: 13, y: 0, width: 2, height: 80)])
        #expect(sut.extent == Rectangle(x: 0, y: 0, width: 50, height: 80))
    }

    @Test("a vertical title's units move down their line with the tracking, and their parts are cut into bands down it")
    func cutsVerticalUnits() throws {
        // Given
        let text = try resolvedText(#"""
            { "kind": "title", "text": "漢字", "paragraph": { "writingMode": "vertical-rl" }, "character": { "highlight": { "color": "#FF0000" } },
              "animation": { "preset": "frames/fade", "by": "character" },
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)
        let item = GlyphsItem(text: text, factor: 1, at: SampleTime(1))

        // When
        let parts = [0, 1].map { text.parts(of: $0, at: SampleTime(1)) }
        let sut = parts.map { item.runs[0].carrying(glyphs: [], parts: $0, writingMode: .verticalRightToLeft, factor: 1) }

        // Then
        #expect(text.unitBox(of: 0, at: SampleTime(1)) == Rectangle(x: 0, y: 0, width: 40, height: 40))
        #expect(text.unitBox(of: 1, at: SampleTime(1)) == Rectangle(x: 0, y: 44, width: 40, height: 40))
        #expect(text.extent(of: 1, at: SampleTime(1)) == Rectangle(x: 0, y: 44, width: 40, height: 40))
        #expect(parts == [
            [UnitPart(run: 0, piece: 0, span: -Double.infinity...44)],
            [UnitPart(run: 0, piece: 0, span: 44...Double.infinity)]
        ])
        #expect(sut.map { $0.highlight?.bands } == [[0...44], [44...84]])
    }

    // MARK: - Private
    private func resolvedText(_ clip: String) throws -> ResolvedText {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))
        let clips = try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips
        guard case let .picture(.title(text), _) = clips.first?.content else {
            Issue.record("the clip is a title")
            return ResolvedText(size: Size(width: 0, height: 0), background: nil, runs: [])
        }

        return text
    }

    private func document(_ clip: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000" } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ \#(clip.dropLast(1)), "style": "caption", "position": [400, 225], "at": [0, 2] } ] }
            """#
    }
}
