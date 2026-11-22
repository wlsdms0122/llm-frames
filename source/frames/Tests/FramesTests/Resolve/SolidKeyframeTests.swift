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
            "solid": "#FF0000", "keyframes": [ { "at": 0, "solid": null }, { "at": 2, "solid": "brand" } ]
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(sequence.storyline[0].solid?.value(at: 0) == Color(written: "#FF0000"))
        #expect(fill(of: list) == Color(written: "color(srgb 0.5 0 0.5)"))
    }

    @Test("a solid without keyframes keeps its colour at every instant")
    func holdsStaticColour() throws {
        // Given
        let sequence = try resolved(#""solid": "brand""#)

        // When
        let list = sut.displayList(of: sequence, at: 1.5)

        // Then
        #expect(fill(of: list) == Color(written: "#0000FF"))
    }

    @Test("a static colour that every keyframe writing it replaces stops, since it would never show")
    func refusesHiddenStaticColour() {
        // Given
        let place = Place.root.appending(key: "storyline").appending(index: 0).appending(key: "solid")

        // When, Then
        #expect(throws: LookError.staticAndKeyframed(place: place)) {
            try resolved(#"""
                "solid": "#FF0000", "keyframes": [ { "at": 0, "solid": "#000000" }, { "at": 2, "solid": "#FFFFFF" } ]
                """#)
        }
    }

    @Test("a solid's keyframes are written as a keyframe list of colours and read back as they were")
    func roundTripsColour() throws {
        // Given
        let sequence = try resolved(#"""
            "solid": "#FF0000", "keyframes": [ { "at": 0, "solid": null, "ease": "ease-in" }, { "at": 2, "solid": "brand" } ]
            """#)

        // When
        let read = try ResolvedDocumentReader().read(ResolvedDocumentWriter().write(sequence))

        // Then
        #expect(read.storyline[0].solid == sequence.storyline[0].solid)
        #expect(sequence.storyline[0].solid?.count == 2)
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
}
