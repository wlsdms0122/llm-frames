//
//  ImpulseResponse.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

// A `convolve` op's impulse response h of `frameCount` taps a channel, left and right, at the mix plan's sample rate,
// laid out for a convolution that adds no delay: its first `headLength` taps are summed directly, and the taps after
// them in stages of uniform partitions. Each stage's first tap is at least one of its blocks from tap 0, so a block of
// input is transformed before any of its output is due.
struct ImpulseResponse: Sendable {
    // MARK: - Property
    static let headLength = 128

    // Each stage's block size and first tap. A stage runs to the next one's first tap, and the last to the end of h.
    private static let layout = [(128, 128), (1024, 2048), (8192, 16_384), (65_536, 131_072)]

    let frameCount: Int
    // Per channel, the taps [0, min(`headLength`, `frameCount`)).
    let head: [[Double]]
    let stages: [ImpulseResponseStage]

    // MARK: - Initializer
    // `taps` holds the two channels, of the same count of taps and at least one. `path` names the file in a failure.
    init(
        taps: [[Double]],
        path: String
    ) throws {
        let frameCount = taps[0].count
        var stages = [ImpulseResponseStage]()
        for (index, (blockSize, offset)) in Self.layout.enumerated() where offset < frameCount {
            let end = index + 1 < Self.layout.count ? Self.layout[index + 1].1 : frameCount
            let transform = try RealFourierTransform(size: 2 * blockSize, path: path)
            stages.append(ImpulseResponseStage(
                blockSize: blockSize,
                offset: offset,
                end: end,
                taps: taps,
                transform: transform
            ))
        }

        self.frameCount = frameCount
        self.head = taps.map { Array($0.prefix(Self.headLength)) }
        self.stages = stages
    }

    // MARK: - Public
    // MARK: - Private
}
