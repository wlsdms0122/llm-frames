//
//  CollectionSpaceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("Collection Space Tests")
struct CollectionSpaceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a grapheme cluster is a space when its first scalar is white space, whatever follows it",
        arguments: [
            (" ", true),
            (" \u{301}", true),
            ("\u{A0}", true),
            ("\u{3000}", true),
            ("\n", true),
            ("\u{200B}", false),
            ("\u{2060}", false),
            ("a", false),
            ("", false)
        ]
    )
    func findsSpace(text: String, isSpace: Bool) {
        // Given
        let sut = Array(text.unicodeScalars)

        // When
        let found = sut.isSpace

        // Then
        #expect(found == isSpace)
    }
}
