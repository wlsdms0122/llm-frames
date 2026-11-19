//
//  PrimaryChromaticities.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The chromaticities of a picture's red, green and blue and of its white point, as the colour primaries code point of
// ITU-T H.273 a video is tagged with names them.
package struct PrimaryChromaticities: Equatable, Sendable {
    // MARK: - Property
    package let red: Chromaticity
    package let green: Chromaticity
    package let blue: Chromaticity
    package let white: Chromaticity

    // MARK: - Initializer
    package init(
        red: Chromaticity,
        green: Chromaticity,
        blue: Chromaticity,
        white: Chromaticity
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
    }

    package init(_ primaries: ColorPrimaries) {
        self.init(red: primaries.red, green: primaries.green, blue: primaries.blue, white: ColorPrimaries.whitePoint)
    }

    // The primaries H.273 gives for the code point, nil for a value it reserves. 2 (unspecified) is not a set of
    // primaries: a caller takes it as `srgb`'s.
    package init?(colorPrimaries codePoint: Int) {
        let d65 = ColorPrimaries.whitePoint
        let illuminantC = Chromaticity(x: 0.310, y: 0.316)
        let smpte170M = (red: Chromaticity(x: 0.630, y: 0.340), green: Chromaticity(x: 0.310, y: 0.595))

        switch codePoint {
        case 1:
            self.init(.bt709)

        case 4:
            self.init(
                red: Chromaticity(x: 0.67, y: 0.33),
                green: Chromaticity(x: 0.21, y: 0.71),
                blue: Chromaticity(x: 0.14, y: 0.08),
                white: illuminantC
            )

        case 5:
            self.init(
                red: Chromaticity(x: 0.64, y: 0.33),
                green: Chromaticity(x: 0.29, y: 0.60),
                blue: Chromaticity(x: 0.15, y: 0.06),
                white: d65
            )

        case 6, 7:
            self.init(
                red: smpte170M.red,
                green: smpte170M.green,
                blue: Chromaticity(x: 0.155, y: 0.070),
                white: d65
            )

        case 8:
            self.init(
                red: Chromaticity(x: 0.681, y: 0.319),
                green: Chromaticity(x: 0.243, y: 0.692),
                blue: Chromaticity(x: 0.145, y: 0.049),
                white: illuminantC
            )

        case 9:
            self.init(.bt2020)

        case 10:
            self.init(
                red: Chromaticity(x: 1, y: 0),
                green: Chromaticity(x: 0, y: 1),
                blue: Chromaticity(x: 0, y: 0),
                white: Chromaticity(x: 1.0 / 3, y: 1.0 / 3)
            )

        case 11:
            self.init(
                red: ColorPrimaries.p3D65.red,
                green: ColorPrimaries.p3D65.green,
                blue: ColorPrimaries.p3D65.blue,
                white: Chromaticity(x: 0.314, y: 0.351)
            )

        case 12:
            self.init(.p3D65)

        case 22:
            self.init(
                red: smpte170M.red,
                green: Chromaticity(x: 0.295, y: 0.605),
                blue: Chromaticity(x: 0.155, y: 0.077),
                white: d65
            )

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
