//
//  TrackReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `track` prints: the area as found at `--at`, before padding, and its quad and fitted motion on every frame the
// tracker followed it on, in time order.
package struct TrackReport: Equatable, Sendable {
    // MARK: - Property
    let track: Track

    // MARK: - Initializer
    init(track: Track) {
        self.track = track
    }

    // MARK: - Public
    // MARK: - Private
}
