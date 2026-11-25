//
//  TrackReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `track` prints, track data (FRAMES-12 Track data): `time` is the media time of `--at`, and `frames` the area's
// quad on every frame the tracker followed it on, in time order, the frame at `--at` among them.
package struct TrackReport: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let frames: [TrackedFrame]

    // MARK: - Initializer
    init(
        time: Double,
        frames: [TrackedFrame]
    ) {
        self.time = time
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}
