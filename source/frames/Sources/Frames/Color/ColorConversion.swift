//
//  ColorConversion.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// Converts between working values and the encoded values of one colour space, as FRAMES-26 gives: a working value in
// its encoded form, red, green and blue on BT.709 primaries, taken to linear light by the extended sRGB transfer, to
// the space's primaries by matrix, and encoded by the space's transfer. An HDR space holds display light, 203 cd/m²
// for a working value of 1. Alpha is not taken: a picture's colour is unpremultiplied before a conversion.
package struct ColorConversion: Equatable, Sendable {
    // MARK: - Property
    // Display light of a working value of 1, the reference white of BT.2408.
    package static let referenceWhite = 203.0

    private static let toBT2020 = ColorMatrix(from: .bt709, to: .bt2020)
    private static let fromBT2020 = ColorMatrix(from: .bt2020, to: .bt709)

    package let space: ColorSpace
    private let toSpace: ColorMatrix
    private let fromSpace: ColorMatrix

    // MARK: - Initializer
    package init(space: ColorSpace) {
        self.space = space
        self.toSpace = ColorMatrix(from: .bt709, to: space.primaries)
        self.fromSpace = ColorMatrix(from: space.primaries, to: .bt709)
    }

    // MARK: - Public
    // The space's encoded value of a working value. An SDR value is not clipped; HDR display light is clipped to the
    // space's range before it is encoded.
    package func encoded(_ working: RGB) -> RGB {
        switch space {
        case .srgb:
            return working

        case .displayP3, .rec2020, .rec709:
            return transferFunction.encode(toSpace.applied(to: TransferFunction.sRGB.decode(working)))

        case .rec2100PQ:
            return PerceptualQuantizer().encoded(displayLight: displayLight(ofWorking: working))

        case .rec2100HLG:
            return HybridLogGamma().encoded(displayLight: displayLight(ofWorking: working))
        }
    }

    // The encoded value the output writes, each channel from 0 to 1: an SDR space's linear value clipped to 0 to 1
    // and then encoded, an `srgb` working value clipped to 0 to 1, and an HDR value as `encoded` gives it.
    package func output(_ working: RGB) -> RGB {
        switch space {
        case .srgb:
            return working.clipped(to: 0...1)

        case .displayP3, .rec2020, .rec709:
            let linear = toSpace.applied(to: TransferFunction.sRGB.decode(working))
            return transferFunction.encode(linear.clipped(to: 0...1))

        case .rec2100PQ, .rec2100HLG:
            return encoded(working)
        }
    }

    // The working value of the space's encoded value. An HDR value is clipped to 0 to 1 first, so it names finite
    // light.
    package func working(_ encoded: RGB) -> RGB {
        switch space {
        case .srgb:
            return encoded

        case .displayP3, .rec2020, .rec709:
            return TransferFunction.sRGB.encode(fromSpace.applied(to: transferFunction.decode(encoded)))

        case .rec2100PQ, .rec2100HLG:
            return working(displayLight: displayLight(encoded))
        }
    }

    // Display light in cd/m² on BT.2020 primaries of the space's encoded value: by the PQ EOTF, or by the HLG inverse
    // OETF and its OOTF at 1000 cd/m². An SDR value's is its working value's, unclipped.
    package func displayLight(_ encoded: RGB) -> RGB {
        switch space {
        case .rec2100PQ:
            PerceptualQuantizer().displayLight(encoded: encoded)

        case .rec2100HLG:
            HybridLogGamma().displayLight(encoded: encoded)

        case .srgb, .displayP3, .rec2020, .rec709:
            Self.toBT2020.applied(to: TransferFunction.sRGB.decode(working(encoded))).scaled(by: Self.referenceWhite)
        }
    }

    // The working value of display light in cd/m² on BT.2020 primaries, unclipped.
    package func working(displayLight: RGB) -> RGB {
        TransferFunction.sRGB.encode(Self.fromBT2020.applied(to: displayLight.scaled(by: 1 / Self.referenceWhite)))
    }

    // The working value of an HDR picture's encoded value, tone mapped to the mapping's target peak. Nothing is
    // clipped: every channel of the mapped display light is at most the target peak, and gamut is clipped at the
    // output.
    package func toneMapped(
        _ encoded: RGB,
        by toneMapping: ToneMapping
    ) -> RGB {
        working(displayLight: toneMapping.mapped(displayLight(encoded)))
    }

    // MARK: - Private
    // An SDR space's transfer; only SDR spaces reach it.
    private var transferFunction: TransferFunction {
        space.transferFunction ?? .sRGB
    }

    // The display light of a working value in an HDR space, clipped to the space's range.
    private func displayLight(ofWorking working: RGB) -> RGB {
        let light = Self.toBT2020.applied(to: TransferFunction.sRGB.decode(working)).scaled(by: Self.referenceWhite)

        return light.clipped(to: 0...space.peakLuminance)
    }
}
