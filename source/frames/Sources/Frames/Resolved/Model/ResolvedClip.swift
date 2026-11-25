//
//  ResolvedClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A clips entry: a title, shape or media clip, an adjustment, or a null, its content with how it is placed.
// `start` and `end` are its visible window, already narrowed. `storyline` is the index of the storyline entry a
// connected clip belongs to, nil for a sequence clip, and `parent` the id of the clip whose space it is placed in, nil
// for an unparented clip. Its content carries how it is placed in that space, and a shape or a null placed by its
// geometry carries where it goes in its geometry. `track` is its track, nil for none, and `isMotionBlurred` its
// `motionBlur`. Keyframes are in sequence time.
struct ResolvedClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let content: ResolvedClipContent
    let start: Double
    let end: Double
    let storyline: Int?
    let parent: String?
    let track: ResolvedTrack?
    let isMotionBlurred: Bool
    let animation: ResolvedAnimation

    // The clip's own coordinate space, which its mask is in and which it gives its children.
    var space: OwnSpace {
        OwnSpace(content: content)
    }

    // The media time a timed media clip shows, which a clip tracked in its media follows, nil for any other clip.
    var clock: MediaClock? {
        guard case let .picture(.media(media), _, _) = content else { return nil }
        return media.clock
    }

    // How a picture or an adjustment composites, its masks and track matte with it, nil for a null, which draws nothing.
    var composite: ResolvedComposite? {
        switch content {
        case let .picture(_, _, composite), let .adjustment(_, _, composite):
            composite

        case .null:
            nil
        }
    }

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        content: ResolvedClipContent,
        start: Double,
        end: Double,
        storyline: Int?,
        parent: String?,
        track: ResolvedTrack?,
        isMotionBlurred: Bool = false,
        animation: ResolvedAnimation
    ) {
        self.place = place
        self.id = id
        self.content = content
        self.start = start
        self.end = end
        self.storyline = storyline
        self.parent = parent
        self.track = track
        self.isMotionBlurred = isMotionBlurred
        self.animation = animation
    }

    // MARK: - Public
    // The same clip with `animation` in place of its own.
    func with(animation: ResolvedAnimation) -> ResolvedClip {
        ResolvedClip(
            place: place,
            id: id,
            content: content,
            start: start,
            end: end,
            storyline: storyline,
            parent: parent,
            track: track,
            isMotionBlurred: isMotionBlurred,
            animation: animation
        )
    }

    // MARK: - Private
}
