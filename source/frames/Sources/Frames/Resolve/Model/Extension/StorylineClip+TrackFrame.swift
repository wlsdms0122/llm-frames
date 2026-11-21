//
//  StorylineClip+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A tracked storyline clip follows its own media, so its crop is a followed value (FRAMES-12 What is tracked), true on
// the track's frame where it is written without keyframes as numbers or as the target found there.
extension StorylineClip {
    // MARK: - Property
    var isCropOnTrackFrame: Bool {
        guard let track, case let .value(crop) = crop else { return false }

        return track.isOnTrackFrame(.crop, isFoundByText: crop.isFoundByText)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
