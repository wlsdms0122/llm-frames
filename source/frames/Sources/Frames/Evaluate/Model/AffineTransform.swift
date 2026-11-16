//
//  AffineTransform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// The affine matrix `[a, b, c, d, tx, ty]`: a point (x, y) goes to (a x + c y + tx, b x + d y + ty). The y axis points
// down, so a positive angle turns clockwise.
struct AffineTransform: Equatable, Sendable {
    // MARK: - Property
    static let identity = AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    let a: Double
    let b: Double
    let c: Double
    let d: Double
    let tx: Double
    let ty: Double

    // Nil when the matrix flattens the plane, as a scale of 0 does.
    var inverse: AffineTransform? {
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
    init(
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

    init(translation offset: Point) {
        self.init(a: 1, b: 0, c: 0, d: 1, tx: offset.x, ty: offset.y)
    }

    init(scale: Double, about center: Point) {
        self.init(a: scale, b: 0, c: 0, d: scale, tx: center.x * (1 - scale), ty: center.y * (1 - scale))
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

    // `degrees` turns clockwise.
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
        [
            Point(x: rectangle.x, y: rectangle.y),
            Point(x: rectangle.x + rectangle.width, y: rectangle.y),
            Point(x: rectangle.x + rectangle.width, y: rectangle.y + rectangle.height),
            Point(x: rectangle.x, y: rectangle.y + rectangle.height)
        ]
        .map(apply(to:))
    }

    // MARK: - Private
}
