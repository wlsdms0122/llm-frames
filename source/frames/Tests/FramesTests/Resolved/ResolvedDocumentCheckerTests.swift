//
//  ResolvedDocumentCheckerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ResolvedDocumentChecker Tests")
struct ResolvedDocumentCheckerTests {
    // MARK: - Property
    private let sut = ResolvedDocumentChecker(current: "1.2.3")

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a resolved document from this major version at this minor version or an earlier one is read",
        arguments: ["1.2.3", "1.2.0", "1.2.9", "1.0.0", "1.1.7"]
    )
    func readsVersion(version: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "resolved": "\#(version)" }"#)

        // When
        let read = try sut.version(of: document, theme: nil, arguments: nil)

        // Then
        #expect(read == version)
    }

    @Test(
        "a resolved document from another major version, a later minor version or no version is refused, naming both",
        arguments: [
            (#""1.3.0""#, "1.3.0"),
            (#""2.0.0""#, "2.0.0"),
            (#""0.9.0""#, "0.9.0"),
            (#""1.2""#, "1.2"),
            (#""1.2.3-beta""#, "1.2.3-beta"),
            (#""v1.2.3""#, "v1.2.3"),
            ("1", "1")
        ] as [(String, String)]
    )
    func refusesVersion(
        written: String,
        version: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "image", "resolved": \#(written) }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.version(of: document, theme: nil, arguments: nil) }
        #expect(error == .unreadableResolvedVersion(
            place: Place.root.appending(key: "resolved"),
            kind: "image",
            written: version,
            current: "1.2.3"
        ))
        #expect(error?.description.contains("1.2.3") == true)
        #expect(error?.description.contains(version) == true)
    }

    @Test("a document without resolved is not a resolved document")
    func passesDocument() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [] }"#)

        // When
        let read = try sut.version(of: document, theme: "shorts", arguments: nil)

        // Then
        #expect(read == nil)
    }

    @Test("a resolved document with --theme or --args stops, since both are already written in")
    func refusesOptions() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "layout", "resolved": "1.2.3" }"#)
        let arguments = ArgumentFile(name: "args.json", value: try Fixture.json("{}"))

        // When, Then
        #expect(throws: ResolveError.optionOnResolved(place: .root, kind: "layout", option: "--theme")) {
            try sut.version(of: document, theme: "shorts", arguments: nil)
        }
        #expect(throws: ResolveError.optionOnResolved(place: .root, kind: "layout", option: "--args")) {
            try sut.version(of: document, theme: nil, arguments: arguments)
        }
    }

    @Test(
        "a stop names the kind as written, since nothing checks a resolved document's keys before it",
        arguments: [
            (#"{ "kind": "sequnce", "resolved": "1.2.3" }"#, "sequnce"),
            (#"{ "resolved": "1.2.3" }"#, "document")
        ]
    )
    func namesWrittenKind(
        body: String,
        kind: String
    ) throws {
        // Given
        let document = try Fixture.json(body)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.version(of: document, theme: "shorts", arguments: nil) }
        #expect(error == .optionOnResolved(place: .root, kind: kind, option: "--theme"))
    }
}
