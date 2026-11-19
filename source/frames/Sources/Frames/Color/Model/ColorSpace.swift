//
//  ColorSpace.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// A colour space a sequence is output in, media are read in and a LUT is built for, by its name in a document. Every
// space has the D65 white point.
package enum ColorSpace: String, CaseIterable, Equatable, Sendable {
    case srgb
    case displayP3 = "display-p3"
    case rec2020
    case rec709
    case rec2100PQ = "rec2100-pq"
    case rec2100HLG = "rec2100-hlg"

    // MARK: - Property
    package var primaries: ColorPrimaries {
        switch self {
        case .srgb, .rec709:
            .bt709

        case .displayP3:
            .p3D65

        case .rec2020, .rec2100PQ, .rec2100HLG:
            .bt2020
        }
    }

    // The transfer of an SDR space, nil for an HDR one, whose transfer takes display light.
    package var transferFunction: TransferFunction? {
        switch self {
        case .srgb, .displayP3:
            .sRGB

        case .rec2020:
            .bt2020

        case .rec709:
            .bt1886

        case .rec2100PQ, .rec2100HLG:
            nil
        }
    }

    package var isHighDynamicRange: Bool {
        transferFunction == nil
    }

    // The display light an HDR space holds, in cd/m², nil for an SDR space.
    package var peakLuminance: Double? {
        switch self {
        case .srgb, .displayP3, .rec2020, .rec709:
            nil

        case .rec2100PQ:
            PerceptualQuantizer.peakLuminance

        case .rec2100HLG:
            HybridLogGamma.nominalPeakLuminance
        }
    }

    // The code points a video in this space is tagged with.
    package var codePoints: CodePoints {
        switch self {
        case .srgb:
            CodePoints(colorPrimaries: 1, transferCharacteristics: 13, matrixCoefficients: 1)

        case .displayP3:
            CodePoints(colorPrimaries: 12, transferCharacteristics: 13, matrixCoefficients: 1)

        case .rec2020:
            CodePoints(colorPrimaries: 9, transferCharacteristics: 14, matrixCoefficients: 9)

        case .rec709:
            CodePoints(colorPrimaries: 1, transferCharacteristics: 1, matrixCoefficients: 1)

        case .rec2100PQ:
            CodePoints(colorPrimaries: 9, transferCharacteristics: 16, matrixCoefficients: 9)

        case .rec2100HLG:
            CodePoints(colorPrimaries: 9, transferCharacteristics: 18, matrixCoefficients: 9)
        }
    }

    // MARK: - Initializer
    // The space a picture tagged with these code points is in, nil for a pair outside the table. A code point left
    // out or written as 2 (unspecified) is taken as `srgb`'s, so an untagged picture is `srgb`.
    package init?(
        colorPrimaries: Int?,
        transferCharacteristics: Int?
    ) {
        let primaries = colorPrimaries.flatMap { $0 == 2 ? nil : $0 } ?? 1
        let transfer = transferCharacteristics.flatMap { $0 == 2 ? nil : $0 } ?? 13
        let bt709Transfers = [1, 6, 14, 15]

        switch (primaries, transfer) {
        case (1, 13):
            self = .srgb

        case (12, 13):
            self = .displayP3

        case let (9, transfer) where bt709Transfers.contains(transfer):
            self = .rec2020

        case let (1, transfer) where bt709Transfers.contains(transfer):
            self = .rec709

        case (9, 16):
            self = .rec2100PQ

        case (9, 18):
            self = .rec2100HLG

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
