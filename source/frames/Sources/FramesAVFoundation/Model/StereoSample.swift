//
//  StereoSample.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Foundation

// One sample of both channels of a sound mapped onto stereo, full scale 1.
struct StereoSample: Equatable, Sendable {
    // MARK: - Property
    let left: Double
    let right: Double

    // The level the compressor and the gate read, one for both channels so they never move the stereo image: the
    // larger magnitude in dBFS, minus infinity for silence, which is below every threshold.
    var level: Double {
        20 * log10(max(abs(left), abs(right)))
    }

    // MARK: - Initializer
    init(
        left: Double,
        right: Double
    ) {
        self.left = left
        self.right = right
    }

    // MARK: - Public
    func scaled(by gain: Double) -> StereoSample {
        StereoSample(left: left * gain, right: right * gain)
    }

    // This sample as dry and `wet` mixed by `mix`, dry × (1 - mix) + wet × mix on each channel.
    func mixed(
        with wet: StereoSample,
        by mix: Double
    ) -> StereoSample {
        StereoSample(left: left * (1 - mix) + wet.left * mix, right: right * (1 - mix) + wet.right * mix)
    }

    // MARK: - Private
}
