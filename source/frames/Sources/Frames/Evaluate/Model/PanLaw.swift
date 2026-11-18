//
//  PanLaw.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// A pan from -1 (left) to 1 (right) on a sound already mapped onto stereo. A mono sound takes the equal-power law, so
// its power is the same at every pan; a sound of two or more channels takes a balance, untouched at the centre. Every
// mixer pans by this law, so a document's pan sounds the same whichever mixer plays it.
package struct PanLaw: Sendable {
    // MARK: - Property
    private let isMono: Bool

    // MARK: - Initializer
    package init(layout: ChannelLayout) {
        self.isMono = layout.isMono
    }

    // MARK: - Public
    package func gains(at pan: Float) -> StereoGain {
        guard isMono else { return StereoGain(left: min(1, 1 - pan), right: min(1, 1 + pan)) }

        let angle = (Double(pan) + 1) * .pi / 4
        return StereoGain(left: Float(cos(angle)), right: Float(sin(angle)))
    }

    // MARK: - Private
}
