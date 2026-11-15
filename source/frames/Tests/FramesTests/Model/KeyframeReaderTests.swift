//
//  KeyframeReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("KeyframeReader Tests")
struct KeyframeReaderTests {
    // MARK: - Property
    private let sut = KeyframeReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("each property joins only the keyframes that name it")
    func joinsOwnKeyframes() throws {
        // Given
        let keyframes = try Fixture.json(#"[ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ]"#)

        // When
        let scale = sut.track(of: "scale", in: keyframes) { $0.numberValue ?? 0 }
        let position = sut.track(of: "position", in: keyframes) { value in
            let numbers = value.arrayValue?.compactMap(\.numberValue) ?? []
            return Point(x: numbers[0], y: numbers[1])
        }
        let opacity = sut.track(of: "opacity", in: keyframes) { $0.numberValue ?? 0 }

        // Then
        #expect(scale?.value(at: 0) == 1.5)
        #expect(scale?.value(at: 3.5) == 1.5)
        #expect(position?.keyframes.first?.ease == .easeInOut)
        #expect(position?.value(at: 3.5) == Point(x: 465, y: 700))
        #expect(opacity == nil)
    }

    @Test("an ease on a keyframe that no later keyframe follows for any of its properties stops")
    func refusesUnfollowedEase() throws {
        // Given
        let keyframes = try Fixture.json(#"[ { "at": 4, "scale": 2 }, { "at": 3, "position": [0, 0], "ease": "ease-in" } ]"#)

        // When, Then
        let error = #expect(throws: ModelError.self) {
            try sut.checkEases(in: keyframes, place: Place.root.appending(key: "keyframes"))
        }
        #expect(error?.description == #"keyframes[1] (keyframe): "ease" shapes no span, since no later keyframe names position"#)
    }

    @Test("an ease followed by a later keyframe of one of its properties is kept")
    func acceptsFollowedEase() throws {
        // Given
        let keyframes = try Fixture.json(#"[ { "at": 3, "position": [0, 0], "scale": 1, "ease": "ease-in" }, { "at": 4, "scale": 2 } ]"#)

        // When, Then
        try sut.checkEases(in: keyframes, place: .root)
    }

    @Test("a later keyframe at the same instant does not follow, since the span between them has no length")
    func refusesEaseFollowedAtSameInstant() throws {
        // Given
        let keyframes = try Fixture.json(#"[ { "at": 1, "opacity": 0, "ease": "ease-in" }, { "at": 1, "opacity": 1 } ]"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.checkEases(in: keyframes, place: .root) }
        #expect(error?.description == #"[0] (keyframe): "ease" shapes no span, since no later keyframe names opacity"#)
    }
}
