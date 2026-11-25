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
@Suite("Renderer Agreement Tests", .serialized, .blockingLimit)
struct RendererAgreementTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("metal draws every case within the tolerances of quartz: each component within 2^-9 and 2^-12 on average, at flat pixels and at the others")
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
                #expect(agreement.otherLargest <= 0x1p-9, "\(name): \(agreement.summary)")
                #expect(agreement.otherMean <= 0x1p-12, "\(name): \(agreement.summary)")
            }
        }
    }

    @Test("the crossfade halfway through mixes two different detailed pictures on both renderers")
    func crossfadeMixesDetailedPictures() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let cases = try await AgreementCase.all(in: directory)
        let decoder = AVFoundationDecoder()
        let renderers: [(String, any Renderer)] = [
            ("quartz", QuartzRenderer(decoder: decoder)),
            ("metal", MetalRenderer(decoder: decoder))
        ]
        var checked = 0

        for agreementCase in cases {
            for case let .mix(outgoing, incoming, time) in agreementCase.checks {
                for (name, sut) in renderers {
                    // When
                    let frame = { (time: Double) in
                        try sut.bitmap(of: Evaluator().displayList(of: agreementCase.document, at: time))
                    }
                    let first = try frame(outgoing)
                    let second = try frame(incoming)
                    let mixed = try frame(time)

                    // Then
                    let pixelCount = Double(first.width * first.height)
                    let firstDetail = Double(RendererAgreement(of: first, against: first).otherCount) / pixelCount
                    let secondDetail = Double(RendererAgreement(of: second, against: second).otherCount) / pixelCount
                    let apart = RendererAgreement(of: second, against: first).mean
                    let fromFirst = RendererAgreement(of: mixed, against: first).mean
                    let fromSecond = RendererAgreement(of: mixed, against: second).mean
                    let summary = "\(agreementCase.name) on \(name): detail \(firstDetail), \(secondDetail); "
                        + "apart \(apart); mixed from each \(fromFirst), \(fromSecond)"
                    print("mix \(summary)")
                    #expect(firstDetail >= 0.2 && secondDetail >= 0.2, "\(summary)")
                    #expect(apart >= 0.1, "\(summary)")
                    #expect(fromFirst >= apart / 4 && fromSecond >= apart / 4, "\(summary)")
                }
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    @Test("metal puts every probed hard edge within 1/64 px of where quartz puts it")
    func edgesAgreeWithQuartz() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let cases = try await AgreementCase.all(in: directory)
        let decoder = AVFoundationDecoder()
        let reference = QuartzRenderer(decoder: decoder)
        let sut = MetalRenderer(decoder: decoder)
        var checked = 0

        for agreementCase in cases {
            for time in agreementCase.times {
                let list = Evaluator().displayList(of: agreementCase.document, at: time)
                for case let .edge(probe) in agreementCase.checks {
                    // When
                    let position = probe.position(in: try sut.bitmap(of: list))
                    let expected = probe.position(in: try reference.bitmap(of: list))

                    // Then
                    let summary = "\(probe.name) at \(time): metal \(position), quartz \(expected)"
                    print("edge \(summary)")
                    #expect(abs(position - expected) <= 0x1p-6, "\(summary)")
                    checked += 1
                }
            }
        }
        #expect(checked > 0)
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
