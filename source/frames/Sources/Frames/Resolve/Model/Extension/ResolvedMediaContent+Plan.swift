//
//  ResolvedMediaContent+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a storyline clip or media clip shows: its nested document's resolved form, or its media file pinned. Nil for a
// solid, which shows no media.
extension ResolvedMediaContent {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        media: ResolvedMedia?,
        nested: DocumentPlan?,
        hashes: any FileHashProvider
    ) throws {
        if let nested {
            self = .nested(try ResolvedDocument(plan: nested, hashes: hashes))
        } else if case let .file(file) = media?.source {
            self = .pinned(try PinnedMedia(file: file, hashes: hashes))
        } else {
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
