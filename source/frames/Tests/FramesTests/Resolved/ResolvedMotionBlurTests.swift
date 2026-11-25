//
//  ResolvedMotionBlurTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("ResolvedMotionBlur Tests")
struct ResolvedMotionBlurTests {
    // MARK: - Property
    private let sut = ResolvedDocumentReader()
    private let writer = ResolvedDocumentWriter()

    // A storyline video and a solid, a connected title, a shape, an adjustment, a still media clip and a sound.
    private static let document = #"""
        { "kind": "sequence", "format": { "size": [160, 90] },
          "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 2,
                           "connected": [ { "at": [0, 1], "kind": "title", "text": "Hi", "style": "title" } ] },
                         { "kind": "solid", "color": "#000000", "duration": 1 } ],
          "clips": [ { "at": [0, 1], "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent" },
                     { "at": [0, 1], "kind": "adjustment", "adjust": "mine/grade" },
                     { "at": [0, 1], "kind": "media", "media": "/abs/page.png", "width": 20 },
                     { "kind": "audio", "media": "/abs/bgm.m4a", "at": 0 } ] }
        """#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a resolved format writes the shutter with every default, and each picture entry its motionBlur, false written out")
    func writesDefaults() throws {
        // Given
        let text = try written(Self.document)

        // When
        let root = try #require(try JSONReader().read(text).objectValue)

        // Then
        let format = try #require(root["format"]?.objectValue)
        let shutter = try #require(format["motionBlur"]?.objectValue)
        #expect(format.keys.last == "motionBlur")
        #expect(shutter.keys == ["shutterAngle", "shutterPhase", "samplesPerFrame"])
        #expect(shutter["shutterAngle"] == .number(180))
        #expect(shutter["shutterPhase"] == .number(0))
        #expect(shutter["samplesPerFrame"] == .number(16))
        let storyline = (root["storyline"]?.arrayValue ?? []).compactMap(\.objectValue)
        let clips = (root["clips"]?.arrayValue ?? []).compactMap(\.objectValue)
        let audio = (root["audio"]?.arrayValue ?? []).compactMap(\.objectValue)
        #expect(storyline.map { $0["motionBlur"] } == [.bool(false), .bool(false)])
        #expect(clips.map { $0["motionBlur"] } == [.bool(false), .bool(false), .bool(false), .bool(false)])
        #expect(audio.allSatisfy { !$0.contains("motionBlur") })
    }

    @Test("motionBlur follows blend in a storyline entry and in a clips entry")
    func writesSwitchAfterBlend() throws {
        // Given
        let text = try written(Self.document)

        // When
        let root = try #require(try JSONReader().read(text).objectValue)

        // Then
        let entries = (root["storyline"]?.arrayValue ?? []) + (root["clips"]?.arrayValue ?? []).dropLast()
        for entry in entries.compactMap(\.objectValue) {
            let keys = entry.keys
            let blend = try #require(keys.firstIndex(of: "blend"))
            #expect(keys[blend + 1] == "motionBlur")
        }
    }

    @Test(
        "a shutter written in part takes the defaults of what it leaves out",
        arguments: [
            (#"{ "shutterAngle": 90 }"#, Shutter(angle: 90, phase: 0, samplesPerFrame: 16)),
            (#"{ "shutterPhase": -90 }"#, Shutter(angle: 180, phase: -90, samplesPerFrame: 16)),
            (#"{ "samplesPerFrame": 64 }"#, Shutter(angle: 180, phase: 0, samplesPerFrame: 64)),
            (#"{ "shutterAngle": 360, "shutterPhase": -180, "samplesPerFrame": 2 }"#, Shutter(angle: 360, phase: -180, samplesPerFrame: 2))
        ]
    )
    func resolvesPartialShutter(
        shutter: String,
        expected: Shutter
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [160, 90], "motionBlur": \#(shutter) },
              "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 2 } ] }
            """#

        // When
        let sequence = try sut.read(written(document))

        // Then
        #expect(sequence.format.shutter == expected)
    }

    @Test("each clip's motionBlur is resolved as written and reads back")
    func readsSwitch() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 2, "motionBlur": true,
                               "connected": [ { "at": [0, 1], "kind": "title", "text": "Hi", "style": "title", "motionBlur": true } ] },
                             { "kind": "solid", "color": "#000000", "duration": 1, "motionBlur": true } ],
              "clips": [ { "at": [0, 1], "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent" },
                         { "at": [0, 1], "kind": "adjustment", "adjust": "mine/grade", "motionBlur": true } ] }
            """#

        // When
        let sequence = try sut.read(written(document))

        // Then
        #expect(sequence.storyline.map(\.isMotionBlurred) == [true, true])
        #expect(sequence.clips.map(\.isMotionBlurred) == [true, false, true])
    }

    @Test("a resolved document with a shutter and switches reads back to the model it was written from")
    func roundTrips() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [160, 90], "motionBlur": { "shutterAngle": 270.5, "shutterPhase": -135.25, "samplesPerFrame": 32 } },
              "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 2, "motionBlur": true } ],
              "clips": [ { "at": [0, 1], "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "motionBlur": true } ] }
            """#
        let sequence = try resolved(document)

        // When
        let read = try sut.read(writer.write(sequence))

        // Then
        #expect(read == sequence)
        #expect(read.format.shutter == Shutter(angle: 270.5, phase: -135.25, samplesPerFrame: 32))
    }

    @Test("a nested resolved sequence writes its own shutter")
    func writesNestedShutter() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "kind": "media", "media": { "kind": "sequence", "format": { "size": [160, 90], "motionBlur": { "shutterAngle": 90 } },
                                          "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 2 } ] } } ] }
            """#

        // When
        let sequence = try sut.read(written(document))

        // Then
        guard case let .nested(nested) = sequence.storyline.first?.media else {
            Issue.record("the storyline clip is not a nested sequence")
            return
        }
        #expect(sequence.format.shutter == .default)
        #expect(nested.format.shutter == Shutter(angle: 90, phase: 0, samplesPerFrame: 16))
    }

    @Test(
        "a resolved shutter value outside its range or of another type stops",
        arguments: [
            ("shutterAngle", "0", "format.motionBlur.shutterAngle (motion blur): a shutter angle lies above 0 and at most 720, found 0"),
            ("shutterAngle", "721", "format.motionBlur.shutterAngle (motion blur): a shutter angle lies above 0 and at most 720, found 721"),
            ("shutterPhase", "-181", "format.motionBlur.shutterPhase (motion blur): a shutter phase lies from -180 to 0, found -181"),
            ("shutterPhase", "1", "format.motionBlur.shutterPhase (motion blur): a shutter phase lies from -180 to 0, found 1"),
            ("samplesPerFrame", "1", "format.motionBlur.samplesPerFrame (motion blur): samples per frame lie from 2 to 256, found 1"),
            ("samplesPerFrame", "2.5", "format.motionBlur.samplesPerFrame (motion blur): expected a whole number, found 2.5")
        ]
    )
    func refusesShutterValue(
        key: String,
        value: String,
        message: String
    ) throws {
        // Given
        let root = try writtenRoot()
        let format = try #require(root["format"]?.objectValue)
        let shutter = try #require(format["motionBlur"]?.objectValue)
        let changed = format.setting("motionBlur", to: .object(shutter.setting(key, to: try Fixture.json(value))))
        let text = JSONWriter().write(.object(root.setting("format", to: .object(changed))))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a resolved format without the shutter, or a shutter without one of its keys, stops")
    func refusesMissingShutter() throws {
        // Given
        let root = try writtenRoot()
        let format = try #require(root["format"]?.objectValue)
        let shutter = try #require(format["motionBlur"]?.objectValue)
        let withoutShutter = root.setting("format", to: .object(removing("motionBlur", from: format)))
        let withoutAngle = root.setting(
            "format",
            to: .object(format.setting("motionBlur", to: .object(removing("shutterAngle", from: shutter))))
        )

        // When
        let shutterError = #expect(throws: ModelError.self) { try sut.read(JSONWriter().write(.object(withoutShutter))) }
        let angleError = #expect(throws: ModelError.self) { try sut.read(JSONWriter().write(.object(withoutAngle))) }

        // Then
        #expect(shutterError?.description == #"format (format): missing key "motionBlur""#)
        #expect(angleError?.description == #"format.motionBlur (motion blur): missing key "shutterAngle""#)
    }

    @Test("a resolved storyline entry or clips entry without motionBlur stops")
    func refusesMissingSwitch() throws {
        // Given
        let root = try writtenRoot()
        let storyline = (root["storyline"]?.arrayValue ?? []).compactMap(\.objectValue)
        let clips = (root["clips"]?.arrayValue ?? []).compactMap(\.objectValue)
        let withoutEntrySwitch = root.setting(
            "storyline",
            to: .array([.object(removing("motionBlur", from: storyline[0]))] + storyline.dropFirst().map(JSONValue.object))
        )
        let withoutClipSwitch = root.setting(
            "clips",
            to: .array([.object(removing("motionBlur", from: clips[0]))] + clips.dropFirst().map(JSONValue.object))
        )

        // When
        let entryError = #expect(throws: ModelError.self) { try sut.read(JSONWriter().write(.object(withoutEntrySwitch))) }
        let clipError = #expect(throws: ModelError.self) { try sut.read(JSONWriter().write(.object(withoutClipSwitch))) }

        // Then
        #expect(entryError?.description == #"storyline[0] (storyline clip): missing key "motionBlur""#)
        #expect(clipError?.description == #"clips[0] (clip): missing key "motionBlur""#)
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func written(_ document: String) throws -> String {
        writer.write(try resolved(document))
    }

    private func writtenRoot() throws -> JSONObject {
        try #require(try JSONReader().read(written(Self.document)).objectValue)
    }

    private func removing(
        _ key: String,
        from object: JSONObject
    ) -> JSONObject {
        JSONObject(members: object.members.filter { $0.key != key })
    }
}
