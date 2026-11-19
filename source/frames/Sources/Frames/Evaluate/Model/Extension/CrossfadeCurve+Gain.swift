//
//  CrossfadeCurve+Gain.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// `progress` runs from 0 at the transition's start to 1 at its end at an even pace. Every gain a crossfade puts on a
// sound comes from here.
extension CrossfadeCurve {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func gains(at progress: Double) -> CrossfadeGains {
        switch self {
        case .constantPower:
            CrossfadeGains(outgoing: cos(progress * .pi / 2), incoming: sin(progress * .pi / 2))

        case .constantGain:
            CrossfadeGains(outgoing: 1 - progress, incoming: progress)
        }
    }

    // MARK: - Private
}
