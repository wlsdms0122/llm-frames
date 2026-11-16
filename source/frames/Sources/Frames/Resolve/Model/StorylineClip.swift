//
//  StorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip as written. `media` is nil for a solid, and `solid` its colour as written. Whether media is timed
// or still is known once it is probed. `crop` and `track` are as written, and a crop's keyframes are on the clip's own
// clock. `filter` is the filter choice as written.
struct StorylineClip: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let media: ClipMedia?
    let solid: String?
    let duration: Double?
    let transition: TransitionChoice?
    let keyframes: [KeyframeInstant]
    let crop: PropertyValue<CropForm>?
    let track: TrackTarget?
    let filter: JSONValue?
    let connected: [Clip]

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        media: ClipMedia?,
        solid: String? = nil,
        duration: Double?,
        transition: TransitionChoice?,
        keyframes: [KeyframeInstant],
        crop: PropertyValue<CropForm>? = nil,
        track: TrackTarget? = nil,
        filter: JSONValue? = nil,
        connected: [Clip]
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.solid = solid
        self.duration = duration
        self.transition = transition
        self.keyframes = keyframes
        self.crop = crop
        self.track = track
        self.filter = filter
        self.connected = connected
    }

    // MARK: - Public
    // MARK: - Private
}
