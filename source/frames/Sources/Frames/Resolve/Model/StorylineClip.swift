//
//  StorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip as written. `media` is nil for a solid. Whether media is timed or still is known once it is probed.
struct StorylineClip: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let media: ClipMedia?
    let duration: Double?
    let transition: TransitionChoice?
    let keyframes: [KeyframeInstant]
    let connected: [Clip]

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        media: ClipMedia?,
        duration: Double?,
        transition: TransitionChoice?,
        keyframes: [KeyframeInstant],
        connected: [Clip]
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.duration = duration
        self.transition = transition
        self.keyframes = keyframes
        self.connected = connected
    }

    // MARK: - Public
    // MARK: - Private
}
