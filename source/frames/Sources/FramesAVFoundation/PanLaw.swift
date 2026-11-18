//
//  PanLaw.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames

// The pan law of FRAMES-13, from -1 (left) to 1 (right), on a sound already mapped onto stereo. A mono sound, the same
// on both channels, takes the equal-power law, cos((p + 1)π/4) on the left and sin((p + 1)π/4) on the right, so its
// power is the same at every pan and both channels are at cos(π/4) at the centre. A sound of two or more channels takes
// a balance, min(1, 1 - p) on the left and min(1, 1 + p) on the right, so it is untouched at the centre and turning it
// to one side lowers the other.
struct PanLaw {
    // MARK: - Property
    private let isMono: Bool

    // MARK: - Initializer
    init(layout: ChannelLayout) {
        self.isMono = layout.isMono
    }

    // MARK: - Public
    func gains(at pan: Float) -> StereoGain {
        guard isMono else { return StereoGain(left: min(1, 1 - pan), right: min(1, 1 + pan)) }

        let angle = (Double(pan) + 1) * .pi / 4
        return StereoGain(left: Float(cos(angle)), right: Float(sin(angle)))
    }

    // MARK: - Private
}
