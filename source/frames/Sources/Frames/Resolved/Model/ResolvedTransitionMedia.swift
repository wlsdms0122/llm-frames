//
//  ResolvedTransitionMedia.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The media a transition's cover or matte shows: its pinned file with its frame times, and its length in media
// seconds. At progress p a video shows media time p x `duration`, and a still its one frame.
struct ResolvedTransitionMedia: Equatable, Sendable {
    // MARK: - Property
    let media: PinnedMedia
    let duration: Double

    // MARK: - Initializer
    init(
        media: PinnedMedia,
        duration: Double
    ) {
        self.media = media
        self.duration = duration
    }

    // MARK: - Public
    // MARK: - Private
}
