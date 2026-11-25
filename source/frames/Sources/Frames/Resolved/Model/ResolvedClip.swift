//
//  ResolvedClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A clips entry: a title, shape, adjustment or media clip, its content with how its picture composites, or a null.
// `start` and `end` are its visible window, already narrowed. `storyline` is the index of the storyline entry a
// connected clip belongs to, nil for a sequence clip, and `parent` the id of the clip whose space it is placed in, nil
// for an unparented clip. `placement` places it in that space, and a shape or a null placed by its geometry carries its
// placement in its content. `track` is its track, nil for none, and `isMotionBlurred` its `motionBlur`. Keyframes are
// in sequence time.
struct ResolvedClip: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let content: ResolvedClipContent
    let start: Double
    let end: Double
    let storyline: Int?
    let parent: String?
    let placement: ResolvedPlacement
    let track: ResolvedTrack?
    let isMotionBlurred: Bool
    let animation: ResolvedAnimation

    // The clip's own coordinate space, which its mask is in and which it gives its children.
    var space: OwnSpace {
        OwnSpace(content: content)
    }

    // The media time a timed media clip shows, which a clip tracked in its media follows, nil for any other clip.
    var clock: MediaClock? {
        guard case let .picture(.media(media), _) = content else { return nil }
        return media.clock
    }

    // How its picture is composited, nil for a null, which draws nothing.
    var composite: ResolvedComposite? {
        guard case let .picture(_, composite) = content else { return nil }
        return composite
    }

    // Its box, nil under a corner pin, for a shape or a null placed by its geometry and for an adjustment without one.
    var box: ResolvedBox? {
        switch placement {
        case let .transform(transform):
            transform.box

        case .cornerPin:
            nil

        case let .box(box):
            box
        }
    }

    // Its corner pin, nil for a clip placed by a transform or by its box alone.
    var cornerPin: ResolvedCornerPin? {
        guard case let .cornerPin(cornerPin) = placement else { return nil }
        return cornerPin
    }

    // Its scale keyframes, nil under a corner pin and for an adjustment, which are not scaled.
    var scale: [Keyframe<Scale>]? {
        guard case let .transform(transform) = placement else { return nil }
        return transform.scale
    }

    // Its rotation keyframes, nil under a corner pin and for an adjustment, which are not rotated.
    var rotation: [Keyframe<Double>]? {
        guard case let .transform(transform) = placement else { return nil }
        return transform.rotation
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
        placement: ResolvedPlacement,
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
        self.placement = placement
        self.track = track
        self.isMotionBlurred = isMotionBlurred
        self.animation = animation
    }

    // MARK: - Public
    // MARK: - Private
}
