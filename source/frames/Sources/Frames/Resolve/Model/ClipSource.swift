//
//  ClipSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a connected or sequence clip shows or plays: its kind, its media (nil for a title, shape or adjustment), and
// for timed media how it plays: its played range, with the start of its window left at 0 until the window is known,
// or its `timeRemap` keyframes on the clip's clock.
struct ClipSource: Equatable, Sendable {
    // MARK: - Property
    let kind: ClipKind
    let media: MediaPlan?
    let played: PlayedRange?
    let timeRemap: PropertyValue<Double>?

    // MARK: - Initializer
    init(
        kind: ClipKind,
        media: MediaPlan? = nil,
        played: PlayedRange? = nil,
        timeRemap: PropertyValue<Double>? = nil
    ) {
        self.kind = kind
        self.media = media
        self.played = played
        self.timeRemap = timeRemap
    }

    // MARK: - Public
    // MARK: - Private
}
