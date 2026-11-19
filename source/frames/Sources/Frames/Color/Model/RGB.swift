//
//  RGB.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The red, green and blue of a colour, each any real number, in the space and form the code that holds it names.
package struct RGB: Equatable, Sendable {
    // MARK: - Property
    package let red: Double
    package let green: Double
    package let blue: Double

    package var maximum: Double {
        max(red, green, blue)
    }

    // MARK: - Initializer
    package init(
        red: Double,
        green: Double,
        blue: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    // MARK: - Public
    // Each channel taken on its own.
    package func map(_ transform: (Double) -> Double) -> RGB {
        RGB(red: transform(red), green: transform(green), blue: transform(blue))
    }

    package func scaled(by factor: Double) -> RGB {
        map { $0 * factor }
    }

    // Each channel clipped to `range`.
    package func clipped(to range: ClosedRange<Double>) -> RGB {
        map { min(max($0, range.lowerBound), range.upperBound) }
    }

    // MARK: - Private
}
