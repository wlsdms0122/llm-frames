//
//  ManifestReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("ManifestReader Tests")
struct ManifestReaderTests {
    // MARK: - Property
    private let sut = ManifestReader()
    private let file = "/packs/shorts/pack.json"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a pack.json with only engine gives the range and nothing the pack says about itself")
    func readsEngineOnly() throws {
        // Given
        let data = Data(#"{ "engine": "^1" }"#.utf8)

        // When
        let manifest = try sut.manifest(from: data, file: file)

        // Then
        #expect(manifest == PackManifest(
            name: nil,
            version: nil,
            description: nil,
            engine: try #require(EngineRange("^1"))
        ))
    }

    @Test("a pack.json gives what the pack calls itself, its version and description, and the engine range")
    func readsAllKeys() throws {
        // Given
        let data = Data(#"""
            {
              "engine": "^1.0",
              "name": "Shorts",
              "version": "1.0.0",
              "description": "Looks for vertical shorts"
            }
            """#.utf8)

        // When
        let manifest = try sut.manifest(from: data, file: file)

        // Then
        #expect(manifest == PackManifest(
            name: "Shorts",
            version: "1.0.0",
            description: "Looks for vertical shorts",
            engine: try #require(EngineRange("^1.0"))
        ))
    }

    @Test(
        "a pack.json that misses engine, writes a key as another type, holds another key or a bad range stops at its place",
        arguments: [
            (#"{ "name": "Shorts" }"#,
             #"top level (manifest): missing key "engine""#),
            (#"{ "engine": 1 }"#,
             "engine (manifest): expected a string, found 1"),
            (#"{ "engine": "^1", "version": 1 }"#,
             "version (manifest): expected a string, found 1"),
            (#"{ "engine": "^1", "author": "Someone" }"#,
             #"top level (manifest): unknown key "author". Allowed: engine, name, version, description"#),
            (#"{ "engine": ">=1.0" }"#,
             #"engine (manifest): ">=1.0" is not a range of versions. Write ^major, ^major.minor or ^major.minor.patch"#)
        ]
    )
    func refusesManifest(text: String, message: String) throws {
        // Given
        let data = Data(text.utf8)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.manifest(from: data, file: file) }
        #expect(error.map { "\($0)" } == "\(file): \(message)")
    }

    @Test("a pack.json that is not JSON stops, naming the file by its path")
    func refusesSyntax() throws {
        // Given
        let data = Data(#"{ "engine": "^1", }"#.utf8)

        // When, Then
        let error = #expect(throws: JSONError.self) { try sut.manifest(from: data, file: file) }
        #expect(error?.description == "\(file): line 1, column 19: expected a key in quotes")
    }
}
