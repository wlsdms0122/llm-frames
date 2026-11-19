//
//  Color.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A working value in its encoded form, at full precision: red, green and blue on BT.709 primaries, each any real
// number, 1 at reference white, and alpha from 0 to 1, straight.
package struct Color: Equatable, Sendable {
    // MARK: - Property
    package static let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
    package static let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
    package static let transparent = Color(red: 0, green: 0, blue: 0, alpha: 0)

    package let red: Double
    package let green: Double
    package let blue: Double
    package let alpha: Double

    package var encoded: RGB {
        RGB(red: red, green: green, blue: blue)
    }

    // The linear form, by the extended sRGB transfer.
    package var linear: RGB {
        TransferFunction.sRGB.decode(encoded)
    }

    // MARK: - Initializer
    package init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    package init(
        encoded: RGB,
        alpha: Double
    ) {
        self.init(red: encoded.red, green: encoded.green, blue: encoded.blue, alpha: alpha)
    }

    package init(
        linear: RGB,
        alpha: Double
    ) {
        self.init(encoded: TransferFunction.sRGB.encode(linear), alpha: alpha)
    }

    // MARK: - Public
    // MARK: - Private
}
