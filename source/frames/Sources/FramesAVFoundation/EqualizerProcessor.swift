//
//  EqualizerProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Frames

// An `eq`: its bands as a cascade of biquads, the first band applied first.
final class EqualizerProcessor: AudioOperationProcessor {
    // MARK: - Property
    private var filters: [BiquadFilter]

    // MARK: - Initializer
    init(
        bands: [MixBand],
        sampleRate: Double
    ) {
        self.filters = bands.map { BiquadFilter(band: $0, sampleRate: sampleRate) }
    }

    // MARK: - Lifecycle
    func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample {
        var output = input
        for index in filters.indices {
            output = filters[index].process(output, atSample: sample)
        }

        return output
    }

    // MARK: - Public
    // MARK: - Private
}
