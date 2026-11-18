//
//  MotionSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

struct MotionSample: Equatable, Sendable {
    // MARK: - Property
    // Every property at its default.
    static let none = MotionSample(motion: Motion(), revealFrom: .left)

    let motion: Motion
    let revealFrom: RevealEdge

    var reveal: Reveal {
        Reveal(amount: motion.value(of: .reveal))
    }

    // MARK: - Initializer
    init(
        motion: Motion,
        revealFrom: RevealEdge
    ) {
        self.motion = motion
        self.revealFrom = revealFrom
    }

    // MARK: - Public
    // MARK: - Private
}
