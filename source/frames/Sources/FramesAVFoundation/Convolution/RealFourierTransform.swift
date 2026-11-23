//
//  RealFourierTransform.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

import Accelerate

// The discrete Fourier transform of `size` real samples, `size` a power of 2, by vDSP's radix 2 FFT in double precision.
// A spectrum is packed in `size` / 2 complex values: bin k in place k for k from 1, and bin 0 and bin `size` / 2, both
// real, as the real and imaginary parts of place 0. The forward transform gives 2 × the DFT, and the inverse of the
// forward transform gives 2 × `size` × the samples. Nothing in it, its setup included, is written after it is made,
// so threads share it.
final class RealFourierTransform: @unchecked Sendable {
    // MARK: - Property
    let size: Int

    private let logSize: vDSP_Length
    private let setup: FFTSetupD

    // MARK: - Initializer
    init(
        size: Int,
        path: String
    ) throws {
        let logSize = vDSP_Length(size.trailingZeroBitCount)
        guard let setup = vDSP_create_fftsetupD(logSize, FFTRadix(kFFTRadix2)) else {
            throw MixerError.unrenderable(file: path, reason: "no Fourier transform of \(size) samples")
        }

        self.size = size
        self.logSize = logSize
        self.setup = setup
    }

    deinit {
        vDSP_destroy_fftsetupD(setup)
    }

    // MARK: - Public
    // The packed spectrum of the `size` samples at `signal`, written to `real` and `imaginary`, `size` / 2 each.
    func forward(
        _ signal: UnsafePointer<Double>,
        real: UnsafeMutablePointer<Double>,
        imaginary: UnsafeMutablePointer<Double>
    ) {
        var spectrum = DSPDoubleSplitComplex(realp: real, imagp: imaginary)
        signal.withMemoryRebound(to: DSPDoubleComplex.self, capacity: size / 2) { pairs in
            vDSP_ctozD(pairs, 2, &spectrum, 1, vDSP_Length(size / 2))
        }
        vDSP_fft_zripD(setup, &spectrum, 1, logSize, FFTDirection(kFFTDirection_Forward))
    }

    // The `size` samples of the packed spectrum in `real` and `imaginary`, written to `signal`. The spectrum is
    // overwritten.
    func inverse(
        real: UnsafeMutablePointer<Double>,
        imaginary: UnsafeMutablePointer<Double>,
        into signal: UnsafeMutablePointer<Double>
    ) {
        var spectrum = DSPDoubleSplitComplex(realp: real, imagp: imaginary)
        vDSP_fft_zripD(setup, &spectrum, 1, logSize, FFTDirection(kFFTDirection_Inverse))
        signal.withMemoryRebound(to: DSPDoubleComplex.self, capacity: size / 2) { pairs in
            vDSP_ztocD(&spectrum, 1, pairs, 2, vDSP_Length(size / 2))
        }
    }

    // MARK: - Private
}
