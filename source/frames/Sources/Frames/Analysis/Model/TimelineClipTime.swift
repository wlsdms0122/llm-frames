//
//  TimelineClipTime.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a connected or sequence clip's time map gives at the sequence time `timeline --at` names (FRAMES-8): the media
// time it shows, nil for a clip without media (a title, a shape, an adjustment clip), which has no media time. Such a
// clip has no clip time of its own.
struct TimelineClipTime: Equatable, Sendable {
    // MARK: - Property
    let mediaTime: Double?

    // MARK: - Initializer
    init(mediaTime: Double?) {
        self.mediaTime = mediaTime
    }

    // MARK: - Public
    // MARK: - Private
}
