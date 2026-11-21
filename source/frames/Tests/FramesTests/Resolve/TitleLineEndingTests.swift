//
//  TitleLineEndingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// Titles are sequence clips over `/abs/screen.mp4` in a 1920 by 1080 frame, so theme lengths are output pixels. The
// style `caption` is 40, so a glyph is 20 wide. Tracking takes keyframes, so the resolved title writes its lines.
@Suite("Title line ending Tests")
struct TitleLineEndingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "each line ending is read as one \\n, so the text breaks there and its ranges count it as one scalar",
        arguments: [
            #""a\r\nb""#,
            #""a\rb""#,
            #""a\u0085b""#,
            #""a\u000Bb""#,
            #""a\u000Cb""#,
            #""a b""#,
            #""a b""#,
            #"[ { "text": "a\r" }, { "text": "\nb" } ]"#
        ]
    )
    func readsLineEndings(title: String) throws {
        // When
        let text = try resolvedText(title)

        // Then
        #expect(text.runs.flatMap(\.glyphs).map(\.id) == [97, 98])
        #expect(text.lines?.map(\.range) == [0..<1, 2..<3])
        #expect(text.lines?.map(\.hanging) == [[], []])
    }

    @Test("a CR LF split over two runs is one \\n in the run of its CR")
    func keepsSplitLineEndingInFirstRun() throws {
        // When
        let text = try resolvedText(#"[ { "text": "a\r" }, { "text": "\nb" } ]"#)

        // Then
        #expect(text.runs.map(\.source) == [0, 1])
        #expect(text.lines?.map { $0.clusters.map(\.glyphs.run) } == [[0], [1]])
    }

    // MARK: - Private
    private func resolvedText(_ title: String) throws -> ResolvedText {
        let clip = #"""
            { "title": \#(title), "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ],
              "at": [0, 2] }
            """#
        let document = #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000" } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip) ] }
            """#
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document))
        let clips = try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips
        guard case let .title(text) = clips.first?.content else {
            Issue.record("the clip is a title")
            return ResolvedText(size: Size(width: 0, height: 0), background: nil, runs: [])
        }

        return text
    }
}
