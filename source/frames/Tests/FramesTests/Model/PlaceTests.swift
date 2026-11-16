//
//  PlaceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Place Tests")
struct PlaceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a place is written the way messages name it")
    func writesMessageForm() {
        // Given
        let sut = Place.root.appending(key: "storyline").appending(index: 2).appending(key: "connected").appending(index: 0)

        // When
        let description = sut.description

        // Then
        #expect(description == "storyline[2].connected[0]")
    }

    @Test("a clip with an id is named by it beside its index")
    func writesIdentifier() {
        // Given
        let sut = Place.root.appending(key: "clips").appending(index: 1, id: "intro").appending(key: "at")

        // When
        let description = sut.description

        // Then
        #expect(description == "clips[1]#intro.at")
    }

    @Test("the top of a document has a name of its own")
    func namesRoot() {
        // Given
        let sut = Place.root

        // When
        let description = sut.description

        // Then
        #expect(description == "top level")
    }
}
