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

// The same display lists drawn by `metal` again give the same bytes (FRAMES-24 Tolerances).
@Suite("Metal Determinism Tests", .serialized, .blockingLimit)
struct MetalDeterminismTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("metal gives the same bytes for the same list drawn twice by one renderer and once by another")
    func givesSameBytes() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let cases = try await AgreementCase.all(in: directory)
        let sut = MetalRenderer(decoder: AVFoundationDecoder())
        let other = MetalRenderer(decoder: AVFoundationDecoder())

        for agreementCase in cases {
            for time in agreementCase.times {
                let list = Evaluator().displayList(of: agreementCase.document, at: time)

                // When
                let first = rows(of: try sut.bitmap(of: list))
                let second = rows(of: try sut.bitmap(of: list))
                let third = rows(of: try other.bitmap(of: list))

                // Then
                #expect(first == second, "\(agreementCase.name) at \(time) drawn again")
                #expect(first == third, "\(agreementCase.name) at \(time) drawn by another renderer")
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
