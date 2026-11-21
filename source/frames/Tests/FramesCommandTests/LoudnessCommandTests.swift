//
//  LoudnessCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

// `loudness` run end to end on the real decoder and mixer. Serialized, since AVAssetReader needs a free thread of the
// shared pool.
@Suite("LoudnessCommand Tests", .serialized)
struct LoudnessCommandTests {
    // MARK: - Property
    private static let measures = ["integrated", "range", "momentaryMax", "shortTermMax", "truePeak", "samplePeak"]

    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("loudness --json of a medium prints the loudness object, a 997 Hz tone at 0.5 on both channels at -6.02 LUFS")
    func measuresMedium() async throws {
        // Given
        let tone = try await sound(named: "tone.wav", end: 1)

        // When
        let code = sut.run(["loudness", tone, "--json"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        let object = try #require(try JSONReader().read(Data(sut.standardOutput.utf8)).objectValue)
        #expect(object.keys == ["loudness"] + Self.measures)
        #expect(sut.standardOutput.hasPrefix("{\n  \"loudness\": \"\(FramesVersion.current)\","))
        let integrated = try #require(object["integrated"]?.numberValue)
        let samplePeak = try #require(object["samplePeak"]?.numberValue)
        #expect(abs(integrated + 6.02) <= 0.02, "\(integrated)")
        #expect(abs(samplePeak + 6.02) <= 0.02, "\(samplePeak)")
        #expect(object["range"] == .null)
        #expect(object["shortTermMax"] == .null)
    }

    @Test("loudness of a document that plays a medium from 0 at volume 1 prints the medium's measures")
    func measuresDocumentAsItsMix() async throws {
        // Given
        let tone = try await sound(named: "tone.wav", end: 1)
        let document = try sut.write(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 }, "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ { "media": "\#(tone)", "at": [0, 1] } ] }
            """#, named: "doc.json")
        _ = sut.run(["loudness", tone, "--json", "--from", "0.25"])
        let medium = sut.standardOutput

        // When
        let code = sut.run(["loudness", document, "--json", "--from", "0.25"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        #expect(sut.standardOutput == medium)
    }

    @Test("loudness of a document with no sound prints null for every measure")
    func measuresSilence() throws {
        // Given
        let document = try sut.write(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 }, "storyline": [ { "solid": "#000000", "duration": 1 } ] }
            """#, named: "doc.json")

        // When
        let code = sut.run(["loudness", document, "--json"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        let object = try #require(try JSONReader().read(Data(sut.standardOutput.utf8)).objectValue)
        #expect(Self.measures.allSatisfy { object[$0] == .null })
    }

    @Test("a document whose audioFilter ends with a limiter at mix 1 measures at or under its ceiling")
    func measuresLimitedDocument() async throws {
        // Given
        let tone = try await sound(named: "tone.wav", end: 2)
        let document = try sut.write(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 }, "storyline": [ { "solid": "#000000", "duration": 2 } ],
              "clips": [ { "media": "\#(tone)", "at": [0, 2] }, { "media": "\#(tone)", "at": [0.5, 2] } ],
              "audioFilter": { "op": "limiter", "gain": 12, "ceiling": -1 } }
            """#, named: "doc.json")

        // When
        let code = sut.run(["loudness", document, "--json"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        let object = try #require(try JSONReader().read(Data(sut.standardOutput.utf8)).objectValue)
        let samplePeak = try #require(object["samplePeak"]?.numberValue)
        let truePeak = try #require(object["truePeak"]?.numberValue)
        #expect(samplePeak <= -1 && samplePeak > -1.5, "\(samplePeak)")
        #expect(truePeak <= -0.95, "\(truePeak)")
    }

    @Test("loudness prints the measures for people without --json")
    func printsText() async throws {
        // Given
        let tone = try await sound(named: "tone.wav", end: 1)

        // When
        let code = sut.run(["loudness", tone])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        let names = sut.standardOutput.split(separator: "\n").map { $0.split(separator: " ").first.map(String.init) }
        #expect(names == ["integrated", "range", "momentary", "short-term", "true", "sample"])
    }

    @Test("a medium without sound stops, since it has no sound to measure")
    func stopsOnMediumWithoutSound() throws {
        // Given
        let image = sut.directory.file("still.png")
        try ImageWriter(size: Size(width: 32, height: 18)).write(to: image) { _ in }

        // When
        let code = sut.run(["loudness", image])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: media \"\(image)\" has no sound to measure\n")
    }

    @Test("a page of a PDF stops as a still does, since it has no sound to measure")
    func stopsOnPage() throws {
        // Given
        let page = sut.directory.file("slide.pdf")
        try PageWriter().write(width: 32, height: 18, content: "0 g 0 0 32 18 re f", to: page)

        // When
        let code = sut.run(["loudness", page])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: media \"\(page)\" has no sound to measure\n")
    }

    @Test("--args with a medium stops, since a medium has no params to take them")
    func stopsOnArgumentsOfMedium() async throws {
        // Given
        let tone = try await sound(named: "tone.wav", end: 1)
        let arguments = try sut.write("{}", named: "args.json")

        // When
        let code = sut.run(["loudness", tone, "--args", arguments])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: loudness: media \"\(tone)\" has no params, so it takes no --args\n")
    }

    @Test("--from and --to outside the sound or out of order stop before anything is measured", arguments: [
        (["--from", "1"], "--from: second 1 is at or after the end of the sound at 1"),
        (["--to", "1.5"], "--to: second 1.5 is after the end of the sound at 1"),
        (["--from", "0.5", "--to", "0.5"], "--from: 0.5 is not before --to 0.5")
    ])
    func stopsOnRangeOutsideSound(
        options: [String],
        message: String
    ) async throws {
        // Given
        let tone = try await sound(named: "tone.wav", end: 1)
        let document = try sut.write(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 }, "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ { "media": "\#(tone)", "at": [0, 1] } ] }
            """#, named: "doc.json")

        for input in [tone, document] {
            // When
            let code = sut.run(["loudness", input] + options)

            // Then
            #expect(code == 1, "\(input)")
            #expect(sut.standardError.hasSuffix("frames: \(message)\n"), "\(sut.standardError)")
        }
    }

    // MARK: - Private
    // A 997 Hz tone at 0.5 on both channels of a 48 kHz file, `end` seconds long.
    private func sound(
        named name: String,
        end: Double
    ) async throws -> String {
        let file = sut.directory.file(name)
        try await SoundWriter(end: end, signal: .tone(frequency: 997), levels: [0.5, 0.5]).write(to: file)

        return file
    }
}
