//
//  ChannelLabelAudioChannelLabelTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import CoreAudioTypes
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("ChannelLabel+AudioChannelLabel Tests")
struct ChannelLabelAudioChannelLabelTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a left or right label, a matrix-encoded pair and a headphone pair are left and right, and an unnamed one is discrete",
        arguments: [
            (kAudioChannelLabel_Left, ChannelLabel.left),
            (kAudioChannelLabel_Right, .right),
            (kAudioChannelLabel_LeftTotal, .left),
            (kAudioChannelLabel_RightTotal, .right),
            (kAudioChannelLabel_HeadphonesLeft, .left),
            (kAudioChannelLabel_HeadphonesRight, .right),
            (kAudioChannelLabel_Discrete_0, .discrete)
        ]
    )
    func mapsLabel(
        label: AudioChannelLabel,
        expected: ChannelLabel
    ) {
        #expect(ChannelLabel(audioChannelLabel: label) == expected)
    }

    // MARK: - Private
}
