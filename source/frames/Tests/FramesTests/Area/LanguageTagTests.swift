//
//  LanguageTagTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("LanguageTag Tests")
struct LanguageTagTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a well-formed BCP 47 tag is taken as written",
        arguments: ["en", "en-US", "ko-KR", "zh-Hans", "zh-Hant-TW", "es-419", "de-CH-1996", "en-a-bbb-x-ccc", "x-mine", "zh-yue-HK"]
    )
    func takesWellFormedTag(text: String) {
        // Given, When
        let sut = LanguageTag(text)

        // Then
        #expect(sut?.text == text)
    }

    @Test(
        "a tag that is not well-formed is refused",
        arguments: ["", "e", "en_US", "en-", "-en", "en--US", "en-US-a", "toolongtag", "1en", "en-x", "ko KR"]
    )
    func refusesMalformedTag(text: String) {
        // Given, When
        let sut = LanguageTag(text)

        // Then
        #expect(sut == nil)
    }

    @Test("tags separated by commas keep their order, and one malformed tag refuses the list")
    func readsCommaSeparatedList() {
        // Given, When
        let sut = [LanguageTag](commaSeparated: "en-US,ko-KR")
        let malformed = [LanguageTag](commaSeparated: "en-US,,ko-KR")

        // Then
        #expect(sut?.map(\.text) == ["en-US", "ko-KR"])
        #expect(malformed == nil)
    }
}
