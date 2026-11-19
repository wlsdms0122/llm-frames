//
//  MediaColor.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// What a picture the decoder reads is converted to working values by (FRAMES-26 Media): a colour space of the table,
// a video's code points outside the table, which the formulas of ITU-T H.273 convert, or a matrix and tone-curve ICC
// profile, which is converted colorimetrically.
package enum MediaColor: Equatable, Sendable {
    case space(ColorSpace)
    case codePoints(CodePoints)
    case profile(MatrixProfile)

    // MARK: - Property
    // The table's name for the colour, nil outside the table.
    package var colorSpace: ColorSpace? {
        guard case let .space(space) = self else { return nil }

        return space
    }

    // MARK: - Initializer
    // The colour of a video tagged with these code points, 2 (unspecified) standing for `srgb`'s. Nil where a code
    // point is one H.273 reserves, so no formula defines the picture.
    package init?(codePoints: CodePoints) {
        let primaries = codePoints.colorPrimaries == 2 ? 1 : codePoints.colorPrimaries
        let transfer = codePoints.transferCharacteristics == 2 ? 13 : codePoints.transferCharacteristics
        let matrix = codePoints.matrixCoefficients
        guard (0...14).contains(matrix), matrix != 3 else { return nil }

        if let space = ColorSpace(colorPrimaries: primaries, transferCharacteristics: transfer) {
            self = .space(space)
            return
        }
        guard
            PrimaryChromaticities(colorPrimaries: primaries) != nil,
            TransferFunction(transferCharacteristics: transfer) != nil || [16, 18].contains(transfer)
        else {
            return nil
        }

        self = .codePoints(CodePoints(
            colorPrimaries: primaries,
            transferCharacteristics: transfer,
            matrixCoefficients: matrix
        ))
    }

    // The colour of an image by its matrix and tone-curve profile: the table's space where the profile describes one.
    package init(profile: MatrixProfile) {
        self = profile.colorSpace.map(Self.space) ?? .profile(profile)
    }

    // MARK: - Public
    // MARK: - Private
}
