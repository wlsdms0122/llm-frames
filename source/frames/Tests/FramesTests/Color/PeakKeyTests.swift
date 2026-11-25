//
//  PeakKeyTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

// `format.peak`: the mastering peak of a `rec2100-pq` sequence, from 400 to 10000 cd/m², 1000 by default, carried by
// the resolved document, the display list's outermost list and every tone mapped picture's `targetPeak`.
@Suite("Peak Key Tests")
struct PeakKeyTests {
    // MARK: - Property
    private let checker = KeyChecker(mediaKinds: Fixture.mediaKinds)
    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let listWriter = DisplayListWriter()
    private let listReader = DisplayListReader()
    private let evaluator = Evaluator()
    private let hashes = FileHashTable()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a PQ sequence's peak is 1000 by default or as written, and every other sequence's is null",
        arguments: [
            (#""colorSpace": "rec2100-pq""#, Optional(1000.0)),
            (#""colorSpace": "rec2100-pq", "peak": 4000"#, 4000),
            (#""colorSpace": "rec2100-hlg""#, nil),
            (#""colorSpace": "display-p3""#, nil),
            ("", nil)
        ]
    )
    func resolvesPeak(
        members: String,
        expected: Double?
    ) throws {
        // Given
        let document = #"{ "kind": "sequence", "format": { \#(members) }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#

        // When
        let resolved = try resolved(document)
        let written = try #require(try JSONReader().read(writer.write(resolved)).objectValue)
        let read = try reader.read(writer.write(resolved))

        // Then
        #expect(resolved.format.peak == expected)
        let format = try #require(written["format"]?.objectValue)
        #expect(format["peak"] == (expected.map { .number($0) } ?? .null))
        #expect(read == resolved)
    }

    @Test(
        "a peak outside 400 to 10000 or in a sequence that is not rec2100-pq stops at check",
        arguments: [
            (#""colorSpace": "rec2100-pq", "peak": 300"#, "format.peak"),
            (#""colorSpace": "rec2100-pq", "peak": 12000"#, "format.peak"),
            (#""peak": 1000"#, "only a rec2100-pq sequence takes a peak, and this one's colorSpace is srgb"),
            (#""colorSpace": "rec2100-hlg", "peak": 1000"#, "this one's colorSpace is rec2100-hlg")
        ]
    )
    func refusesPeak(
        members: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(
            #"{ "kind": "sequence", "format": { \#(members) }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description.contains(message) == true)
    }

    @Test(
        "a resolved format stops on a peak outside 400 to 10000 and on one in a sequence that is not rec2100-pq",
        arguments: [("rec2100-pq", "200"), ("rec2100-pq", "null"), ("srgb", "1000")]
    )
    func refusesResolvedPeak(
        colorSpace: String,
        peak: String
    ) throws {
        // Given
        let resolved = try resolved(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#)
        let text = writer.write(resolved)
            .replacingOccurrences(of: #""colorSpace": "srgb""#, with: #""colorSpace": "\#(colorSpace)""#)
            .replacingOccurrences(of: #""peak": null"#, with: #""peak": \#(peak)"#)

        // When, Then
        #expect(throws: ModelError.self) { try reader.read(text) }
    }

    @Test("a PQ sequence's display list carries its peak, and its pictures are tone mapped to it")
    func carriesPeakInDisplayList() throws {
        // Given
        let resolved = try resolved(#"""
            { "kind": "sequence", "format": { "colorSpace": "rec2100-pq", "peak": 600 }, "storyline": [
                { "kind": "media", "media": "/abs/run.mp4" } ] }
            """#)

        // When
        let list = evaluator.displayList(of: resolved, at: 0.5)
        let read = try listReader.read(listWriter.write(list))

        // Then
        #expect(list.peak == 600)
        #expect(targetPeaks(in: list) == [600])
        #expect(read.peak == 600)
    }

    @Test("an SDR sequence's display list writes a null peak")
    func writesNullPeak() throws {
        // Given
        let resolved = try resolved(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#)

        // When
        let list = evaluator.displayList(of: resolved, at: 0.5)
        let written = try #require(try JSONReader().read(listWriter.write(list)).objectValue)

        // Then
        #expect(list.peak == nil)
        #expect(written["peak"] == .null)
        #expect(Array(written.keys.prefix(5)) == ["displayList", "size", "background", "colorSpace", "peak"])
    }

    // MARK: - Private
    // The target peak of every media frame a picture shows, nested lists included, bottom first.
    private func targetPeaks(in list: DisplayList) -> [Double?] {
        list.items.flatMap { item -> [Double?] in
            guard case let .picture(picture) = item.content else { return [] }

            switch picture.source {
            case let .media(frame):
                guard case let .working(_, targetPeak) = frame.reading else { return [nil] }

                return [targetPeak]

            case let .displayList(nested):
                return targetPeaks(in: nested)
            }
        }
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: hashes)
    }
}
