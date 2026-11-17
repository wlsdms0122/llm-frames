//
//  ResolvedPictureWriterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ResolvedPictureWriter Tests")
struct ResolvedPictureWriterTests {
    // MARK: - Property
    private let sut = ResolvedDocumentWriter()
    private let hashes = FileHashTable(["/abs/page.png": "c07d9a1e44f2"])

    // MARK: - Initializer
    // MARK: - Test
    @Test("an image resolves to its final size and its drawing steps in order, each with its clip")
    func writesImage() throws {
        // Given
        let document = #"""
            { "kind": "image", "source": "/abs/page.png",
              "ops": [ { "crop": [100, 100, 400, 200] }, { "resize": { "width": 800 } }, { "pad": 20 },
                       { "shape": "box", "area": [150, 150, 100, 50] }, { "border": true } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let steps = try #require(resolved["steps"]?.arrayValue?.compactMap { $0.objectValue })
        #expect(resolved.keys == ["kind", "resolved", "size", "steps"])
        #expect(resolved["kind"] == .string("image"))
        #expect(resolved["resolved"] == .string(FramesVersion.current))
        #expect(resolved["size"] == .array([.number(840), .number(440)]))
        #expect(steps.map { $0["draw"] } == ["picture", "fill", "fill", "fill", "fill", "box", "border"].map(JSONValue.string))
        #expect(steps.allSatisfy { Array($0.keys.prefix(4)) == ["place", "id", "kind", "draw"] && $0.keys.last == "clip" })
        #expect(steps.map { $0["place"] } == ["source", "ops[2]", "ops[2]", "ops[2]", "ops[2]", "ops[3]", "ops[4]"].map(JSONValue.string))
        #expect(steps.map { $0["kind"] } == ["image", "pad", "pad", "pad", "pad", "box", "border"].map(JSONValue.string))
        #expect(steps.allSatisfy { $0["id"] == .null })
        #expect(steps[0]["crop"] == .array([.number(100), .number(100), .number(400), .number(200)]))
        #expect(steps[0]["frame"] == .array([.number(20), .number(20), .number(800), .number(400)]))
        #expect(steps[6]["clip"] == .array([.number(0), .number(0), .number(840), .number(440)]))
    }

    @Test("the source picture is pinned and shown at its media second")
    func pinsSource() throws {
        // Given
        let document = #"{ "kind": "image", "source": "/abs/page.png", "ops": [] }"#

        // When
        let resolved = try write(document)

        // Then
        let picture = try #require(resolved["steps"]?.arrayValue?.first?.objectValue?["picture"]?.objectValue)
        #expect(picture.keys == ["file", "sha256", "time"])
        #expect(picture["file"] == .string("/abs/page.png"))
        #expect(picture["sha256"] == .string("c07d9a1e44f2"))
        #expect(picture["time"] == .number(0))
    }

    @Test("a layout keeps its kind, and a document it holds is written in place, its places continued from its item")
    func writesLayout() throws {
        // Given
        let document = #"""
            { "kind": "layout",
              "items": [ { "image": "/abs/card.png" }, { "image": { "kind": "image", "source": "/abs/page.png" } } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let pictures = try #require(resolved["steps"]?.arrayValue?.compactMap { $0.objectValue?["picture"]?.objectValue })
        #expect(resolved["kind"] == .string("layout"))
        #expect(pictures.first?["file"] == .string("/abs/card.png"))
        #expect(pictures.last?["kind"] == .string("image"))
        #expect(pictures.last?.keys == ["kind", "size", "steps"])
        let nested = pictures.last?["steps"]?.arrayValue?.first?.objectValue
        #expect(nested?["place"] == .string("items[1].image.source"))
        #expect(nested?["kind"] == .string("image"))
    }

    // MARK: - Private
    private func write(_ document: String) throws -> JSONObject {
        let text = sut.write(try ResolvedDocument(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: hashes))

        return try #require(try JSONReader().read(text).objectValue)
    }
}
