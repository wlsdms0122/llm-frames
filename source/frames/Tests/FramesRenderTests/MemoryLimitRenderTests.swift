//
//  MemoryLimitRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import Frames
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

// A run's memory limit, which the decoder's readers and reading ahead, the renderer's pictures and the pipeline's
// frames and sound draw from, changes how a render reads its videos and never its frames, what the budget counts stays
// within it, the process's measured footprint is reported, and a limit under the run's floor is refused before the
// first frame (FRAMES-30).
@Suite("MemoryLimitRender Tests", .ownThread)
struct MemoryLimitRenderTests {
    // MARK: - Property
    // Four videos of 160 by 120 pixels, read as 8-bit Y'CbCr 4:2:0, cost 806 400 bytes a reader; the renderer keeps
    // the four videos' pictures of two frames, 153 600 bytes each, 1 228 800 together; the two frames in flight of a
    // 160 by 120 sequence cost 307 200 and its 0.4 s of sound 153 600, so a run's floor is 2 496 000 bytes, and at 3 MB
    // the budget leaves no room for a second reader.
    private static let videoCount = 4

    // MARK: - Initializer
    // MARK: - Test
    @Test("a render at a limit where the readers take turns gives the same frames as one with no limit")
    func givesSameFrames() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let document = try await document(in: directory)
        let limited = MemoryBudget(limit: try #require(MemorySize("3MB")))
        let unlimited = MemoryBudget(limit: .unlimited)

        // When
        let limitedFrames = try render(document, budget: limited, to: directory.file("limited.mov"))
        let unlimitedFrames = try render(document, budget: unlimited, to: directory.file("unlimited.mov"))

        // Then
        let readers = try #require(limited.usage.holders.first { $0.holder == .readers })
        #expect(readers.refused > 0)
        let pictures = try #require(limited.usage.holders.first { $0.holder == .pictures })
        #expect(pictures.peak == 8 * 153_600)
        #expect(limited.usage.peak <= limited.limit.bytes)
        #expect(limited.usage.uncounted > 0)
        #expect(unlimited.usage.holders.first { $0.holder == .readers }?.refused == 0)
        #expect(limitedFrames.count == 12)
        #expect(limitedFrames == unlimitedFrames)
    }

    @Test("a render's floor holds one reader of its costliest video, its pictures of two frames, its two frames in flight and its sound")
    func declaresFloor() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let document = try await document(in: directory)
        let sut = MemoryBudget(limit: .unlimited)

        // When
        _ = try render(document, budget: sut, to: directory.file("out.mov"))

        // Then
        let floors = sut.usage.holders.map(\.floor)
        #expect(floors == [806_400, 0, 0, 1_228_800, 307_200, 153_600])
        #expect(sut.usage.floor == 2_496_000)
    }

    @Test("a render reports the process's largest footprint, which holds the pictures the budget counted in the process")
    func reportsProcessFootprint() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let document = try await document(in: directory)
        let sut = MemoryBudget(limit: .unlimited)

        // When
        _ = try render(document, budget: sut, to: directory.file("out.mov"))

        // Then
        let pictures = try #require(sut.usage.holders.first { $0.holder == .pictures })
        #expect(pictures.peak == 8 * 153_600)
        #expect(sut.usage.process >= pictures.peak)
    }

    @Test("a limit under the run's floor is refused before the first frame, naming the limit, the floor and its holders")
    func refusesUnderFloor() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let document = try await document(in: directory)
        let budget = MemoryBudget(limit: try #require(MemorySize("1MB")))
        let encoder = FrameCapturingEncoder()

        // When
        let error = #expect(throws: MemoryError.self) {
            try pipeline(budget: budget, encoder: encoder).render(
                document,
                to: directory.file("out.mov"),
                at: nil,
                delivery: nil
            )
        }

        // Then
        #expect(error?.description == """
            memory limit 1MB is under the 2.4 MB this run needs: readers 0.8 MB, readAhead 0 MB, turns 0 MB, \
            pictures 1.2 MB, frames 0.3 MB, sound 0.1 MB
            """)
        #expect(encoder.captured.isEmpty)
    }

    // MARK: - Private
    // A sequence of 160 by 120 pixels and 12 frames at 30 fps showing four videos at once in a grid, each its own
    // pattern on each frame.
    private func document(in directory: TemporaryDirectory) async throws -> ResolvedSequence {
        var clips: [String] = []
        for video in 0..<Self.videoCount {
            let path = directory.file("video-\(video).mov")
            let writer = MovieWriter(
                size: Size(width: 160, height: 120),
                frameTimes: (0..<12).map { Double($0) / 30 },
                end: 0.4
            )
            try await writer.write(to: path) { canvas, frame in
                canvas.fill(red: Double(40 * video + 20), green: Double(16 * frame), blue: 90)
                canvas.fill(
                    Rectangle(x: Double(10 * frame), y: Double(20 * video), width: 24, height: 30),
                    red: 250,
                    green: 250,
                    blue: Double(60 * video)
                )
            }
            let center = (x: 40 + 80 * (video % 2), y: 30 + 60 * (video / 2))
            clips.append(#"""
                { "kind": "media", "media": "\#(path)", "at": [0, 0.4], "lane": \#(video + 1), "width": 80, \#
                "position": [\#(center.x), \#(center.y)] }
                """#)
        }

        return try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [160, 120], "fps": 30 },
              "storyline": [ { "kind": "solid", "color": "#101010", "duration": 0.4,
                               "connected": [ \#(clips.joined(separator: ", ")) ] } ] }
            """#)
    }

    // The frames a render of `document` at `budget` hands its encoder.
    private func render(
        _ document: ResolvedSequence,
        budget: MemoryBudget,
        to output: String
    ) throws -> [Data] {
        let encoder = FrameCapturingEncoder()
        try pipeline(budget: budget, encoder: encoder).render(document, to: output, at: nil, delivery: nil)

        return encoder.captured
    }

    private func pipeline(
        budget: MemoryBudget,
        encoder: FrameCapturingEncoder
    ) -> RenderPipeline {
        let decoder = AVFoundationDecoder(budget: budget)

        return RenderPipeline(
            decoder: decoder,
            renderer: QuartzRenderer(decoder: decoder, budget: budget),
            mixer: AVFoundationMixer(decoder: decoder),
            encoder: encoder,
            budget: budget
        )
    }
}
