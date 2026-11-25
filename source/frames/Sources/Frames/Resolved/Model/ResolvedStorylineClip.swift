//
//  ResolvedStorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry. `place` is its place in the document as written, and `content` the solid's colour or the media
// it shows. `in` and `out` are its clip time, `speed` as written, and `start` and `end` its edit range in sequence
// time. `crop` is every crop conformed to the frame, the whole picture when none was written, with keyframes
// in sequence time. `mask` is its masks in the media pixels of its media, nil for none, a keyframe's where it lies at
// its own time when tracked, and `trackMatte` its track matte, nil for none. `placement` places the box the crop
// fills, by its position, anchor, scale and rotation or by a corner pin, and `opacity` is keyframes in sequence time.
// `blend` is how its storyline picture is drawn over what lies below, `isMotionBlurred` its `motionBlur`, and
// `radius`, `border` and `shadow` how its box is drawn. A solid keeps their plain values, and is placed by its box.
struct ResolvedStorylineClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let content: ResolvedStorylineContent
    let `in`: Double
    let out: Double
    let speed: Double
    let start: Double
    let end: Double
    let crop: FollowedValue<Crop>
    let mask: [ResolvedMask]?
    let trackMatte: TrackMatte?
    let track: ResolvedTrack?
    let filter: TimedValue
    let placement: ResolvedStorylinePlacement
    let opacity: [Keyframe<Double>]
    let blend: String
    let isMotionBlurred: Bool
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue
    let transition: ResolvedTransition?

    // Its clip time at a sequence time: `in` at `start`, at `speed`, on the same line in the handles.
    var map: TimeMap {
        TimeMap(origin: start, in: `in`, speed: speed)
    }

    // The media time it shows at a sequence time, nil for a solid: its line, or its `timeRemap`, held to its media's
    // first and last frame.
    var clock: MediaClock? {
        guard case let .media(media) = content else { return nil }

        return MediaClock(line: map, timeRemap: media.timeRemap, frames: media.media.frames)
    }

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        content: ResolvedStorylineContent,
        in: Double,
        out: Double,
        speed: Double,
        start: Double,
        end: Double,
        crop: FollowedValue<Crop>,
        mask: [ResolvedMask]?,
        trackMatte: TrackMatte?,
        track: ResolvedTrack?,
        filter: TimedValue,
        placement: ResolvedStorylinePlacement,
        opacity: [Keyframe<Double>],
        blend: String,
        isMotionBlurred: Bool = false,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue,
        transition: ResolvedTransition?
    ) {
        self.place = place
        self.id = id
        self.content = content
        self.in = `in`
        self.out = out
        self.speed = speed
        self.start = start
        self.end = end
        self.crop = crop
        self.mask = mask
        self.trackMatte = trackMatte
        self.track = track
        self.filter = filter
        self.placement = placement
        self.opacity = opacity
        self.blend = blend
        self.isMotionBlurred = isMotionBlurred
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
