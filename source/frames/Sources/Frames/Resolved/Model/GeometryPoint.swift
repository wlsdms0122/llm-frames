//
//  GeometryPoint.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A point as evaluation takes it: a point, or the point a placement name gives of a clip area.
enum GeometryPoint: Equatable, Sendable {
    case point(Point)
    case clip(ClipArea, point: String)

    // MARK: - Property
    // The point where it is fixed, and the origin for a clip area, for a value resolve checked to hold none.
    var fixed: Point {
        guard case let .point(point) = self else { return Point(x: 0, y: 0) }

        return point
    }

    var clipArea: ClipArea? {
        guard case let .clip(area, _) = self else { return nil }

        return area
    }

    // MARK: - Initializer
    // MARK: - Public
    func map(_ transform: (Point) -> Point) -> GeometryPoint {
        guard case let .point(point) = self else { return self }

        return .point(transform(point))
    }

    // MARK: - Private
}
