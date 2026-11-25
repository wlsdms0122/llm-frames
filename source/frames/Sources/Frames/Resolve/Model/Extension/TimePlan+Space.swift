//
//  TimePlan+Space.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The spaces a planned clip's coordinates are written in (FRAMES-10), which resolve finds geometry in and `timeline`
// reports.
extension TimePlan {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The space a parent gives its child's `position`, `area`, `points` and `cornerPin`. The chain is walked up past
    // every shape placed by its geometry, every adjustment and every clip with a corner pin, which give their children
    // the space they are written in themselves, and ParentFinder has ruled out a cycle, so it ends. A solid and a
    // storyline clip with a corner pin give output pixels.
    func space(givenBy parent: ClipParent?) -> CoordinateSpace {
        var parent = parent
        while case let .clip(index, _) = parent, clips[index].space == .parent || clips[index].isPinned {
            parent = clips[index].parent
        }

        switch parent {
        case .none:
            return .output

        case let .storyline(index, _):
            let clip = storyline[index]
            let isOutput = clip.source.media == nil || sequence.storyline[index].cornerPin != nil
            return isOutput ? .output : .media(clip.place.description)

        case let .clip(index, _):
            let clip = clips[index]
            return clip.space == .box ? .box(clip.place.description) : .media(clip.place.description)
        }
    }

    // The space a clip's `crop` and `mask` are written in: its own media or box, and for a shape placed by its
    // geometry or an adjustment the space its parent gives.
    func ownSpace(of clip: ClipPlan) -> CoordinateSpace {
        switch clip.space {
        case .media:
            .media(clip.place.description)

        case .box:
            .box(clip.place.description)

        case .parent:
            space(givenBy: clip.parent)
        }
    }

    // A storyline clip's own space is its media, and a solid's output pixels.
    func ownSpace(of clip: StorylinePlan) -> CoordinateSpace {
        clip.source.media == nil ? .output : .media(clip.place.description)
    }

    // MARK: - Private
}
