//
//  ChannelLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The speaker each channel of a sound feeds, in channel order.
package struct ChannelLayout: Equatable, Sendable {
    // MARK: - Property
    package let labels: [ChannelLabel]

    // One channel, whatever speaker it names: a mixer plays it on both sides and pans it by the equal-power law.
    package var isMono: Bool {
        labels.count == 1
    }

    // MARK: - Initializer
    package init(labels: [ChannelLabel]) {
        self.labels = labels
    }

    // The layout of `channels` channels when nothing names one, in the order of SMPTE and WAVE: mono, stereo, 3.0, 4.0
    // with a centre surround, 5.0, 5.1, 6.1 and 7.1. Any other count is discrete.
    package init(channels: Int) {
        let labels: [ChannelLabel] = switch channels {
        case 1:
            [.mono]

        case 2:
            [.left, .right]

        case 3:
            [.left, .right, .center]

        case 4:
            [.left, .right, .center, .centerSurround]

        case 5:
            [.left, .right, .center, .leftSurround, .rightSurround]

        case 6:
            [.left, .right, .center, .lowFrequencyEffects, .leftSurround, .rightSurround]

        case 7:
            [.left, .right, .center, .lowFrequencyEffects, .leftSurround, .rightSurround, .centerSurround]

        case 8:
            [
                .left,
                .right,
                .center,
                .lowFrequencyEffects,
                .leftSurround,
                .rightSurround,
                .leftRearSurround,
                .rightRearSurround
            ]

        default:
            Array(repeating: .discrete, count: max(channels, 0))
        }

        self.init(labels: labels)
    }

    // MARK: - Public
    // MARK: - Private
}
