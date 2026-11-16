//
//  ResolvedClip+Place.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Whether a clips entry is a connected clip or a sequence clip, read from its place in the document: a connected
// clip's place lies under its storyline clip's, and a sequence clip's under `clips`.
extension ResolvedClip {
    // MARK: - Property
    var isConnected: Bool {
        place.hasPrefix("storyline")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
