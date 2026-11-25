//
//  ColorConversion.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// Converts between working values and the encoded values of one colour space, as FRAMES-26 gives: a working value in
// its encoded form, red, green and blue on BT.709 primaries, taken to linear light by the extended sRGB transfer, to
// the space's primaries by matrix, and encoded by the space's transfer. An HDR space holds display light, 203 cd/m²
// for a working value of 1. `peak` is the sequence's peak in cd/m², which an output in an HDR space is clipped to.
// Alpha is not taken: a picture's colour is unpremultiplied before a conversion.
package struct ColorConversion: Equatable, Sendable {
    // MARK: - Property
    // Display light of a working value of 1, the reference white of BT.2408.
    package static let referenceWhite = 203.0

    private static let toBT2020 = ColorMatrix(from: .bt709, to: .bt2020)
    private static let fromBT2020 = ColorMatrix(from: .bt2020, to: .bt709)

    package let space: ColorSpace
    package let peak: Double
    private let toSpace: ColorMatrix
    private let fromSpace: ColorMatrix
    // The decode of an SDR space's transfer; only SDR spaces reach it.
    private let decodeTable: TransferDecodeTable

    // MARK: - Initializer
    // `peak` is the space's own where none is given.
    package init(
        space: ColorSpace,
        peak: Double? = nil
    ) {
        self.space = space
        self.peak = peak ?? space.peakLuminance
        self.toSpace = ColorMatrix(from: .bt709, to: space.primaries)
        self.fromSpace = ColorMatrix(from: space.primaries, to: .bt709)
        self.decodeTable = TransferDecodeTable(space.transferFunction ?? .sRGB)
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

        case .rec2100PQ, .rec2100HLG:
            return encoded(displayLight: displayLight(ofWorking: working, clippedTo: space.transferRange ?? 0...peak))
        }
    }

    // The encoded value the output writes, each channel from 0 to 1: an SDR space's linear value clipped to 0 to 1
    // and then encoded, an `srgb` working value clipped to 0 to 1, and an HDR value's display light clipped to 0 to
    // `peak` and then encoded.
    package func output(_ working: RGB) -> RGB {
        switch space {
        case .srgb:
            return working.clipped(to: 0...1)

        case .displayP3, .rec2020, .rec709:
            let linear = toSpace.applied(to: TransferFunction.sRGB.decode(working))
            return transferFunction.encode(linear.clipped(to: 0...1))

        case .rec2100PQ, .rec2100HLG:
            return encoded(displayLight: displayLight(ofWorking: working, clippedTo: 0...peak))
        }
    }

    // The analysis picture's value of a frame's working value, every channel from 0 to 1 in sRGB: an SDR space's frame
    // encoded as an `srgb` output, and an HDR space's encoded as its own output and then tone mapped from `peak` to
    // reference white, so its light at `peak` is white.
    package func analysis(_ working: RGB) -> RGB {
        guard space.isHighDynamicRange else { return working.clipped(to: 0...1) }

        let mapping = ToneMapping(sourcePeak: peak, targetPeak: Self.referenceWhite)

        return toneMapped(output(working), by: mapping).clipped(to: 0...1)
    }

    // The conversion to working values as the steps a GPU runs.
    package var workingSteps: ConversionSteps {
        switch space {
        case .srgb:
            .identity

        case .displayP3, .rec2020, .rec709:
            .decodeMatrixEncode(decodeTable: decodeTable, toLinearSRGB: fromSpace)

        case .rec2100PQ, .rec2100HLG:
            .formulas
        }
    }

    // The output conversion as the steps a GPU runs.
    package var outputSteps: OutputSteps {
        switch space {
        case .srgb:
            .clip

        case .displayP3, .rec2020, .rec709:
            .decodeMatrixClipEncode(fromLinearSRGB: toSpace, transfer: transferFunction)

        case .rec2100PQ, .rec2100HLG:
            .formulas
        }
    }

    // The working value of the space's encoded value. An HDR value is clipped to 0 to 1 first, so it names finite
    // light.
    package func working(_ encoded: RGB) -> RGB {
        switch space {
        case .srgb:
            return encoded

        case .displayP3, .rec2020, .rec709:
            return TransferFunction.sRGB.encode(fromSpace.applied(to: decodeTable.decode(encoded)))

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

    // The display light of a working value in an HDR space, each channel clipped to `range`.
    private func displayLight(
        ofWorking working: RGB,
        clippedTo range: ClosedRange<Double>
    ) -> RGB {
        let light = Self.toBT2020.applied(to: TransferFunction.sRGB.decode(working)).scaled(by: Self.referenceWhite)

        return light.clipped(to: range)
    }

    // An HDR space's encoded value of display light within its transfer's range.
    private func encoded(displayLight: RGB) -> RGB {
        space == .rec2100PQ
            ? PerceptualQuantizer().encoded(displayLight: displayLight)
            : HybridLogGamma().encoded(displayLight: displayLight)
    }
}
