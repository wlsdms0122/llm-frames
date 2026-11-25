//
//  MetalDeterminismTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// The same display lists drawn by `metal` again give the same bytes (FRAMES-21 Rules, FRAMES-24 Tolerances).
@Suite("Metal Determinism Tests", .serialized, .ownThread)
struct MetalDeterminismTests {
    // MARK: - Property
    // Each round draws every case again by the first renderer and by a renderer of its own on a decoder of its own.
    private static let rounds = 8

    // MARK: - Initializer
    // MARK: - Test
    @Test("metal gives the same bytes for every case drawn again by one renderer and by new renderers on new decoders, round after round")
    func givesSameBytes() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let cases = try await AgreementCase.all(in: directory)
        let frames = cases.flatMap { agreementCase in
            agreementCase.times.map { time in
                (
                    name: "\(agreementCase.name) at \(time)",
                    list: Evaluator().displayList(of: agreementCase.document, at: time)
                )
            }
        }
        let sut = MetalRenderer(decoder: AVFoundationDecoder())
        let firsts = try frames.map { rows(of: try sut.bitmap(of: $0.list)) }

        for round in 1...Self.rounds {
            let other = MetalRenderer(decoder: AVFoundationDecoder())
            for (frame, first) in zip(frames, firsts) {
                // When
                let again = rows(of: try sut.bitmap(of: frame.list))
                let another = rows(of: try other.bitmap(of: frame.list))

                // Then
                let width = Int(frame.list.size.width.rounded(.up))
                #expect(
                    again == first,
                    "\(frame.name) drawn again in round \(round): \(FrameDifference(of: again, against: first, width: width))"
                )
                #expect(
                    another == first,
                    "\(frame.name) drawn by another renderer in round \(round): \(FrameDifference(of: another, against: first, width: width))"
                )
            }
        }
    }

    // MARK: - Private
    // The bytes of the bitmap's pixels, row by row, without what pads a row.
    private func rows(of bitmap: Bitmap) -> Data {
        var rows = Data()
        let rowLength = bitmap.width * 8
        for y in 0..<bitmap.height {
            rows.append(bitmap.pixels.subdata(in: y * bitmap.bytesPerRow..<y * bitmap.bytesPerRow + rowLength))
        }

        return rows
    }
}
