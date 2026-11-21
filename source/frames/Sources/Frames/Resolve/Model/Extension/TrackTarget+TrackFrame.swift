//
//  TrackTarget+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Whether a followed value written without keyframes is true on the track's frame (FRAMES-12 The track): written as
// numbers, or found by text as the clip's own geometry, which `true` and `{"time": t}` search on that frame. Any other
// text form is searched at the clip's instant, so it is where it lies on the frame shown there.
extension TrackTarget {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func isOnTrackFrame(
        _ value: FollowedKey,
        isFoundByText: Bool
    ) -> Bool {
        guard isFoundByText else { return true }

        return isOwn && [.area, .cornerPin, .crop, .mask].contains(value)
    }

    // MARK: - Private
}
