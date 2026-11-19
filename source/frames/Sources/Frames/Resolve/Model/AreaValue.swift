//
//  AreaValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A clip's `area` as resolve finds it: an area found in its picture, or a clip area, which evaluation takes at each
// instant.
enum AreaValue: Equatable, Sendable {
    case found(FoundArea)
    case clip(ClipArea)

    // MARK: - Property
    var found: FoundArea? {
        guard case let .found(area) = self else { return nil }

        return area
    }

    var geometry: GeometryArea {
        switch self {
        case let .found(area):
            .rectangle(area.rectangle)

        case let .clip(area):
            .clip(area)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func map(_ transform: (FoundArea) -> FoundArea) -> AreaValue {
        guard case let .found(area) = self else { return self }

        return .found(transform(area))
    }

    // MARK: - Private
}
