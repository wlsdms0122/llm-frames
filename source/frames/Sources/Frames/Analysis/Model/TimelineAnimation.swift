//
//  TimelineAnimation.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The preset each span of a clip's animation comes from, nil for a span the clip does not take.
struct TimelineAnimation: Equatable, Sendable {
    // MARK: - Property
    let entrance: String?
    let loop: String?
    let exit: String?

    // MARK: - Initializer
    init(
        entrance: String?,
        loop: String?,
        exit: String?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
    }

    // MARK: - Public
    // MARK: - Private
}
