//
//  Rectangle+Geometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The measures resolve takes of a rectangle once it is found: its edges, growing it, cutting it to a picture, and the
// rectangle around two.
extension Rectangle {
    // MARK: - Property
    var maxX: Double {
        x + width
    }

    var maxY: Double {
        y + height
    }

    // MARK: - Initializer
    // MARK: - Public
    func grown(by length: Double) -> Rectangle {
        Rectangle(x: x - length, y: y - length, width: width + length * 2, height: height + length * 2)
    }

    // Nil when nothing of it lies inside.
    func intersection(_ other: Rectangle) -> Rectangle? {
        let left = max(x, other.x)
        let top = max(y, other.y)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        guard left < right, top < bottom else { return nil }

        return Rectangle(x: left, y: top, width: right - left, height: bottom - top)
    }

    func union(_ other: Rectangle) -> Rectangle {
        let left = min(x, other.x)
        let top = min(y, other.y)

        return Rectangle(x: left, y: top, width: max(maxX, other.maxX) - left, height: max(maxY, other.maxY) - top)
    }

    func contains(_ other: Rectangle) -> Bool {
        other.x >= x && other.y >= y && other.maxX <= maxX && other.maxY <= maxY
    }

    // The point a placement name names: `top-left` is the top left corner and `center` the centre.
    func point(named name: String) -> Point {
        let horizontal = name.hasSuffix("left") ? x : name.hasSuffix("right") ? maxX : center.x
        let vertical = name.hasPrefix("top") ? y : name.hasPrefix("bottom") ? maxY : center.y

        return Point(x: horizontal, y: vertical)
    }

    // MARK: - Private
}
