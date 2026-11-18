//
//  TrackedFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The target's quad in media pixels on the frame at `time`, in media seconds, as a tracker reports it.
package struct TrackedFrame: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let quad: Quad

    // MARK: - Initializer
    package init(
        time: Double,
        quad: Quad
    ) {
        self.time = time
        self.quad = quad
    }

    // MARK: - Public
    // MARK: - Private
}
