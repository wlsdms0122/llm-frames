//
//  ResolvedStorylineClip+Mask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's masks at a sequence time as its inner item takes them, empty for none. They are in its media
// pixels and carried to the frame by its space's map, before its transition motion, which the outer item carries
// (FRAMES-9, FRAMES-20). A tracked entry's masks are where they are at each keyframe's own time: each keyframe is
// brought back through the motion at its media time, they are interpolated there, and the motion at the media time
// shown carries them whole. The feather scales with the entry's own scale.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func masks(at time: Double) -> [ItemMask] {
        guard let mask else { return [] }

        let scale = scale.value(at: time)
        guard let track else {
            let transform = spaceTransform(at: time)
            return mask.value(at: time).map { ItemMask(mask: $0, transform: transform, scale: scale) }
        }

        let transform = track.transform(on: self, at: time).concatenating(spaceTransform(at: time))
        return track.masks(of: mask, on: self, at: time).map { ItemMask(mask: $0, transform: transform, scale: scale) }
    }

    // MARK: - Private
}
