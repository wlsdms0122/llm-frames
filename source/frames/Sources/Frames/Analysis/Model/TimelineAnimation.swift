//
//  TimelineAnimation.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The spans of a clip's animation, each nil when the clip does not take it, and a title's unit, stagger and order when
// its entrance and exit play by unit.
struct TimelineAnimation: Equatable, Sendable {
    // MARK: - Property
    let entrance: TimelineSpan?
    let loop: TimelineSpan?
    let exit: TimelineSpan?
    let units: UnitStagger?

    // MARK: - Initializer
    init(
        entrance: TimelineSpan?,
        loop: TimelineSpan?,
        exit: TimelineSpan?,
        units: UnitStagger?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
        self.units = units
    }

    // MARK: - Public
    // MARK: - Private
}
