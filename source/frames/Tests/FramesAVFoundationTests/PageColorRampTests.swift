//
//  PageColorRampTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

// The ramp check on the cases the probe of Core Graphics measured (FRAMES-26 Notes): spaces it draws by the formula
// pass, and spaces it draws otherwise, or that have no formula, are refused.
@Suite("PageColorRamp Tests")
struct PageColorRampTests {
    // MARK: - Property
    private static let d50: PDFValue = .array([.real(0.9642), .integer(1), .real(0.8249)])
    private static let d65: PDFValue = .array([.real(0.3127 / 0.3290), .integer(1), .real(0.3583 / 0.3290)])
    // The sRGB primaries in CIE XYZ at a D65 white, as a CalRGB Matrix writes them.
    private static let srgbMatrix: PDFValue = .array([
        0.4124564, 0.2126729, 0.0193339, 0.3575761, 0.7151522, 0.1191920, 0.1804375, 0.0721750, 0.9503041
    ].map(PDFValue.real))
    // The sRGB primaries adapted by Bradford to the D50 white, so that its columns add up to `d50`.
    private static let srgbMatrixAtD50: PDFValue = {
        let matrix = ColorMatrix(
            bradfordFrom: RGB(red: 0.3127 / 0.3290, green: 1, blue: 0.3583 / 0.3290),
            to: RGB(red: 0.9642, green: 1, blue: 0.8249)
        ).multiplied(by: ColorMatrix(normalizedPrimaryOf: .bt709))

        return .array((0..<3).flatMap { column in (0..<3).map { row in PDFValue.real(matrix.rows[row][column]) } })
    }()
    // A sampled tint transform of two samples, (0, 0, 0) and (1, 128 / 255, 0).
    private static let sampledTint = PDFValue.stream([
        "FunctionType": .integer(0),
        "Domain": .array([.integer(0), .integer(1)]),
        "Range": .array([.integer(0), .integer(1), .integer(0), .integer(1), .integer(0), .integer(1)]),
        "Size": .array([.integer(2)]),
        "BitsPerSample": .integer(8)
    ], Data([0, 0, 0, 255, 128, 0]))

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a space Core Graphics draws by its formula passes",
        arguments: [
            PDFValue.name("DeviceRGB"),
            .name("DeviceGray"),
            calGray(gamma: 1),
            calGray(gamma: 2.2),
            calRGB(gamma: 2.2, white: d50, matrix: srgbMatrixAtD50),
            lab(range: [-127.5, 127.5, -127.5, 127.5]),
            icc(CGColorSpace(name: CGColorSpace.displayP3)?.copyICCData() as Data?, components: 3),
            icc(ICCProfileWriter.grayProfile(curve: ICCProfileWriter.parametric(functionType: 0, parameters: [1])), components: 1),
            .array([.name("Indexed"), .name("DeviceRGB"), .integer(1), .string(Data([255, 0, 0, 0, 128, 255]))]),
            separation(alternate: .name("DeviceRGB")),
            separation(alternate: .name("DeviceRGB"), tint: sampledTint),
            separation(alternate: .name("DeviceRGB"), tint: calculatorTint("{ dup 0.5 mul 0 }", inputs: 1)),
            .array([
                .name("DeviceN"),
                .array([.name("Spot"), .name("Other")]),
                .name("DeviceRGB"),
                calculatorTint("{ 0 }", inputs: 2)
            ]),
            .name("Pattern")
        ]
    )
    func passes(_ written: PDFValue) {
        // Given
        let sut = PageColorSpace(written)

        // When
        let fault = PageColorRamp.fault(of: sut, written: written)

        // Then
        #expect(fault == nil)
    }

    @Test(
        "a space Core Graphics draws otherwise than its formula is refused",
        arguments: [
            calGray(gamma: 1.8),
            calRGB(gamma: 2.4, white: d50, matrix: srgbMatrixAtD50),
            calRGB(gamma: 2.2, white: d65, matrix: srgbMatrix),
            lab(range: [-100, 100, -100, 100]),
            icc(ICCProfileWriter.grayProfile(curve: ICCProfileWriter.parametric(functionType: 0, parameters: [2.4])), components: 1),
            icc(ICCProfileWriter.grayProfile(curve: ICCProfileWriter.table([0.1, 0.9])), components: 1)
        ]
    )
    func refusesDifference(_ written: PDFValue) throws {
        // Given
        let sut = PageColorSpace(written)

        // When
        let fault = try #require(PageColorRamp.fault(of: sut, written: written))

        // Then
        #expect(fault.reason.contains("which Core Graphics draws"))
    }

    @Test(
        "a space with no formula is refused without a ramp",
        arguments: [
            PDFValue.name("DeviceCMYK"),
            icc(CGColorSpace(name: CGColorSpace.genericCMYK)?.copyICCData() as Data?, components: 4),
            .array([.name("Indexed"), .name("DeviceCMYK"), .integer(0), .string(Data([0, 0, 0, 255]))]),
            separation(alternate: .name("DeviceCMYK"))
        ]
    )
    func refusesNoFormula(_ written: PDFValue) throws {
        // Given
        let sut = PageColorSpace(written)

        // When
        let fault = try #require(PageColorRamp.fault(of: sut, written: written))

        // Then
        #expect(fault.reason.contains("no formula is fixed"))
    }

    // MARK: - Private
    private static func calGray(gamma: Double) -> PDFValue {
        .array([.name("CalGray"), .dictionary(["WhitePoint": d50, "Gamma": .real(gamma)])])
    }

    // A CalRGB space of the sRGB primaries. Core Graphics draws it at a D65 white 2.4e-4 of linear light from the
    // formula, on a primary alone, and at a D50 white within the tolerance.
    private static func calRGB(
        gamma: Double,
        white: PDFValue,
        matrix: PDFValue
    ) -> PDFValue {
        .array([.name("CalRGB"), .dictionary([
            "WhitePoint": white,
            "Gamma": .array([.real(gamma), .real(gamma), .real(gamma)]),
            "Matrix": matrix
        ])])
    }

    private static func lab(range: [Double]) -> PDFValue {
        .array([.name("Lab"), .dictionary(["WhitePoint": d50, "Range": .array(range.map(PDFValue.real))])])
    }

    private static func icc(
        _ profile: Data?,
        components: Int
    ) -> PDFValue {
        .array([.name("ICCBased"), .stream(["N": .integer(components)], profile ?? Data())])
    }

    // A PostScript calculator tint transform of `inputs` tints into three components.
    private static func calculatorTint(
        _ program: String,
        inputs: Int
    ) -> PDFValue {
        .stream([
            "FunctionType": .integer(4),
            "Domain": .array(Array(repeating: [PDFValue.integer(0), .integer(1)], count: inputs).flatMap { $0 }),
            "Range": .array([.integer(0), .integer(1), .integer(0), .integer(1), .integer(0), .integer(1)])
        ], Data(program.utf8))
    }

    private static func separation(
        alternate: PDFValue,
        tint: PDFValue
    ) -> PDFValue {
        .array([.name("Separation"), .name("Spot"), alternate, tint])
    }

    // A spot colour whose tint t is (t, t / 2, 0) in the alternate space, or (t, 0, 0, 0) in a CMYK one.
    private static func separation(alternate: PDFValue) -> PDFValue {
        let isCMYK = alternate == .name("DeviceCMYK")
        let end: [PDFValue] = isCMYK ? [.integer(1), .integer(0), .integer(0), .integer(0)] : [.integer(1), .real(0.5), .integer(0)]
        let start = [PDFValue](repeating: .integer(0), count: end.count)

        return .array([
            .name("Separation"),
            .name("Spot"),
            alternate,
            .dictionary([
                "FunctionType": .integer(2),
                "Domain": .array([.integer(0), .integer(1)]),
                "C0": .array(start),
                "C1": .array(end),
                "N": .integer(1)
            ])
        ])
    }
}
