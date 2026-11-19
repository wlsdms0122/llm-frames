//
//  AudioPresetReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("AudioPresetReader Tests")
struct AudioPresetReaderTests {
    // MARK: - Property
    private let sut = PresetReader()
    private let file = Place(file: "mine/voice", components: [])

    // MARK: - Initializer
    // MARK: - Test
    @Test("an audio preset reads with every parameter at its default and with a choice's arguments in place")
    func readsWithDefaultsAndArguments() throws {
        // Given
        let published = try sut.publishedAudio(from: json(#"""
            { "description": "voice", "params": { "cut": { "type": "number", "default": 80, "description": "cut" } },
              "ops": [ { "op": "eq", "bands": [ { "type": "highPass", "frequency": { "param": "cut" } } ] } ] }
            """#), place: file)

        // When
        let read = try sut.audio(published, instance: PresetInstance(name: "mine/voice", arguments: JSONObject(members: [JSONMember(key: "cut", value: .number(120))])))

        // Then
        #expect(published.defaults.description == "voice")
        #expect(published.defaults.operations.first?["bands"]?.arrayValue?.first?.objectValue?["frequency"] == .number(80))
        #expect(read.operations.first?["bands"]?.arrayValue?.first?.objectValue?["frequency"] == .number(120))
    }

    @Test("a parameter outside its range stops at its default, and with a choice's arguments")
    func refusesOutOfRange() throws {
        // Given
        let preset = #"""
            { "description": "", "params": { "squash": { "type": "number", "default": 3, "description": "ratio" } },
              "ops": [ { "op": "compressor", "threshold": -20, "ratio": { "param": "squash" } } ] }
            """#
        let published = try sut.publishedAudio(from: json(preset), place: file)

        // When, Then
        #expect(throws: LookError.outsideDomain(place: file.appending(key: "ops").appending(index: 0).appending(key: "ratio"), value: 0.5, domain: .range(1...Double.infinity))) {
            try sut.publishedAudio(from: json(preset.replacingOccurrences(of: #""default": 3"#, with: #""default": 0.5"#)), place: file)
        }
        #expect(throws: PresetError.self) {
            try sut.audio(published, instance: PresetInstance(name: "mine/voice", arguments: JSONObject(members: [JSONMember(key: "squash", value: .number(0.5))])))
        }
    }

    @Test("a band whose type takes a gain stops where the preset leaves it out")
    func refusesBandWithoutGain() throws {
        // Given
        let preset = #"""
            { "description": "", "ops": [ { "op": "eq", "bands": [ { "type": "peak", "frequency": 3000 } ] } ] }
            """#

        // When, Then
        #expect(throws: ModelError.missingKey(place: file.appending(key: "ops").appending(index: 0).appending(key: "bands").appending(index: 0), kind: "band", keys: ["gain"])) {
            try sut.publishedAudio(from: json(preset), place: file)
        }
    }

    @Test(
        "a colour or choice parameter, an op's mix and an unknown op stop",
        arguments: [
            ##"{ "description": "", "params": { "tint": { "type": "color", "default": "#FFFFFF", "description": "tint" } }, "ops": [ { "op": "gate", "threshold": -50 } ] }"##,
            #"{ "description": "", "params": { "curve": { "type": "choice", "default": "linear", "options": ["linear"], "description": "curve" } }, "ops": [ { "op": "gate", "threshold": -50 } ] }"#,
            #"{ "description": "", "ops": [ { "op": "gate", "threshold": -50, "mix": 0.5 } ] }"#,
            #"{ "description": "", "ops": [ { "op": "reverb" } ] }"#
        ]
    )
    func refusesShapes(preset: String) throws {
        // When, Then
        #expect(throws: ModelError.self) { try sut.publishedAudio(from: json(preset), place: file) }
    }

    // MARK: - Private
    private func json(_ text: String) throws -> JSONValue {
        try JSONReader().read(text)
    }
}
