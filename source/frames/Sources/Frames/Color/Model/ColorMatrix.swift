//
//  ColorMatrix.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// A 3 by 3 matrix that takes linear red, green and blue to another linear space, row by row.
package struct ColorMatrix: Equatable, Sendable {
    // MARK: - Property
    package static let identity = ColorMatrix(rows: [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    // The white of the ICC profile connection space, D50, in CIE XYZ.
    package static let profileConnectionWhite = RGB(red: 0.9642, green: 1, blue: 0.8249)
    // CIE XYZ in the ICC profile connection space to linear sRGB: N_sRGB⁻¹ × A⁻¹, with A the Bradford adaptation from
    // D65 to D50.
    package static let profileConnectionToLinearSRGB = ColorMatrix(normalizedPrimaryOf: .bt709).inverse.multiplied(
        by: ColorMatrix(bradfordFrom: profileConnectionWhite, to: tristimulus(of: ColorPrimaries.whitePoint))
    )

    private static let bradford = ColorMatrix(rows: [
        [0.8951, 0.2664, -0.1614],
        [-0.7502, 1.7135, 0.0367],
        [0.0389, -0.0685, 1.0296]
    ])

    package let rows: [[Double]]

    package var inverse: ColorMatrix {
        let m = rows
        let cofactors = [
            [
                m[1][1] * m[2][2] - m[1][2] * m[2][1],
                m[0][2] * m[2][1] - m[0][1] * m[2][2],
                m[0][1] * m[1][2] - m[0][2] * m[1][1]
            ],
            [
                m[1][2] * m[2][0] - m[1][0] * m[2][2],
                m[0][0] * m[2][2] - m[0][2] * m[2][0],
                m[0][2] * m[1][0] - m[0][0] * m[1][2]
            ],
            [
                m[1][0] * m[2][1] - m[1][1] * m[2][0],
                m[0][1] * m[2][0] - m[0][0] * m[2][1],
                m[0][0] * m[1][1] - m[0][1] * m[1][0]
            ]
        ]
        let determinant = m[0][0] * cofactors[0][0] + m[0][1] * cofactors[1][0] + m[0][2] * cofactors[2][0]

        return ColorMatrix(rows: cofactors.map { row in row.map { $0 / determinant } })
    }

    // MARK: - Initializer
    // `rows` is three rows of three.
    package init(rows: [[Double]]) {
        self.rows = rows
    }

    // The normalized primary matrix of SMPTE RP 177: linear red, green and blue of `primaries` to CIE XYZ, white at
    // Y = 1.
    package init(normalizedPrimaryOf primaries: ColorPrimaries) {
        self.init(normalizedPrimaryOf: PrimaryChromaticities(primaries))
    }

    package init(normalizedPrimaryOf chromaticities: PrimaryChromaticities) {
        let colorants = [chromaticities.red, chromaticities.green, chromaticities.blue]
        let primaryMatrix = ColorMatrix(rows: [
            colorants.map(\.x),
            colorants.map(\.y),
            colorants.map { 1 - $0.x - $0.y }
        ])
        let coefficients = primaryMatrix.inverse.applied(to: Self.tristimulus(of: chromaticities.white))
        let scales = [coefficients.red, coefficients.green, coefficients.blue]

        self.init(rows: primaryMatrix.rows.map { row in zip(row, scales).map(*) })
    }

    // Linear values on `source` primaries to linear values on `target` primaries. Every space has the D65 white point,
    // so no chromatic adaptation is applied.
    package init(
        from source: ColorPrimaries,
        to target: ColorPrimaries
    ) {
        guard source != target else {
            self = .identity
            return
        }

        self = ColorMatrix(normalizedPrimaryOf: target).inverse.multiplied(by: ColorMatrix(normalizedPrimaryOf: source))
    }

    // Linear values on `source` primaries to linear values on `target` primaries, a white point other than D65 adapted
    // to D65 by the Bradford transform.
    package init(
        from source: PrimaryChromaticities,
        to target: ColorPrimaries
    ) {
        let adaptation = ColorMatrix(
            bradfordFrom: Self.tristimulus(of: source.white),
            to: Self.tristimulus(of: ColorPrimaries.whitePoint)
        )

        self = ColorMatrix(normalizedPrimaryOf: target).inverse
            .multiplied(by: adaptation)
            .multiplied(by: ColorMatrix(normalizedPrimaryOf: source))
    }

    // The Bradford adaptation from the white `source` to the white `target`, each in CIE XYZ with Y 1:
    // B⁻¹ × diag(B × target / B × source) × B.
    package init(
        bradfordFrom source: RGB,
        to target: RGB
    ) {
        let bradford = Self.bradford
        let sourceCone = bradford.applied(to: source)
        let targetCone = bradford.applied(to: target)
        let scale = ColorMatrix(rows: [
            [targetCone.red / sourceCone.red, 0, 0],
            [0, targetCone.green / sourceCone.green, 0],
            [0, 0, targetCone.blue / sourceCone.blue]
        ])

        self = bradford.inverse.multiplied(by: scale).multiplied(by: bradford)
    }

    // MARK: - Public
    // This matrix times `other`, which applies `other` first.
    package func multiplied(by other: ColorMatrix) -> ColorMatrix {
        ColorMatrix(rows: rows.map { row in
            (0..<3).map { column in (0..<3).reduce(0) { sum, index in sum + row[index] * other.rows[index][column] } }
        })
    }

    package func applied(to value: RGB) -> RGB {
        RGB(
            red: rows[0][0] * value.red + rows[0][1] * value.green + rows[0][2] * value.blue,
            green: rows[1][0] * value.red + rows[1][1] * value.green + rows[1][2] * value.blue,
            blue: rows[2][0] * value.red + rows[2][1] * value.green + rows[2][2] * value.blue
        )
    }

    // MARK: - Private
    // CIE XYZ of a chromaticity at Y = 1.
    private static func tristimulus(of white: Chromaticity) -> RGB {
        RGB(red: white.x / white.y, green: 1, blue: (1 - white.x - white.y) / white.y)
    }
}
