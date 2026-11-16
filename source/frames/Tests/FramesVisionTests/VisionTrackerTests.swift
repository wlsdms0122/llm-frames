//
//  VisionTrackerTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import FramesVision
import Testing

// Serialized, since the decoder blocks a thread of the shared pool while AVFoundation loads.
@Suite("VisionTracker Tests", .serialized)
struct VisionTrackerTests {
    // MARK: - Property
    // How far a followed rectangle's centre may lie from the drawn box's, in media pixels, and how far its width and
    // height may be from the drawn ones, as a fraction. Vision's box drifts in shape, not only in place.
    private let centreTolerance = 4.0
    private let sizeTolerance = 0.12
    private let decoder = AVFoundationDecoder()
    private let times = (0..<30).map { Double($0) / 30 }

    // MARK: - Initializer
    // MARK: - Test
    @Test("a box moving across the frames is followed both ways from its frame")
    func followsMovingBox() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await video(in: directory) { index in box(at: index) }
        let sut = VisionTracker(decoder: decoder)

        // When
        let frames = try sut.track(box(at: 10), in: media, atMediaTime: times[10], over: 0...1)

        // Then
        #expect(frames.map(\.time) == times)
        for (index, frame) in frames.enumerated() {
            #expect(isNear(frame.rectangle, box(at: index)), "frame \(index): \(frame.rectangle)")
        }
    }

    @Test("a box that disappears is lost at that frame, in that direction")
    func losesBoxWhereItDisappears() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await video(in: directory) { index in (5..<20).contains(index) ? box(at: index) : nil }
        let sut = VisionTracker(decoder: decoder)

        // When
        let frames = try sut.track(box(at: 10), in: media, atMediaTime: times[10], over: 0...1)

        // Then
        #expect(frames.map(\.time) == Array(times[5..<20]))
    }

    @Test("only the frames whose media times lie in the range are followed, and the target's frame")
    func followsOverRange() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await video(in: directory) { index in box(at: index) }
        let sut = VisionTracker(decoder: decoder)

        // When
        let frames = try sut.track(
            box(at: 10),
            in: media,
            atMediaTime: times[10] + 0.01,
            over: times[8]...times[13]
        )

        // Then
        #expect(frames.map(\.time) == Array(times[8...13]))
    }

    // MARK: - Private
    // A box with a pattern that does not repeat, 8 pixels further right on each frame.
    private func box(at index: Int) -> Rectangle {
        Rectangle(x: 80 + Double(index) * 8, y: 120, width: 96, height: 96)
    }

    // A video of the frames `times`, whose frame i shows the box `boxes(i)` gives, if any, over a still background.
    private func video(
        in directory: TemporaryDirectory,
        boxes: @escaping (Int) -> Rectangle?
    ) async throws -> MediaFile {
        let file = directory.file("moving.mov")
        let size = Size(width: 640, height: 360)
        try await VideoWriter(size: size, frameTimes: times, end: 1).write(to: file) { canvas, index in
            canvas.fill(red: 90, green: 110, blue: 130)
            for column in 0..<8 {
                let x = Double(column) * 80 + 20
                canvas.fill(Rectangle(x: x, y: 300, width: 40, height: 30), red: 60, green: 70, blue: 80)
            }
            guard let box = boxes(index) else { return }
            canvas.fill(box, red: 240, green: 200, blue: 40)
            for row in 0..<4 {
                for column in 0..<4 where 0b1011_0110_0101_1100 >> (row * 4 + column) & 1 == 1 {
                    let x = box.x + Double(column) * 24
                    let y = box.y + Double(row) * 24
                    canvas.fill(Rectangle(x: x, y: y, width: 24, height: 24), red: 20, green: 20, blue: 20)
                }
            }
        }
        let probed = try #require(decoder.probedMedia(of: file))

        return MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
    }

    private func isNear(
        _ found: Rectangle,
        _ drawn: Rectangle
    ) -> Bool {
        let centres = [
            (found.x + found.width / 2, drawn.x + drawn.width / 2),
            (found.y + found.height / 2, drawn.y + drawn.height / 2)
        ]
        let sizes = [(found.width, drawn.width), (found.height, drawn.height)]

        return centres.allSatisfy { abs($0 - $1) <= centreTolerance }
            && sizes.allSatisfy { abs($0 / $1 - 1) <= sizeTolerance }
    }
}
