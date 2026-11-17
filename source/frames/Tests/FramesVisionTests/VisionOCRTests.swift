//
//  VisionOCRTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import CoreText
import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import FramesVision
import Testing

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("VisionOCR Tests", .serialized)
struct VisionOCRTests {
    // MARK: - Property
    // How far a recognised rectangle's edges may lie from the drawn glyphs' ink, in media pixels.
    private let tolerance = 8.0
    // How far a recognised rectangle's top and bottom may lie from the drawn glyphs' ink, in media pixels: a row of
    // antialiased edge fainter than half the ink is not ink.
    private let inkTolerance = 2.0
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
                canvas.draw(text, font: font, size: size, x: x, y: y)
                drawn[text] = inkBox(of: text, font: font, size: size, x: x, y: y)
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
            #expect(isNear(line.rectangle, box), "\(line.text): \(line.rectangle) inked at \(box)")
        }
        #expect(lines == again)
    }

    @Test("a line on a turned video is found where the display shows it")
    func recognisesOnTurnedVideo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("portrait.mov")
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 720, ty: 0)
        let writer = MovieWriter(size: Size(width: 1280, height: 720), frameTimes: [0], end: 1, transform: quarterTurn)
        try await writer.write(to: file) { canvas, _ in
            canvas.fill(red: 255, green: 255, blue: 255)
            canvas.draw("Send message", font: "Helvetica", size: 48, x: 120, y: 900)
        }
        let drawn = inkBox(of: "Send message", font: "Helvetica", size: 48, x: 120, y: 900)
        let probed = try #require(try decoder.probedMedia(of: file))
        let sut = VisionOCR(decoder: decoder)

        // When
        let media = MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
        let lines = try sut.lines(in: media, atMediaTime: 0)

        // Then
        #expect(probed.size == Size(width: 720, height: 1280))
        #expect(lines.map(\.text) == ["Send message"])
        #expect(lines.first.map { isNear($0.rectangle, drawn) } == true, "\(lines) inked at \(drawn)")
    }

    @Test("the frame read is the one shown at the media time")
    func readsFrameShownAtTime() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("two.mov")
        let words = ["First", "Second"]
        try await MovieWriter(size: Size(width: 640, height: 360), frameTimes: [0, 0.5], end: 1).write(to: file) {
            canvas, index in
            canvas.fill(red: 255, green: 255, blue: 255)
            canvas.draw(words[index], font: "Helvetica", size: 64, x: 100, y: 140)
        }
        let probed = try #require(try decoder.probedMedia(of: file))
        let media = MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
        let sut = VisionOCR(decoder: decoder)

        // When
        let texts = try [0, 0.49, 0.5, 0.9].map { try sut.lines(in: media, atMediaTime: $0).map(\.text) }

        // Then
        #expect(texts == [["First"], ["First"], ["Second"], ["Second"]])
    }

    @Test(
        "a line's rectangle reaches from the top to the bottom of its ink, with and without descenders",
        arguments: [
            ("Total 42,000", "Helvetica", 40.0, false),
            ("Shipping jog 4,000", "Helvetica", 24, false),
            ("메시지 보내기", "AppleSDGothicNeo-Regular", 40, false),
            ("합계 12,000원", "AppleSDGothicNeo-Regular", 24, false),
            ("Shipping 4,000", "AppleSDGothicNeo-Bold", 32, true)
        ]
    )
    func hugsInk(
        text: String,
        font: String,
        size: Double,
        isLightOnDark: Bool
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("line.png")
        let (background, ink) = isLightOnDark ? (28.0, 255.0) : (242.0, 0.0)
        try ImageWriter(size: Size(width: 800, height: 450)).write(to: file) { canvas in
            canvas.fill(red: background, green: background, blue: background)
            canvas.draw(text, font: font, size: size, x: 60, y: 150, gray: ink)
        }
        let sut = VisionOCR(decoder: decoder)

        // When
        let lines = try sut.lines(in: MediaFile(path: file), atMediaTime: 0)

        // Then
        let line = try #require(lines.first)
        let drawn = inkBox(of: text, font: font, size: size, x: 60, y: 150)
        #expect(lines.map(\.text) == [text])
        #expect(isNearVertically(line.rectangle, drawn), "\(line.rectangle) inked at \(drawn)")
    }

    @Test("a line on a decoded H.264 frame reaches from the top to the bottom of its ink")
    func hugsInkOnVideo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("frame.mov")
        let text = "합계 12,000원"
        try await MovieWriter(size: Size(width: 1280, height: 720), frameTimes: [0], end: 1).write(to: file) {
            canvas, _ in
            canvas.fill(red: 242, green: 244, blue: 246)
            canvas.draw(text, font: "AppleSDGothicNeo-Regular", size: 32, x: 60, y: 150)
        }
        let probed = try #require(try decoder.probedMedia(of: file))
        let media = MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
        let sut = VisionOCR(decoder: decoder)

        // When
        let lines = try sut.lines(in: media, atMediaTime: 0)

        // Then
        let line = try #require(lines.first)
        let drawn = inkBox(of: text, font: "AppleSDGothicNeo-Regular", size: 32, x: 60, y: 150)
        #expect(lines.map(\.text) == [text])
        #expect(isNearVertically(line.rectangle, drawn), "\(line.rectangle) inked at \(drawn)")
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

    private func isNearVertically(
        _ found: Rectangle,
        _ inked: Rectangle
    ) -> Bool {
        abs(found.y - inked.y) <= inkTolerance && abs(found.y + found.height - inked.y - inked.height) <= inkTolerance
    }

    // The glyphs' ink of a line `Canvas.draw` sets with its line box at `x`, `y`.
    private func inkBox(
        of text: String,
        font name: String,
        size: Double,
        x: Double,
        y: Double
    ) -> Rectangle {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let baseline = y + CTFontGetAscent(font)

        return Rectangle(x: x + bounds.minX, y: baseline - bounds.maxY, width: bounds.width, height: bounds.height)
    }
}
