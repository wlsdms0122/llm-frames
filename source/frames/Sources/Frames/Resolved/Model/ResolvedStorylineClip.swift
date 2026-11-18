//
//  ResolvedStorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry. `place` is its place in the document as written, and `media` is nil for a solid, which carries its
// colour as `solid`. `in`, `out` and `speed` are media time, and `start` and `end` its edit range in sequence time.
// `crop` is every crop conformed to the frame, the whole picture when none was written, with keyframes in sequence
// time. `box` is the frame the crop fills, placed by its position and anchor, and `opacity`, `scale` and `rotation`
// are keyframes in sequence time. `blend` is how its storyline picture is drawn over what lies below, and `radius`,
// `border` and `shadow` how its box is drawn. A solid keeps their plain values.
struct ResolvedStorylineClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let media: ResolvedMediaContent?
    let solid: Color?
    let `in`: Double
    let out: Double
    let speed: Double
    let start: Double
    let end: Double
    let crop: [Keyframe<Crop>]
    let track: ResolvedTrack?
    let filter: [ResolvedFilterOperation]
    let box: ResolvedBox
    let opacity: [Keyframe<Double>]
    let scale: [Keyframe<Double>]
    let rotation: [Keyframe<Double>]
    let blend: String
    let radius: Double
    let border: MediaBorder?
    let shadow: DropShadow?
    let transition: ResolvedTransition?

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        media: ResolvedMediaContent?,
        solid: Color?,
        in: Double,
        out: Double,
        speed: Double,
        start: Double,
        end: Double,
        crop: [Keyframe<Crop>],
        track: ResolvedTrack?,
        filter: [ResolvedFilterOperation],
        box: ResolvedBox,
        opacity: [Keyframe<Double>],
        scale: [Keyframe<Double>],
        rotation: [Keyframe<Double>],
        blend: String,
        radius: Double,
        border: MediaBorder?,
        shadow: DropShadow?,
        transition: ResolvedTransition?
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.solid = solid
        self.in = `in`
        self.out = out
        self.speed = speed
        self.start = start
        self.end = end
        self.crop = crop
        self.track = track
        self.filter = filter
        self.box = box
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.radius = radius
        self.border = border
        self.shadow = shadow
        self.transition = transition
    }

    // MARK: - Public
    // MARK: - Private
}
