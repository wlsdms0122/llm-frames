//
//  TOMLReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("TOMLReader Tests")
struct TOMLReaderTests {
    // MARK: - Property
    private let sut = TOMLReader(file: "/packs/shorts/manifest.toml")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a manifest reads into one object per table, with strings, integers, booleans and lists")
    func readsSubset() throws {
        // Given
        let data = Data(#"""
            # The specification is open-package

            [open-package]
            version = "1.0.0"   # a comment after a value

            [package]
            name = "Shorts \"vertical\" #1\tcut"
            requires = ["python3", "sh"]
            count = 42
            listed = true
            """#.utf8)

        // When
        let value = try sut.read(data)

        // Then
        let expected = try Fixture.json(#"""
            { "open-package": { "version": "1.0.0" },
              "package": { "name": "Shorts \"vertical\" #1\tcut", "requires": ["python3", "sh"], "count": 42, "listed": true } }
            """#)
        #expect(value == expected)
    }

    @Test(
        "what the subset does not read is refused with its line",
        arguments: [
            ("[[command]]", "line 3: an array of tables is not read here"),
            ("[command.nested]", #"line 3: "command.nested" is a nested table, and tables here have one level"#),
            ("[\"command\"]", #"line 3: "\"command\"" is not a table name"#),
            ("open-package.version = \"1.0.0\"", #"line 3: "open-package.version" is a dotted key. Write a [table] header"#),
            ("name = \"\"\"long\"\"\"", #"line 3: unexpected text after the value: "long""""#),
            ("name = 'literal'", #"line 3: unquoted value 'literal'. Write a string as "'literal'""#),
            ("released = 2026-11-15", #"line 3: unquoted value 2026-11-15. Write a string as "2026-11-15""#),
            ("ratio = 1.5", #"line 3: unquoted value 1.5. Write a string as "1.5""#),
            ("inline = { a = 1 }", #"line 3: unquoted value {. Write a string as "{""#),
            ("name = \"a\\qb\"", #"line 3: unknown escape \q"#),
            ("name = \"open", "line 3: a string is not closed"),
            ("name = \"y\"", #"line 3: "package.name" is written twice"#),
            ("name", "line 3: expected key = value, found name")
        ]
    )
    func refusesOutsideSubset(line: String, reason: String) throws {
        // Given
        let data = Data("[package]\nname = \"x\"\n\(line)".utf8)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.read(data) }
        #expect(error?.description == "/packs/shorts/manifest.toml: \(reason)")
    }

    @Test("a key written before any table header is refused")
    func refusesKeyOutsideTable() throws {
        // Given
        let data = Data("name = \"x\"\n[package]".utf8)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.read(data) }
        #expect(error?.description == #"/packs/shorts/manifest.toml: line 1: "name" is written before any [table] header"#)
    }

    @Test("a table header may be written again, and its keys still may not")
    func reopensTable() throws {
        // Given
        let data = Data("[package]\nname = \"x\"\n[frames]\nengine = \"^1\"\n[package]\nversion = \"1.0.0\"".utf8)

        // When
        let value = try sut.read(data)

        // Then
        #expect(value == (try Fixture.json(#"{ "package": { "name": "x", "version": "1.0.0" }, "frames": { "engine": "^1" } }"#)))
    }
}
