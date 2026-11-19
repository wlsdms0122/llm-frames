//
//  ResolveEndToEndTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import CoreText
import Foundation
import FramesAVFoundation
import FramesCoreText
import FramesPointTracker
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
    // may lie from where the drawn line moved it, in media pixels.
    private let ocrTolerance = 8.0
    private let trackTolerance = 1.5
    private let times = ScreenRecording.frameTimes

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sequence on generated media resolves through the real decoder, OCR, tracker and shaper")
    func resolvesOnRealProviders() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let packs = try TemporaryDirectory()
        let (document, drawn) = try await screenDocument(in: directory)
        let sut = planner(packs: packs)

        // When
        let plan = try sut.plan(document)

        // Then
        guard case let .value(area) = plan.clips[0].area else {
            Issue.record("the box's area is not one value")
            return
        }
        #expect(area.lines.map(\.text) == ["Total 12,000원"])
        #expect(isNear(area.target, drawn[0]), "found \(area.target), drawn \(drawn[0])")

        let track = try #require(plan.clips[0].track?.track)
        #expect(track.samples.map(\.time) == times)
        for (index, frame) in track.samples.enumerated() {
            let moved = frame.quad.centroid.y - track.target.centroid.y
            let drift = drawn[index].center.y - drawn[0].center.y
            let along = frame.quad.centroid.x - track.target.centroid.x
            #expect(abs(moved - drift) <= trackTolerance, "frame \(index) moved \(moved), drawn \(drift)")
            #expect(abs(along) <= trackTolerance, "frame \(index) moved \(along) along the line")
        }

        let title = try #require(plan.clips[1].title)
        #expect(title.runs.map(\.face.name) == ["AppleSDGothicNeo-Bold", "HelveticaNeue-Bold", "AppleSDGothicNeo-Bold"])
        #expect(title.runs.allSatisfy { FileManager.default.fileExists(atPath: $0.face.file) })
        #expect(title.runs.flatMap(\.glyphs).count == "결제 완료".unicodeScalars.count)
    }

    // The first line holds a bold run at 48 and a regular one at 36, the second only the regular run, and the role
    // style's lines lie 45 apart, 1.25 times its size.
    @Test("a title of runs in two faces is set by the real shaper on shared baselines, in a box of first ascent plus last descent")
    func setsRunsInTwoFaces() throws {
        // Given
        let packs = try TemporaryDirectory()
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "name": { "size": 48, "weight": "bold" }, "role": { "size": 36 } } },
              "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ { "at": [0, 1], "title": [ { "text": "Ana", "style": "name" }, { "text": " Ruiz\nDirector" } ],
                           "style": "role", "position": [400, 225] } ] }
            """#)
        let sut = planner(packs: packs)

        // When
        let plan = try sut.plan(document)

        // Then
        let title = try #require(plan.clips[0].title)
        #expect(title.runs.map(\.face.name) == ["HelveticaNeue-Bold", "HelveticaNeue", "HelveticaNeue"])
        #expect(title.runs.map(\.size) == [48, 36, 36])
        #expect(title.runs.map { $0.glyphs.count } == [3, 5, 8])

        let bold = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 48, nil)
        let regular = CTFontCreateWithName("HelveticaNeue" as CFString, 36, nil)
        let baseline = Double(max(CTFontGetAscent(bold), CTFontGetAscent(regular)))
        let ys = title.runs.map { Set($0.glyphs.map(\.y)) }
        #expect(ys[0] == ys[1])
        #expect(ys[0].count == 1 && ys[2].count == 1)
        #expect(abs((ys[0].first ?? 0) - baseline) < 1e-9)
        #expect(abs((ys[2].first ?? 0) - (baseline + 45)) < 1e-9)
        #expect(abs(title.size.height - (baseline + 45 + Double(CTFontGetDescent(regular)))) < 1e-9)
    }

    @Test("a resolved sequence reads back as it was written, and its tracked box follows the line on every frame")
    func evaluatesWhatItReadsBack() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let packs = try TemporaryDirectory()
        let (document, drawn) = try await screenDocument(in: directory)
        let resolved = try ResolvedSequence(plan: try planner(packs: packs).plan(document), hashes: FileHasher())
        let sut = Evaluator()

        // When
        let text = ResolvedDocumentWriter().write(resolved)
        let read = try ResolvedDocumentReader().read(text)
        let boxes = try times.map { time in try box(in: sut.displayList(of: read, at: time)) }

        // Then
        #expect(read == resolved)
        #expect(ResolvedDocumentWriter().write(read) == text)
        for (index, box) in boxes.enumerated() {
            let moved = box.center.y - boxes[0].center.y
            let drift = drawn[index].center.y - drawn[0].center.y
            #expect(abs(moved - drift) <= trackTolerance, "frame \(index) box moved \(moved), drawn \(drift)")
            #expect(abs(box.center.x - boxes[0].center.x) <= trackTolerance, "frame \(index) box moved along the line")
        }
    }

    // MARK: - Private
    // The screen recording with a box tracking its scrolling line and a title over it. The drawn boxes of the
    // scrolling line come back in frame order.
    private func screenDocument(in directory: TemporaryDirectory) async throws -> (JSONValue, [Rectangle]) {
        let file = directory.file("screen.mov")
        let drawn = try await ScreenRecording(scale: 0.5).write(to: file)
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "id": "screen", "media": "\#(file)", "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "screen", "track": true } ] } ],
              "clips": [ { "at": [0, 1], "title": "결제 완료", "style": "title" } ] }
            """#)

        return (document, drawn)
    }

    private func planner(packs: TemporaryDirectory) -> DocumentPlanner {
        let decoder = AVFoundationDecoder()
        let library = ReferenceLibrary(
            packs: PackLibrary(installed: URL(fileURLWithPath: packs.path), shipped: URL(fileURLWithPath: packs.path)),
            mediaFacts: decoder
        )

        return DocumentPlanner(
            mediaFacts: decoder,
            presets: Fixture.presets,
            ocr: VisionOCR(decoder: decoder),
            languages: ["ko-KR", "en-US"].compactMap(LanguageTag.init),
            tracker: PointTracker(decoder: decoder),
            shaper: CoreTextShaper(),
            library: library
        )
    }

    // The box's stroke carried by its item's transform to output pixels, as the rectangle around its corners.
    private func box(in list: DisplayList) throws -> Rectangle {
        let strokes = list.items.compactMap { item -> Rectangle? in
            guard
                case let .path(path) = item.content,
                path.stroke != nil,
                case let .rect(rectangle, _) = path.geometry
            else {
                return nil
            }

            let corners = item.transform.apply(toCornersOf: rectangle)
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            let minX = xs.min() ?? 0
            let minY = ys.min() ?? 0
            return Rectangle(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
        }

        return try #require(strokes.first)
    }

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
