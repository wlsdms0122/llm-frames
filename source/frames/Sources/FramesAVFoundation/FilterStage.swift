//
//  FilterStage.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Frames

// A run of an entry's ops: ops that take one sample at a time, run together sample by sample, a limiter, which reads
// ahead in its input and runs over the whole sound at once, or a convolution, which runs over the sound in its own
// blocks.
enum FilterStage {
    case samples([any AudioOperationProcessor])
    case limiter(LimiterProcessor)
    case convolution(ConvolutionProcessor)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The stages of `operations` in order, each run of ops that take one sample at a time one stage. `place` is the
    // entry's place in the plan followed by a dot, as `segments[0].filter[1].`, and names an op whose impulse response
    // cannot be read.
    static func stages(
        of operations: [MixFilterOperation],
        place: String,
        sampleRate: Double,
        impulseResponses: ImpulseResponseCache
    ) throws -> [FilterStage] {
        try operations.enumerated().reduce(into: [FilterStage]()) { stages, element in
            let (index, operation) = element
            let processor: any AudioOperationProcessor
            switch operation {
            case let .eq(bands):
                processor = EqualizerProcessor(bands: bands, sampleRate: sampleRate)

            case let .compressor(compressor):
                processor = CompressorProcessor(compressor: compressor, sampleRate: sampleRate)

            case let .gate(gate):
                processor = GateProcessor(gate: gate, sampleRate: sampleRate)

            case let .limiter(limiter):
                stages.append(.limiter(LimiterProcessor(limiter: limiter, sampleRate: sampleRate)))
                return

            case let .convolve(convolution):
                let impulseResponse = try impulseResponses.impulseResponse(
                    of: convolution.file,
                    place: "\(place)ops[\(index)]"
                )
                stages.append(.convolution(try ConvolutionProcessor(
                    convolution: convolution,
                    impulseResponse: impulseResponse,
                    sampleRate: sampleRate
                )))
                return
            }

            if case let .samples(processors) = stages.last {
                stages[stages.count - 1] = .samples(processors + [processor])
            } else {
                stages.append(.samples([processor]))
            }
        }
    }

    // Runs the stage over `frames` samples of each of `channels` in place, frame 0 at sequence sample `first`.
    func process(
        _ channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        switch self {
        case let .samples(processors):
            for frame in 0..<frames {
                let input = StereoSample(left: Double(channels[0][frame]), right: Double(channels[1][frame]))
                let output = processors.reduce(input) { output, processor in
                    processor.process(output, atSample: first + frame)
                }
                channels[0][frame] = Float(output.left)
                channels[1][frame] = Float(output.right)
            }

        case let .limiter(limiter):
            limiter.process(channels, frames: frames, first: first)

        case let .convolution(convolution):
            convolution.process(channels, frames: frames, first: first)
        }
    }

    // MARK: - Private
}
