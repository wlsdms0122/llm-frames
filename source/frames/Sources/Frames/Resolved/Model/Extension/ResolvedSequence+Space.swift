//
//  ResolvedSequence+Space.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The spaces a resolved clip's coordinates are written in (FRAMES-10), by the rules the plan finds them by, with
// parents named by id.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The space the parent with the id gives its child, output pixels for an unparented clip. The chain is walked up past every
    // shape placed by its geometry, every adjustment and every clip with a corner pin, and a resolved document holds
    // no cycle, so it ends. A solid and a storyline clip with a corner pin give output pixels.
    func space(givenBy parent: String?) -> CoordinateSpace {
        var parent = parent
        while let id = parent, let clip = clips.first(where: { $0.id == id }), clip.space == .parent || clip.cornerPin != nil {
            parent = clip.parent
        }
        guard let id = parent else { return .output }

        if let clip = clips.first(where: { $0.id == id }) {
            return clip.space == .box ? .box(clip.place) : .media(clip.place)
        }
        guard
            let clip = storyline.first(where: { $0.id == id }),
            case .media = clip.content,
            case .transform = clip.placement
        else {
            return .output
        }

        return .media(clip.place)
    }

    // The space a clip's `crop` and `mask` are written in: its own media, a title's text box or its own box, and for a
    // shape placed by its geometry or an adjustment the space its parent gives.
    func ownSpace(of clip: ResolvedClip) -> CoordinateSpace {
        switch clip.space {
        case .media:
            .media(clip.place)

        case .box:
            if case .picture(.title, _) = clip.content { .text(clip.place) } else { .box(clip.place) }

        case .parent:
            space(givenBy: clip.parent)
        }
    }

    // A storyline clip's own space is its media, and a solid's output pixels.
    func ownSpace(of clip: ResolvedStorylineClip) -> CoordinateSpace {
        switch clip.content {
        case .solid:
            .output

        case .media:
            .media(clip.place)
        }
    }

    // MARK: - Private
}
