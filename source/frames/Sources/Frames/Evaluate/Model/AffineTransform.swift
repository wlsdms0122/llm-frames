//
//  AffineTransform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// The affine matrix `[a, b, c, d, tx, ty]`: a point (x, y) goes to (a x + c y + tx, b x + d y + ty). The y axis points
// down, so a positive angle turns clockwise.
package struct AffineTransform: Equatable, Sendable {
    // MARK: - Property
    package static let identity = AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    package let a: Double
    package let b: Double
    package let c: Double
    package let d: Double
    package let tx: Double
    package let ty: Double

    var matrix: [Double] {
        [a, b, c, d, tx, ty]
    }

    // The length factor k, the geometric mean of the scales the map applies.
    package var lengthFactor: Double {
        abs(a * d - b * c).squareRoot()
    }

    // The rotation of the polar decomposition, the one nearest the linear part, in degrees clockwise. Under a mirror it
    // is the rotation of the map with its own x axis mirrored first, so a map flipped vertically turns by a half turn
    // more than one flipped horizontally. It is 0 where the map leaves no direction to take, as a scale of 0 does.
    package var rotation: Double {
        let (y, x) = a * d - b * c >= 0 ? (b - c, a + d) : (-(b + c), d - a)
        guard x != 0 || y != 0 else { return 0 }

        return atan2(y, x) * 180 / .pi
    }

    // Nil when the matrix flattens the plane, as a scale of 0 does.
    package var inverse: AffineTransform? {
        let determinant = a * d - b * c
        guard determinant != 0 else { return nil }

        return AffineTransform(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }

    // MARK: - Initializer
    package init(
        a: Double,
        b: Double,
        c: Double,
        d: Double,
        tx: Double,
        ty: Double
    ) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    // Six numbers in the order `matrix` gives them.
    init(matrix: [Double]) {
        self.init(a: matrix[0], b: matrix[1], c: matrix[2], d: matrix[3], tx: matrix[4], ty: matrix[5])
    }

    init(translation offset: Point) {
        self.init(a: 1, b: 0, c: 0, d: 1, tx: offset.x, ty: offset.y)
    }

    init(scale: Double, about center: Point) {
        self.init(scale: Scale(scale), about: center)
    }

    init(scale: Scale, about center: Point) {
        self.init(a: scale.x, b: 0, c: 0, d: scale.y, tx: center.x * (1 - scale.x), ty: center.y * (1 - scale.y))
    }

    // The transform that scales a box of `size` with its top left at the origin onto `rectangle`.
    init(
        mapping size: Size,
        onto rectangle: Rectangle
    ) {
        self.init(
            a: rectangle.width / size.width,
            b: 0,
            c: 0,
            d: rectangle.height / size.height,
            tx: rectangle.x,
            ty: rectangle.y
        )
    }

    init(rotation degrees: Double, about center: Point) {
        let radians = degrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)

        self.init(
            a: cosine,
            b: sine,
            c: -sine,
            d: cosine,
            tx: center.x - cosine * center.x + sine * center.y,
            ty: center.y - sine * center.x - cosine * center.y
        )
    }

    // A clip's own transform about its anchor point: scale, then turn `degrees` clockwise, about `anchor`, then move by
    // `offset`.
    init(
        scale: Double,
        rotation degrees: Double,
        about anchor: Point,
        offset: Point
    ) {
        self.init(scale: Scale(scale), rotation: degrees, about: anchor, offset: offset)
    }

    init(
        scale: Scale,
        rotation degrees: Double,
        about anchor: Point,
        offset: Point
    ) {
        self = AffineTransform(scale: scale, about: anchor)
            .concatenating(AffineTransform(rotation: degrees, about: anchor))
            .concatenating(AffineTransform(translation: offset))
    }

    // MARK: - Public
    // The transform that applies this one first and `other` after it.
    func concatenating(_ other: AffineTransform) -> AffineTransform {
        AffineTransform(
            a: other.a * a + other.c * b,
            b: other.b * a + other.d * b,
            c: other.a * c + other.c * d,
            d: other.b * c + other.d * d,
            tx: other.a * tx + other.c * ty + other.tx,
            ty: other.b * tx + other.d * ty + other.ty
        )
    }

    func apply(to point: Point) -> Point {
        Point(x: a * point.x + c * point.y + tx, y: b * point.x + d * point.y + ty)
    }

    // The rectangle's corners carried by the transform, clockwise from its top left.
    func apply(toCornersOf rectangle: Rectangle) -> [Point] {
        Quad(rectangle).applying(self).corners
    }

    // How far a disc of `radius` about a point reaches from it along each axis once carried by the transform: the half
    // width and half height of the ellipse it lands on.
    func reach(ofDisc radius: Double) -> Size {
        Size(width: radius * (a * a + c * c).squareRoot(), height: radius * (b * b + d * d).squareRoot())
    }

    // MARK: - Private
}
