//
//  PagePinningTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("Page Pinning Tests")
struct PagePinningTests {
    // MARK: - Property
    private static let pageClips = #"""
        { "kind": "sequence", "storyline": [ { "media": { "file": "/abs/deck.pdf", "page": 3 }, "duration": 2, "connected": [
            { "media": { "file": "/abs/deck.pdf", "page": 2 }, "at": [0, 1] } ] } ] }
        """#

    private let hashes = FileHashTable()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a page resolves as a still of its PDF, pinned as its file with its number")
    func pinsPage() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": { "file": "/abs/deck.pdf", "page": 3 }, "duration": 2 } ] }
            """#

        // When
        let resolved = try resolved(document)

        // Then
        #expect(resolved.storyline[0].media == .pinned(PinnedMedia(
            source: .page(PinnedFile(path: "/abs/deck.pdf", sha256: "sha256-of-/abs/deck.pdf"), page: 3)
        )))
        #expect(resolved.storyline[0].end == 2)
    }

    @Test("a PDF of one page named as a file and as {file, page: 1} are written in one form, {file, sha256, page}")
    func writesOnePageFileAsPage() throws {
        // Given
        let named = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/logo.pdf", "duration": 2 } ] }"#
        let page = #"{ "kind": "sequence", "storyline": [ { "media": { "file": "/abs/logo.pdf", "page": 1 }, "duration": 2 } ] }"#

        // When
        let namedMedia = try writtenMedia(of: resolved(named))
        let pageMedia = try writtenMedia(of: resolved(page))

        // Then
        #expect(namedMedia == pageMedia)
        #expect(namedMedia.map(\.key) == ["file", "sha256", "page"])
        #expect(namedMedia.last?.value == .number(1))
    }

    @Test("a pinned page reads back as written, and a page that is not a whole number from 1 stops")
    func readsPinnedPage() throws {
        // Given
        let sut = ResolvedValueReader()
        let pinned = try Fixture.json(#"{ "file": "/abs/deck.pdf", "sha256": "abc", "page": 3 }"#)
        let zero = try Fixture.json(#"{ "file": "/abs/deck.pdf", "sha256": "abc", "page": 0 }"#)

        // When
        let media = try sut.media(PlacedJSONValue(pinned, place: .root, kind: "clip"))
        let error = #expect(throws: ModelError.self) { try sut.media(PlacedJSONValue(zero, place: .root, kind: "clip")) }

        // Then
        #expect(media == PinnedMedia(source: .page(PinnedFile(path: "/abs/deck.pdf", sha256: "abc"), page: 3)))
        #expect(error?.description.contains("a whole number, 1 or more") == true)
    }

    @Test("a page's storyline entry and media clip write toneMap null, as media that takes none, and read back as written")
    func writesNoToneMapOfPage() throws {
        // Given
        let sut = ResolvedDocumentWriter()
        let resolved = try resolved(Self.pageClips)

        // When
        let text = sut.write(resolved)

        // Then
        let root = try #require(try JSONReader().read(text).objectValue)
        #expect(root["storyline"]?.arrayValue?.first?.objectValue?["toneMap"] == .null)
        #expect(root["clips"]?.arrayValue?.first?.objectValue?["toneMap"] == .null)
        #expect(try ResolvedDocumentReader().read(text) == resolved)
    }

    @Test(
        "a resolved page entry that writes a toneMap or a colour space of high dynamic range stops, naming its place",
        arguments: [
            ("storyline", "toneMap", "true", #"storyline[0].toneMap (storyline clip): a page is not HDR and takes no toneMap, so it is null here, found true"#),
            ("clips", "toneMap", "false", #"clips[0].toneMap (clip): a page is not HDR and takes no toneMap, so it is null here, found false"#),
            ("storyline", "colorSpace", #""rec2100-pq""#, #"storyline[0].colorSpace (storyline clip): unknown value "rec2100-pq""#),
            ("clips", "colorSpace", #""rec2100-hlg""#, #"clips[0].colorSpace (clip): unknown value "rec2100-hlg""#)
        ]
    )
    func refusesHighDynamicRangePageReading(
        list: String,
        key: String,
        value: String,
        message: String
    ) throws {
        // Given
        let sut = ResolvedDocumentReader()
        let root = try #require(try JSONReader().read(ResolvedDocumentWriter().write(resolved(Self.pageClips))).objectValue)
        var entries = try #require(root[list]?.arrayValue)
        let entry = try #require(entries[0].objectValue)
        entries[0] = .object(entry.setting(key, to: try Fixture.json(value)))
        let text = JSONWriter().write(.object(root.setting(list, to: .array(entries))))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description.hasPrefix(message) == true)
    }

    @Test("two places that read one page in different colour spaces stop, an unwritten one read as srgb")
    func refusesPageInTwoColorSpaces() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": { "file": "/abs/deck.pdf", "page": 3 }, "duration": 2, "connected": [
                { "media": { "file": "/abs/deck.pdf", "page": 3 }, "colorSpace": "display-p3", "at": [0, 1] } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try checkMediaColorSpaces(of: document) }
        #expect(error?.description.hasPrefix(#"storyline[0].connected[0] (clip): "/abs/deck.pdf" is read as "display-p3" here and as "srgb" at storyline[0]"#) == true)
    }

    @Test("two pages of one PDF are two media, so each reads in its own colour space, and srgb written or not agrees")
    func acceptsPagesInTheirOwnColorSpaces() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": { "file": "/abs/deck.pdf", "page": 3 }, "duration": 2, "connected": [
                { "media": { "file": "/abs/deck.pdf", "page": 4 }, "colorSpace": "display-p3", "at": [0, 1] },
                { "media": { "file": "/abs/deck.pdf", "page": 3 }, "colorSpace": "srgb", "at": [0, 1] } ] } ] }
            """#

        // When, Then
        #expect(throws: Never.self) { try checkMediaColorSpaces(of: document) }
    }

    @Test("the timeline names a clip of a page by kind page")
    func reportsPageKind() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 2, "connected": [
                { "media": { "file": "/abs/deck.pdf", "page": 3 }, "at": [0, 1] } ] } ] }
            """#

        // When
        let report = TimelineReporter(planner: Fixture.documentPlanner).report(of: try resolved(document))

        // Then
        #expect(report.clips.map(\.kind) == ["page"])
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: hashes)
    }

    private func checkMediaColorSpaces(of document: String) throws {
        let plan = try Fixture.documentPlanner.plan(Fixture.json(document))
        try ResolvedSequence(plan: plan, hashes: hashes)
            .checkMediaColorSpaces(taggedColorSpaces: plan.time.taggedColorSpaces)
    }

    private func writtenMedia(of resolved: ResolvedSequence) throws -> [JSONMember] {
        guard case let .pinned(media)? = resolved.storyline.first?.media else {
            Issue.record("no pinned media")
            return []
        }

        return ResolvedValueWriter().media(media)
    }
}
