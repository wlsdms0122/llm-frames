//
//  ResolvedMediaClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media clip's picture: what it shows, how a timed one plays (nil for a still), its filter, and how it fills its box.
struct ResolvedMediaClip: Equatable, Sendable {
    // MARK: - Property
    let media: ResolvedMediaContent
    let timing: MediaTiming?
    let filter: [ResolvedFilterOperation]
    let appearance: ResolvedMediaAppearance

    // The media time a timed clip shows, nil for a still.
    var clock: MediaClock? {
        timing.map { timing in MediaClock(timing: timing, frames: media.frames) }
    }

    // MARK: - Initializer
    init(
        media: ResolvedMediaContent,
        timing: MediaTiming?,
        filter: [ResolvedFilterOperation],
        appearance: ResolvedMediaAppearance
    ) {
        self.media = media
        self.timing = timing
        self.filter = filter
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}
