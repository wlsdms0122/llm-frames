//
//  StorylineClip+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A tracked storyline clip follows its own media, so its crop is a followed value (FRAMES-12 What is tracked), true on
// the track's frame where it is written without keyframes.
extension StorylineClip {
    // MARK: - Property
    var isCropOnTrackFrame: Bool {
        guard track != nil, case .value = crop else { return false }

        return true
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
