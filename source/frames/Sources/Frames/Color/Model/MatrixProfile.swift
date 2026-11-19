//
//  MatrixProfile.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// A matrix and tone-curve ICC profile (ICC.1) of an RGB or grey picture: each channel's tone curve, and the matrix
// whose columns are its red, green and blue colorants in CIE XYZ of the profile connection space, white D50. A grey
// profile has one curve, and colorants that take equal channels to the white.
package struct MatrixProfile: Equatable, Sendable {
    // MARK: - Property
    // How far a profile's numbers may lie from a space of the table and still describe it: ICC.1 writes colorants in
    // s15Fixed16 and tables in 16 bits, and a profile's white adaptation is the profile maker's.
    private static let tolerance = 0.002
    private static let samples = (0...32).map { Double($0) / 32 }

    package let curves: [ToneCurve]
    package let colorants: ColorMatrix

    // Linear values of the profile to linear sRGB, by the profile connection space.
    package var toLinearSRGB: ColorMatrix {
        ColorMatrix.profileConnectionToLinearSRGB.multiplied(by: colorants)
    }

    // The space of the table of SDR range the profile describes, its primaries, white point and transfer, nil for
    // any other.
    package var colorSpace: ColorSpace? {
        let toLinearSRGB = toLinearSRGB
        let spaces: [ColorSpace] = [.srgb, .displayP3, .rec2020, .rec709]

        return spaces.first { space in
            let matrix = ColorMatrix(from: space.primaries, to: .bt709)
            let matches = zip(matrix.rows.joined(), toLinearSRGB.rows.joined()).allSatisfy { expected, actual in
                abs(expected - actual) <= Self.tolerance
            }
            guard matches, let transfer = space.transferFunction else { return false }

            return curves.allSatisfy { curve in
                Self.samples.allSatisfy { abs(curve.linear($0) - transfer.decode($0)) <= Self.tolerance }
            }
        }
    }

    // MARK: - Initializer
    // `curves` holds one curve for each of red, green and blue, in that order.
    package init(
        curves: [ToneCurve],
        colorants: ColorMatrix
    ) {
        self.curves = curves
        self.colorants = colorants
    }

    // A grey profile by its one curve.
    package init(greyCurve: ToneCurve) {
        self.init(curves: [greyCurve, greyCurve, greyCurve], colorants: ColorMatrix.profileConnectionToLinearSRGB.inverse)
    }

    // MARK: - Public
    // MARK: - Private
}
