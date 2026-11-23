//
//  ClipPlan+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The values a tracked clip's track carries, as its placement decides them (FRAMES-12 What is tracked), the clock each
// of its values is searched on, and those followed values it writes without keyframes that are true on the track's
// frame, which the resolved document writes as values. Which of a mask's or a path's leaves are written without
// keyframes, and which of them a text form found, is decided where its masks are found and where its vertices are
// brought into its parent's space, so a followed mask and a path's `points` are taken whole here.
extension ClipPlan {
    // MARK: - Property
    var followedKeys: Set<FollowedKey> {
        if isPinned {
            return [.cornerPin]
        }
        if kind == .media(.video) {
            return [.crop, .mask]
        }

        return space == .parent ? [.area, .points, .position, .mask] : [.area, .points, .position]
    }

    // MARK: - Initializer
    // MARK: - Public
    // The clock a value of the clip under `value` is searched on, `clock` being the one of its instant: the track's
    // frame for a followed value its track searches there, and `clock` for every other.
    func clock(
        of value: FollowedKey,
        on clock: PictureClock,
        track: TrackTarget?
    ) -> PictureClock {
        guard followedKeys.contains(value), let track else { return clock }

        return track.clock(of: value, on: clock)
    }

    func onTrackFrame(of written: Clip) -> Set<FollowedKey> {
        guard let target = written.track else { return [] }

        return followedKeys.filter { value in
            isOnTrackFrame(value, of: written, target: target)
        }
    }

    // MARK: - Private
    private func isOnTrackFrame(
        _ value: FollowedKey,
        of written: Clip,
        target: TrackTarget
    ) -> Bool {
        let isFoundByText: Bool
        switch value {
        case .area:
            guard case let .value(area) = written.area else { return false }

            isFoundByText = area.isFoundByText

        case .points:
            guard case let .shape(shape) = written.content else { return false }

            return shape.points != nil

        case .position:
            guard case let .value(position) = written.position else { return false }

            isFoundByText = position.isFoundByText

        case .cornerPin:
            guard case let .value(points) = written.cornerPin else { return false }

            isFoundByText = points.contains(where: \.isFoundByText)

        case .crop:
            guard case let .value(crop) = written.crop else { return false }

            isFoundByText = crop.isFoundByText

        case .mask:
            return written.mask != nil
        }

        return target.isOnTrackFrame(value, isFoundByText: isFoundByText)
    }
}
