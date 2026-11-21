//
//  MotionSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `isRevealSet` is whether a reveal is set on the receiver in a sample of a frame with motion blur: an animation or a
// transition that writes `reveal` acts on it at T (FRAMES-29). Its rectangle is then written in every sample, whole
// where the wipe is complete, and otherwise only where the wipe hides a part.
struct MotionSample: Equatable, Sendable {
    // MARK: - Property
    // Every property at its default.
    static let none = MotionSample(motion: Motion(), revealFrom: .left)

    let motion: Motion
    let revealFrom: RevealEdge
    let isRevealSet: Bool

    var reveal: Reveal {
        Reveal(amount: motion.value(of: .reveal))
    }

    // MARK: - Initializer
    init(
        motion: Motion,
        revealFrom: RevealEdge,
        isRevealSet: Bool = false
    ) {
        self.motion = motion
        self.revealFrom = revealFrom
        self.isRevealSet = isRevealSet
    }

    // MARK: - Public
    // The part of the receiver's box the reveal shows from its side, nil where it shows all of it and no reveal is set.
    func revealRectangle(wiping box: Rectangle) -> Rectangle? {
        guard reveal.amount < 1 || isRevealSet else { return nil }

        return reveal.rectangle(wiping: box, from: revealFrom)
    }

    func settingReveal(_ isRevealSet: Bool) -> MotionSample {
        MotionSample(motion: motion, revealFrom: revealFrom, isRevealSet: isRevealSet)
    }

    // MARK: - Private
}
