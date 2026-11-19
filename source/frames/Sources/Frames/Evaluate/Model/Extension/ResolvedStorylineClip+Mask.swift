//
//  ResolvedStorylineClip+Mask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's masks as its inner item takes them: in its media pixels, carried to the frame by its space's map,
// before its transition motion. A tracked entry's mask keyframes are each brought back through the motion at their own
// media time and interpolated there, and the motion at the media time shown carries them whole.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func masks(at time: Double) -> [ItemMask] {
        guard let mask else { return [] }

        let factor = scale.value(at: time).factor
        guard let track, let clock else {
            let transform = spaceTransform(at: time)
            return mask.value(at: time).map { ItemMask(mask: $0, transform: transform, factor: factor) }
        }

        let transform = track.transform(on: clock, at: time).concatenating(spaceTransform(at: time))
        return track.masks(of: mask, on: clock, at: time).map { ItemMask(mask: $0, transform: transform, factor: factor) }
    }

    // MARK: - Private
}
