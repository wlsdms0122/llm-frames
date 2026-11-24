//
//  CornerRadii.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// The radii of a rectangle's four corners, top left, top right, bottom right and bottom left, the order CSS
// `border-radius` writes them, the top left at the rectangle's least x and y (FRAMES-11 Shapes, FRAMES-20). A number
// is the radius of every corner. Corners interpolate one by one.
package struct CornerRadii: Interpolable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    // MARK: - Property
    package static let zero = CornerRadii(0)

    package let topLeft: Double
    package let topRight: Double
    package let bottomRight: Double
    package let bottomLeft: Double

    // The four radii in the order they are written.
    package var values: [Double] { [topLeft, topRight, bottomRight, bottomLeft] }

    package var isZero: Bool { values.allSatisfy { $0 == 0 } }

    // Each radius 0 or more, as a sampled length is held.
    package var nonNegative: CornerRadii {
        mapped { max($0, 0) }
    }

    // MARK: - Initializer
    package init(
        topLeft: Double,
        topRight: Double,
        bottomRight: Double,
        bottomLeft: Double
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    package init(_ radius: Double) {
        self.init(topLeft: radius, topRight: radius, bottomRight: radius, bottomLeft: radius)
    }

    // Nil unless `values` holds four radii.
    package init?(values: [Double]) {
        guard values.count == 4 else { return nil }

        self.init(topLeft: values[0], topRight: values[1], bottomRight: values[2], bottomLeft: values[3])
    }

    package init(integerLiteral value: Int) {
        self.init(Double(value))
    }

    package init(floatLiteral value: Double) {
        self.init(value)
    }

    // MARK: - Public
    static func interpolate(
        from start: CornerRadii,
        to end: CornerRadii,
        progress: Double
    ) -> CornerRadii {
        CornerRadii(values: .interpolate(from: start.values, to: end.values, progress: progress)) ?? start
    }

    package func scaled(by factor: Double) -> CornerRadii {
        mapped { $0 * factor }
    }

    package func grown(by length: Double) -> CornerRadii {
        mapped { $0 + length }
    }

    // The radii a rectangle of `size` rounds its corners by: each 0 or more, then every one scaled by one factor where
    // the radii of a side's two corners add up to more than the side, the least of each side's length over that sum,
    // as CSS Backgrounds keeps corner curves from overlapping. Equal radii are so cut to half the shorter side.
    package func fitted(to size: Size) -> CornerRadii {
        let radii = nonNegative
        let width = abs(size.width)
        let height = abs(size.height)
        let sides = [
            (width, radii.topLeft + radii.topRight),
            (height, radii.topRight + radii.bottomRight),
            (width, radii.bottomRight + radii.bottomLeft),
            (height, radii.bottomLeft + radii.topLeft)
        ]
        let factor = sides.reduce(1) { factor, side in side.1 > side.0 ? min(factor, side.0 / side.1) : factor }

        return factor < 1 ? radii.scaled(by: factor) : radii
    }

    // MARK: - Private
    private func mapped(_ transform: (Double) -> Double) -> CornerRadii {
        CornerRadii(
            topLeft: transform(topLeft),
            topRight: transform(topRight),
            bottomRight: transform(bottomRight),
            bottomLeft: transform(bottomLeft)
        )
    }
}
