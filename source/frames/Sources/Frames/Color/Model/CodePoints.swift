//
//  CodePoints.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The code points of ITU-T H.273 a video is tagged with: its colour primaries, transfer characteristics and matrix
// coefficients.
package struct CodePoints: Equatable, Sendable {
    // MARK: - Property
    package let colorPrimaries: Int
    package let transferCharacteristics: Int
    package let matrixCoefficients: Int

    // MARK: - Initializer
    package init(
        colorPrimaries: Int,
        transferCharacteristics: Int,
        matrixCoefficients: Int
    ) {
        self.colorPrimaries = colorPrimaries
        self.transferCharacteristics = transferCharacteristics
        self.matrixCoefficients = matrixCoefficients
    }

    // MARK: - Public
    // MARK: - Private
}
