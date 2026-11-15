//
//  StorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip as written. `media` is nil for a solid. Whether media is timed or still is known once it is probed.
// `crop` and `track` are as written, and a crop's keyframes are on the clip's own clock.
struct StorylineClip: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let media: ClipMedia?
    let duration: Double?
    let transition: TransitionChoice?
    let keyframes: [KeyframeInstant]
    let crop: PropertyValue<CropForm>?
    let track: TrackTarget?
    let connected: [Clip]

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        media: ClipMedia?,
        duration: Double?,
        transition: TransitionChoice?,
        keyframes: [KeyframeInstant],
        crop: PropertyValue<CropForm>? = nil,
        track: TrackTarget? = nil,
        connected: [Clip]
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.duration = duration
        self.transition = transition
        self.keyframes = keyframes
        self.crop = crop
        self.track = track
        self.connected = connected
    }

    // MARK: - Public
    // MARK: - Private
}
