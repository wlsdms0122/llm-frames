//
//  GreyImageTests.swift
//  FramesPointTrackerTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Frames
@testable import FramesPointTracker
import Testing

@Suite("GreyImage Tests")
struct GreyImageTests {
    // MARK: - Property
    // Red, white and half transparent white, premultiplied.
    private let colours: [[Double]] = [[1, 0, 0, 1], [1, 1, 1, 1], [0.5, 0.5, 0.5, 0.5]]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a picture becomes its Rec. 709 luma, the same at eight and sixteen bits", arguments: [BitDepth.eight, .sixteen])
    func readsLuma(depth: BitDepth) {
        // Given
        let picture = picture(of: colours, depth: depth)

        // When
        let sut = GreyImage(picture: picture)

        // Then
        #expect(sut.width == 3)
        #expect(sut.height == 1)
        for (value, expected) in zip(sut.values, [0.2126, 1, 0.5]) {
            #expect(abs(Double(value) - expected) < 0.003, "\(sut.values)")
        }
    }

    // MARK: - Private
    private func picture(
        of colours: [[Double]],
        depth: BitDepth
    ) -> Bitmap {
        let maximum = Double((1 << depth.bitsPerComponent) - 1)
        var pixels = Data()
        for component in colours.flatMap({ $0 }) {
            let value = (component * maximum).rounded()
            switch depth {
            case .eight:
                pixels.append(UInt8(value))

            case .sixteen:
                withUnsafeBytes(of: UInt16(value)) { pixels.append(contentsOf: $0) }
            }
        }

        return Bitmap(
            width: colours.count,
            height: 1,
            depth: depth,
            bytesPerRow: colours.count * 4 * depth.bitsPerComponent / 8,
            pixels: pixels
        )
    }
}
