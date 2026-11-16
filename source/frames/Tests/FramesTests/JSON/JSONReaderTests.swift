//
//  JSONReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("JSONReader Tests")
struct JSONReaderTests {
    // MARK: - Property
    private let sut = JSONReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a boolean and a number stay apart")
    func keepsBoolAndNumberApart() throws {
        // Given
        let text = #"{ "loop": true, "volume": 1, "fade": 0, "off": false }"#

        // When
        let object = try sut.read(text).objectValue

        // Then
        #expect(object?["loop"] == .bool(true))
        #expect(object?["volume"] == .number(1))
        #expect(object?["fade"] == .number(0))
        #expect(object?["off"] == .bool(false))
    }

    @Test("keys keep the order they were written in")
    func keepsKeyOrder() throws {
        // Given
        let text = #"{ "z": 1, "a": 2, "m": 3 }"#

        // When
        let object = try sut.read(text).objectValue

        // Then
        #expect(object?.keys == ["z", "a", "m"])
    }

    @Test("every kind of value is read as itself")
    func readsEveryKind() throws {
        // Given
        let text = #"[null, true, -1.5e2, "a\nb\u00e9\ud83d\ude00", [], {}]"#

        // When
        let value = try sut.read(text)

        // Then
        #expect(value == .array([
            .null,
            .bool(true),
            .number(-150),
            .string("a\nbé😀"),
            .array([]),
            .object(JSONObject())
        ]))
    }

    @Test("a key written twice stops")
    func refusesDuplicateKey() {
        // Given
        let text = #"{ "in": 1, "in": 2 }"#

        // When, Then
        let error = #expect(throws: JSONError.self) { try sut.read(text) }
        #expect(error?.description == #"line 1, column 12: key "in" is written twice"#)
    }

    @Test("a syntax error names its line and column")
    func reportsLineAndColumn() {
        // Given
        let text = "{\n  \"a\": 1,\n  \"b\" 2\n}"

        // When, Then
        let error = #expect(throws: JSONError.self) { try sut.read(text) }
        #expect(error == .syntax(line: 3, column: 7, reason: "expected \":\" after a key"))
    }

    @Test(
        "text that is not one JSON value stops",
        arguments: [
            "",
            "{",
            "[1, 2,]",
            "{\"a\": 1,}",
            "01",
            "1.",
            "tru",
            "'a'",
            "\"unclosed",
            "{} {}",
            "{\"a\" : \"\t\"}",
            "\"\\x\""
        ]
    )
    func refusesMalformedText(text: String) {
        // Given, When, Then
        #expect(throws: JSONError.self) { try sut.read(text) }
    }

    @Test("a column counts characters, not bytes")
    func countsColumnsInCharacters() {
        // Given
        let text = #"{ "제목": "안녕" x }"#

        // When, Then
        let error = #expect(throws: JSONError.self) { try sut.read(text) }
        #expect(error == .syntax(line: 1, column: 14, reason: "expected \",\" or \"}\" in an object"))
    }
}
