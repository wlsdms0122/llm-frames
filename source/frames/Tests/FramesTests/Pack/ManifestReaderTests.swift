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
    private let file = "/packs/shorts/manifest.toml"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a manifest gives what the pack calls itself, its version and description, and the engine range")
    func readsManifest() throws {
        // Given
        let data = Data(#"""
            [open-package]
            version = "1.0.0"

            [package]
            name = "Vertical shorts"
            version = "1.2.0"
            description = "Looks for vertical shorts"
            requires = ["sh"]

            [command]
            build = "sh build.sh"

            [frames]
            engine = "^1.0"
            """#.utf8)

        // When
        let manifest = try sut.manifest(from: data, file: file)

        // Then
        #expect(manifest == PackManifest(
            name: "Vertical shorts",
            version: "1.2.0",
            description: "Looks for vertical shorts",
            engine: try #require(EngineRange("^1.0"))
        ))
    }

    @Test(
        "a manifest that misses what frames reads, or writes it as another type, stops at its place",
        arguments: [
            ("[package]\nname = \"x\"\nversion = \"1\"\n[frames]\nengine = \"^1\"",
             #"top level (manifest): missing key "open-package""#),
            ("[open-package]\nversion = \"1.0.0\"\n[frames]\nengine = \"^1\"",
             #"top level (manifest): missing key "package""#),
            ("[open-package]\nversion = \"1.0.0\"\n[package]\nversion = \"1\"\n[frames]\nengine = \"^1\"",
             #"package (manifest): missing key "name""#),
            ("[open-package]\nversion = 1\n[package]\nname = \"x\"\nversion = \"1\"\n[frames]\nengine = \"^1\"",
             "open-package.version (manifest): expected a string, found 1"),
            ("[open-package]\nversion = \"1.0.0\"\n[package]\nname = \"x\"\nversion = \"1\"",
             #"top level (manifest): missing key "frames""#),
            ("[open-package]\nversion = \"1.0.0\"\n[package]\nname = \"x\"\nversion = \"1\"\n[frames]\nengine = \"^1\"\nlicense = \"MIT\"",
             #"frames (manifest): unknown key "license". Allowed: engine"#),
            ("[open-package]\nversion = \"1.0.0\"\n[package]\nname = \"x\"\nversion = \"1\"\n[frames]\nengine = \">=1.0\"",
             #"frames.engine (manifest): ">=1.0" is not a range of versions. Write ^major, ^major.minor or ^major.minor.patch"#)
        ]
    )
    func refusesManifest(text: String, message: String) throws {
        // Given
        let data = Data(text.utf8)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.manifest(from: data, file: file) }
        #expect(error.map { "\($0)" } == "\(file): \(message)")
    }
}
