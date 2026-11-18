//
//  ClosedRange+FrameBounds.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The first and last media time a picture exists at, which a media clock holds its media time to: the first and last
// of a video's or image sequence's frame times, or a nested sequence's `[0, duration)` on whole microseconds. Resolve
// and the resolved document both take a clip's frame bounds from here.
extension ClosedRange<Double> {
    // MARK: - Property
    // MARK: - Initializer
    // nil for media without frame times, a still or sound, which has no frames to hold.
    init?(frameTimes: [Double]) {
        guard let first = frameTimes.first, let last = frameTimes.last else { return nil }

        self = first...last
    }

    // A sequence shorter than a microsecond has one frame, at 0.
    init(sequenceDuration duration: Double) {
        self = 0...Swift.max(duration - .timeResolution, 0)
    }

    // MARK: - Public
    // MARK: - Private
}
