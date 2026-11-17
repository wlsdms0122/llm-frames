//
//  ResolvedStorylineClip+Crop.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry's conformed crop at a sequence time, in the media pixels of its picture, interpolated as a `Crop`.
// A tracked crop is where it is at each keyframe's own time: each keyframe is brought back through the motion at its
// media time, they are interpolated there, and the result is carried by the motion at the media time shown.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func crop(at time: Double) -> Rectangle {
        guard let track else { return crop.value(at: time).rectangle }

        let keyframes = crop.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Crop(track.bringBack(keyframe.value.rectangle, fromMediaTime: mediaTime(at: keyframe.at))),
                ease: keyframe.ease
            )
        }

        return track.carry(keyframes.value(at: time).rectangle, toMediaTime: mediaTime(at: time))
    }

    // MARK: - Private
}
