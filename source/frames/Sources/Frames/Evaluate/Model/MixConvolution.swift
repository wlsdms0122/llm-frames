//
//  MixConvolution.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// A `convolve` op's parameters with its defaults written: `file`, the impulse response, pinned and static, and `gain`
// in dB.
package struct MixConvolution: Equatable, Sendable {
    // MARK: - Property
    package let file: PinnedFile
    package let gain: MixValue

    // MARK: - Initializer
    package init(
        file: PinnedFile,
        gain: MixValue
    ) {
        self.file = file
        self.gain = gain
    }

    // MARK: - Public
    // MARK: - Private
}
