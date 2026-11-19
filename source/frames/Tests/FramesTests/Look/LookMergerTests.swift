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

    // MARK: - Private
}
