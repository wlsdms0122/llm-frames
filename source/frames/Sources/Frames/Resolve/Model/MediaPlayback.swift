//
//  MediaPlayback.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What turns sequence time into the media time a clip shows, before that time is clamped to its media (FRAMES-8): a
// storyline clip's line, which goes on into its handles, a media clip's played range, or `timeRemap` keyframes in
// sequence time whose values are media seconds.
enum MediaPlayback: Equatable, Sendable {
    case line(TimeMap)
    case played(PlayedRange)
    case remapped([Keyframe<Double>])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mediaTime(atSequenceTime time: Double) -> Double {
        switch self {
        case let .line(map):
            map.clipTime(atSequenceTime: time)

        case let .played(range):
            range.clipTime(atSequenceTime: time)

        case let .remapped(keyframes):
            keyframes.value(at: time)
        }
    }

    // MARK: - Private
}
