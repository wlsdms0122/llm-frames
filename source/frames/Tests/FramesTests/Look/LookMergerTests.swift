//
//  LookMergerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("LookMerger Tests")
struct LookMergerTests {
    // MARK: - Property
    private let sut = LookMerger()
    private let reader = LookReader()
    private let place = Place.root.appending(key: "clips").appending(index: 0).appending(key: "stroke")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a merged stroke whose dash holds only zeros stops at its dash, wherever the zeros come from")
    func refusesMergedZeroDash() throws {
        // Given
        let style = reader.value(of: try Fixture.json(#"{ "width": 4, "dash": [10, 5] }"#), as: LookStructureTable.stroke)
        let clip = reader.value(of: try Fixture.json(#"{ "dash": [0, 0] }"#), as: LookStructureTable.stroke)

        // When
        let merged = try #require(try sut.merge([style, clip], as: LookStructureTable.stroke, place: place))

        // Then
        #expect(throws: LookError.allZero(place: place.appending(key: "dash"))) {
            try sut.checkRequired(in: merged, as: LookStructureTable.stroke, place: place)
        }
    }

    @Test("a merged dash with a length above 0 or gaps of 0 is taken")
    func takesMergedDash() throws {
        // Given
        let style = reader.value(of: try Fixture.json(#"{ "width": 4, "dash": [0, 0] }"#), as: LookStructureTable.stroke)
        let clips = try [#"{ "dash": [3, 0] }"#, #"{ "dash": [0, 5] }"#].map { written in
            reader.value(of: try Fixture.json(written), as: LookStructureTable.stroke)
        }

        // When, Then
        for clip in clips {
            let merged = try #require(try sut.merge([style, clip], as: LookStructureTable.stroke, place: place))
            try sut.checkRequired(in: merged, as: LookStructureTable.stroke, place: place)
        }
    }

    @Test("a keyframe dash whose lengths over the merged dash are all 0 stops at that keyframe")
    func refusesKeyframeZeroDash() throws {
        // Given
        let merged = reader.value(of: try Fixture.json(#"{ "width": 4, "dash": [3, 0] }"#), as: LookStructureTable.stroke)
        let keyframes = try [#"{ "dash": [null, null] }"#, #"{ "dash": [0, null] }"#].enumerated().map { index, written in
            PropertyKeyframe(
                index: index,
                at: Double(index),
                value: reader.value(of: try Fixture.json(written), as: LookStructureTable.stroke),
                ease: .linear
            )
        }
        let lookPlace = LookPlace(clip: Place.root.appending(key: "clips").appending(index: 0), key: "stroke")

        // When, Then
        #expect(throws: LookError.allZero(place: lookPlace.keyframe(1).appending(key: "dash"))) {
            try sut.checkRequired(in: merged, keyframes: keyframes, as: LookStructureTable.stroke, place: lookPlace)
        }
    }

    // MARK: - Private
}
