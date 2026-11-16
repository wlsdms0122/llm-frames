//
//  MotionSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The motion of a span at one instant, with the side its span reveals from.
struct MotionSample: Equatable, Sendable {
    // MARK: - Property
    // Every property at its default: the thing simply shows.
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
