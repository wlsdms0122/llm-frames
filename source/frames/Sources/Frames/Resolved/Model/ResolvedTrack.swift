//
//  ResolvedTrack.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What the tracker followed, as resolve pinned it: `media` is the media followed, the clip's own or its parent's, and
// `track` the target's quad at the instant and its quad and fitted motion on every frame followed, in media time.
struct ResolvedTrack: Equatable, Sendable {
    // MARK: - Property
    let media: PinnedMedia
    let track: Track

    // MARK: - Initializer
    init(
        media: PinnedMedia,
        track: Track
    ) {
        self.media = media
        self.track = track
    }

    // MARK: - Public
    func motion(atMediaTime time: Double) -> TrackMotion {
        track.motion(atMediaTime: time)
    }

    // MARK: - Private
}
