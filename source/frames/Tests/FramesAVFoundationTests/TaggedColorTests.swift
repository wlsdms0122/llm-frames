//
//  TaggedColorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/25/26.
//

import Frames
import Testing

@testable import FramesAVFoundation

@Suite("TaggedColor Tests")
struct TaggedColorTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("probe's conversion of a video is the form its code points are converted by, and null where no fixed formula converts them", arguments: [
        (1, 1, 1, WorkingConversion.space(.rec709) as WorkingConversion?),
        (9, 16, 9, .space(.rec2100PQ)),
        (1, 8, 1, .transfer),
        (1, 16, 1, .perceptualQuantizer),
        (12, 18, 1, .hybridLogGamma),
        (1, 1, 3, nil)
    ])
    func probesVideoConversion(
        primaries: Int,
        transfer: Int,
        matrix: Int,
        conversion: WorkingConversion?
    ) {
        // Given
        let sut = TaggedColor(primaries: primaries, transfer: transfer, matrix: matrix, bitDepth: 10, masteringDisplayPeak: nil)

        // Then
        #expect(sut.probed.conversion == conversion)
    }

    @Test("probe's conversion of an untagged image is none, srgb as it is")
    func probesUntaggedImage() {
        // Given
        let sut = TaggedColor(profile: nil, bitDepth: 8, masteringDisplayPeak: nil)

        // Then
        #expect(sut.probed.conversion == .identity)
        #expect(sut.probed.name == .srgb)
    }

    // MARK: - Private
}
