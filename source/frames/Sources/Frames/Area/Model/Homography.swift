//
//  Homography.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A homography of the plane, the matrix `[[a, c, tx], [b, d, ty], [g, h, i]]` acting on (x, y, 1): a point (x, y) goes
// to ((a x + c y + tx) / w, (b x + d y + ty) / w) with w = g x + h y + i (FRAMES-27). Its first six numbers are named as
// in `AffineTransform`, and with g = h = 0 it is affine.
//
// Every homography here is the identity or is made from strictly convex quads, so w is above 0 inside the quad it takes
// from: S(q) has it on the unit square, and an inverse and a product keep it. So a point lies in front of the horizon,
// where w has the sign it has inside that quad, exactly where w is above 0.
package struct Homography: Equatable, Sendable {
    // MARK: - Property
    static let identity = Homography(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0, g: 0, h: 0, i: 1)

    package let a: Double
    package let b: Double
    package let c: Double
    package let d: Double
    package let tx: Double
    package let ty: Double
    package let g: Double
    package let h: Double
    package let i: Double

    // The homography that takes the destination back to the source, the matrix's adjugate over its determinant. w of
    // the inverse at a point of the destination is 1 over w at the point it comes from, so it is above 0 inside the
    // destination.
    package var inverse: Homography {
        let cofactor00 = d * i - ty * h
        let cofactor01 = ty * g - b * i
        let cofactor02 = b * h - d * g
        let cofactor10 = tx * h - c * i
        let cofactor11 = a * i - tx * g
        let cofactor12 = c * g - a * h
        let cofactor20 = c * ty - tx * d
        let cofactor21 = tx * b - a * ty
        let cofactor22 = a * d - c * b
        let determinant = a * cofactor00 + c * cofactor01 + tx * cofactor02

        return Homography(
            a: cofactor00 / determinant,
            b: cofactor01 / determinant,
            c: cofactor10 / determinant,
            d: cofactor11 / determinant,
            tx: cofactor20 / determinant,
            ty: cofactor21 / determinant,
            g: cofactor02 / determinant,
            h: cofactor12 / determinant,
            i: cofactor22 / determinant
        )
    }

    // MARK: - Initializer
    private init(
        a: Double,
        b: Double,
        c: Double,
        d: Double,
        tx: Double,
        ty: Double,
        g: Double,
        h: Double,
        i: Double
    ) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
        self.g = g
        self.h = h
        self.i = i
    }

    // S(q), the homography that takes the unit square's corners (0, 0), (1, 0), (1, 1), (0, 1) to the quad's corners
    // in order, with i = 1, by the closed form of FRAMES-27. Nil when the quad is not strictly convex. w is 1, 1 + g,
    // 1 + g + h and 1 + h at the square's corners, all above 0 for a strictly convex quad.
    init?(unitSquareTo quad: Quad) {
        guard quad.isStrictlyConvex else { return nil }

        let (x0, y0) = (quad.topLeft.x, quad.topLeft.y)
        let (x1, y1) = (quad.topRight.x, quad.topRight.y)
        let (x2, y2) = (quad.bottomRight.x, quad.bottomRight.y)
        let (x3, y3) = (quad.bottomLeft.x, quad.bottomLeft.y)
        let deltaX1 = x1 - x2
        let deltaX2 = x3 - x2
        let deltaY1 = y1 - y2
        let deltaY2 = y3 - y2
        let sumX = x0 - x1 + x2 - x3
        let sumY = y0 - y1 + y2 - y3
        let denominator = deltaX1 * deltaY2 - deltaX2 * deltaY1
        let g = (sumX * deltaY2 - deltaX2 * sumY) / denominator
        let h = (deltaX1 * sumY - sumX * deltaY1) / denominator

        self.init(
            a: x1 - x0 + g * x1,
            b: y1 - y0 + g * y1,
            c: x3 - x0 + h * x3,
            d: y3 - y0 + h * y3,
            tx: x0,
            ty: y0,
            g: g,
            h: h,
            i: 1
        )
    }

    // H(p → q), the one homography that takes the source's corners to the destination's in order: S(q) S(p)⁻¹. Nil when
    // either quad is not strictly convex, a box with a width or a height of 0 included.
    package init?(
        from source: Quad,
        to destination: Quad
    ) {
        guard let squareToSource = Homography(unitSquareTo: source),
              let squareToDestination = Homography(unitSquareTo: destination)
        else { return nil }

        self = squareToSource.inverse.concatenating(squareToDestination)
    }

    // MARK: - Public
    func w(at point: Point) -> Double {
        g * point.x + h * point.y + i
    }

    // Whether the point lies in front of the horizon, w above 0. A point where w is 0 lies on the horizon and does not.
    package func isInFront(_ point: Point) -> Bool {
        w(at: point) > 0
    }

    // Nil when the point does not lie in front of the horizon.
    package func apply(to point: Point) -> Point? {
        let w = self.w(at: point)
        guard w > 0 else { return nil }

        return Point(x: (a * point.x + c * point.y + tx) / w, y: (b * point.x + d * point.y + ty) / w)
    }

    // Each corner carried, nil when any corner does not lie in front of the horizon.
    package func apply(to quad: Quad) -> Quad? {
        guard let topLeft = apply(to: quad.topLeft),
              let topRight = apply(to: quad.topRight),
              let bottomRight = apply(to: quad.bottomRight),
              let bottomLeft = apply(to: quad.bottomLeft)
        else { return nil }

        return Quad(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
    }

    // MARK: - Private
    // The homography that applies this one first and `other` after it, the matrix product `other` × self.
    private func concatenating(_ other: Homography) -> Homography {
        Homography(
            a: other.a * a + other.c * b + other.tx * g,
            b: other.b * a + other.d * b + other.ty * g,
            c: other.a * c + other.c * d + other.tx * h,
            d: other.b * c + other.d * d + other.ty * h,
            tx: other.a * tx + other.c * ty + other.tx * i,
            ty: other.b * tx + other.d * ty + other.ty * i,
            g: other.g * a + other.h * b + other.i * g,
            h: other.g * c + other.h * d + other.i * h,
            i: other.g * tx + other.h * ty + other.i * i
        )
    }
}
