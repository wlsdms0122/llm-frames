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
    private static let impulseResponseHash = String(repeating: "c", count: 64)
    private static let video = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/run.mp4", sha256: hash), frameTimes: [0, 0.033367, 0.066733])
    )
    private static let music = PinnedMedia(source: .file(PinnedFile(path: "/abs/bgm.m4a", sha256: hash), frameTimes: nil))

    // An audio filter of every op: an `eq` with a band of each kind, its high pass sweeping up, a compressor, a gate
    // fading in by its `mix`, and a limiter whose `gain` moves followed by a convolution whose `gain` holds.
    private static let filter = [
        MixFilterEntry(
            operations: [
                .eq(bands: [
                    MixBand(
                        type: .highPass,
                        frequency: .envelope([EnvelopePoint(time: 0, value: 80), EnvelopePoint(time: 1, value: 160)]),
                        gain: nil,
                        q: .constant(0.7071)
                    ),
                    MixBand(type: .lowPass, frequency: .constant(12_000), gain: nil, q: .constant(0.7071)),
                    MixBand(type: .peak, frequency: .constant(3000), gain: .constant(3), q: .constant(1)),
                    MixBand(type: .lowShelf, frequency: .constant(200), gain: .constant(-2), q: .constant(0.7071)),
                    MixBand(type: .highShelf, frequency: .constant(8000), gain: .constant(1.5), q: .constant(0.7071))
                ]),
                .compressor(MixCompressor(
                    threshold: .constant(-18),
                    ratio: .constant(3),
                    knee: .constant(6),
                    attack: .constant(0.01),
                    release: .constant(0.1),
                    makeup: .constant(2)
                ))
            ],
            mix: .constant(1)
        ),
        MixFilterEntry(
            operations: [
                .gate(MixGate(
                    threshold: .constant(-50),
                    range: .constant(-80),
                    attack: .constant(0.001),
                    hold: .constant(0.05),
                    release: .constant(0.1)
                ))
            ],
            mix: .envelope([EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.5, value: 1), EnvelopePoint(time: 3, value: 1)])
        ),
        MixFilterEntry(
            operations: [
                .limiter(MixLimiter(
                    gain: .envelope([EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 3, value: 4.5)]),
                    ceiling: .constant(-1),
                    lookahead: 0.005,
                    release: .constant(0.1)
                )),
                .convolve(MixConvolution(file: PinnedFile(path: "/abs/hall.wav", sha256: impulseResponseHash), gain: .constant(-6)))
            ],
            mix: .constant(1)
        )
    ]

    // A silent plan; a video's sound at speed 2 with a fade in and an audio filter, a loop of music as one segment per
    // repeat under a ducking envelope and panning left, and a sound at speed 0.5; and a compound clip's bus holding a
    // sound and the bus of a compound clip inside it, its chain and level moving, under the sequence's chain.
    private static let plans = [
        MixPlan(length: 0, segments: []),
        MixPlan(length: 192_000, segments: [
            MixSegment(
                media: .pinned(video),
                mediaStart: 2,
                speed: 2,
                start: 0,
                end: 3,
                filter: filter,
                envelope: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.5, value: 1), EnvelopePoint(time: 3, value: 1)],
                pan: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 3, value: 0)]
            ),
            MixSegment(
                media: .pinned(music),
                mediaStart: 0,
                speed: 1,
                start: 0,
                end: 2.5,
                envelope: [EnvelopePoint(time: 0, value: 0.3), EnvelopePoint(time: 2.5, value: 0.3)],
                pan: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 2.5, value: -0.4)]
            ),
            MixSegment(
                media: .pinned(music),
                mediaStart: 0,
                speed: 1,
                start: 2.5,
                end: 4,
                envelope: [EnvelopePoint(time: 2.5, value: 0.3), EnvelopePoint(time: 3.033333, value: 0.15), EnvelopePoint(time: 4, value: 0)],
                pan: [EnvelopePoint(time: 2.5, value: -0.4), EnvelopePoint(time: 4, value: -0.4)]
            ),
            MixSegment(media: .pinned(video), mediaStart: 0.125, speed: 0.5, start: 3, end: 4, envelope: [], pan: [])
        ]),
        MixPlan(
            length: 4805,
            segments: [],
            buses: [
                MixBus(
                    start: 0,
                    end: 0.1,
                    segments: [
                        MixSegment(
                            media: .pinned(music),
                            mediaStart: 1,
                            speed: 1,
                            start: 0,
                            end: 0.1,
                            envelope: [EnvelopePoint(time: 0, value: 1), EnvelopePoint(time: 0.1, value: 1)],
                            pan: [EnvelopePoint(time: 0, value: 0.5), EnvelopePoint(time: 0.1, value: 0.5)]
                        )
                    ],
                    buses: [
                        MixBus(
                            start: 0.05,
                            end: 0.1,
                            segments: [MixSegment(media: .pinned(video), mediaStart: 0, speed: 2, start: 0.05, end: 0.1, envelope: [], pan: [])],
                            envelope: [EnvelopePoint(time: 0.05, value: 0.8), EnvelopePoint(time: 0.1, value: 0)]
                        )
                    ],
                    filter: Array(filter.suffix(2)),
                    envelope: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.033367, value: 1), EnvelopePoint(time: 0.1, value: 1)]
                )
            ],
            filter: Array(filter.prefix(1))
        )
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

    @Test("a pan envelope is written as [time, pan] points after the gain envelope")
    func writesPanPoints() throws {
        // Given
        let plan = Self.plans[1]

        // When
        let segment = writer.document(plan).objectValue?["segments"]?.arrayValue?[1].objectValue

        // Then
        #expect(segment?.keys.suffix(2) == ["envelope", "pan"])
        #expect(segment?["pan"]?.arrayValue == [.array([.number(0), .number(0)]), .array([.number(2.5), .number(-0.4)])])
    }

    @Test(
        "a mix plan from a later minor version or another major version is refused, naming both versions",
        arguments: ["0.2.0", "1.0.0"]
    )
    func refusesOtherVersion(version: String) throws {
        // Given
        let text = replacingFirst(#""mixPlan": "0.1.0""#, with: #""mixPlan": "\#(version)""#, in: written())

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            mixPlan (mix plan): the mix plan was written by frames "\#(version)", and frames 0.1.0 reads only one \#
            written by frames 0.0 up to 0.1
            """#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""mixPlan": "0.1.0","#, "", #"top level (mix plan): missing key "mixPlan""#),
            (#""speed": 2,"#, "", #"segments[0] (segment): missing key "speed""#),
            (#""speed": 2,"#, #""speed": 2, "rate": 2,"#, #"segments[0] (segment): unknown key "rate". Allowed: media, mediaStart, speed, start, end, filter, envelope, pan"#),
            (#""mixPlan": "0.1.0","#, #""mixPlan": "0.1.0", "duration": 4,"#, #"top level (mix plan): unknown key "duration". Allowed: mixPlan, length, segments, buses, filter"#),
            (#""length": 192000,"#, "", #"top level (mix plan): missing key "length""#),
            (#""length": 192000,"#, #""length": 192000.5,"#, #"length (mix plan): expected a whole number, found 192000.5"#),
            (#""end": 3,"#, #""end": "3","#, #"segments[0].end (segment): expected a number, found "3""#),
            (#""kind": "file","#, "", #"segments[0].media (segment): missing key "kind""#),
            (#""kind": "file","#, #""kind": "video","#, #"segments[0].media.kind (segment): unknown value "video". Allowed: file, imageSequence, page"#)
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

    @Test("a filter value that holds is written as a number, and one that moves as [time, value] points")
    func writesFilterValues() throws {
        // Given
        let plan = Self.plans[1]

        // When
        let segment = writer.document(plan).objectValue?["segments"]?.arrayValue?.first?.objectValue
        let entries = segment?["filter"]?.arrayValue
        let band = entries?.first?.objectValue?["ops"]?.arrayValue?.first?.objectValue?["bands"]?.arrayValue?.first

        // Then
        #expect(segment?.keys == ["media", "mediaStart", "speed", "start", "end", "filter", "envelope", "pan"])
        #expect(segment?["media"]?.objectValue?.keys == ["kind", "file", "sha256", "frames"])
        #expect(segment?["media"]?.objectValue?["kind"] == .string("file"))
        #expect(band?.objectValue?.keys == ["kind", "frequency", "q"])
        #expect(band?.objectValue?["frequency"] == .array([.array([.number(0), .number(80)]), .array([.number(1), .number(160)])]))
        #expect(band?.objectValue?["q"] == .number(0.7071))
        #expect(entries?[1].objectValue?["mix"]?.arrayValue?.count == 3)
    }

    @Test("a limiter is written with its parameters in the op table's order, its static `lookahead` a plain number")
    func writesLimiter() throws {
        // Given
        let plan = Self.plans[1]

        // When
        let segment = writer.document(plan).objectValue?["segments"]?.arrayValue?.first?.objectValue
        let limiter = segment?["filter"]?.arrayValue?.last?.objectValue?["ops"]?.arrayValue?.first?.objectValue

        // Then
        #expect(limiter?.keys == ["kind", "gain", "ceiling", "lookahead", "release"])
        #expect(limiter?["kind"] == .string("limiter"))
        #expect(limiter?["gain"] == .array([.array([.number(0), .number(0)]), .array([.number(3), .number(4.5)])]))
        #expect(limiter?["ceiling"] == .number(-1) && limiter?["lookahead"] == .number(0.005))
    }

    @Test("a convolution is written with its pinned impulse response and its gain")
    func writesConvolution() throws {
        // Given
        let plan = Self.plans[1]

        // When
        let segment = writer.document(plan).objectValue?["segments"]?.arrayValue?.first?.objectValue
        let convolution = segment?["filter"]?.arrayValue?.last?.objectValue?["ops"]?.arrayValue?.last?.objectValue

        // Then
        #expect(convolution?.keys == ["kind", "file", "sha256", "gain"])
        #expect(convolution?["kind"] == .string("convolve"))
        #expect(convolution?["file"] == .string("/abs/hall.wav"))
        #expect(convolution?["sha256"] == .string(Self.impulseResponseHash))
        #expect(convolution?["gain"] == .number(-6))
    }

    @Test(
        "a filter entry, op or band written in a form the writer never writes stops, naming its place",
        arguments: [
            (
                #""kind": "highPass","#,
                #""kind": "notch","#,
                #"segments[0].filter[0].ops[0].bands[0].kind (band): unknown value "notch". Allowed: lowShelf, highShelf, peak, lowPass, highPass"#
            ),
            (
                #""kind": "highPass","#,
                #""kind": "highPass", "gain": 3,"#,
                #"segments[0].filter[0].ops[0].bands[0] (highPass band): unknown key "gain". Allowed: kind, frequency, q"#
            ),
            (
                #""kind": "compressor","#,
                #""kind": "saturator","#,
                #"segments[0].filter[0].ops[1].kind (audio op): unknown value "saturator". Allowed: eq, compressor, gate, limiter, convolve"#
            ),
            (
                #""lookahead": 0.005"#,
                #""lookahead": [[0, 0.005]]"#,
                #"segments[0].filter[2].ops[0].lookahead (limiter): expected a number, found a list of 1"#
            ),
            (
                #""kind": "limiter","#,
                #""kind": "limiter", "threshold": -1,"#,
                #"segments[0].filter[2].ops[0] (limiter): unknown key "threshold". Allowed: kind, gain, ceiling, lookahead, release"#
            ),
            (
                #""kind": "convolve","#,
                #""kind": "convolve", "threshold": -1,"#,
                #"segments[0].filter[2].ops[1] (convolve): unknown key "threshold". Allowed: kind, file, sha256, gain"#
            ),
            (
                #""sha256": "\#(impulseResponseHash)","#,
                "",
                #"segments[0].filter[2].ops[1] (convolve): missing key "sha256""#
            ),
            (
                #""gain": -6"#,
                #""gain": "loud""#,
                #"segments[0].filter[2].ops[1].gain (convolve): expected a number or a list of [time, value] points, found "loud""#
            ),
            (
                #""kind": "compressor","#,
                #""kind": "compressor", "hold": 0,"#,
                #"segments[0].filter[0].ops[1] (compressor): unknown key "hold". Allowed: kind, threshold, ratio, knee, attack, release, makeup"#
            ),
            (
                #""threshold": -18,"#,
                "",
                #"segments[0].filter[0].ops[1] (compressor): missing key "threshold""#
            ),
            (
                #""mix": 1"#,
                #""mix": []"#,
                #"segments[0].filter[0].mix (filter entry): expected a number or a list of [time, value] points, found a list of 0"#
            )
        ]
    )
    func refusesUnreadableFilter(
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

    @Test("a segment of a file nothing pins writes its media as a file with its hash and frame times null")
    func writesUnpinnedMedia() throws {
        // Given
        let plan = MixPlanner().mix(ofMedium: "/abs/tone.wav", duration: 1)

        // When
        let segment = writer.document(plan).objectValue?["segments"]?.arrayValue?.first?.objectValue

        // Then
        #expect(segment?["media"] == .object(JSONObject(members: [
            JSONMember(key: "kind", value: .string("file")),
            JSONMember(key: "file", value: .string("/abs/tone.wav")),
            JSONMember(key: "sha256", value: .null),
            JSONMember(key: "frames", value: .null)
        ])))
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
