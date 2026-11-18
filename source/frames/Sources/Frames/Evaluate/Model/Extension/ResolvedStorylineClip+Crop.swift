//
//  ResolvedStorylineClip+Crop.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry's conformed crop at a sequence time, in the media pixels of its picture, interpolated as a `Crop`.
// A tracked crop is where it is at each keyframe's own time: each keyframe is brought back through the motion at its
// media time, they are interpolated there, and the result is carried by the motion at the media time shown. A crop is
// an upright region of its media, so it takes the motion's move and scale and not its rotation (FRAMES-12).
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func crop(at time: Double) -> Rectangle {
        guard let track else { return crop.value(at: time).rectangle }

        let keyframes = crop.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Crop(motion(at: keyframe.at, of: track).bringBack(keyframe.value.rectangle)),
                ease: keyframe.ease
            )
        }

        return motion(at: time, of: track).carry(keyframes.value(at: time).rectangle)
    }

    // MARK: - Private
    private func motion(
        at time: Double,
        of track: ResolvedTrack
    ) -> TrackMotion {
        track.motion(atMediaTime: mediaTime(at: time)).upright
    }
}
