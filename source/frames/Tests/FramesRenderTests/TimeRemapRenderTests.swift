//
//  TimeRemapRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Remapped clips drawn by the real decoder and renderer from documents resolved on the real providers, read as frames
// before encoding. The code movie shows the value i on its frame i, one frame every tenth of a second from 0 to 1.1.
// Serialized, so that the tests running at once read far fewer files with AVFoundation than the 64 at once at which its
// reads stop finishing (FRAMES-21 Notes).
@Suite("TimeRemap Render Tests", .serialized, .ownThread)
struct TimeRemapRenderTests {
    // MARK: - Property
    private static let codeFrames = 12

    // A picture decoded from H.264 keeps to within a few eight bit steps.
    private let decodedTolerance = 6.0 / 255

    // MARK: - Initializer
    // MARK: - Test
    @Test("two keys with one value show one identical frame on every output frame between them")
    func holdsOneFrame() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let code = try await codeMovie(in: directory)
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [128, 32], "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(code)", "in": 0, "out": 2, "keyframes": [
                { "at": 0, "timeRemap": 0 }, { "at": 0.2, "timeRemap": 0.5 }, { "at": 1.4, "timeRemap": 0.5 },
                { "at": 2, "timeRemap": 1.1 } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frames = try (0..<20).map { index in
            try sut.bitmap(of: Evaluator().displayList(of: document, at: Double(index) / 10))
        }

        // Then
        let held = frames[2...14]
        #expect(held.allSatisfy { $0.pixels == frames[2].pixels })
        #expect(self.code(in: frames[2]) == 5)
        #expect(self.code(in: frames[1]) != 5)
        #expect(self.code(in: frames[15]) != 5)
    }

    @Test("a remap value before the media shows its first frame, and one past it, held or after the last key, its last")
    func clampsToMedia() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let code = try await codeMovie(in: directory)
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [128, 32], "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(code)", "in": 0, "out": 3, "keyframes": [
                { "at": 0, "timeRemap": -1 }, { "at": 1, "timeRemap": 9 }, { "at": 2, "timeRemap": 9 } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let codes = try [0, 0.05, 1.5, 2.5].map { time in
            try self.code(in: sut.bitmap(of: Evaluator().displayList(of: document, at: time)))
        }

        // Then
        #expect(codes == [0, 0, Self.codeFrames - 1, Self.codeFrames - 1])
    }

    @Test("a remapped compound clip shows its inner sequence at the remapped time, here played backwards")
    func remapsCompoundClip() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let code = try await codeMovie(in: directory)
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [128, 32], "fps": 10 },
              "storyline": [ { "in": 0, "out": 1,
                "kind": "media",
                "media": { "kind": "sequence", "format": { "size": [128, 32], "fps": 10 },
                           "storyline": [ { "kind": "media", "media": "\#(code)", "in": 0, "out": 1.2 } ] },
                "keyframes": [ { "at": 0, "timeRemap": 1 }, { "at": 1, "timeRemap": 0 } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let codes = try (0..<10).map { index in
            try self.code(in: sut.bitmap(of: Evaluator().displayList(of: document, at: Double(index) / 10)))
        }

        // Then
        #expect(codes == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
    }

    // MARK: - Private
    // A 128 x 32 movie whose frame i shows the code i.
    private func codeMovie(in directory: TemporaryDirectory) async throws -> String {
        let file = directory.file("code.mov")
        let times = (0..<Self.codeFrames).map { Double($0) / 10 }
        let writer = MovieWriter(size: Size(width: 128, height: 32), frameTimes: times, end: 1.2)
        try await writer.write(to: file) { canvas, index in
            canvas.drawCode(index, bits: 4, side: 32)
        }

        return file
    }

    // The value `Canvas.drawCode` drew in four squares across the frame.
    private func code(in frame: Bitmap) -> Int {
        (0..<4).reduce(0) { value, bit in
            let isWhite = frame.pixel(x: bit * 32 + 16, y: 16)[1] > 0.5 + decodedTolerance

            return isWhite ? value | 1 << bit : value
        }
    }
}
