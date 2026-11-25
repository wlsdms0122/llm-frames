//
//  ClipAreaRefusal.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The kinds of clip a clip area cannot name, since a clip area reads a box: a solid, which fills the frame with a
// colour, an adjustment clip and an audio clip.
enum ClipAreaRefusal: Equatable, Sendable {
    case solid
    case adjustment
    case audio

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
