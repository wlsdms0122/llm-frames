//
//  ResolvedStorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry. `place` is its place in the document as written, and `media` is nil for a solid, which carries its
// colour as `solid`. `in`, `out` and `speed` are media time, and `start` and `end` its edit range in sequence time.
// `crop` is every crop conformed to the frame, the whole picture when none was written, with keyframes in sequence
// time.
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
        self.transition = transition
    }

    // MARK: - Public
    // MARK: - Private
}
