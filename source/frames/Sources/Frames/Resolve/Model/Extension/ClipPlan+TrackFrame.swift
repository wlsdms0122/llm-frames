//
//  ClipPlan+TrackFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The values a tracked clip's track carries, as its placement decides them (FRAMES-12 What is tracked), and those of
// them it writes without keyframes that are true on the track's frame, which the resolved document writes as values.
// A mask is true there as a whole when it is written without keyframes; which of its leaves a text form found is
// decided where its masks are found.
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
        guard let target = written.track else { return [] }

        let points: PropertyValue<[PositionForm]>? = if case let .shape(shape) = written.content { shape.points } else { nil }
        let found: [FollowedKey: Bool?] = [
            .area: Self.staticValue(of: written.area).map(\.isFoundByText),
            .points: Self.staticValue(of: points).map { $0.contains(where: \.isFoundByText) },
            .position: Self.staticValue(of: written.position).map(\.isFoundByText),
            .cornerPin: Self.staticValue(of: written.cornerPin).map { $0.contains(where: \.isFoundByText) },
            .crop: Self.staticValue(of: written.crop).map(\.isFoundByText),
            .mask: written.mask.flatMap { $0.keyframes.isEmpty ? false : nil }
        ]

        return followedKeys.filter { value in
            guard let isFoundByText = found[value] ?? nil else { return false }

            return target.isOnTrackFrame(value, isFoundByText: isFoundByText)
        }
    }

    // MARK: - Private
    private static func staticValue<Value>(of property: PropertyValue<Value>?) -> Value? {
        guard case let .value(value) = property else { return nil }

        return value
    }
}
