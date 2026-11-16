//
//  TransitionMedia.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The media a transition's cover or matte shows, as probed: its file with its frame times, and its length in media
// seconds, which the transition stretches over its own (a still has none to stretch).
struct TransitionMedia: Equatable, Sendable {
    // MARK: - Property
    let file: MediaFile
    let duration: Double

    // MARK: - Initializer
    init(
        file: MediaFile,
        duration: Double
    ) {
        self.file = file
        self.duration = duration
    }

    // MARK: - Public
    // MARK: - Private
}
