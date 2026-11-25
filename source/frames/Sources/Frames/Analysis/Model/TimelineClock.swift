//
//  TimelineClock.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The map of the times a clip writes, its `at` and its keyframes' `at`, to sequence time (FRAMES-8): a time c lies at
// `origin + c / speed`. `clip` is the place of the clip whose clip time they are on, the clip itself for a storyline
// clip and its storyline clip for a connected clip, nil where they are on sequence time, for a sequence clip and for
// every clip of a resolved document, which writes every instant in sequence time.
struct TimelineClock: Equatable, Sendable {
    // MARK: - Property
    static let sequence = TimelineClock(clip: nil, origin: 0, speed: 1)

    let clip: String?
    let origin: Double
    let speed: Double

    // MARK: - Initializer
    init(
        clip: String?,
        origin: Double,
        speed: Double
    ) {
        self.clip = clip
        self.origin = origin
        self.speed = speed
    }

    init(
        clip: String?,
        map: TimeMap
    ) {
        self.init(clip: clip, origin: map.sequenceTime(ofClipTime: 0), speed: map.speed)
    }

    // MARK: - Public
    // MARK: - Private
}
