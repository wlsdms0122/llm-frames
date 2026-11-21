//
//  ResolvedStorylineClip+Mask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's masks as its inner item takes them: in its media pixels, carried to the frame by its space's map,
// before its transition motion. Each keyframe of a tracked entry's mask geometry is brought back through the motion at
// its own media time and interpolated there, and the motion at the media time shown carries the masks whole.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func masks(at time: SampleTime) -> [ItemMask] {
        guard let mask else { return [] }

        let factor = scale.value(at: time).factor
        guard let track, let clock else {
            let transform = spaceTransform(at: time)
            return mask.map { ItemMask(mask: $0.sampled(at: time), transform: transform, factor: factor) }
        }

        let transform = track.transform(on: clock, at: time.instant).concatenating(spaceTransform(at: time))
        return track.masks(of: mask, on: clock, at: time).map { ItemMask(mask: $0, transform: transform, factor: factor) }
    }

    // MARK: - Private
}
