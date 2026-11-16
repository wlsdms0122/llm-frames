//
//  ResolvedStorylineClip+Crop.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry's conformed crop at a sequence time, in the media pixels of its picture, interpolated as a `Crop`.
// A tracked crop is where it is at each keyframe's own time: each keyframe is brought back through the motion at its
// media time, they are interpolated there, and the result is carried by the motion at the media time shown. A band
// crop takes only the vertical move of the motion, so it keeps its ratio.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func crop(at time: Double) -> Rectangle {
        guard let track else { return value(of: crop, at: time) }

        let keyframes = crop.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Crop(track.bringBack(crop: keyframe.value.rectangle, fromMediaTime: mediaTime(at: keyframe.at))),
                ease: keyframe.ease
            )
        }

        return track.carry(crop: value(of: keyframes, at: time), toMediaTime: mediaTime(at: time))
    }

    // MARK: - Private
    private func value(
        of keyframes: [Keyframe<Crop>],
        at time: Double
    ) -> Rectangle {
        // An entry has at least one crop, the whole picture when none was written, so the keyframes always give one.
        (KeyframeTrack(keyframes: keyframes).value(at: time) ?? keyframes[0].value).rectangle
    }
}
