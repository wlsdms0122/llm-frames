//
//  WorkingConversion.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The form of FRAMES-26 Media by which a decoder takes a picture's stored values to working values, as a run's report
// and `probe` name it (FRAMES-23 Runs): `identity` for `srgb`, whose stored values are working values, which machine
// output names `none`; a space of the table by its formulas; a video tagged outside the table by H.273's transfer and
// primaries matrix, or by PQ or HLG on primaries other than BT.2020; and an image by a matrix and tone-curve ICC
// profile that describes no space of the table. `MediaColorConversion` decides which form converts a colour.
package enum WorkingConversion: Equatable, Hashable, Sendable {
    case identity
    case space(ColorSpace)
    case transfer
    case perceptualQuantizer
    case hybridLogGamma
    case profile

    // MARK: - Property
    // The space of the table the pictures are read in, nil outside the table.
    package var colorSpace: ColorSpace? {
        switch self {
        case .identity:
            .srgb

        case let .space(space):
            space

        case .transfer, .perceptualQuantizer, .hybridLogGamma, .profile:
            nil
        }
    }

    // The name machine output gives the form.
    package var name: String {
        switch self {
        case .identity:
            "none"

        case .space:
            "space"

        case .transfer:
            "transfer"

        case .perceptualQuantizer:
            "pq"

        case .hybridLogGamma:
            "hlg"

        case .profile:
            "profile"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
