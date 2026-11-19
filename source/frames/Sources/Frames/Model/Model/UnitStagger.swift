//
//  UnitStagger.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's entrance and exit played on each of its units in reading order, `stagger` seconds from the start of one
// unit's span to the start of the next.
struct UnitStagger: Equatable, Sendable {
    // MARK: - Property
    let by: TextUnit
    let stagger: Double

    // MARK: - Initializer
    init(
        by: TextUnit,
        stagger: Double
    ) {
        self.by = by
        self.stagger = stagger
    }

    // MARK: - Public
    // MARK: - Private
}
