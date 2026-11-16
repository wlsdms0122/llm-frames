//
//  TrackReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `track` prints: the area's rectangle on every frame the tracker followed it on, in time order, before padding.
package struct TrackReport: Equatable, Sendable {
    // MARK: - Property
    package let frames: [TrackedFrame]

    // MARK: - Initializer
    init(frames: [TrackedFrame]) {
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}
