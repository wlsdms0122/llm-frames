//
//  ColorMatrixTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

@Suite("ColorMatrix Tests")
struct ColorMatrixTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the matrices between primaries are those FRAMES-26 gives to ten places",
        arguments: [
            (ColorPrimaries.bt709, ColorPrimaries.p3D65, [
                [0.8224619687, 0.1775380313, 0],
                [0.0331941989, 0.9668058011, 0],
                [0.0170826307, 0.0723974407, 0.9105199286]
            ]),
            (.p3D65, .bt709, [
                [1.2249401763, -0.2249401763, 0],
                [-0.0420569547, 1.0420569547, 0],
                [-0.0196375546, -0.0786360456, 1.0982736001]
            ]),
            (.bt709, .bt2020, [
                [0.6274038959, 0.3292830384, 0.0433130657],
                [0.0690972894, 0.9195403951, 0.0113623156],
                [0.0163914389, 0.0880133079, 0.8955952532]
            ]),
            (.bt2020, .bt709, [
                [1.6604910021, -0.5876411388, -0.0728498633],
                [-0.1245504745, 1.1328998971, -0.0083494226],
                [-0.0181507634, -0.1005788980, 1.1187296614]
            ])
        ]
    )
    func derivesConversionMatrices(
        source: ColorPrimaries,
        target: ColorPrimaries,
        expected: [[Double]]
    ) {
        // Given
        let primaries = (source, target)

        // When
        let sut = ColorMatrix(from: primaries.0, to: primaries.1)

        // Then
        for (row, expectedRow) in zip(sut.rows, expected) {
            for (value, expectedValue) in zip(row, expectedRow) {
                #expect(abs(value - expectedValue) < 1e-10)
            }
        }
    }

    @Test("a normalized primary matrix takes white to Y = 1")
    func takesWhiteToUnitLuminance() {
        // Given
        let white = RGB(red: 1, green: 1, blue: 1)

        // When
        let sut = ColorMatrix(normalizedPrimaryOf: .bt2020)

        // Then
        #expect(abs(sut.applied(to: white).green - 1) < 1e-12)
    }

    @Test("a matrix times its inverse is the identity")
    func invertsToIdentity() {
        // Given
        let matrix = ColorMatrix(normalizedPrimaryOf: .p3D65)

        // When
        let sut = matrix.multiplied(by: matrix.inverse)

        // Then
        for (row, identityRow) in zip(sut.rows, ColorMatrix.identity.rows) {
            for (value, identityValue) in zip(row, identityRow) {
                #expect(abs(value - identityValue) < 1e-12)
            }
        }
    }
}
