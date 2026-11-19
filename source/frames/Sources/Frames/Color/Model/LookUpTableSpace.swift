//
//  LookUpTableSpace.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The space a `lut` is built for, its `space` (FRAMES-15): a colour space of the table, whose encoded values the LUT
// takes and gives, or `srgb-linear`, the linear form of the working values (FRAMES-26 Working values), which is no
// colour space of the table and is never output.
package enum LookUpTableSpace: Equatable, Sendable {
    case colorSpace(ColorSpace)
    case srgbLinear

    // MARK: - Property
    // `srgb`, whose encoded values are the working values.
    package static let srgb = LookUpTableSpace.colorSpace(.srgb)

    // MARK: - Initializer
    // MARK: - Public
    // The value the LUT takes of a working value.
    package func encoded(_ working: RGB) -> RGB {
        switch self {
        case let .colorSpace(space):
            ColorConversion(space: space).encoded(working)

        case .srgbLinear:
            TransferFunction.sRGB.decode(working)
        }
    }

    // The working value of a value the LUT gives.
    package func working(_ encoded: RGB) -> RGB {
        switch self {
        case let .colorSpace(space):
            ColorConversion(space: space).working(encoded)

        case .srgbLinear:
            TransferFunction.sRGB.encode(encoded)
        }
    }

    // MARK: - Private
}

extension LookUpTableSpace: CaseIterable {
    // MARK: - Property
    package static let allCases = ColorSpace.allCases.map(Self.colorSpace) + [.srgbLinear]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

extension LookUpTableSpace: RawRepresentable {
    // MARK: - Property
    // Its name in a document.
    package var rawValue: String {
        switch self {
        case let .colorSpace(space):
            space.rawValue

        case .srgbLinear:
            "srgb-linear"
        }
    }

    // MARK: - Initializer
    package init?(rawValue: String) {
        guard let space = Self.allCases.first(where: { $0.rawValue == rawValue }) else { return nil }

        self = space
    }

    // MARK: - Public
    // MARK: - Private
}
