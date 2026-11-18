//
//  RecognitionLanguageTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("Recognition Language Tests")
struct RecognitionLanguageTests {
    // MARK: - Property
    private let korean = ["ko-KR"].compactMap(LanguageTag.init)
    // A text area a clip is drawn over, and a text a clip follows, both found by OCR in the parent's media.
    private static let documents = [
        #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "screen" } ] } ] }"#,
        #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "parent": "screen", "track": { "text": "Total" } } ] } ] }"#
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("resolve finds a text area and a tracked text in the recognition languages it is given", arguments: documents)
    func resolvesInGivenLanguages(document: String) throws {
        // Given
        let sut = planner(languages: korean)
        let document = try Fixture.json(document)

        // When
        let plan = try sut.plan(document)

        // Then
        #expect(plan.time.storyline.count == 1)
    }

    @Test("resolve without recognition languages asks the provider to detect them", arguments: documents)
    func resolvesWithoutLanguages(document: String) throws {
        // Given
        let sut = planner(languages: nil)
        let document = try Fixture.json(document)

        // When
        let error = #expect(throws: AreaError.self) { try sut.plan(document) }

        // Then
        #expect(error?.description.contains(#""Total""#) == true)
    }

    @Test("track finds a text area in the recognition languages it is given")
    func tracksInGivenLanguages() throws {
        // Given
        let sut = TrackReporter(
            mediaFacts: Fixture.mediaFacts,
            ocr: LanguageOCRTable(languages: korean, table: Fixture.ocr),
            languages: korean,
            tracker: Fixture.tracker
        )
        let detecting = TrackReporter(
            mediaFacts: Fixture.mediaFacts,
            ocr: LanguageOCRTable(languages: korean, table: Fixture.ocr),
            languages: nil,
            tracker: Fixture.tracker
        )

        // When
        let report = try sut.report(of: "/abs/screen.mp4", area: #"{"text": "Total"}"#, at: 1, to: 1)
        let error = #expect(throws: AreaError.self) {
            try detecting.report(of: "/abs/screen.mp4", area: #"{"text": "Total"}"#, at: 1, to: 1)
        }

        // Then
        #expect(report.track.target == Quad(Fixture.total))
        #expect(error != nil)
    }

    // MARK: - Private
    private func planner(languages: [LanguageTag]?) -> DocumentPlanner {
        DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: LanguageOCRTable(languages: korean, table: Fixture.ocr),
            languages: languages,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )
    }
}
