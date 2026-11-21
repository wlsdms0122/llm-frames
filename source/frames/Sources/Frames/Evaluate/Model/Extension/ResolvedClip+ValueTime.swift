//
//  ResolvedClip+ValueTime.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The time a clip's values are read at in a sample, by its own switch and held in its visible window (FRAMES-29).
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func valueTime(in sample: SampleInstant) -> SampleTime {
        sample.readTime(ownedBy: isMotionBlurred, in: TimeRange(start: start, end: end))
    }

    // MARK: - Private
}
