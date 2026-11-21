//
//  PageMediaCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("Page Media Check Tests")
struct PageMediaCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a page of a PDF takes a still's keys, on the storyline and as a media clip")
    func takesStillKeys() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": { "file": "/abs/deck.pdf", "page": 3 }, "colorSpace": "display-p3", "duration": 2, "crop": [10, 10, 100.5, 50.25],
                "connected": [ { "at": [0, 2], "media": "/abs/logo.pdf", "colorSpace": "srgb", "width": 200, "placement": "top-right" } ] }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a text form is allowed in the crop of a page clip and in the area of a clip parented to one")
    func takesTextFormOnPage() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/run.mp4", "connected": [
                { "id": "page", "at": [0, 2], "media": { "file": "/abs/deck.pdf", "page": 3 }, "crop": { "text": "Total", "padding": 4 } },
                { "at": [0, 2], "parent": "page", "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" } } ] }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a PDF of one page named as a file is a page, as {file, page: 1} is")
    func readsOnePageFileAsPage() throws {
        // Given
        let named = JSONValue.string("/abs/logo.pdf")
        let page = try Fixture.json(#"{ "file": "/abs/logo.pdf", "page": 1 }"#)

        // When
        let namedKind = try sut.mediaKind(of: named, place: .root, kind: "clip")
        let pageKind = try sut.mediaKind(of: page, place: .root, kind: "clip")

        // Then
        #expect(namedKind == .page)
        #expect(pageKind == .page)
    }

    @Test(
        "a PDF of several pages named as a file stops, naming the file and its page count",
        arguments: [
            (
                #"{ "storyline": [ { "media": "/abs/deck.pdf" } ] }"#,
                #"storyline[0].media (storyline clip): media "/abs/deck.pdf" is a PDF of 12 pages, more than one picture, so a page of it is named as {"file", "page"}"#
            ),
            (
                #"{ "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "media": "/abs/deck.pdf" } ] } ] }"#,
                #"storyline[0].connected[0].media (clip): media "/abs/deck.pdf" is a PDF of 12 pages, more than one picture, so a page of it is named as {"file", "page"}"#
            )
        ]
    )
    func refusesPdfOfSeveralPagesByFile(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a page the file does not hold stops: one above the page count, and any page of a file that is not a PDF",
        arguments: [
            (
                #"{ "file": "/abs/deck.pdf", "page": 13 }"#,
                #"storyline[0].media.page (storyline clip): media "/abs/deck.pdf" has 12 pages, so it has no page 13"#
            ),
            (
                #"{ "file": "/abs/card.png", "page": 1 }"#,
                #"storyline[0].media.page (storyline clip): media "/abs/card.png" is not a PDF, so it has no pages"#
            ),
            (
                #"{ "file": "/abs/unknown.pdf", "page": 1 }"#,
                #"storyline[0].media (storyline clip): media "/abs/unknown.pdf" is not there"#
            )
        ]
    )
    func refusesPageTheFileDoesNotHold(
        media: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": \#(media) } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a page is a whole number from 1, and file and page are both required",
        arguments: [
            (#"{ "file": "/abs/deck.pdf", "page": 0 }"#, "storyline[0].media.page (page): expected a whole number, 1 or more, found 0"),
            (#"{ "file": "/abs/deck.pdf", "page": 1.5 }"#, "storyline[0].media.page (page): expected a whole number, 1 or more, found 1.5"),
            (#"{ "file": "/abs/deck.pdf", "page": "2" }"#, #"storyline[0].media.page (page): expected a whole number, 1 or more, found "2""#),
            (#"{ "file": "/abs/deck.pdf" }"#, #"storyline[0].media (page): missing key "page""#),
            (#"{ "file": "/abs/deck.pdf", "page": 2, "fps": 30 }"#, #"storyline[0].media (page): unknown key "fps". Allowed: file, page"#)
        ]
    )
    func refusesMalformedPage(
        media: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": \#(media) } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("media written as an object names one of its forms, a page among them")
    func namesPageAmongForms() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "page": 2 } } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[0].media (media): needs one of kind, imageSequence, template, file")
    }

    @Test("an argument object holding file is media, so its page is checked where it is written")
    func checksPageArgument() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "pack/card", "args": { "still": { "file": "/abs/deck.pdf", "page": -1 } } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[0].media.args.still.page (page): expected a whole number, 1 or more, found -1")
    }

    // MARK: - Private
}
