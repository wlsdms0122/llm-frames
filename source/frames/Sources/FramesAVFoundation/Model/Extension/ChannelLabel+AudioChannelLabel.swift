//
//  ChannelLabel+AudioChannelLabel.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import CoreAudioTypes
import Frames

// The speaker a Core Audio channel label names. Core Audio's direct surrounds are the side ones, and its rear
// surrounds are the ones behind them in 7.1.
extension ChannelLabel {
    // MARK: - Property
    // MARK: - Initializer
    init(audioChannelLabel label: AudioChannelLabel) {
        self = switch label {
        case kAudioChannelLabel_Mono:
            .mono

        case kAudioChannelLabel_Left:
            .left

        case kAudioChannelLabel_Right:
            .right

        case kAudioChannelLabel_Center:
            .center

        case kAudioChannelLabel_LFEScreen, kAudioChannelLabel_LFE2:
            .lowFrequencyEffects

        case kAudioChannelLabel_LeftSurround, kAudioChannelLabel_LeftSurroundDirect:
            .leftSurround

        case kAudioChannelLabel_RightSurround, kAudioChannelLabel_RightSurroundDirect:
            .rightSurround

        case kAudioChannelLabel_CenterSurround:
            .centerSurround

        case kAudioChannelLabel_RearSurroundLeft:
            .leftRearSurround

        case kAudioChannelLabel_RearSurroundRight:
            .rightRearSurround

        default:
            .discrete
        }
    }

    // MARK: - Public
    // MARK: - Private
}
