//
//  ImpulseResponseStage.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

// The taps [offset, offset + partitionCount × blockSize) of a two channel impulse response, 0 past its end, cut into
// partitions of `blockSize` taps. Each partition is kept as the packed spectrum of its taps followed by `blockSize`
// zeros, scaled by 1 / (8 × blockSize), so that the inverse transform of its product with the forward spectrum of
// 2 × `blockSize` samples is their circular convolution.
struct ImpulseResponseStage: Sendable {
    // MARK: - Property
    let blockSize: Int
    let offset: Int
    let partitionCount: Int
    // Per channel, the spectrum of partition p in [p × blockSize, (p + 1) × blockSize).
    let real: [[Double]]
    let imaginary: [[Double]]

    // MARK: - Initializer
    // `transform` is of 2 × `blockSize` samples, and the stage ends at tap `end` or at the end of `taps`.
    init(
        blockSize: Int,
        offset: Int,
        end: Int,
        taps: [[Double]],
        transform: RealFourierTransform
    ) {
        let end = min(end, taps[0].count)
        let partitionCount = (end - offset + blockSize - 1) / blockSize
        let scale = 1 / Double(8 * blockSize)
        var padded = [Double](repeating: 0, count: 2 * blockSize)
        var real = [[Double]](repeating: [Double](repeating: 0, count: partitionCount * blockSize), count: taps.count)
        var imaginary = real

        for channel in taps.indices {
            for partition in 0..<partitionCount {
                let first = offset + partition * blockSize
                let last = min(first + blockSize, end)
                for tap in 0..<blockSize {
                    padded[tap] = first + tap < last ? taps[channel][first + tap] * scale : 0
                }
                padded.withUnsafeBufferPointer { padded in
                    real[channel].withUnsafeMutableBufferPointer { real in
                        imaginary[channel].withUnsafeMutableBufferPointer { imaginary in
                            transform.forward(
                                padded.baseAddress!,
                                real: real.baseAddress! + partition * blockSize,
                                imaginary: imaginary.baseAddress! + partition * blockSize
                            )
                        }
                    }
                }
            }
        }

        self.blockSize = blockSize
        self.offset = offset
        self.partitionCount = partitionCount
        self.real = real
        self.imaginary = imaginary
    }

    // MARK: - Public
    // MARK: - Private
}
