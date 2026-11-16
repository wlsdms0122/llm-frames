//
//  AnimationPreset.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct AnimationPreset: Equatable, Sendable {
    // MARK: - Property
    let description: String
    let entrance: AnimationSpan?
    let loop: AnimationSpan?
    let exit: AnimationSpan?

    // MARK: - Initializer
    init(
        description: String,
        entrance: AnimationSpan?,
        loop: AnimationSpan?,
        exit: AnimationSpan?
    ) {
        self.description = description
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
    }

    // MARK: - Public
    // MARK: - Private
}
