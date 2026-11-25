//
//  SolidKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

@testable import Frames

// Each case is a 2 second solid alone on the storyline of a 64 by 36 frame whose theme holds the colour `brand`.
@Suite("Solid keyframe Tests")
struct SolidKeyframeTests {
    // MARK: - Property
    private let sut = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a solid's colour moves between its keyframes, a keyframe written null taking the static colour")
    func movesColour() throws {
        // Given
        let sequence = try resolved(#"""
            "kind": "solid",
            "color": "#FF0000", "keyframes": [ { "at": 0, "color": null }, { "at": 2, "color": "brand" } ]
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(color(of: sequence.storyline[0])?.value(at: 0) == Color(written: "#FF0000"))
        #expect(fill(of: list) == Color(written: "color(srgb 0.5 0 0.5)"))
    }

    @Test("a solid without keyframes keeps its colour at every instant")
    func holdsStaticColour() throws {
        // Given
        let sequence = try resolved(#""kind": "solid", "color": "brand""#)

        // When
        let list = sut.displayList(of: sequence, at: 1.5)

        // Then
        #expect(fill(of: list) == Color(written: "#0000FF"))
    }

    @Test("a solid whose keyframes give its colour resolves without a static colour")
    func resolvesColourOfKeyframes() throws {
        // Given
        let sequence = try resolved(#"""
            "kind": "solid",
            "keyframes": [ { "at": 0, "color": "#000000" }, { "at": 2, "color": "#FFFFFF" } ]
            """#)

        // When
        let colours = stride(from: 0.0, to: 2, by: 0.25).map { fill(of: sut.displayList(of: sequence, at: $0)) }

        // Then
        #expect(colours.first == Color(written: "#000000"))
        #expect(colours[4] == Color(written: "color(srgb 0.5 0.5 0.5)"))
        #expect(color(of: sequence.storyline[0])?.map(\.value) == [Color(written: "#000000"), Color(written: "#FFFFFF")])
    }

    @Test("a solid whose static colour every keyframe replaces stops, since the static colour never shows")
    func refusesColourEveryKeyframeReplaces() throws {
        // Given
        let keys = #"""
            "kind": "solid",
            "color": "#FF0000", "keyframes": [ { "at": 0, "color": "#000000" }, { "at": 2, "color": "#FFFFFF" } ]
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolved(keys) }
        #expect(error.map { "\($0)" } == "storyline[0].color: written as a static value and in every keyframe that writes it, so the static value never shows")
    }

    @Test("a solid's keyframes are written as a keyframe list of colours and read back as they were")
    func roundTripsColour() throws {
        // Given
        let sequence = try resolved(#"""
            "kind": "solid",
            "color": "#FF0000", "keyframes": [ { "at": 0, "color": null, "ease": "ease-in" }, { "at": 2, "color": "brand" } ]
            """#)

        // When
        let read = try ResolvedDocumentReader().read(ResolvedDocumentWriter().write(sequence))

        // Then
        #expect(read.storyline[0].content == sequence.storyline[0].content)
        #expect(color(of: sequence.storyline[0])?.count == 2)
    }

    @Test("a resolved solid entry with a time remap stops, since a solid shows no media")
    func refusesSolidTimeRemap() throws {
        // Given
        let sequence = try resolved(##""kind": "solid", "color": "#FF0000""##)
        let root = try #require(try JSONReader().read(ResolvedDocumentWriter().write(sequence)).objectValue)
        var storyline = try #require(root["storyline"]?.arrayValue)
        let entry = try #require(storyline[0].objectValue)
        storyline[0] = .object(entry.setting("timeRemap", to: try JSONReader().read(#"[{ "at": 0, "value": 0, "ease": "linear" }]"#)))

        // When
        let error = #expect(throws: ModelError.self) {
            try ResolvedDocumentReader().read(.object(root.setting("storyline", to: .array(storyline))))
        }

        // Then
        #expect(error?.description.hasPrefix("storyline[0].timeRemap (storyline clip): an entry of kind solid has no timeRemap, so it is null") == true)
    }

    // MARK: - Private
    private func resolved(_ keys: String) throws -> ResolvedSequence {
        let document = #"""
            { "kind": "sequence", "format": { "size": [64, 36] }, "theme": { "colors": { "brand": "#0000FF" } },
              "storyline": [ { "duration": 2, \#(keys) } ] }
            """#
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document))

        return try ResolvedSequence(plan: plan, hashes: FileHashTable())
    }

    // The colour of the path a storyline solid draws inside its picture.
    private func fill(of list: DisplayList) -> Color? {
        guard case let .picture(picture) = list.items.first?.content,
            case let .displayList(inner) = picture.source,
            case let .path(path) = inner.items.first?.content,
            case let .color(color) = path.fill
        else {
            return nil
        }

        return color
    }

    // A solid entry's colour keyframes, nil for an entry with media.
    private func color(of entry: ResolvedStorylineClip) -> [Keyframe<Color>]? {
        guard case let .solid(solid) = entry.content else { return nil }

        return solid.color
    }
}
