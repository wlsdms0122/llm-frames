//
//  ResolvedClip+Unit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title animated by unit plays its entrance and its exit on each unit, in its visible window.
extension ResolvedClip {
    // MARK: - Property
    // Nil for a clip not animated by unit.
    var unitSchedule: UnitSchedule? {
        guard case let .picture(.title(text), _, _) = content, let units = text.units, let stagger = animation.units else {
            return nil
        }

        return UnitSchedule(
            animation: animation,
            stagger: stagger.stagger,
            order: stagger.order,
            count: units.count,
            in: TimeRange(start: start, end: end)
        )
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
