//
//  ChannelLabel.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The speaker a channel of sound feeds. Side surrounds are `leftSurround` and `rightSurround`, and the surrounds behind
// them in 7.1 are the rear ones. `discrete` is a channel named for no speaker here.
package enum ChannelLabel: Equatable, Sendable {
    case mono
    case left
    case right
    case center
    case lowFrequencyEffects
    case leftSurround
    case rightSurround
    case centerSurround
    case leftRearSurround
    case rightRearSurround
    case discrete
}
