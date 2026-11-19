//
//  GeometryAnchor.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The anchor a shape placed by its geometry names: a point of its geometry's box as written, or, when that geometry
// holds a clip area, the placement name of a point of the box, which only evaluation knows at each instant.
enum GeometryAnchor: Equatable, Sendable {
    case point(Point)
    case named(String)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func point(in box: Rectangle) -> Point {
        switch self {
        case let .point(point):
            point

        case let .named(name):
            box.point(named: name)
        }
    }

    // MARK: - Private
}
