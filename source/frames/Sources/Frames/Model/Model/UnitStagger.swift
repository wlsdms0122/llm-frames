//
//  UnitStagger.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's entrance and exit played on each of its units, in the order `order` ranks them, `stagger` seconds from the
// start of one rank's spans to the start of the next.
struct UnitStagger: Equatable, Sendable {
    // MARK: - Property
    let by: TextUnit
    let stagger: Double
    let order: UnitOrder

    // MARK: - Initializer
    init(
        by: TextUnit,
        stagger: Double,
        order: UnitOrder = .forward
    ) {
        self.by = by
        self.stagger = stagger
        self.order = order
    }

    // MARK: - Public
    // MARK: - Private
}
