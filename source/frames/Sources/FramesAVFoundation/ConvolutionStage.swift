//
//  ConvolutionStage.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

import Accelerate

// One stage of an impulse response run over a sound's two channels by uniformly partitioned overlap-save, made at
// rest. With B the block size, each block of input that completes is transformed with the block before it, and the
// spectra of the last P such windows are kept for the stage's P partitions. The sum over p of partition p times the
// spectrum of the window p blocks back, transformed back, gives in its last B samples the stage's output for the block
// `offset` / B blocks later, which is kept until it plays.
final class ConvolutionStage {
    // MARK: - Property
    private let stage: ImpulseResponseStage
    private let transform: RealFourierTransform
    private let delay: Int

    // Per channel 2B samples: the last complete block, then the block being filled.
    private let window: UnsafeMutableBufferPointer<Double>
    // Per channel P spectra of B packed bins, the spectrum of block i at i mod P.
    private let spectraReal: UnsafeMutableBufferPointer<Double>
    private let spectraImaginary: UnsafeMutableBufferPointer<Double>
    // Per channel `delay` blocks of output, block m's at m mod `delay`.
    private let delayed: UnsafeMutableBufferPointer<Double>
    private let sumReal: UnsafeMutableBufferPointer<Double>
    private let sumImaginary: UnsafeMutableBufferPointer<Double>
    private let product: UnsafeMutableBufferPointer<Double>

    private var block = 0
    private var position = 0

    // MARK: - Initializer
    init(
        stage: ImpulseResponseStage,
        path: String
    ) throws {
        let blockSize = stage.blockSize
        let delay = stage.offset / blockSize

        self.stage = stage
        self.transform = try RealFourierTransform(size: 2 * blockSize, path: path)
        self.delay = delay
        self.window = .zeroed(2 * 2 * blockSize)
        self.spectraReal = .zeroed(2 * stage.partitionCount * blockSize)
        self.spectraImaginary = .zeroed(2 * stage.partitionCount * blockSize)
        self.delayed = .zeroed(2 * delay * blockSize)
        self.sumReal = .zeroed(blockSize)
        self.sumImaginary = .zeroed(blockSize)
        self.product = .zeroed(2 * blockSize)
    }

    deinit {
        for buffer in [window, spectraReal, spectraImaginary, delayed, sumReal, sumImaginary, product] {
            buffer.deallocate()
        }
    }

    // MARK: - Public
    // Takes `count` samples of each of the two channels at `input`, no more than are left in the current block, and
    // adds the stage's output for them into `output`.
    func process(
        _ input: [UnsafePointer<Double>],
        frames count: Int,
        into output: [UnsafeMutablePointer<Double>]
    ) {
        let blockSize = stage.blockSize
        let played = delayed.baseAddress! + (block % delay) * blockSize + position
        for channel in 0..<2 {
            (window.baseAddress! + channel * 2 * blockSize + blockSize + position).update(from: input[channel], count: count)
            let source = played + channel * delay * blockSize
            vDSP_vaddD(output[channel], 1, source, 1, output[channel], 1, vDSP_Length(count))
        }
        position += count
        guard position == blockSize else { return }

        for channel in 0..<2 {
            complete(channel: channel)
        }
        block += 1
        position = 0
    }

    // MARK: - Private
    // The block `block` of `channel` is complete: keeps the spectrum of the window, writes the output it gives into
    // the place of the block that has just played, and moves the window on by a block.
    private func complete(channel: Int) {
        let blockSize = stage.blockSize
        let partitionCount = stage.partitionCount
        let window = self.window.baseAddress! + channel * 2 * blockSize
        let spectraReal = self.spectraReal.baseAddress! + channel * partitionCount * blockSize
        let spectraImaginary = self.spectraImaginary.baseAddress! + channel * partitionCount * blockSize
        let newest = (block % partitionCount) * blockSize
        transform.forward(window, real: spectraReal + newest, imaginary: spectraImaginary + newest)

        let sumReal = self.sumReal.baseAddress!
        let sumImaginary = self.sumImaginary.baseAddress!
        sumReal.update(repeating: 0, count: blockSize)
        sumImaginary.update(repeating: 0, count: blockSize)
        stage.real[channel].withUnsafeBufferPointer { partitionReal in
            stage.imaginary[channel].withUnsafeBufferPointer { partitionImaginary in
                for partition in 0..<partitionCount {
                    let spectrum = ((block - partition) % partitionCount + partitionCount) % partitionCount * blockSize
                    let taps = partition * blockSize
                    multiplyAdd(
                        DSPDoubleSplitComplex(
                            realp: UnsafeMutablePointer(mutating: partitionReal.baseAddress! + taps),
                            imagp: UnsafeMutablePointer(mutating: partitionImaginary.baseAddress! + taps)
                        ),
                        DSPDoubleSplitComplex(realp: spectraReal + spectrum, imagp: spectraImaginary + spectrum),
                        into: DSPDoubleSplitComplex(realp: sumReal, imagp: sumImaginary)
                    )
                }
            }
        }

        let product = self.product.baseAddress!
        transform.inverse(real: sumReal, imaginary: sumImaginary, into: product)
        let played = delayed.baseAddress! + channel * delay * blockSize + (block % delay) * blockSize
        played.update(from: product + blockSize, count: blockSize)
        window.update(from: window + blockSize, count: blockSize)
    }

    // sum += partition × spectrum over B packed bins: place 0 as its two real bins, and the others as complex values.
    private func multiplyAdd(
        _ partition: DSPDoubleSplitComplex,
        _ spectrum: DSPDoubleSplitComplex,
        into sum: DSPDoubleSplitComplex
    ) {
        sum.realp[0] += partition.realp[0] * spectrum.realp[0]
        sum.imagp[0] += partition.imagp[0] * spectrum.imagp[0]
        var partitionBins = DSPDoubleSplitComplex(realp: partition.realp + 1, imagp: partition.imagp + 1)
        var spectrumBins = DSPDoubleSplitComplex(realp: spectrum.realp + 1, imagp: spectrum.imagp + 1)
        var addend = DSPDoubleSplitComplex(realp: sum.realp + 1, imagp: sum.imagp + 1)
        var result = addend
        vDSP_zvmaD(&partitionBins, 1, &spectrumBins, 1, &addend, 1, &result, 1, vDSP_Length(stage.blockSize - 1))
    }
}
