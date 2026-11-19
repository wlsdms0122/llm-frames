//
//  ResolvedStorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry. `place` is its place in the document as written, and `media` is nil for a solid, which carries its
// colour as `solid`. `in` and `out` are its clip time, `speed` as written, `timeRemap` keyframes in sequence time whose
// values are media seconds (nil for none, when clip time is media time), and `start` and `end` its edit range in
// sequence time.
// `crop` is every crop conformed to the frame, the whole picture when none was written, with keyframes in sequence
// time. `mask` is its masks in the media pixels of its media, nil for none, a keyframe's where it lies at its own
// time when tracked, and `trackMatte` its track matte, nil for none. `box` is the frame the crop fills, placed by its
// position and anchor, and `opacity`, `scale` and `rotation` are keyframes in sequence time. `blend` is how its
// storyline picture is drawn over what lies below, and `radius`, `border` and `shadow` how its box is drawn. A solid
// keeps their plain values.
struct ResolvedStorylineClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let media: ResolvedMediaContent?
    let solid: Color?
    let `in`: Double
    let out: Double
    let speed: Double
    let timeRemap: [Keyframe<Double>]?
    let start: Double
    let end: Double
    let crop: [Keyframe<Crop>]
    let mask: [ResolvedMask]?
    let trackMatte: TrackMatte?
    let track: ResolvedTrack?
    let filter: TimedValue
    let box: ResolvedBox
    let opacity: [Keyframe<Double>]
    let scale: [Keyframe<Double>]
    let rotation: [Keyframe<Double>]
    let blend: String
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue
    let transition: ResolvedTransition?

    // The media time it shows at a sequence time, nil for a solid: `in` at `start`, at `speed`, on the same line in the
    // handles, or its `timeRemap`, held to its media's first and last frame.
    var clock: MediaClock? {
        guard let media else { return nil }

        let line = TimeMap(origin: start, in: `in`, speed: speed)
        return MediaClock(line: line, timeRemap: timeRemap, frames: media.frames)
    }

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        media: ResolvedMediaContent?,
        solid: Color?,
        in: Double,
        out: Double,
        speed: Double,
        timeRemap: [Keyframe<Double>]?,
        start: Double,
        end: Double,
        crop: [Keyframe<Crop>],
        mask: [ResolvedMask]?,
        trackMatte: TrackMatte?,
        track: ResolvedTrack?,
        filter: TimedValue,
        box: ResolvedBox,
        opacity: [Keyframe<Double>],
        scale: [Keyframe<Double>],
        rotation: [Keyframe<Double>],
        blend: String,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue,
        transition: ResolvedTransition?
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.solid = solid
        self.in = `in`
        self.out = out
        self.speed = speed
        self.timeRemap = timeRemap
        self.start = start
        self.end = end
        self.crop = crop
        self.mask = mask
        self.trackMatte = trackMatte
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
    func mediaTime(at time: Double) -> Double {
        clock?.mediaTime(atSequenceTime: time) ?? 0
    }

    // MARK: - Private
}
