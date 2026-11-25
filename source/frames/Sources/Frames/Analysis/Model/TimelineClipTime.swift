//
//  TimelineClipTime.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a connected or sequence clip gives at the sequence time `timeline --at` names: what its time map gives there
// (FRAMES-8), the media time it shows, nil for a clip without media (a title, a shape, an adjustment clip), which has no
// media time, and where it lies there. Such a clip has no clip time of its own.
struct TimelineClipTime: Equatable, Sendable {
    // MARK: - Property
    let mediaTime: Double?
    let geometry: TimelineGeometry

    // MARK: - Initializer
    init(
        mediaTime: Double?,
        geometry: TimelineGeometry
    ) {
        self.mediaTime = mediaTime
        self.geometry = geometry
    }

    // MARK: - Public
    // MARK: - Private
}
