//
//  MixPlanReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("MixPlanReader Tests")
struct MixPlanReaderTests {
    // MARK: - Property
    private let sut = MixPlanReader()
    private let writer = MixPlanWriter()

    private static let hash = String(repeating: "b", count: 64)
    private static let video = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/run.mp4", sha256: hash)),
        frameTimes: [0, 0.033367, 0.066733]
    )
    private static let music = PinnedMedia(source: .file(PinnedFile(path: "/abs/bgm.m4a", sha256: hash)))

    // A video's sound at speed 2 with a fade in, a loop of music as one segment per repeat under a ducking envelope,
    // and a compound clip's sound as a segment of its own.
    private static let plans = [
        MixPlan(segments: []),
        MixPlan(segments: [
            MixSegment(
                media: video,
                mediaStart: 2,
                speed: 2,
                start: 0,
                end: 3,
                envelope: [EnvelopePoint(time: 0, gain: 0), EnvelopePoint(time: 0.5, gain: 1), EnvelopePoint(time: 3, gain: 1)]
            ),
            MixSegment(
                media: music,
                mediaStart: 0,
                speed: 1,
                start: 0,
                end: 2.5,
                envelope: [EnvelopePoint(time: 0, gain: 0.3), EnvelopePoint(time: 2.5, gain: 0.3)]
            ),
            MixSegment(
                media: music,
                mediaStart: 0,
                speed: 1,
                start: 2.5,
                end: 4,
                envelope: [EnvelopePoint(time: 2.5, gain: 0.3), EnvelopePoint(time: 3.033333, gain: 0.15), EnvelopePoint(time: 4, gain: 0)]
            ),
            MixSegment(media: video, mediaStart: 0.125, speed: 0.5, start: 3, end: 4, envelope: [])
        ])
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mix plan reads back to the plan it was written from", arguments: plans.indices)
    func readsWrittenPlan(index: Int) throws {
        // Given
        let plan = Self.plans[index]

        // When
        let read = try sut.read(writer.write(plan))

        // Then
        #expect(read == plan)
    }

    @Test("an envelope is written as [time, gain] points")
    func writesEnvelopePoints() throws {
        // Given
        let plan = Self.plans[1]

        // When
        let segment = writer.document(plan).objectValue?["segments"]?.arrayValue?.first?.objectValue

        // Then
        #expect(segment?["envelope"]?.arrayValue?.last == .array([.number(3), .number(1)]))
    }

    @Test(
        "a mix plan from a later minor version or another major version is refused, naming both versions",
        arguments: ["1.1.0", "2.0.0", "0.9.0"]
    )
    func refusesOtherVersion(version: String) throws {
        // Given
        let text = replacingFirst(#""mixPlan": "1.0.0""#, with: #""mixPlan": "\#(version)""#, in: written())

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            mixPlan (mix plan): the mix plan was written by frames "\#(version)", and frames 1.0.0 reads only one \#
            written by frames 1.0 up to 1.0
            """#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""mixPlan": "1.0.0","#, "", #"top level (mix plan): missing key "mixPlan""#),
            (#""speed": 2,"#, "", #"segments[0] (segment): missing key "speed""#),
            (#""speed": 2,"#, #""speed": 2, "rate": 2,"#, #"segments[0] (segment): unknown key "rate". Allowed: media, mediaStart, speed, start, end, envelope"#),
            (#""mixPlan": "1.0.0","#, #""mixPlan": "1.0.0", "duration": 4,"#, #"top level (mix plan): unknown key "duration". Allowed: mixPlan, segments"#),
            (#""end": 3,"#, #""end": "3","#, #"segments[0].end (segment): expected a number, found "3""#)
        ]
    )
    func refusesUnreadableMember(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = replacingFirst(written, with: replacement, in: self.written())

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    // MARK: - Private
    private func written() -> String {
        writer.write(Self.plans[1])
    }

    private func replacingFirst(
        _ target: String,
        with replacement: String,
        in text: String
    ) -> String {
        guard let range = text.range(of: target) else {
            Issue.record("\(target) is not in the text")
            return text
        }

        return text.replacingCharacters(in: range, with: replacement)
    }
}
