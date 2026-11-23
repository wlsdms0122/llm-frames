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

    // The layout of `channels` channels when nothing names one: one channel is mono, two are left and right, and each
    // channel of more is unknown.
    package init(channels: Int) {
        let labels: [ChannelLabel] = switch channels {
        case 1:
            [.mono]

        case 2:
            [.left, .right]

        default:
            Array(repeating: .unknown, count: max(channels, 0))
        }

        self.init(labels: labels)
    }

    // MARK: - Public
    // MARK: - Private
}
