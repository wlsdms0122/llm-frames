//
//  TrackMotion.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A track's motion on one frame: the similarity, a move, one uniform scale and one rotation, that takes the target's
// quad at the instant nearest by least squares to its quad on the frame. `transform` is the motion M as a matrix,
// always of the form `[a, b, -b, a, tx, ty]`, and `origin` is the target's centroid p̄ at the instant.
package struct TrackMotion: Equatable, Sendable {
    // MARK: - Property
    static let identity = TrackMotion(transform: .identity, origin: Point(x: 0, y: 0))

    package let transform: AffineTransform
    let origin: Point

    package var scale: Double {
        (transform.a * transform.a + transform.b * transform.b).squareRoot()
    }

    // In degrees, clockwise positive in y-down pixels.
    package var rotation: Double {
        atan2(transform.b, transform.a) * 180 / .pi
    }

    // The move and the scale without the rotation, as a crop takes them: the centroid goes where the motion takes it.
    var upright: TrackMotion {
        let scale = scale
        let center = transform.apply(to: origin)

        return TrackMotion(
            transform: AffineTransform(
                a: scale,
                b: 0,
                c: 0,
                d: scale,
                tx: center.x - scale * origin.x,
                ty: center.y - scale * origin.y
            ),
            origin: origin
        )
    }

    // MARK: - Initializer
    init(
        transform: AffineTransform,
        origin: Point
    ) {
        self.transform = transform
        self.origin = origin
    }

    init(
        from target: Quad,
        to frame: Quad
    ) {
        self.init(from: target.corners, to: frame.corners)
    }

    // The least-squares fit of points to points in the same order: with each taken about its centroid, `a` is Σ pᵢ' ·
    // qᵢ', `b` is Σ pᵢ' × qᵢ' and `spread` is Σ |pᵢ'|², so s cos θ = a / spread and s sin θ = b / spread. The same
    // points give the identity exactly.
    package init(
        from starts: [Point],
        to ends: [Point]
    ) {
        let origin = Point.centroid(of: starts)
        let center = Point.centroid(of: ends)
        var a = 0.0
        var b = 0.0
        var spread = 0.0
        for (start, end) in zip(starts, ends) {
            let x = start.x - origin.x
            let y = start.y - origin.y
            let endX = end.x - center.x
            let endY = end.y - center.y
            a += x * endX + y * endY
            b += x * endY - y * endX
            spread += x * x + y * y
        }
        let cosine = a / spread
        let sine = b / spread

        self.init(
            transform: AffineTransform(
                a: cosine,
                b: sine,
                c: -sine,
                d: cosine,
                tx: center.x - (cosine * origin.x - sine * origin.y),
                ty: center.y - (sine * origin.x + cosine * origin.y)
            ),
            origin: origin
        )
    }

    // MARK: - Public
    func carry(_ point: Point) -> Point {
        transform.apply(to: point)
    }

    // The inverse of the motion: R(-θ) / s about the centroids.
    func bringBack(_ point: Point) -> Point {
        let center = transform.apply(to: origin)
        let x = point.x - center.x
        let y = point.y - center.y
        let norm = transform.a * transform.a + transform.b * transform.b

        return Point(
            x: origin.x + (transform.a * x + transform.b * y) / norm,
            y: origin.y + (transform.a * y - transform.b * x) / norm
        )
    }

    // An offset, a path's tangent, is brought back by the inverse's linear part alone, its scale and rotation.
    func bringBack(offset: Point) -> Point {
        let center = transform.apply(to: origin)
        let point = bringBack(Point(x: center.x + offset.x, y: center.y + offset.y))

        return Point(x: point.x - origin.x, y: point.y - origin.y)
    }

    // A rectangle keeps its shape: its centre is carried and its size scaled. A motion that turns turns the space it
    // is carried in, not the rectangle within it.
    func carry(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(center: carry(rectangle.center), width: rectangle.width * scale, height: rectangle.height * scale)
    }

    func bringBack(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(center: bringBack(rectangle.center), width: rectangle.width / scale, height: rectangle.height / scale)
    }

    // MARK: - Private
}
