//
//  ResolvedClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A clips entry: a title, shape, adjustment or media clip. `start` and `end` are its visible window, already narrowed.
// `parent` is the index of the storyline entry a parented clip is composited with. `area` and `box` place it, each nil
// where the other does. `crop` is a media clip's every crop conformed to its box. Keyframes are in sequence time.
// `scale` and `rotation` belong to a title or media clip and `blend` to anything but an adjustment, and each is nil
// where its entry has no such key.
struct ResolvedClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let content: ResolvedClipContent
    let start: Double
    let end: Double
    let lane: Int?
    let parent: Int?
    let area: [Keyframe<Rectangle>]?
    let box: ResolvedBox?
    let crop: [Keyframe<Crop>]?
    let track: ResolvedTrack?
    let label: ResolvedLabel?
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
        parent: Int?,
        area: [Keyframe<Rectangle>]?,
        box: ResolvedBox?,
        crop: [Keyframe<Crop>]?,
        track: ResolvedTrack?,
        label: ResolvedLabel?,
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
        self.parent = parent
        self.area = area
        self.box = box
        self.crop = crop
        self.track = track
        self.label = label
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.animation = animation
    }

    // MARK: - Public
    // MARK: - Private
}
