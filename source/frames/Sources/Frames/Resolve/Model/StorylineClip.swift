//
//  StorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip as written, its keyframes on the clip's own clock. `media` is nil for a solid, and whether media is
// timed or still is known once it is probed. `position`, `scale`, `rotation`, `opacity`, `blend`, `radius`, `border`
// and `shadow` are its transform and how its box is drawn, as on a media clip.
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
    let mask: PropertyValue<[ClipMask]>?
    let trackMatte: TrackMatte?
    let track: TrackTarget?
    let filter: FilterChoice?
    let anchor: String?
    let position: PropertyValue<PositionForm>?
    let scale: PropertyValue<Double>?
    let rotation: PropertyValue<Double>?
    let opacity: PropertyValue<Double>?
    let blend: String?
    let radius: LookProperty?
    let border: LookProperty?
    let shadow: LookProperty?
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
        mask: PropertyValue<[ClipMask]>? = nil,
        trackMatte: TrackMatte? = nil,
        track: TrackTarget? = nil,
        filter: FilterChoice? = nil,
        anchor: String? = nil,
        position: PropertyValue<PositionForm>? = nil,
        scale: PropertyValue<Double>? = nil,
        rotation: PropertyValue<Double>? = nil,
        opacity: PropertyValue<Double>? = nil,
        blend: String? = nil,
        radius: LookProperty? = nil,
        border: LookProperty? = nil,
        shadow: LookProperty? = nil,
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
        self.mask = mask
        self.trackMatte = trackMatte
        self.track = track
        self.filter = filter
        self.anchor = anchor
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.blend = blend
        self.radius = radius
        self.border = border
        self.shadow = shadow
        self.connected = connected
    }

    // MARK: - Public
    // MARK: - Private
}
