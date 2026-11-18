//
//  StereoGain.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/18/26.
//

// The gains a sound reaches the left and right output channels at.
struct StereoGain: Equatable, Sendable {
    // MARK: - Property
    let left: Float
    let right: Float

    // MARK: - Initializer
    init(
        left: Float,
        right: Float
    ) {
        self.left = left
        self.right = right
    }

    // MARK: - Public
    // MARK: - Private
}
