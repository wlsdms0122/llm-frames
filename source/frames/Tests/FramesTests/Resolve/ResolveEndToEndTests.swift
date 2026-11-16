//
//  ResolveEndToEndTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation
import FramesAVFoundation
import FramesCoreText
import FramesTestMedia
import FramesVision
import Testing

@testable import Frames

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("Resolve End To End Tests", .serialized)
struct ResolveEndToEndTests {
    // MARK: - Property
    // How far the found area's edges may lie from the drawn line box, and how far each followed rectangle's centre
    // may lie from where the drawn line moved it, in media pixels. Vision's tracker holds a line of text well across
    // the line and loosely along it.
    private let ocrTolerance = 8.0
    private let acrossTolerance = 4.0
    private let alongTolerance = 16.0
    private let times = (0..<30).map { Double($0) / 30 }

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sequence on generated media resolves through the real decoder, OCR, tracker and shaper")
    func resolvesOnRealProviders() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("screen.mov")
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 720, ty: 0)
        let writer = VideoWriter(
            size: Size(width: 1280, height: 720),
            frameTimes: times,
            end: 1,
            transform: quarterTurn
        )
        var drawn: [Rectangle] = []
        try await writer.write(to: file) { canvas, index in
            canvas.fill(red: 255, green: 255, blue: 255)
            canvas.draw("Send message", font: "Helvetica", size: 48, x: 60, y: 200)
            drawn.append(canvas.draw(
                "Total 12,000원",
                font: "AppleSDGothicNeo-Bold",
                size: 48,
                x: 100,
                y: 700 - 4 * Double(index)
            ))
        }
        let decoder = AVFoundationDecoder()
        let packs = try TemporaryDirectory()
        let library = ReferenceLibrary(
            packs: PackLibrary(installed: URL(fileURLWithPath: packs.path), shipped: URL(fileURLWithPath: packs.path)),
            mediaFacts: decoder
        )
        let sut = DocumentPlanner(
            mediaFacts: decoder,
            presets: Fixture.presets,
            ocr: VisionOCR(decoder: decoder),
            tracker: VisionTracker(decoder: decoder),
            shaper: CoreTextShaper(),
            library: library
        )
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "media": "\#(file)", "connected": [ { "shape": "box", "area": "Total", "track": true } ] } ],
              "clips": [ { "at": [0, 1], "title": "결제 완료", "style": "headline" } ] }
            """#)

        // When
        let plan = try #require(try sut.plan(document).sequence)

        // Then
        guard case let .value(area) = plan.clips[0].area else {
            Issue.record("the box's area is not one value")
            return
        }
        #expect(area.lines.map(\.text) == ["Total 12,000원"])
        #expect(isNear(area.target, drawn[0]), "found \(area.target), drawn \(drawn[0])")

        let track = try #require(plan.clips[0].track)
        #expect(track.frames.map(\.time) == times)
        for (index, frame) in track.frames.enumerated() {
            let moved = frame.rectangle.center.y - track.target.center.y
            let drift = drawn[index].center.y - drawn[0].center.y
            let along = frame.rectangle.center.x - track.target.center.x
            #expect(abs(moved - drift) <= acrossTolerance, "frame \(index) moved \(moved), drawn \(drift)")
            #expect(abs(along) <= alongTolerance, "frame \(index) moved \(along) along the line")
        }

        let title = try #require(plan.clips[1].title)
        #expect(title.runs.map(\.face.name) == ["AppleSDGothicNeo-Bold"])
        #expect(title.runs.allSatisfy { FileManager.default.fileExists(atPath: $0.face.file) })
        #expect(title.runs.flatMap(\.glyphs).count == "결제 완료".unicodeScalars.count)
    }

    // MARK: - Private
    private func isNear(
        _ found: Rectangle,
        _ drawn: Rectangle
    ) -> Bool {
        [
            (found.x, drawn.x),
            (found.y, drawn.y),
            (found.maxX, drawn.maxX),
            (found.maxY, drawn.maxY)
        ]
        .allSatisfy { abs($0 - $1) <= ocrTolerance }
    }
}
