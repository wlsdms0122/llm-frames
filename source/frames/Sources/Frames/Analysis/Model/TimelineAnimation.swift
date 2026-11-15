//
//  TimelineAnimation.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The spans of a clip's animation, each nil when the clip does not take it.
struct TimelineAnimation: Equatable, Sendable {
    // MARK: - Property
    let entrance: TimelineSpan?
    let loop: TimelineSpan?
    let exit: TimelineSpan?

    // MARK: - Initializer
    init(
        entrance: TimelineSpan?,
        loop: TimelineSpan?,
        exit: TimelineSpan?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
    }

    // MARK: - Public
    // MARK: - Private
}
