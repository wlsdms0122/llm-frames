//
//  ResolvedClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A clips entry: a title, shape, adjustment or media clip. `start` and `end` are its visible window, already narrowed.
// `storyline` is the index of the storyline entry a connected clip belongs to, nil for a sequence clip, and `parent`
// the id of the clip whose space it is placed in, nil for an unparented clip. `box` places a title, a media clip or a
// shape given by `width` and `height`, `cornerPin` places one with a corner pin in place of `box`, and a shape placed
// by its geometry carries its placement in its content. `crop` is a media
// clip's every crop conformed to its box. `mask` is the clip's masks in its own coordinate space, nil for none, a
// keyframe's where it lies at its own time when tracked, and `trackMatte` its track matte, nil for none. Keyframes are
// in sequence time. `scale` and `rotation` belong to anything but an adjustment, whose entry has no such key, and are
// nil for an adjustment and for a clip with a corner pin, whose entry writes them as null.
struct ResolvedClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let content: ResolvedClipContent
    let start: Double
    let end: Double
    let lane: Int?
    let storyline: Int?
    let parent: String?
    let box: ResolvedBox?
    let cornerPin: ResolvedCornerPin?
    let crop: [Keyframe<Crop>]?
    let mask: [ResolvedMask]?
    let trackMatte: TrackMatte?
    let track: ResolvedTrack?
    let opacity: [Keyframe<Double>]
    let scale: [Keyframe<Scale>]?
    let rotation: [Keyframe<Double>]?
    let blend: String
    let animation: ResolvedAnimation
    // The clip's own coordinate space, which its mask is in and which it gives its children.
    var space: OwnSpace {
        OwnSpace(content: content)
    }

    // The media time a timed media clip shows, which a clip tracked in its media follows, nil for any other clip.
    var clock: MediaClock? {
        guard case let .media(media) = content else { return nil }

        return media.clock
    }

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        content: ResolvedClipContent,
        start: Double,
        end: Double,
        lane: Int?,
        storyline: Int?,
        parent: String?,
        box: ResolvedBox?,
        cornerPin: ResolvedCornerPin? = nil,
        crop: [Keyframe<Crop>]?,
        mask: [ResolvedMask]?,
        trackMatte: TrackMatte?,
        track: ResolvedTrack?,
        opacity: [Keyframe<Double>],
        scale: [Keyframe<Scale>]?,
        rotation: [Keyframe<Double>]?,
        blend: String,
        animation: ResolvedAnimation
    ) {
        self.place = place
        self.id = id
        self.content = content
        self.start = start
        self.end = end
        self.lane = lane
        self.storyline = storyline
        self.parent = parent
        self.box = box
        self.cornerPin = cornerPin
        self.crop = crop
        self.mask = mask
        self.trackMatte = trackMatte
        self.track = track
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.animation = animation
    }

    // MARK: - Public
    // MARK: - Private
}
