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
        let chromaticities = [primaries.red, primaries.green, primaries.blue]
        let primaryMatrix = ColorMatrix(rows: [
            chromaticities.map(\.x),
            chromaticities.map(\.y),
            chromaticities.map { 1 - $0.x - $0.y }
        ])
        let white = ColorPrimaries.whitePoint
        let coefficients = primaryMatrix.inverse.applied(to: RGB(
            red: white.x / white.y,
            green: 1,
            blue: (1 - white.x - white.y) / white.y
        ))
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
}
