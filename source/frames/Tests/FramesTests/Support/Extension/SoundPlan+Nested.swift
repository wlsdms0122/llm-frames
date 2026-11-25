//
//  SoundPlan+Nested.swift
//  FramesTests
//
//  Created by JSilver on 11/26/26.
//

@testable import Frames

// What a source of sound that plays a nested sequence holds, nil for one that plays a file.
extension SoundPlan {
    // MARK: - Property
    var nestedSounds: [SoundPlan]? {
        guard case let .nested(sounds, _) = source else { return nil }

        return sounds
    }

    var nestedAudioFilter: TimedValue? {
        guard case let .nested(_, audioFilter) = source else { return nil }

        return audioFilter
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
