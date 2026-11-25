//
//  AreaValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A clip's `area` as resolve keeps it: a rectangle, or a clip area, which evaluation takes at each instant.
enum AreaValue: Equatable, Sendable {
    case rectangle(Rectangle)
    case clip(ClipArea)

    // MARK: - Property
    var rectangle: Rectangle? {
        guard case let .rectangle(rectangle) = self else { return nil }

        return rectangle
    }

    var geometry: GeometryArea {
        switch self {
        case let .rectangle(rectangle):
            .rectangle(rectangle)

        case let .clip(area):
            .clip(area)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func map(_ transform: (Rectangle) -> Rectangle) -> AreaValue {
        guard case let .rectangle(rectangle) = self else { return self }

        return .rectangle(transform(rectangle))
    }

    // MARK: - Private
}
