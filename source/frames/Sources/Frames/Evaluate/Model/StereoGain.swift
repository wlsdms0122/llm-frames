//
//  StereoGain.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The gains a sound reaches the left and right output channels at.
package struct StereoGain: Equatable, Sendable {
    // MARK: - Property
    package let left: Float
    package let right: Float

    // MARK: - Initializer
    package init(
        left: Float,
        right: Float
    ) {
        self.left = left
        self.right = right
    }

    // MARK: - Public
    // MARK: - Private
}
