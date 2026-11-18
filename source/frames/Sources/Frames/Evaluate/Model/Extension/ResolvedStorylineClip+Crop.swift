//
//  ResolvedStorylineClip+Crop.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline entry's conformed crop at a sequence time, in the media pixels of its picture, interpolated as a `Crop`,
// and followed on its media when tracked.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func crop(at time: Double) -> Rectangle {
        guard let track, let clock else { return crop.value(at: time).rectangle }

        return track.crop(of: crop, on: clock, at: time)
    }

    // MARK: - Private
}
