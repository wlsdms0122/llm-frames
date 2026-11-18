//
//  MediaPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Media with what time knows of it. `reference` is the media as the document wrote it (`shorts/leak.mov`), the same on
// every machine, and nil for media written in place. `frames` is the first and last media time a picture exists at,
// nil for a still, which simply goes on, and for sound. `hasSound` says whether it plays sound: a file with a sound
// track, or a nested sequence that holds one.
struct MediaPlan: Equatable, Sendable {
    // MARK: - Property
    let kind: MediaKind
    let reference: String?
    let source: MediaPlanSource
    let duration: Double
    let hasSound: Bool

    var frames: ClosedRange<Double>? {
        switch source {
        case let .file(file):
            ClosedRange(frameTimes: file.frameTimes)

        case let .sequence(plan):
            ClosedRange(sequenceDuration: plan.duration)
        }
    }

    // MARK: - Initializer
    init(
        kind: MediaKind,
        reference: String?,
        source: MediaPlanSource,
        duration: Double,
        hasSound: Bool = false
    ) {
        self.kind = kind
        self.reference = reference
        self.source = source
        self.duration = duration
        self.hasSound = hasSound
    }

    // MARK: - Public
    // MARK: - Private
}
