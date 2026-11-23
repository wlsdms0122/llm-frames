//
//  ConvolutionProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

import Accelerate
import Foundation
import Frames

// The `convolve` op of FRAMES-13 over a sound's two channels, in place: y[n] = 10^(G[n] / 20) × Σ h[k] x[n - k], k from
// 0 to K - 1, each channel by its own h, with x 0 before the sound's first sample, where it is made at rest. The head
// of h is summed directly and its stages by their transforms (`ImpulseResponse`), in double precision, so each output
// sample is ready once its input sample is, and the sound can be handed over in blocks of any size with the same
// result. The input is cut where a block of the head ends, so no stage's block is crossed. `gain` is read at the
// sequence time of each sample.
final class ConvolutionProcessor {
    // MARK: - Property
    private static let chunkSize = ImpulseResponse.headLength

    private let sampleRate: Double
    private let head: [[Double]]
    private let headLength: Int
    private let stages: [ConvolutionStage]
    private let constantScale: Double?
    private var gain: EnvelopeCursor

    // Per channel the `headLength` - 1 samples before the chunk, then the chunk.
    private let history: UnsafeMutableBufferPointer<Double>
    // Per channel the output of the chunk.
    private let output: UnsafeMutableBufferPointer<Double>
    // The scale 10^(G / 20) of each sample of the chunk.
    private let scales: UnsafeMutableBufferPointer<Double>
    private var position = 0

    private var historyLength: Int {
        headLength - 1 + Self.chunkSize
    }

    // MARK: - Initializer
    init(
        convolution: MixConvolution,
        impulseResponse: ImpulseResponse,
        sampleRate: Double
    ) {
        let headLength = impulseResponse.head[0].count

        self.sampleRate = sampleRate
        self.head = impulseResponse.head
        self.headLength = headLength
        self.stages = impulseResponse.stages.map(ConvolutionStage.init)
        self.constantScale = if case let .constant(gain) = convolution.gain { pow(10, gain / 20) } else { nil }
        self.gain = EnvelopeCursor(value: convolution.gain)
        self.history = .zeroed(2 * (headLength - 1 + Self.chunkSize))
        self.output = .zeroed(2 * Self.chunkSize)
        self.scales = .zeroed(Self.chunkSize)
    }

    deinit {
        history.deallocate()
        output.deallocate()
        scales.deallocate()
    }

    // MARK: - Public
    // Convolves `frames` samples of each of the two `channels` in place, frame 0 at sequence sample `first`, carrying
    // on from the samples taken before.
    func process(
        _ channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        var frame = 0
        while frame < frames {
            let count = min(frames - frame, Self.chunkSize - position)
            let block = channels.map { $0 + frame }
            convolve(block, frames: count)
            raise(into: block, frames: count, first: first + frame)
            position = (position + count) % Self.chunkSize
            frame += count
        }
    }

    // MARK: - Private
    // Writes Σ h[k] x[n - k] for the `count` samples of each channel at `input` into `output`.
    private func convolve(
        _ input: [UnsafeMutablePointer<Float>],
        frames count: Int
    ) {
        let history = self.history.baseAddress!
        let output = self.output.baseAddress!
        let past = headLength - 1
        for channel in 0..<2 {
            let samples = history + channel * historyLength
            vDSP_vspdp(input[channel], 1, samples + past, 1, vDSP_Length(count))
            head[channel].withUnsafeBufferPointer { head in
                vDSP_convD(
                    samples,
                    1,
                    head.baseAddress! + past,
                    -1,
                    output + channel * Self.chunkSize,
                    1,
                    vDSP_Length(count),
                    vDSP_Length(headLength)
                )
            }
        }

        let taken = [UnsafePointer(history + past), UnsafePointer(history + historyLength + past)]
        let results = [output, output + Self.chunkSize]
        for stage in stages {
            stage.process(taken, frames: count, into: results)
        }

        for channel in 0..<2 {
            let samples = history + channel * historyLength
            samples.update(from: samples + count, count: past)
        }
    }

    // Writes the chunk's output raised by `gain` into the `count` samples of each channel at `channels`, the first at
    // sequence sample `first`.
    private func raise(
        into channels: [UnsafeMutablePointer<Float>],
        frames count: Int,
        first: Int
    ) {
        let output = self.output.baseAddress!
        let scales = self.scales.baseAddress!
        for offset in 0..<count {
            scales[offset] = constantScale ?? pow(10, gain.value(at: Double(first + offset) / sampleRate) / 20)
        }
        for channel in 0..<2 {
            let samples = output + channel * Self.chunkSize
            vDSP_vmulD(samples, 1, scales, 1, samples, 1, vDSP_Length(count))
            vDSP_vdpsp(samples, 1, channels[channel], 1, vDSP_Length(count))
        }
    }
}
