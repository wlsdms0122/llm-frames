//
//  VisionOCRTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import FramesVision
import Testing

// Serialized, since the decoder blocks a thread of the shared pool while AVFoundation loads.
@Suite("VisionOCR Tests", .serialized)
struct VisionOCRTests {
    // MARK: - Property
    // How far a recognised rectangle's edges may lie from the drawn line box (ascent and descent), in media pixels.
    private let tolerance = 8.0
    private let decoder = AVFoundationDecoder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("Korean and English lines are found with their text where they were drawn, the same on every run")
    func recognisesKoreanAndEnglish() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("screen.png")
        var drawn: [String: Rectangle] = [:]
        try ImageWriter(size: Size(width: 720, height: 1280)).write(to: file) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
            let lines = [
                ("Send message", "Helvetica", 48.0, 60.0, 200.0),
                ("메시지 보내기", "AppleSDGothicNeo-Regular", 48, 60, 500),
                ("Total 12,000원", "AppleSDGothicNeo-Bold", 40, 200, 900)
            ]
            for (text, font, size, x, y) in lines {
                drawn[text] = canvas.draw(text, font: font, size: size, x: x, y: y)
            }
        }
        let sut = VisionOCR(decoder: decoder)

        // When
        let lines = try sut.lines(in: MediaFile(path: file), atMediaTime: 0)
        let again = try sut.lines(in: MediaFile(path: file), atMediaTime: 0)

        // Then
        #expect(Set(lines.map(\.text)) == Set(drawn.keys))
        for line in lines {
            let box = try #require(drawn[line.text])
            #expect(isNear(line.rectangle, box), "\(line.text): \(line.rectangle) drawn at \(box)")
        }
        #expect(lines == again)
    }

    @Test("a line on a turned video is found where the display shows it")
    func recognisesOnTurnedVideo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("portrait.mov")
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 720, ty: 0)
        let writer = VideoWriter(size: Size(width: 1280, height: 720), frameTimes: [0], end: 1, transform: quarterTurn)
        var drawn = Rectangle(x: 0, y: 0, width: 0, height: 0)
        try await writer.write(to: file) { canvas, _ in
            canvas.fill(red: 255, green: 255, blue: 255)
            drawn = canvas.draw("Send message", font: "Helvetica", size: 48, x: 120, y: 900)
        }
        let probed = try #require(decoder.probedMedia(of: file))
        let sut = VisionOCR(decoder: decoder)

        // When
        let media = MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
        let lines = try sut.lines(in: media, atMediaTime: 0)

        // Then
        #expect(probed.size == Size(width: 720, height: 1280))
        #expect(lines.map(\.text) == ["Send message"])
        #expect(lines.first.map { isNear($0.rectangle, drawn) } == true, "\(lines) drawn at \(drawn)")
    }

    @Test("the frame read is the one shown at the media time")
    func readsFrameShownAtTime() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("two.mov")
        let words = ["First", "Second"]
        try await VideoWriter(size: Size(width: 640, height: 360), frameTimes: [0, 0.5], end: 1).write(to: file) {
            canvas, index in
            canvas.fill(red: 255, green: 255, blue: 255)
            canvas.draw(words[index], font: "Helvetica", size: 64, x: 100, y: 140)
        }
        let probed = try #require(decoder.probedMedia(of: file))
        let media = MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
        let sut = VisionOCR(decoder: decoder)

        // When
        let texts = try [0, 0.49, 0.5, 0.9].map { try sut.lines(in: media, atMediaTime: $0).map(\.text) }

        // Then
        #expect(texts == [["First"], ["First"], ["Second"], ["Second"]])
    }

    // MARK: - Private
    private func isNear(
        _ found: Rectangle,
        _ drawn: Rectangle
    ) -> Bool {
        [
            (found.x, drawn.x),
            (found.y, drawn.y),
            (found.x + found.width, drawn.x + drawn.width),
            (found.y + found.height, drawn.y + drawn.height)
        ]
        .allSatisfy { abs($0 - $1) <= tolerance }
    }
}
