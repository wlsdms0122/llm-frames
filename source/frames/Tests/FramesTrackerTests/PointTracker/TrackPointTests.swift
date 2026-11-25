//
//  TrackPointTests.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
@testable import FramesTracker
import Testing

// Serialized, so that the tests running at once read far fewer files with AVFoundation than the 64 at once at which its
// reads stop finishing (FRAMES-21 Notes).
@Suite("TrackPoint Tests", .serialized, .ownThread)
struct TrackPointTests {
    // MARK: - Property
    private let decoder = AVFoundationDecoder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a point at either end of a line of text is found within half a pixel from a guess up to 40 pixels off along either axis")
    func findsFromGuessOff() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("line.mov")
        try await MovieWriter(size: Size(width: 720, height: 1280), frameTimes: [0, 1.0 / 30], end: 2.0 / 30)
            .write(to: file) { canvas, index in
                canvas.fill(red: 255, green: 255, blue: 255)
                canvas.draw("Send message to Jineun", font: "Helvetica", size: 40, x: 120, y: 830 + 70 * Double(index))
            }
        let probed = try #require(try decoder.probedMedia(of: file))
        let media = MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
        let images = try (0..<2).map { index in GreyImage(picture: try decoder.picture(of: media, atFrame: index).bitmap) }
        let ends = [CGPoint(x: 180, y: 850), CGPoint(x: 500, y: 850)]
        let points = try ends.map { end in
            try #require(TrackPoint(
                at: end,
                size: CGSize(width: 168, height: 88),
                angle: 0,
                in: images[0]
            ))
        }
        let offsets = [-40.0, -30, -20, -15, -10, -7, -5, -3, 0, 3, 5, 7, 10, 15, 20, 30, 40]
        let guesses = offsets.flatMap { [CGPoint(x: $0, y: 0), CGPoint(x: 0, y: $0)] }

        // When
        let found = points.map { point in
            guesses.map { guess in
                point.find(
                    in: images[1],
                    near: CGPoint(x: point.point.x + guess.x, y: point.point.y + 70 + guess.y),
                    scale: 1,
                    angle: 0
                )
            }
        }

        // Then
        for (point, matches) in zip(points, found) {
            for (guess, match) in zip(guesses, matches) {
                let found = try #require(match, "\(point.point) from \(guess)")
                #expect(abs(found.point.x - point.point.x) < 0.5, "\(point.point) from \(guess): \(found.point)")
                #expect(abs(found.point.y - point.point.y - 70) < 0.5, "\(point.point) from \(guess): \(found.point)")
            }
        }
    }

    // MARK: - Private
}
