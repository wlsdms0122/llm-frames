//
//  MediaTiming.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a timed media clip that is not on the storyline plays over its window: along its played range, or by its
// `timeRemap` keyframes in sequence time, whose values are media seconds. `origin` is the start of the window before
// tracking narrowed it. A remapped clip's keys give the media time at every instant of its window, so it has no `in`,
// `out` or `loop`, and its speed is 1.
enum MediaTiming: Equatable, Sendable {
    case played(PlayedRange)
    case remapped(origin: Double, timeRemap: [Keyframe<Double>])

    // MARK: - Property
    var origin: Double {
        switch self {
        case let .played(range):
            range.origin

        case let .remapped(origin, _):
            origin
        }
    }

    var playback: MediaPlayback {
        switch self {
        case let .played(range):
            .played(range)

        case let .remapped(_, timeRemap):
            .remapped(timeRemap)
        }
    }

    // The played range of a clip that is not remapped, which is what its sound plays.
    var played: PlayedRange? {
        guard case let .played(range) = self else { return nil }

        return range
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
