//
//  ImageCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Image Check Tests")
struct ImageCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test("the image document of the specification passes the key tables")
    func acceptsImageExample() throws {
        // Given
        let document = try Fixture.json(##"""
            {
              "kind": "image",
              "source": "/abs/shot.png",
              "ops": [
                { "crop": { "band": { "from": "Certificate", "to": "Last line" } } },
                { "shape": "fill", "area": "issuerDn:", "color": "#000000" },
                { "shape": "box", "area": "serialNumber: 9190809", "label": "matches the server" },
                { "shape": "dim", "area": { "from": "LV2", "to": "Cert,O=" } },
                { "shape": "arrow", "area": "serialNumber", "side": "right", "label": "here" },
                { "resize": { "width": 800 } },
                { "pad": [20, 40], "color": "#FFFFFF" },
                { "banner": [ { "text": "Bold first line", "style": "bannerHead" }, "Regular line" ], "edge": "top" },
                { "border": true }
              ]
            }
            """##)

        // When, Then
        try sut.check(document: document)
    }

    @Test("the layout document of the specification passes the key tables")
    func acceptsLayoutExample() throws {
        // Given
        let document = try Fixture.json(#"""
            {
              "kind": "layout",
              "banner": [ { "text": "Bold first line", "style": "bannerHead" }, "Regular line" ],
              "columns": 2,
              "border": true,
              "items": [
                { "heading": "Before", "image": { "kind": "image", "source": "/abs/before.png", "ops": [ { "shape": "box", "area": "9190799" } ] } },
                { "heading": "After", "image": "/abs/after.png" }
              ]
            }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "an op is told apart by its op key and takes only that op's keys",
        arguments: [
            (#"{ "crop": [0, 0, 1, 1], "resize": { "scale": 2 } }"#, #"ops[0] (operation): takes only one of "crop", "resize""#),
            (#"{ "id": "x" }"#, "ops[0]#x (operation): needs one of crop, resize, pad, shape, adjust, title, banner, border"),
            (#"{ "pad": 10, "edge": "top" }"#, #"ops[0] (pad): unknown key "edge". Allowed: id, metadata, pad, color"#),
            (#"{ "shape": "box", "area": "a", "side": "left" }"#, #"ops[0] (box): unknown key "side". Allowed: id, metadata, shape, area, label, color"#),
            (#"{ "title": "Hi", "position": [0, 0] }"#, #"ops[0] (title): missing key "style""#),
            (#"{ "title": "Hi", "style": "label" }"#, #"ops[0] (title): missing key "position""#),
            (#"{ "shape": "dim" }"#, #"ops[0] (dim): missing key "area""#),
            (#"{ "banner": ["a"] }"#, #"ops[0] (banner): missing key "edge""#),
            (#"{ "resize": { "width": 800, "height": 600 } }"#, #"ops[0].resize (resize): takes only one of "width", "height""#),
            (#"{ "resize": {} }"#, "ops[0].resize (resize): needs one of scale, width, height"),
            (#"{ "pad": [1, 2, 3] }"#, "ops[0].pad (pad): expected whole pixels, 0 or more, as n, [vertical, horizontal] or [top, right, bottom, left], found a list of 3"),
            (#"{ "pad": -1 }"#, "ops[0].pad (pad): expected whole pixels, 0 or more, found -1"),
            (#"{ "pad": 0.5 }"#, "ops[0].pad (pad): expected whole pixels, 0 or more, found 0.5"),
            (#"{ "pad": [1, -2] }"#, "ops[0].pad[1] (pad): expected whole pixels, 0 or more, found -2"),
            (#"{ "border": false }"#, "ops[0].border (border): expected true or a colour, found false"),
            (#"{ "banner": ["a"], "edge": "left" }"#, #"ops[0].edge (banner): unknown value "left". Allowed: top, bottom"#),
            (#"{ "banner": [ { "style": "banner" } ] }"#, #"ops[0].banner[0] (banner line): missing key "text""#),
            (#"{ "adjust": "pixelate", "area": "Name", "anim": 1 }"#, #"ops[0] (adjust): unknown key "anim". Allowed: id, metadata, adjust, area"#)
        ]
    )
    func checksOperationKeys(
        operation: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "image", "source": "/abs/shot.png", "ops": [ \#(operation) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("every op may carry an id and metadata, and ids are unique in the document")
    func checksOperationIdentifiers() throws {
        // Given
        let unique = try Fixture.json(#"{ "kind": "image", "source": "/abs/shot.png", "ops": [ { "id": "a", "metadata": { "k": 1 }, "border": true }, { "id": "b", "pad": 4 } ] }"#)
        let duplicate = try Fixture.json(#"{ "kind": "image", "source": "/abs/shot.png", "ops": [ { "id": "a", "border": true }, { "id": "a", "pad": 4 } ] }"#)

        // When, Then
        try sut.check(document: unique)
        #expect(throws: ModelError.self) { try sut.check(document: duplicate) }
    }

    @Test(
        "the image and layout documents take only their own keys",
        arguments: [
            (#"{ "kind": "image", "ops": [] }"#, #"top level (image): missing key "source""#),
            (#"{ "kind": "image", "source": "/abs/shot.png", "columns": 2 }"#, #"top level (image): unknown key "columns". Allowed: kind, source, time, theme, params, ops"#),
            (#"{ "kind": "layout", "items": [ { "image": "/abs/a.png", "caption": "x" } ] }"#, #"items[0] (layout item): unknown key "caption". Allowed: heading, image"#),
            (#"{ "kind": "layout", "columns": 1.5 }"#, "columns (layout): expected a whole number, found 1.5"),
            (#"{ "kind": "layout", "theme": { "colours": {} } }"#, #"theme (theme): unknown key "colours". Allowed: baseWidth, font, colors, styles, shapes, area, placement, image, layout, defaults"#)
        ]
    )
    func checksDocumentKeys(
        text: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }
}
