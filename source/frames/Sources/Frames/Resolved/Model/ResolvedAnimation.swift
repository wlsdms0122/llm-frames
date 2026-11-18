//
//  ResolvedAnimation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The animation spans a clip takes, inline: an entrance and an exit by their `seconds`, a loop by its `period`, each
// nil when it takes none.
struct ResolvedAnimation: Equatable, Sendable {
    // MARK: - Property
    static let none = ResolvedAnimation(entrance: nil, loop: nil, exit: nil)

    let entrance: AnimationSpan?
    let loop: AnimationSpan?
    let exit: AnimationSpan?

    // MARK: - Initializer
    init(
        entrance: AnimationSpan?,
        loop: AnimationSpan?,
        exit: AnimationSpan?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
    }

    // MARK: - Public
    // MARK: - Private
}
