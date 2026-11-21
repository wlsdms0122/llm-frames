//
//  AccumulationBufferTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/21/26.
//

import Frames
@testable import FramesQuartz
import Testing

@Suite("AccumulationBuffer Tests")
struct AccumulationBufferTests {
    // MARK: - Property
    // Zero, the smallest subnormal and normal halves, values with and without an exact half, one ulp above 1, the
    // largest half, and negatives, as a frame of unbounded working values holds them.
    private static let values: [Float16] = [
        0, 0x1p-24, 0x1p-14, 0.1, 1, 1 + 0x1p-10, 2.75, 100.3, 65504, -0.25, -1, -65504, 0.5, 3, 0.75, 1
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("the mean of N equal pictures is the picture", arguments: [2, 3, 16, 64, 256])
    func returnsEqualPictures(count: Int) throws {
        // Given
        let frame = try frame(holding: Self.values)
        let sut = AccumulationBuffer(width: frame.width, height: frame.height)

        // When
        for _ in 0..<count {
            sut.add(frame)
        }
        let mean = try sut.mean(compositing: .encoded)

        // Then
        #expect(halves(of: mean) == Self.values)
    }

    @Test("negative zero comes back as zero")
    func readsNegativeZero() throws {
        // Given
        let frame = try frame(holding: [-0, -0, -0, -0])
        let sut = AccumulationBuffer(width: frame.width, height: frame.height)

        // When
        sut.add(frame)
        sut.add(frame)
        let mean = try sut.mean(compositing: .encoded)

        // Then
        #expect(halves(of: mean).allSatisfy { $0 == 0 })
    }

    @Test("the mean of pictures that differ is their sum in 32-bit float divided once, rounded to the nearest half")
    func roundsMeanToNearest() throws {
        // Given
        // The sum is 3 + 2^-9 and the mean 1 + 2^-9 / 3, nearer 1 + 2^-10 than 1, so it does not round toward zero.
        let pictures = try [1, 1 + 0x1p-10, 1 + 0x1p-10].map { (value: Float16) in try frame(holding: [value, 0, 0, 1]) }
        let sut = AccumulationBuffer(width: 1, height: 1)

        // When
        for picture in pictures {
            sut.add(picture)
        }
        let mean = try sut.mean(compositing: .linear)

        // Then
        #expect(halves(of: mean) == [1 + 0x1p-10, 0, 0, 1])
        #expect(mean.compositing == .linear)
    }

    // MARK: - Private
    // A frame of one row of pixels whose components are `values`, four to a pixel.
    private func frame(holding values: [Float16]) throws -> FrameContext {
        let frame = try FrameContext(width: values.count / 4, height: 1, compositing: .encoded)
        let halves = frame.context.data!.assumingMemoryBound(to: Float16.self)
        for (index, value) in values.enumerated() {
            halves[index] = value
        }

        return frame
    }

    private func halves(of frame: FrameContext) -> [Float16] {
        let halves = frame.context.data!.assumingMemoryBound(to: Float16.self)

        return (0..<frame.width * frame.height * 4).map { halves[$0] }
    }
}
