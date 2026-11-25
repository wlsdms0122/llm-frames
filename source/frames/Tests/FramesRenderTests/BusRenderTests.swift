//
//  BusRenderTests.swift
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

// The sound of compound clips, resolved from documents and mixed on the real decoder and mixer, and rendered to a
// master read back through the decoder. Serialized, so that the tests running at once read far fewer files with
// AVFoundation than the 64 at once at which its reads stop finishing (FRAMES-21 Notes), and since a test encodes.
@Suite("Bus Render Tests", .serialized, .ownThread)
struct BusRenderTests {
    // MARK: - Property
    // The rounding of 24-bit PCM, twice over for a sample read back against one mixed.
    private let tolerance: Float = 2.0 / 8_388_608

    // MARK: - Initializer
    // MARK: - Test
    @Test("a compound clip's sound is heard in the master as the same sound played by a clip of its own")
    func rendersCompoundSound() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let tone = media.file("tone.wav")
        try await SoundWriter(end: 1, levels: [0.25]).write(to: tone)
        let grey = try image(in: media, named: "grey.png")
        let compound = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 2 } ],
              "clips": [ { "kind": "audio", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 1 } ],
                                      "clips": [ { "kind": "audio", "media": "\#(tone)", "at": [0, 1] } ] },
                           "at": [0.5, 1.5] } ] }
            """#)
        let plain = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 2 } ],
              "clips": [ { "kind": "audio", "media": "\#(tone)", "at": [0.5, 1.5] } ] }
            """#)
        let decoder = AVFoundationDecoder()
        let sut = pipeline()

        // When
        try sut.render(compound, to: output.file("out.mov"), at: nil, delivery: nil)

        // Then
        let expected = try AVFoundationMixer(decoder: decoder).mix(MixPlanner().mix(of: plain))
        let rendered = try decoder.sound(of: MediaFile(path: output.file("out.mov")), from: 0, to: 2)
        let heard = 24_000..<72_000
        let deviation = heard.map { frame in abs(rendered.samples[frame * 2] - expected.samples[frame * 2]) }.max()!
        #expect(deviation <= tolerance, "\(deviation)")
        #expect(peak(of: rendered, frames: heard) > 0.15)
        #expect(peak(of: rendered, frames: 0..<24_000) == 0)
        #expect(peak(of: rendered, frames: 72_000..<96_000) == 0)
    }

    @Test("a looped compound clip plays each repeat on a bus of its own, its chain at rest at the start of each")
    func playsLoopRepeats() async throws {
        // Given
        let media = try TemporaryDirectory()
        let tone = media.file("tone.wav")
        try await SoundWriter(end: 1, levels: [0.5]).write(to: tone)
        let grey = try image(in: media, named: "grey.png")
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 1.5 } ],
              "clips": [ { "kind": "audio", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "\#(grey)", "duration": 0.5 } ],
                                      "clips": [ { "kind": "audio", "media": "\#(tone)", "at": [0, 0.5] } ],
                                      "audioFilter": { "kind": "compressor", "threshold": -18, "ratio": 4, "knee": 0,
                                                       "attack": 0.002, "release": 0.5 } },
                           "at": [0, 1.5], "loop": true } ] }
            """#)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let plan = MixPlanner().mix(of: document)
        let mixed = try sut.mix(plan)

        // Then
        #expect(plan.buses.map(\.start) == [0, 0.5, 1])
        for index in 1...2 {
            let same = (0..<24_000).allSatisfy { frame in
                mixed.samples[frame * 2] == mixed.samples[(24_000 * index + frame) * 2]
            }
            #expect(same, "repeat \(index)")
        }
        #expect(peak(of: mixed, frames: 24_000..<24_048) > 1.5 * peak(of: mixed, frames: 12_000..<24_000))
    }

    // MARK: - Private
    private func pipeline() -> RenderPipeline {
        let decoder = AVFoundationDecoder()

        return RenderPipeline(
            decoder: decoder,
            renderer: QuartzRenderer(decoder: decoder),
            mixer: AVFoundationMixer(decoder: decoder),
            encoder: AVFoundationEncoder()
        )
    }

    private func image(
        in directory: TemporaryDirectory,
        named name: String
    ) throws -> String {
        let file = directory.file(name)
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: file) { canvas in
            canvas.fill(red: 128, green: 128, blue: 128)
        }

        return file
    }

    // The largest magnitude of the left channel over `frames`.
    private func peak(
        of sound: SoundBuffer,
        frames: Range<Int>
    ) -> Float {
        frames.map { abs(sound.samples[$0 * 2]) }.max() ?? 0
    }
}
