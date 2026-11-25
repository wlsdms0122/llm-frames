//
//  ResolvedStorylineClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry. `place` is its place in the document as written, and `content` the solid or the media it shows,
// media with how its picture is placed and drawn. `in` and `out` are its clip time, `speed` as written, and `start`
// and `end` its edit range in sequence time. `isMotionBlurred` is its `motionBlur`.
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
    let isMotionBlurred: Bool
    let transition: ResolvedTransition?

    // How its picture is placed and drawn: its media's, or a solid's, which is its frame's.
    var picture: ResolvedStorylinePicture {
        switch content {
        case let .solid(solid):
            solid.picture(at: start)

        case let .media(media):
            media.picture
        }
    }

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
        isMotionBlurred: Bool = false,
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
        self.isMotionBlurred = isMotionBlurred
        self.transition = transition
    }

    // MARK: - Public
    func mediaTime(at time: Double) -> Double {
        clock?.mediaTime(atSequenceTime: time) ?? 0
    }

    // The same entry with `transition` in place of its own.
    func with(transition: ResolvedTransition?) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: place,
            id: id,
            content: content,
            in: self.in,
            out: out,
            speed: speed,
            start: start,
            end: end,
            isMotionBlurred: isMotionBlurred,
            transition: transition
        )
    }

    // MARK: - Private
}
