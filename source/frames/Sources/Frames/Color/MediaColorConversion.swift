//
//  MediaColorConversion.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// Converts a picture's encoded values to working values by its colour, as FRAMES-26 Media gives: a space of the table
// as `ColorConversion` converts it, and a colour outside the table to linear sRGB by its formulas with no gamut
// clipped. A PQ or HLG picture on primaries other than BT.2020 is HDR media: its display light is taken on its own
// primaries, the HLG OOTF weighing luminance by the Y row of their normalized primary matrix, and then taken to BT.2020
// primaries, where it is tone mapped.
package struct MediaColorConversion: Sendable {
    // MARK: - Property
    private static let displayLight = ColorConversion(space: .rec2100PQ)

    package let color: MediaColor
    private let form: Form

    // True where the conversion gives each working value back as it is, so a picture needs no conversion.
    package var isIdentity: Bool {
        color == .space(.srgb)
    }

    // The form a run's report and `probe` name the conversion by (FRAMES-23 Runs).
    package var workingConversion: WorkingConversion {
        switch form {
        case let .space(conversion):
            conversion.space == .srgb ? .identity : .space(conversion.space)

        case .transfer:
            .transfer

        case .profile:
            .profile

        case .perceptualQuantizer:
            .perceptualQuantizer

        case .hybridLogGamma:
            .hybridLogGamma
        }
    }

    package var isHighDynamicRange: Bool {
        switch form {
        case let .space(conversion):
            conversion.space.isHighDynamicRange

        case .transfer, .profile:
            false

        case .perceptualQuantizer, .hybridLogGamma:
            true
        }
    }

    // MARK: - Initializer
    package init(_ color: MediaColor) {
        self.color = color

        switch color {
        case let .space(space):
            form = .space(ColorConversion(space: space))

        case let .codePoints(codePoints):
            let chromaticities = PrimaryChromaticities(colorPrimaries: codePoints.colorPrimaries)
                ?? PrimaryChromaticities(.bt709)

            switch codePoints.transferCharacteristics {
            case 16:
                form = .perceptualQuantizer(toBT2020: ColorMatrix(from: chromaticities, to: .bt2020))

            case 18:
                let luminance = ColorMatrix(normalizedPrimaryOf: chromaticities).rows[1]
                form = .hybridLogGamma(
                    toBT2020: ColorMatrix(from: chromaticities, to: .bt2020),
                    luminance: RGB(red: luminance[0], green: luminance[1], blue: luminance[2])
                )

            default:
                form = .transfer(
                    TransferDecodeTable(
                        TransferFunction(transferCharacteristics: codePoints.transferCharacteristics) ?? .sRGB
                    ),
                    toLinearSRGB: ColorMatrix(from: chromaticities, to: .bt709)
                )
            }

        case let .profile(profile):
            form = .profile(profile, toLinearSRGB: profile.toLinearSRGB)
        }
    }

    // MARK: - Public
    // The tone mapping of an HDR picture from its source peak to `targetPeak`: for PQ the mastering display's maximum
    // luminance, or 1000 cd/m² where it has none, and for HLG 1000 cd/m². Nil for an SDR picture.
    package func toneMapping(
        masteringDisplayPeak: Double?,
        targetPeak: Double
    ) -> ToneMapping? {
        switch form {
        case let .space(conversion) where conversion.space.isHighDynamicRange:
            ToneMapping(space: conversion.space, masteringDisplayPeak: masteringDisplayPeak, targetPeak: targetPeak)

        case .perceptualQuantizer:
            ToneMapping(space: .rec2100PQ, masteringDisplayPeak: masteringDisplayPeak, targetPeak: targetPeak)

        case .hybridLogGamma:
            ToneMapping(space: .rec2100HLG, masteringDisplayPeak: nil, targetPeak: targetPeak)

        case .space, .transfer, .profile:
            nil
        }
    }

    // The working value of the picture's encoded value, an HDR one tone mapped by `toneMapping` where it is given and
    // taken as display light otherwise. An SDR picture takes no tone mapping.
    package func working(
        _ encoded: RGB,
        toneMapping: ToneMapping? = nil
    ) -> RGB {
        switch form {
        case let .space(conversion):
            guard conversion.space.isHighDynamicRange, let toneMapping else { return conversion.working(encoded) }

            return conversion.toneMapped(encoded, by: toneMapping)

        case let .transfer(decodeTable, toLinearSRGB):
            return TransferFunction.sRGB.encode(toLinearSRGB.applied(to: decodeTable.decode(encoded)))

        case let .profile(profile, toLinearSRGB):
            let linear = RGB(
                red: profile.curves[0].linear(encoded.red),
                green: profile.curves[1].linear(encoded.green),
                blue: profile.curves[2].linear(encoded.blue)
            )
            return TransferFunction.sRGB.encode(toLinearSRGB.applied(to: linear))

        case let .perceptualQuantizer(toBT2020):
            let light = toBT2020.applied(to: PerceptualQuantizer().displayLight(encoded: encoded))
            return Self.displayLight.working(displayLight: toneMapping?.mapped(light) ?? light)

        case let .hybridLogGamma(toBT2020, luminance):
            let quantizer = HybridLogGamma()
            let scene = encoded.map { quantizer.sceneLight(encoded: $0) }
            let light = toBT2020.applied(to: quantizer.displayLight(sceneLight: scene, luminanceCoefficients: luminance))
            return Self.displayLight.working(displayLight: toneMapping?.mapped(light) ?? light)
        }
    }

    // MARK: - Private
}

extension MediaColorConversion {
    private enum Form: Sendable {
        case space(ColorConversion)
        case transfer(TransferDecodeTable, toLinearSRGB: ColorMatrix)
        case profile(MatrixProfile, toLinearSRGB: ColorMatrix)
        case perceptualQuantizer(toBT2020: ColorMatrix)
        case hybridLogGamma(toBT2020: ColorMatrix, luminance: RGB)
    }
}
