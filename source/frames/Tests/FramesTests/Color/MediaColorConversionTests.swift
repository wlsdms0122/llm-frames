//
//  MediaColorConversionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

@testable import Frames
import Testing

@Suite("MediaColorConversion Tests")
struct MediaColorConversionTests {
    // MARK: - Property
    // Every media colour whose conversion decodes a transfer channel by channel: the SDR spaces of the table other than
    // `srgb`, and code points outside the table, one for each SDR transfer.
    private static let colors: [MediaColor] = [
        .space(.displayP3),
        .space(.rec709),
        .space(.rec2020),
        codePoints(primaries: 12, transfer: 1),
        codePoints(primaries: 12, transfer: 4),
        codePoints(primaries: 1, transfer: 5),
        codePoints(primaries: 6, transfer: 7),
        codePoints(primaries: 1, transfer: 8),
        codePoints(primaries: 1, transfer: 9),
        codePoints(primaries: 1, transfer: 10),
        codePoints(primaries: 1, transfer: 11),
        codePoints(primaries: 1, transfer: 12),
        codePoints(primaries: 9, transfer: 13),
        codePoints(primaries: 10, transfer: 17)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("the working value of every half-float channel is the scalar formula's, bit for bit", arguments: colors)
    func convertsHalfFloats(color: MediaColor) {
        // Given
        let sut = MediaColorConversion(color)

        // When
        let mismatches = (0...UInt16.max).filter { bits in
            let encoded = Self.encoded(at: bits)
            return !Self.isSame(sut.working(encoded), Self.scalarWorking(of: color, encoded))
        }

        // Then
        #expect(mismatches.isEmpty)
    }

    @Test(
        "a premultiplied picture converts to the scalar formula's bits at every alpha",
        arguments: colors,
        [1, 0.5, 0.25, 0.3, 0.75, 0] as [Float]
    )
    func convertsPremultipliedPicture(
        color: MediaColor,
        alpha: Float
    ) {
        // Given
        let sut = MediaColorConversion(color)
        let samples = (0...UInt16.max).flatMap { bits in
            let encoded = Self.encoded(at: bits)
            return [
                Float(encoded.red) * alpha,
                Float(encoded.green) * alpha,
                Float(encoded.blue) * alpha,
                alpha
            ]
        }
        var converted = samples
        var expected = samples

        // When
        converted.withUnsafeMutableBufferPointer { $0.convertColors { sut.working($0) } }
        expected.withUnsafeMutableBufferPointer { $0.convertColors { Self.scalarWorking(of: color, $0) } }

        // Then
        #expect(converted.map(\.bitPattern) == expected.map(\.bitPattern))
    }

    @Test("the form a report names is the one the conversion converts by: srgb as it is, a space of the table, a transfer outside it, PQ for transfer 16, HLG for 18, and a profile", arguments: [
        (MediaColor.space(.srgb), WorkingConversion.identity),
        (.space(.displayP3), .space(.displayP3)),
        (.space(.rec2100PQ), .space(.rec2100PQ)),
        (codePoints(primaries: 1, transfer: 8), .transfer),
        (codePoints(primaries: 1, transfer: 16), .perceptualQuantizer),
        (codePoints(primaries: 12, transfer: 18), .hybridLogGamma),
        (.profile(MatrixProfile(greyCurve: .gamma(1.8))), .profile)
    ])
    func namesForm(
        color: MediaColor,
        form: WorkingConversion
    ) {
        // Given
        let sut = MediaColorConversion(color)

        // Then
        #expect(sut.workingConversion == form)
    }

    // MARK: - Private
    private static func codePoints(
        primaries: Int,
        transfer: Int
    ) -> MediaColor {
        .codePoints(CodePoints(colorPrimaries: primaries, transferCharacteristics: transfer, matrixCoefficients: 1))
    }

    // Each channel a half-float value, the three channels together taking every bit pattern across the 65536 pixels.
    private static func encoded(at bits: UInt16) -> RGB {
        RGB(
            red: Double(Float16(bitPattern: bits)),
            green: Double(Float16(bitPattern: bits &+ 21_845)),
            blue: Double(Float16(bitPattern: bits &+ 43_690))
        )
    }

    // The media formula with each channel decoded by its transfer: the transfer's decode, the matrix to linear sRGB and
    // the sRGB encode.
    private static func scalarWorking(
        of color: MediaColor,
        _ encoded: RGB
    ) -> RGB {
        let transfer: TransferFunction
        let toLinearSRGB: ColorMatrix
        switch color {
        case let .space(space):
            transfer = space.transferFunction!
            toLinearSRGB = ColorMatrix(from: space.primaries, to: .bt709)

        case let .codePoints(codePoints):
            transfer = TransferFunction(transferCharacteristics: codePoints.transferCharacteristics)!
            toLinearSRGB = ColorMatrix(
                from: PrimaryChromaticities(colorPrimaries: codePoints.colorPrimaries)!,
                to: .bt709
            )

        case .profile:
            Issue.record("A profile is not a transfer's colour")
            return encoded
        }

        return TransferFunction.sRGB.encode(toLinearSRGB.applied(to: transfer.decode(encoded)))
    }

    private static func isSame(
        _ value: RGB,
        _ other: RGB
    ) -> Bool {
        value.red.bitPattern == other.red.bitPattern
            && value.green.bitPattern == other.green.bitPattern
            && value.blue.bitPattern == other.blue.bitPattern
    }
}
