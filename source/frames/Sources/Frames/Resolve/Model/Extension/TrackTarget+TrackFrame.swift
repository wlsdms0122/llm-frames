//
//  TrackTarget+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Which followed values a track searches on the track's frame, and on which clock (FRAMES-12 The track). The target is
// found on the track's frame, and under `true` and `{"time": t}` the target is the clip's own geometry, its area, corner
// pin, crop or mask, so a text form in it is searched there; any other text form is searched at the clip's instant, so
// it is where it lies on the frame shown there. A followed value written without keyframes is true on the track's frame
// where it is written as numbers or searched there.
extension TrackTarget {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func isSearchedOnTrackFrame(_ value: FollowedKey) -> Bool {
        guard isOwn else { return false }

        switch value {
        case .area, .cornerPin, .crop, .mask:
            return true

        case .points, .position:
            return false
        }
    }

    func isOnTrackFrame(
        _ value: FollowedKey,
        isFoundByText: Bool
    ) -> Bool {
        !isFoundByText || isSearchedOnTrackFrame(value)
    }

    // The clock a followed value is searched on, `clock` being the one of the clip's instant: under `{"time": t}` the
    // frame t names in the media followed for a value searched on the track's frame. A picture that holds still is not
    // the media followed.
    func clock(
        of value: FollowedKey,
        on clock: PictureClock
    ) -> PictureClock {
        guard isSearchedOnTrackFrame(value), let time, clock != .still else { return clock }

        return .frame(time)
    }

    // MARK: - Private
}
