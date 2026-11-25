//
//  RendererAgreementTests.swift
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

// `metal` against `quartz`, the reference renderer, on the same display lists and decoder (FRAMES-24 Tolerances).
@Suite("Renderer Agreement Tests", .serialized)
struct RendererAgreementTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("metal draws every case within the tolerances of quartz: flat pixels within 2^-9 of a component and 2^-12 on average, others within the bounds of a resampled picture and an edge")
    func agreesWithQuartz() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let cases = try await AgreementCase.all(in: directory)
        let decoder = AVFoundationDecoder()
        let reference = QuartzRenderer(decoder: decoder)
        let sut = MetalRenderer(decoder: decoder)

        for agreementCase in cases {
            for time in agreementCase.times {
                let list = Evaluator().displayList(of: agreementCase.document, at: time)

                // When
                let frame = try sut.bitmap(of: list)
                let agreement = RendererAgreement(of: frame, against: try reference.bitmap(of: list))

                // Then
                let name = "\(agreementCase.name) at \(time)"
                print("agreement \(name): \(agreement.summary)")
                #expect(agreement.flatLargest <= 0x1p-9, "\(name): \(agreement.summary)")
                #expect(agreement.flatMean <= 0x1p-12, "\(name): \(agreement.summary)")
                #expect(agreement.otherLargest <= 0.2, "\(name): \(agreement.summary)")
                #expect(agreement.otherAlphaLargest <= 0.125, "\(name): \(agreement.summary)")
                #expect(agreement.otherMean <= 0.01, "\(name): \(agreement.summary)")
            }
        }
    }

    @Test("metal hands every frame over as a surface")
    func handsSurface() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let cases = try await AgreementCase.all(in: directory)
        let sut = MetalRenderer(decoder: AVFoundationDecoder())

        for agreementCase in cases {
            let list = Evaluator().displayList(of: agreementCase.document, at: agreementCase.times[0])

            // When
            let frame = try sut.frame(of: list)

            // Then
            guard case .surface = frame else {
                Issue.record("\(agreementCase.name) is handed over as a bitmap")
                continue
            }
        }
    }

    // MARK: - Private
}
