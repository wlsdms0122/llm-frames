//
//  ResolvedMediaContent+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a storyline clip or media clip shows: its nested sequence's resolved form, or its media file pinned. Nil for a
// solid, which shows no media.
extension ResolvedMediaContent {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        media: MediaPlan?,
        nested: SequencePlan?,
        hashes: any FileHashProvider
    ) throws {
        if let nested {
            self = .nested(try ResolvedSequence(plan: nested, hashes: hashes))
        } else if case let .file(file) = media?.source {
            self = .pinned(try PinnedMedia(file: file, hashes: hashes))
        } else {
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
