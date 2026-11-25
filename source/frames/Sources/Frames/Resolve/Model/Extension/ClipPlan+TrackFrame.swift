//
//  ClipPlan+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The values a tracked clip's track carries, as its placement decides them (FRAMES-12 What is tracked), and those
// followed values it writes without keyframes, which are true on the track's frame and which the resolved document
// writes as values. Which of a mask's or a path's leaves are written without keyframes is decided where its masks and
// vertices are planned, so a followed mask and a path's `points` are taken whole here.
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
    func onTrackFrame(of written: Clip) -> Set<FollowedKey> {
        guard written.track != nil else { return [] }

        return followedKeys.filter { value in
            isOnTrackFrame(value, of: written)
        }
    }

    // MARK: - Private
    private func isOnTrackFrame(
        _ value: FollowedKey,
        of written: Clip
    ) -> Bool {
        switch value {
        case .area:
            guard case .value = written.area else { return false }

            return true

        case .points:
            guard case let .shape(shape) = written.content else { return false }

            return shape.points != nil

        case .position:
            guard case .value = written.position else { return false }

            return true

        case .cornerPin:
            guard case .value = written.cornerPin else { return false }

            return true

        case .crop:
            guard case .value = written.crop else { return false }

            return true

        case .mask:
            return written.mask != nil
        }
    }
}
