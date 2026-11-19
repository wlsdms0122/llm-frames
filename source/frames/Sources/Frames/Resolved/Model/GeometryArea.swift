//
//  GeometryArea.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An area as evaluation takes it: a rectangle, or a clip area, whose rectangle is known only at the instant evaluated.
enum GeometryArea: Equatable, Sendable {
    case rectangle(Rectangle)
    case clip(ClipArea)

    // MARK: - Property
    // The rectangle where it is fixed, and an empty one at the origin for a clip area, for a value resolve checked to
    // hold none.
    var fixed: Rectangle {
        guard case let .rectangle(rectangle) = self else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

        return rectangle
    }

    var clipArea: ClipArea? {
        guard case let .clip(area) = self else { return nil }

        return area
    }

    // MARK: - Initializer
    // MARK: - Public
    func map(_ transform: (Rectangle) throws -> Rectangle) rethrows -> GeometryArea {
        guard case let .rectangle(rectangle) = self else { return self }

        return .rectangle(try transform(rectangle))
    }

    // MARK: - Private
}
