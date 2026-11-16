//
//  ResolvedMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Media with what time knows of it. `reference` is the media as the document wrote it (`shorts/leak.mov`), the same on
// every machine, and nil for media written in place. `frames` is the first and last media time a picture exists at,
// nil for a still, which simply goes on, and for sound. `hasSound` says whether it plays sound: a file with a sound
// track, or a nested sequence that holds one.
struct ResolvedMedia: Equatable, Sendable {
    // MARK: - Property
    let kind: MediaKind
    let reference: String?
    let source: ResolvedMediaSource
    let duration: Double
    let frames: ClosedRange<Double>?
    let hasSound: Bool

    // MARK: - Initializer
    init(
        kind: MediaKind,
        reference: String?,
        source: ResolvedMediaSource,
        duration: Double,
        frames: ClosedRange<Double>? = nil,
        hasSound: Bool = false
    ) {
        self.kind = kind
        self.reference = reference
        self.source = source
        self.duration = duration
        self.frames = frames
        self.hasSound = hasSound
    }

    // MARK: - Public
    func clamped(_ time: Double) -> Double {
        guard let frames else { return time }

        return min(max(time, frames.lowerBound), frames.upperBound)
    }

    // MARK: - Private
}
