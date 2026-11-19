//
//  MixBand.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// One band of an `eq`: `frequency` in Hz, `gain` in dB where its type takes one and nil where it does not.
package struct MixBand: Equatable, Sendable {
    // MARK: - Property
    package let type: MixBandType
    package let frequency: MixValue
    package let gain: MixValue?
    package let q: MixValue

    // MARK: - Initializer
    package init(
        type: MixBandType,
        frequency: MixValue,
        gain: MixValue?,
        q: MixValue
    ) {
        self.type = type
        self.frequency = frequency
        self.gain = gain
        self.q = q
    }

    // MARK: - Public
    // MARK: - Private
}
