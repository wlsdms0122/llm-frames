//
//  TrackMatteRefusal.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The kinds of clip that are never a track matte: a storyline clip, an adjustment, which draws no picture
// of its own, and an audio clip and a null, which draw none at all.
enum TrackMatteRefusal: Equatable, Sendable {
    case storyline
    case adjustment
    case audio
    case null

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
