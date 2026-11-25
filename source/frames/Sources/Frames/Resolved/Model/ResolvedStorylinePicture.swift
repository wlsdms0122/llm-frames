//
//  ResolvedStorylinePicture.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// How a storyline entry's picture is placed and drawn. `placement` places the box the crop fills, by its position,
// anchor, scale and rotation or by a corner pin. `crop` is every crop conformed to the frame, the whole picture when
// none was written, with keyframes in sequence time. `mask` is its masks in the media pixels of its media, nil for
// none, a keyframe's where it lies at its own time when tracked, `trackMatte` its track matte, nil for none, and
// `track` its track data, nil for none. `opacity` is keyframes in sequence time, `blend` how its storyline picture is
// drawn over what lies below, and `filter`, `radius`, `border` and `shadow` how its box is drawn.
struct ResolvedStorylinePicture: Equatable, Sendable {
    // MARK: - Property
    let placement: ResolvedStorylinePlacement
    let crop: FollowedValue<Crop>
    let mask: [ResolvedMask]?
    let trackMatte: TrackMatte?
    let track: ResolvedTrack?
    let filter: TimedValue
    let opacity: [Keyframe<Double>]
    let blend: String
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        placement: ResolvedStorylinePlacement,
        crop: FollowedValue<Crop>,
        mask: [ResolvedMask]?,
        trackMatte: TrackMatte?,
        track: ResolvedTrack?,
        filter: TimedValue,
        opacity: [Keyframe<Double>],
        blend: String,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue
    ) {
        self.placement = placement
        self.crop = crop
        self.mask = mask
        self.trackMatte = trackMatte
        self.track = track
        self.filter = filter
        self.opacity = opacity
        self.blend = blend
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}
