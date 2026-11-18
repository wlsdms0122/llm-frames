//
//  ClipTiming.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a timed media clip that is not on the storyline plays before its window is known: its played range, with the
// start of its window left at 0, or its `timeRemap` keyframes on the clip's clock.
enum ClipTiming: Equatable, Sendable {
    case played(PlayedRange)
    case remapped(PropertyValue<Double>)

    // MARK: - Property
    // The played range of a clip that is not remapped, whose length its window can take.
    var played: PlayedRange? {
        guard case let .played(range) = self else { return nil }

        return range
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
