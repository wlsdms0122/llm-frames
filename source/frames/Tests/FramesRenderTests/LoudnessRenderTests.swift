//
//  LoudnessRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// The loudness of a document against that of the master it renders to, on the real roles. Serialized, since
// AVAssetReader needs a free thread of the shared pool and each test encodes.
@Suite("Loudness Render Tests", .serialized)
struct LoudnessRenderTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the loudness of a rendered master is the document's, to within the rounding of 24-bit PCM")
    func measuresMasterAsDocument() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let tone = media.file("tone.wav")
        try await SoundWriter(end: 4, signal: .tone(frequency: 997), levels: [0.5, 0.3]).write(to: tone)
        let noise = media.file("noise.wav")
        try await SoundWriter(end: 4, signal: .noise(seed: 3), levels: [0.2]).write(to: noise)
        let grey = media.file("grey.png")
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: grey) { canvas in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 4 } ],
              "clips": [ { "kind": "media", "media": "\#(tone)", "at": [0, 4], "fadeOut": 1 },
                         { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 3 } ],
                                      "clips": [ { "kind": "media", "media": "\#(noise)", "at": [0, 3] } ] },
                           "picture": false, "at": [0.5, 3.5], "fadeIn": 0.5 } ],
              "audioFilter": { "kind": "limiter", "gain": 3, "ceiling": -1 } }
            """#)
        let decoder = AVFoundationDecoder()
        let mixer = AVFoundationMixer(decoder: decoder)
        let pipeline = RenderPipeline(
            decoder: decoder,
            renderer: QuartzRenderer(decoder: decoder),
            mixer: mixer,
            encoder: AVFoundationEncoder()
        )
        try pipeline.render(document, to: output.file("out.mov"), at: nil, delivery: nil)
        let sut = LoudnessReporter(decoder: decoder, mixer: mixer, mediaFacts: decoder)

        // When
        let mixed = try sut.loudness(of: document, from: nil, to: nil)
        let rendered = try sut.loudness(ofMedium: output.file("out.mov"), from: nil, to: nil)

        // Then
        let pairs = [
            (mixed.integrated, rendered.integrated),
            (mixed.range, rendered.range),
            (mixed.momentaryMax, rendered.momentaryMax),
            (mixed.shortTermMax, rendered.shortTermMax),
            (mixed.truePeak, rendered.truePeak),
            (mixed.samplePeak, rendered.samplePeak)
        ]
        for (index, pair) in pairs.enumerated() {
            let (expected, measured) = (try #require(pair.0), try #require(pair.1))
            #expect(abs(expected - measured) <= 0.01, "measure \(index): \(expected) against \(measured)")
        }
    }
}
