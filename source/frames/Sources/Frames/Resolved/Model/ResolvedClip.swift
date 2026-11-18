//
//  ResolvedClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A clips entry: a title, shape, adjustment or media clip. `start` and `end` are its visible window, already narrowed.
// `storyline` is the index of the storyline entry a connected clip belongs to, nil for a sequence clip, and `parent`
// the id of the clip whose space it is placed in, nil for an unparented clip. `box` places a title, a media clip or a
// shape given by `width` and `height`, and a shape placed by its geometry carries it in its content. `crop` is a media
// clip's every crop conformed to its box. `mask` is the clip's masks in its own coordinate space, nil for none, a
// keyframe's where it lies at its own time when tracked. Keyframes are in sequence time. `scale`,
// `rotation` and `blend` belong to anything but an adjustment, and each is nil where its entry has no such key.
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
    let crop: [Keyframe<Crop>]?
    let mask: [Keyframe<[ResolvedMask]>]?
    let track: ResolvedTrack?
    let opacity: [Keyframe<Double>]
    let scale: [Keyframe<Double>]?
    let rotation: [Keyframe<Double>]?
    let blend: String?
    let animation: ResolvedAnimation

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
        crop: [Keyframe<Crop>]?,
        mask: [Keyframe<[ResolvedMask]>]?,
        track: ResolvedTrack?,
        opacity: [Keyframe<Double>],
        scale: [Keyframe<Double>]?,
        rotation: [Keyframe<Double>]?,
        blend: String?,
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
        self.crop = crop
        self.mask = mask
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
