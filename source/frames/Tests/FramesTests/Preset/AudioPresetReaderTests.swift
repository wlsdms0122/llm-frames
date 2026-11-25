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
              "ops": [ { "kind": "eq", "bands": [ { "kind": "highPass", "frequency": { "param": "cut" } } ] } ] }
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
              "ops": [ { "kind": "compressor", "threshold": -20, "ratio": { "param": "squash" } } ] }
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
            { "description": "", "ops": [ { "kind": "eq", "bands": [ { "kind": "peak", "frequency": 3000 } ] } ] }
            """#

        // When, Then
        #expect(throws: ModelError.missingKey(place: file.appending(key: "ops").appending(index: 0).appending(key: "bands").appending(index: 0), kind: "band", keys: ["gain"])) {
            try sut.publishedAudio(from: json(preset), place: file)
        }
    }

    @Test("a preset's limiter reads with its lookahead from a parameter, and a lookahead outside its range stops when read")
    func readsLimiter() throws {
        // Given
        let preset = #"""
            { "description": "", "params": { "ahead": { "type": "number", "default": 0.01, "description": "look-ahead" } },
              "ops": [ { "kind": "limiter", "ceiling": -2, "lookahead": { "param": "ahead" } } ] }
            """#

        // When
        let published = try sut.publishedAudio(from: json(preset), place: file)

        // Then
        #expect(published.defaults.operations.first?["lookahead"] == .number(0.01))
        #expect(throws: LookError.outsideDomain(place: file.appending(key: "ops").appending(index: 0).appending(key: "lookahead"), value: 0.1, domain: .range(0.0015...0.05))) {
            try sut.publishedAudio(from: json(preset.replacingOccurrences(of: #""default": 0.01"#, with: #""default": 0.1"#)), place: file)
        }
        #expect(throws: PresetError.self) {
            try sut.audio(published, instance: PresetInstance(name: "mine/voice", arguments: JSONObject(members: [JSONMember(key: "ahead", value: .number(0.001))])))
        }
    }

    @Test("a preset's convolve takes its gain from a parameter, and a parameter for its file stops")
    func readsConvolution() throws {
        // Given
        let preset = #"""
            { "description": "", "params": { "wet": { "type": "number", "default": -6, "description": "level" } },
              "ops": [ { "kind": "convolve", "file": "/abs/ding.wav", "gain": { "param": "wet" } } ] }
            """#
        let file = #"""
            { "description": "", "params": { "room": { "type": "number", "default": 1, "description": "room" } },
              "ops": [ { "kind": "convolve", "file": { "param": "room" } } ] }
            """#

        // When
        let published = try sut.publishedAudio(from: json(preset), place: self.file)

        // Then
        #expect(published.defaults.operations.first?["gain"] == .number(-6))
        #expect(published.defaults.operations.first?["file"] == .string("/abs/ding.wav"))
        #expect(throws: ModelError.self) { try sut.publishedAudio(from: json(file), place: self.file) }
    }

    @Test(
        "a colour or choice parameter, an op's mix and an unknown op stop",
        arguments: [
            ##"{ "description": "", "params": { "tint": { "type": "color", "default": "#FFFFFF", "description": "tint" } }, "ops": [ { "kind": "gate", "threshold": -50 } ] }"##,
            #"{ "description": "", "params": { "curve": { "type": "choice", "default": "linear", "options": ["linear"], "description": "curve" } }, "ops": [ { "kind": "gate", "threshold": -50 } ] }"#,
            #"{ "description": "", "ops": [ { "kind": "gate", "threshold": -50, "mix": 0.5 } ] }"#,
            #"{ "description": "", "ops": [ { "kind": "reverb" } ] }"#
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
