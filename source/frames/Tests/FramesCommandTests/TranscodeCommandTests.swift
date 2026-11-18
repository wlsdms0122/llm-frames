//
//  TranscodeCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesTestMedia
import Testing

@testable import FramesCommand

// `transcode` runs end to end on the real decoder and encoder. Serialized, since AVAssetReader needs a free thread of
// the shared pool and a video transcode encodes.
@Suite("TranscodeCommand Tests", .serialized)
struct TranscodeCommandTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("transcode writes an image or a video smaller and prints path, size, format and the ratio to the source")
    func printsTranscodeLine() async throws {
        // Given
        let image = sut.directory.file("card.png")
        try ImageWriter(size: Size(width: 320, height: 180), opaque: true).write(to: image) { canvas in
            canvas.fill(red: 255, green: 128, blue: 0)
        }
        let video = sut.directory.file("clip.mov")
        let writer = MovieWriter(size: Size(width: 64, height: 48), frameTimes: [0, 0.5], end: 1)
        try await writer.write(to: video) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        let jpeg = sut.directory.file("card.jpg")
        let movie = sut.directory.file("clip.mp4")

        // When
        let imageCode = sut.run(["transcode", image, "-o", jpeg, "--quality", "low", "--max", "160"])
        let imageOutput = sut.standardOutput
        let videoCode = sut.run(["transcode", video, "-o", movie, "--codec", "h264"])

        // Then
        #expect(imageCode == 0)
        #expect(videoCode == 0, "\(sut.standardError)")
        #expect(try imageOutput == line(of: jpeg, source: image, format: "JPEG"))
        #expect(try sut.standardOutput == line(of: movie, source: video, format: "H.264"))
    }

    @Test("an output that is not smaller than its source gives its share above 100% and nothing more")
    func givesShareAboveWhole() {
        // Given
        let result = TranscodeResult(path: "/abs/out.png", byteCount: 1500, sourceByteCount: 1200, format: .png)

        // When
        let line = TranscodeLine(result).description

        // Then
        #expect(line == "/abs/out.png  1.5 kB  PNG  125.0% of 1.2 kB")
    }

    @Test("a smaller output gives its share of the source with one decimal")
    func givesShare() {
        // Given
        let result = TranscodeResult(path: "/abs/out.mp4", byteCount: 420, sourceByteCount: 2_900_000, format: .aac)

        // When
        let line = TranscodeLine(result).description

        // Then
        #expect(line == "/abs/out.mp4  420 B  AAC  0.0% of 2.9 MB")
    }

    @Test("an output extension that does not fit the input stops with the transcoder's reason")
    func stopsOnExtension() throws {
        // Given
        let image = sut.directory.file("card.png")
        try ImageWriter(size: Size(width: 32, height: 18)).write(to: image) { _ in }
        let output = sut.directory.file("card.mp4")

        // When
        let code = sut.run(["transcode", image, "-o", output])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == """
            frames: "\(output)": "\(image)" is an image, which transcodes to .jpg, .heic or .png files

            """)
    }

    @Test("--max that would make a video's side under 2 pixels stops before anything is written, naming the size")
    func stopsOnUndersizedVideo() async throws {
        // Given
        let video = sut.directory.file("clip.mov")
        let writer = MovieWriter(size: Size(width: 64, height: 48), frameTimes: [0], end: 0.5)
        try await writer.write(to: video) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        let output = sut.directory.file("clip.mp4")

        // When
        let code = sut.run(["transcode", video, "-o", output, "--max", "1"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == """
            frames: "\(output)": --max 1 makes the video 1x1, and a video's sides are at least 2 pixels

            """)
        #expect(!FileManager.default.fileExists(atPath: output))
    }

    // MARK: - Private
    private func line(
        of path: String,
        source: String,
        format: String
    ) throws -> String {
        let bytes = try byteCount(of: path)
        let sourceBytes = try byteCount(of: source)
        let percentage = String(format: "%.1f%%", Double(bytes) / Double(sourceBytes) * 100)
        return "\(path)  \(FileSize(bytes: bytes))  \(format)  \(percentage) of \(FileSize(bytes: sourceBytes))\n"
    }

    private func byteCount(of path: String) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)

        return (attributes[.size] as? NSNumber)?.int64Value ?? -1
    }
}
