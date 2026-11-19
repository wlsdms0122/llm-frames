//
//  Rectangle+Geometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

extension Rectangle {
    // MARK: - Property
    var maxX: Double {
        x + width
    }

    var maxY: Double {
        y + height
    }

    // MARK: - Initializer
    // The axis-aligned box around points, at least one.
    init(bounding points: [Point]) {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        self.init(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }

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
