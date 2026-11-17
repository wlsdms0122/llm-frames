//
//  TrackMotion.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A track's similarity transform on one frame: the target's centre at the instant moves to `center`, and everything
// scales by `scale` about it. The scale is the geometric mean of the width and height ratios, so a crop keeps its
// aspect ratio.
struct TrackMotion: Equatable, Sendable {
    // MARK: - Property
    private static let unit = Rectangle(x: 0, y: 0, width: 1, height: 1)
    static let identity = TrackMotion(from: unit, to: unit)

    let origin: Point
    let center: Point
    let scale: Double

    // MARK: - Initializer
    init(
        from target: Rectangle,
        to frame: Rectangle
    ) {
        self.origin = target.center
        self.center = frame.center
        self.scale = ((frame.width / target.width) * (frame.height / target.height)).squareRoot()
    }

    // MARK: - Public
    func carry(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(center: carry(rectangle.center), width: rectangle.width * scale, height: rectangle.height * scale)
    }

    func carry(_ point: Point) -> Point {
        Point(x: center.x + (point.x - origin.x) * scale, y: center.y + (point.y - origin.y) * scale)
    }

    func bringBack(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(center: bringBack(rectangle.center), width: rectangle.width / scale, height: rectangle.height / scale)
    }

    func bringBack(_ point: Point) -> Point {
        Point(x: origin.x + (point.x - center.x) / scale, y: origin.y + (point.y - center.y) / scale)
    }

    // MARK: - Private
}
